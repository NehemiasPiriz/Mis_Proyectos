
extends CharacterBody2D


# Configuración de vida, movimiento y gravedad

@export_group("Vida y movimiento")
@export var vida_maxima: int = 450
@export var velocidad_movimiento: float = 70.0
@export var velocidad_persecucion: float = 150.0
@export var gravedad: float = 1200.0


# Configuración del combate

@export_group("Detección y combate")
@export var distancia_ataque: float = 80.0
@export var alcance_vertical_ataque: float = 70.0
@export var dano_ataque_1: int = 30
@export var dano_ataque_2: int = 40
@export var dano_ataque_3: int = 55
@export var tiempo_entre_ataques: float = 0.35
@export var tiempo_recuperacion_combo: float = 1.2
@export_range(1, 3, 1) var cantidad_ataques_combo: int = 3

@export var frames_dano_ataque_1: Array[int] = [1, 2]
@export var frames_dano_ataque_2: Array[int] = [2, 3]
@export var frames_dano_ataque_3: Array[int] = [2, 3]


# Configuración del bloqueo

@export_group("Bloqueo")
@export_range(0.0, 1.0, 0.05) var probabilidad_bloqueo: float = 0.35
@export var tiempo_recuperacion_bloqueo: float = 0.8


# Configuración del daño recibido

@export_group("Daño recibido")
@export var tiempo_invulnerabilidad: float = 0.25


# Configuración de la patrulla

@export_group("Patrulla")
@export var invertir_direccion_al_chocar: bool = true
@export var distancia_patruya: float = 180.0


# Colores del personaje

const COLOR_NORMAL: Color = Color.WHITE


# Variables de estado

var vida_actual: int
var direccion: int = 1
var jugador: Node2D = null
var jugador_detectado: bool = false

var atacando: bool = false
var bloqueando: bool = false
var muerto: bool = false

var puede_atacar: bool = true
var puede_bloquear: bool = true

var ataque_actual: int = 0
var combo_en_curso: bool = false

var frames_golpeados: Array[int] = []
var jugador_golpeado: bool = false

var tiempo_invulnerable: float = 0.0
var version_accion: int = 0
var posicion_inicio: Vector2

var animacion_muerte_terminada: bool = false


# Referencias a los nodos

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_deteccion: Area2D = $AreaDeteccion

@onready var audio_ataque: AudioStreamPlayer2D = get_node_or_null("Audio_Ataque")
@onready var audio_pasos: AudioStreamPlayer2D = get_node_or_null("Audio_Pasos")
@onready var audio_dolor: AudioStreamPlayer2D = get_node_or_null("Audio_Dolor")
@onready var audio_muerte: AudioStreamPlayer2D = get_node_or_null("Audio_Muerte")


# Inicialización del esqueleto

func _ready() -> void:
	vida_actual = vida_maxima
	posicion_inicio = global_position

	add_to_group("enemigos")
	animated_sprite.modulate = COLOR_NORMAL

	configurar_animaciones()
	conectar_senales()

	animated_sprite.play("Animacion_Caminar")


# Configuración de las animaciones

func configurar_animaciones() -> void:
	var animaciones := [
		"Animacion_Caminar",
		"Animacion_Ataque",
		"Animacion_Ataque2",
		"Animacion_Ataque3",
		"Animacion_Bloqueo",
		"Animacion_Muerte"
	]

	for animacion in animaciones:
		if animated_sprite.sprite_frames.has_animation(animacion):
			animated_sprite.sprite_frames.set_animation_loop(
				animacion,
				animacion == "Animacion_Caminar"
			)
		else:
			push_warning("Falta la animación: " + animacion)


# Conexión de las señales

func conectar_senales() -> void:
	if not area_deteccion.body_entered.is_connected(_on_body_entered):
		area_deteccion.body_entered.connect(_on_body_entered)

	if not area_deteccion.body_exited.is_connected(_on_body_exited):
		area_deteccion.body_exited.connect(_on_body_exited)

	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

	if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
		animated_sprite.frame_changed.connect(_on_frame_changed)

	if audio_pasos != null:
		if not audio_pasos.finished.is_connected(_on_audio_pasos_finished):
			audio_pasos.finished.connect(_on_audio_pasos_finished)

	if audio_muerte != null:
		if not audio_muerte.finished.is_connected(_on_audio_muerte_finished):
			audio_muerte.finished.connect(_on_audio_muerte_finished)


# Movimiento principal

func _physics_process(delta: float) -> void:
	if muerto:
		return

	if not is_on_floor():
		velocity.y += gravedad * delta

	tiempo_invulnerable = maxf(tiempo_invulnerable - delta, 0.0)

	if not is_instance_valid(jugador):
		jugador = null
		jugador_detectado = false

	if atacando or bloqueando:
		velocity.x = 0.0
	elif jugador_detectado:
		perseguir_jugador()
	else:
		patrullar()

	move_and_slide()

	actualizar_sonido_pasos()

	if (
		not jugador_detectado
		and not atacando
		and not bloqueando
		and invertir_direccion_al_chocar
		and is_on_wall()
	):
		direccion *= -1
		animated_sprite.flip_h = direccion < 0


# Movimiento de patrulla

func patrullar() -> void:
	if absf(global_position.x - posicion_inicio.x) >= distancia_patruya:
		direccion = -1 if global_position.x > posicion_inicio.x else 1

	velocity.x = velocidad_movimiento * direccion
	animated_sprite.flip_h = direccion < 0

	reproducir_caminar()


# Persecución del jugador

func perseguir_jugador() -> void:
	if muerto or atacando or bloqueando:
		return

	if not is_instance_valid(jugador):
		return

	var diferencia: Vector2 = jugador.global_position - global_position

	if absf(diferencia.x) > 1.0:
		direccion = 1 if diferencia.x > 0.0 else -1

	animated_sprite.flip_h = direccion < 0

	if jugador_al_alcance():
		velocity.x = 0.0

		if puede_atacar:
			iniciar_combo()
		else:
			reproducir_caminar()
	else:
		velocity.x = velocidad_persecucion * direccion
		reproducir_caminar()


# Animación de caminar

func reproducir_caminar() -> void:
	if muerto or atacando or bloqueando:
		return

	if not animated_sprite.sprite_frames.has_animation("Animacion_Caminar"):
		return

	if animated_sprite.animation != "Animacion_Caminar":
		animated_sprite.play("Animacion_Caminar")


# Comprobación del alcance del jugador

func jugador_al_alcance() -> bool:
	if not is_instance_valid(jugador):
		return false

	var diferencia: Vector2 = jugador.global_position - global_position

	return (
		absf(diferencia.x) <= distancia_ataque
		and absf(diferencia.y) <= alcance_vertical_ataque
	)


# Inicio del combo

func iniciar_combo() -> void:
	if muerto or atacando or bloqueando or not puede_atacar:
		return

	if not jugador_al_alcance():
		return

	version_accion += 1
	puede_atacar = false
	combo_en_curso = true
	ataque_actual = 1

	ejecutar_ataque()


# Ejecución del ataque correspondiente

func ejecutar_ataque() -> void:
	if muerto or bloqueando or not combo_en_curso:
		return

	if not is_instance_valid(jugador) or not jugador_al_alcance():
		finalizar_combo()
		return

	atacando = true
	velocity.x = 0.0

	frames_golpeados.clear()
	jugador_golpeado = false

	if audio_pasos != null:
		audio_pasos.stop()

	if audio_ataque != null and audio_ataque.stream != null:
		audio_ataque.stop()
		audio_ataque.play()

	match ataque_actual:
		1:
			animated_sprite.play("Animacion_Ataque")
		2:
			animated_sprite.play("Animacion_Ataque2")
		3:
			animated_sprite.play("Animacion_Ataque3")


# Daño durante los fotogramas de impacto

func _on_frame_changed() -> void:
	if muerto or not atacando:
		return

	var frames_dano: Array[int] = []
	var cantidad_dano: int = 0

	match animated_sprite.animation:
		"Animacion_Ataque":
			frames_dano = frames_dano_ataque_1
			cantidad_dano = dano_ataque_1

		"Animacion_Ataque2":
			frames_dano = frames_dano_ataque_2
			cantidad_dano = dano_ataque_2

		"Animacion_Ataque3":
			frames_dano = frames_dano_ataque_3
			cantidad_dano = dano_ataque_3

		_:
			return

	var frame_actual: int = animated_sprite.frame

	if frame_actual not in frames_dano:
		return

	if frame_actual in frames_golpeados:
		return

	frames_golpeados.append(frame_actual)
	hacer_dano(cantidad_dano)


# Aplicación del daño al jugador

func hacer_dano(cantidad: int) -> void:
	if muerto or jugador_golpeado or not jugador_al_alcance():
		return

	var diferencia_x: float = jugador.global_position.x - global_position.x

	if diferencia_x * direccion <= 0.0:
		return

	jugador_golpeado = true

	if jugador.has_method("recibir_dano"):
		jugador.call("recibir_dano", cantidad)
	elif jugador.has_method("recibir_daño"):
		jugador.call("recibir_daño", cantidad)
	else:
		push_warning("El jugador no tiene una función para recibir daño.")


# Finalización de las animaciones

func _on_animation_finished() -> void:
	if muerto:
		if animated_sprite.animation == "Animacion_Muerte":
			animacion_muerte_terminada = true
			finalizar_muerte_si_corresponde()
		return

	match animated_sprite.animation:
		"Animacion_Ataque", "Animacion_Ataque2", "Animacion_Ataque3":
			if atacando:
				continuar_combo()

		"Animacion_Bloqueo":
			if bloqueando:
				finalizar_bloqueo()


# Continuación del combo

func continuar_combo() -> void:
	if muerto or bloqueando or not combo_en_curso:
		return

	if ataque_actual >= cantidad_ataques_combo:
		finalizar_combo()
		return

	var version: int = version_accion

	await get_tree().create_timer(tiempo_entre_ataques).timeout

	if muerto or bloqueando or version != version_accion:
		return

	if not is_instance_valid(jugador) or not jugador_al_alcance():
		finalizar_combo()
		return

	ataque_actual += 1
	ejecutar_ataque()


# Finalización del combo y recuperación

func finalizar_combo() -> void:
	if muerto:
		return

	version_accion += 1

	atacando = false
	combo_en_curso = false
	ataque_actual = 0
	velocity.x = 0.0

	reproducir_caminar()

	var version: int = version_accion

	await get_tree().create_timer(tiempo_recuperacion_combo).timeout

	if muerto or bloqueando or version != version_accion:
		return

	puede_atacar = true

	if jugador_detectado and is_instance_valid(jugador):
		perseguir_jugador()


# Detección del jugador

func _on_body_entered(body: Node2D) -> void:
	if muerto or not body.is_in_group("jugador"):
		return

	jugador = body
	jugador_detectado = true


# El jugador sale del área de detección

func _on_body_exited(body: Node2D) -> void:
	if body != jugador:
		return

	jugador = null
	jugador_detectado = false


# Recepción de daño sin animación de dolor

func recibir_dano(cantidad: int) -> void:
	if muerto or cantidad <= 0 or tiempo_invulnerable > 0.0:
		return

	if bloqueando:
		return

	if puede_bloquear and randf() < probabilidad_bloqueo:
		iniciar_bloqueo()
		return

	vida_actual = maxi(vida_actual - cantidad, 0)
	tiempo_invulnerable = tiempo_invulnerabilidad

	if audio_dolor != null and audio_dolor.stream != null:
		audio_dolor.stop()
		audio_dolor.play()

	if vida_actual <= 0:
		morir()


# Compatibilidad con métodos que usan la letra ñ

func recibir_daño(cantidad: int) -> void:
	recibir_dano(cantidad)


# Inicio del bloqueo

func iniciar_bloqueo() -> void:
	if muerto or bloqueando or not puede_bloquear:
		return

	version_accion += 1

	bloqueando = true
	puede_bloquear = false

	atacando = false
	combo_en_curso = false
	ataque_actual = 0
	frames_golpeados.clear()

	velocity.x = 0.0

	if audio_pasos != null:
		audio_pasos.stop()

	if audio_ataque != null:
		audio_ataque.stop()

	animated_sprite.modulate = COLOR_NORMAL
	animated_sprite.play("Animacion_Bloqueo")


# Finalización del bloqueo y recuperación

func finalizar_bloqueo() -> void:
	if muerto or not bloqueando:
		return

	version_accion += 1
	bloqueando = false
	velocity.x = 0.0

	reproducir_caminar()

	var version: int = version_accion

	await get_tree().create_timer(tiempo_recuperacion_bloqueo).timeout

	if muerto or bloqueando or version != version_accion:
		return

	puede_bloquear = true
	puede_atacar = true

	if jugador_detectado and is_instance_valid(jugador):
		perseguir_jugador()


# Muerte del esqueleto

func morir() -> void:
	if muerto:
		return

	version_accion += 1
	muerto = true

	velocity = Vector2.ZERO

	atacando = false
	bloqueando = false
	combo_en_curso = false
	puede_atacar = false
	puede_bloquear = false

	jugador = null
	jugador_detectado = false

	area_deteccion.set_deferred("monitoring", false)
	area_deteccion.set_deferred("monitorable", false)

	var colision = get_node_or_null("CollisionShape2D")

	if colision is CollisionShape2D:
		colision.set_deferred("disabled", true)

	if audio_pasos != null:
		audio_pasos.stop()

	if audio_ataque != null:
		audio_ataque.stop()

	if audio_dolor != null:
		audio_dolor.stop()

	animacion_muerte_terminada = false

	if audio_muerte != null and audio_muerte.stream != null:
		audio_muerte.stop()
		audio_muerte.play()

	animated_sprite.modulate = COLOR_NORMAL
	animated_sprite.play("Animacion_Muerte")


# Control del sonido de pasos

func actualizar_sonido_pasos() -> void:
	if audio_pasos == null or audio_pasos.stream == null:
		return

	if muerto or atacando or bloqueando or absf(velocity.x) <= 0.1:
		audio_pasos.stop()
	elif not audio_pasos.playing:
		audio_pasos.play()


# Repetición del sonido de pasos

func _on_audio_pasos_finished() -> void:
	if muerto or atacando or bloqueando:
		return

	if absf(velocity.x) > 0.1 and audio_pasos != null and audio_pasos.stream != null:
		audio_pasos.play()


# Eliminación después de la muerte

func finalizar_muerte_si_corresponde() -> void:
	if not muerto or not animacion_muerte_terminada:
		return

	if audio_muerte != null and audio_muerte.playing:
		return

	queue_free()


# Finalización del sonido de muerte

func _on_audio_muerte_finished() -> void:
	finalizar_muerte_si_corresponde()
