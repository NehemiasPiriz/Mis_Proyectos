
extends CharacterBody2D


# Configuración de vida, movimiento y combate

@export var vida_maxima: int = 450
@export var velocidad_movimiento: float = 50.0
@export var velocidad_persecucion: float = 80.0
@export var gravedad: float = 1200.0
@export var distancia_ataque: float = 80.0
@export var alcance_vertical_ataque: float = 70.0
@export var dano_ataque: int = 150
@export var tiempo_entre_ataques: float = 0.5
@export var tiempo_invulnerabilidad: float = 0.25
@export var duracion_destello: float = 0.15


# Colores utilizados para indicar que el enemigo recibió daño

const COLOR_NORMAL: Color = Color.WHITE
const COLOR_DANO: Color = Color(1.0, 0.15, 0.15, 1.0)


# Referencias a las animaciones y al área de detección

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_deteccion: Area2D = $AreaDeteccion


# Referencias a los reproductores de sonido

@onready var audio_pasos: AudioStreamPlayer2D = $Audio_Pasos
@onready var audio_ataque: AudioStreamPlayer2D = $Audio_Ataque
@onready var audio_dolor: AudioStreamPlayer2D = $Audio_Dolor
@onready var audio_muerte: AudioStreamPlayer2D = $Audio_Muerte


# Variables que controlan la vida y el estado del Minotauro

var vida_actual: int = 450
var direccion: int = 1
var jugador: Node2D = null

var jugador_detectado: bool = false
var atacando: bool = false
var puede_atacar: bool = true
var muerto: bool = false


# Variables utilizadas para controlar los efectos de daño

var tiempo_invulnerable: float = 0.0
var tiempo_destello: float = 0.0
var dano_aplicado: bool = false


# Variables que permiten terminar correctamente la muerte

var animacion_muerte_terminada: bool = false


# Inicializa la vida, las animaciones y las señales del personaje

func _ready() -> void:
	vida_actual = vida_maxima

	add_to_group("enemigos")
	animated_sprite.modulate = COLOR_NORMAL

	# Evita que las animaciones de ataque y muerte se repitan en bucle

	for animacion in ["Animacion_Ataque", "Animacion_Muerte"]:
		if animated_sprite.sprite_frames.has_animation(animacion):
			animated_sprite.sprite_frames.set_animation_loop(animacion, false)

	# Conecta las señales de detección del jugador

	area_deteccion.body_entered.connect(_on_body_entered)
	area_deteccion.body_exited.connect(_on_body_exited)

	# Conecta las señales que permiten controlar las animaciones

	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_frame_changed)

	# Conecta las señales que permiten controlar los sonidos

	audio_pasos.finished.connect(_on_audio_pasos_finished)
	audio_muerte.finished.connect(_on_audio_muerte_finished)

	# Inicia la animación de espera

	animated_sprite.play("Animacion_Quieto")


# Controla la gravedad, el movimiento, los temporizadores y los estados

func _physics_process(delta: float) -> void:
	if muerto:
		return

	# Aplica gravedad cuando el Minotauro no está en el suelo

	if not is_on_floor():
		velocity.y += gravedad * delta

	# Actualiza el tiempo de invulnerabilidad y el destello de daño

	tiempo_invulnerable = maxf(tiempo_invulnerable - delta, 0.0)
	tiempo_destello = maxf(tiempo_destello - delta, 0.0)

	# Devuelve el color original cuando termina el destello

	if tiempo_destello <= 0.0:
		animated_sprite.modulate = COLOR_NORMAL

	# Comprueba que el jugador siga existiendo

	if not is_instance_valid(jugador):
		jugador = null
		jugador_detectado = false

	# Decide si debe quedarse quieto, perseguir o patrullar

	if atacando:
		velocity.x = 0.0
	elif jugador_detectado:
		perseguir_jugador()
	else:
		patrullar()

	# Aplica el movimiento y las colisiones del personaje

	move_and_slide()

	# Cambia de dirección cuando choca con una pared durante la patrulla

	if not jugador_detectado and is_on_wall():
		direccion *= -1
		animated_sprite.flip_h = direccion < 0

	# Actualiza el sonido de los pasos según el movimiento

	actualizar_sonido_pasos()


# Hace que el Minotauro patrulle de un lado a otro

func patrullar() -> void:
	velocity.x = velocidad_movimiento * direccion
	animated_sprite.flip_h = direccion < 0

	# Reproduce la animación de caminar si todavía no está activa

	if animated_sprite.animation != "Animacion_Caminar":
		animated_sprite.play("Animacion_Caminar")


# Persigue al jugador y comprueba si se encuentra dentro del alcance de ataque

func perseguir_jugador() -> void:
	if not is_instance_valid(jugador):
		return

	# Calcula la distancia horizontal y vertical respecto al jugador

	var diferencia: Vector2 = jugador.global_position - global_position

	# Orienta al Minotauro hacia el jugador

	if diferencia.x != 0.0:
		direccion = 1 if diferencia.x > 0.0 else -1

	animated_sprite.flip_h = direccion < 0

	# Inicia el ataque cuando el jugador está dentro del alcance

	if absf(diferencia.x) <= distancia_ataque and absf(diferencia.y) <= alcance_vertical_ataque:
		velocity.x = 0.0
		atacar()
	else:
		# Avanza hacia el jugador cuando todavía está lejos

		velocity.x = velocidad_persecucion * direccion

		if animated_sprite.animation != "Animacion_Caminar":
			animated_sprite.play("Animacion_Caminar")


# Inicia el ataque y reproduce su sonido

func atacar() -> void:
	if muerto or atacando or not puede_atacar:
		return

	if not is_instance_valid(jugador):
		return

	atacando = true
	puede_atacar = false
	dano_aplicado = false
	velocity.x = 0.0

	# Detiene los pasos para que no se mezclen con el sonido del ataque

	audio_pasos.stop()

	# Reproduce el sonido del ataque desde el principio

	if audio_ataque.stream != null:
		audio_ataque.stop()
		audio_ataque.play()

	# Inicia la animación de ataque

	animated_sprite.play("Animacion_Ataque")


# Detecta el frame exacto en el que debe aplicarse el daño

func _on_frame_changed() -> void:
	if muerto or not atacando or dano_aplicado:
		return

	# Aplica el daño una sola vez al llegar al frame 3

	if animated_sprite.animation == "Animacion_Ataque" and animated_sprite.frame == 3:
		dano_aplicado = true
		hacer_dano()


# Comprueba la distancia y aplica el daño al jugador

func hacer_dano() -> void:
	if not is_instance_valid(jugador):
		return

	# Calcula la posición del jugador respecto al Minotauro

	var diferencia: Vector2 = jugador.global_position - global_position

	# Comprueba el alcance y que el jugador esté delante del ataque

	var dentro_del_alcance: bool = (
		absf(diferencia.x) <= distancia_ataque
		and absf(diferencia.y) <= alcance_vertical_ataque
		and diferencia.x * direccion > 0.0
	)

	if not dentro_del_alcance:
		return

	# Llama al método de daño del jugador si existe

	if jugador.has_method("recibir_dano"):
		jugador.call("recibir_dano", dano_ataque)
		print("Minotauro causó ", dano_ataque, " de daño.")


# Controla el final de las animaciones de ataque y muerte

func _on_animation_finished() -> void:
	# Espera a que termine la animación de muerte antes de eliminar al enemigo

	if muerto:
		if animated_sprite.animation == "Animacion_Muerte":
			animacion_muerte_terminada = true
			finalizar_muerte_si_corresponde()
		return

	# Finaliza el ataque y prepara al Minotauro para volver a actuar

	if animated_sprite.animation == "Animacion_Ataque":
		atacando = false
		animated_sprite.play("Animacion_Quieto")

		# Espera el tiempo configurado antes de permitir otro ataque

		await get_tree().create_timer(tiempo_entre_ataques).timeout

		if not muerto:
			puede_atacar = true


# Detecta cuándo el jugador entra en el área de detección

func _on_body_entered(body: Node2D) -> void:
	if muerto:
		return

	if body.is_in_group("jugador"):
		jugador = body
		jugador_detectado = true


# Detecta cuándo el jugador abandona el área de detección

func _on_body_exited(body: Node2D) -> void:
	if body == jugador:
		jugador = null
		jugador_detectado = false


# Reduce la vida del Minotauro y reproduce el sonido de dolor

func recibir_dano(cantidad: int) -> void:
	# Impide recibir daño si está muerto, es inválido o está protegido

	if muerto or cantidad <= 0 or tiempo_invulnerable > 0.0:
		return

	# Reduce la vida sin permitir que el valor sea negativo

	vida_actual = maxi(vida_actual - cantidad, 0)

	# Activa la protección temporal y el destello visual

	tiempo_invulnerable = tiempo_invulnerabilidad
	tiempo_destello = duracion_destello
	animated_sprite.modulate = COLOR_DANO

	print("Minotauro recibió ", cantidad, " de daño. Vida: ", vida_actual, "/", vida_maxima)

	# Reproduce el sonido de dolor cuando recibe daño válido

	if audio_dolor.stream != null:
		audio_dolor.stop()
		audio_dolor.play()

	# Inicia la muerte cuando la vida llega a cero

	if vida_actual <= 0:
		morir()


# Permite recibir daño utilizando el nombre de método con ñ

func recibir_daño(cantidad: int) -> void:
	recibir_dano(cantidad)


# Detiene el movimiento y reproduce la animación y el sonido de muerte

func morir() -> void:
	if muerto:
		return

	muerto = true
	velocity = Vector2.ZERO
	atacando = false
	puede_atacar = false
	jugador = null
	jugador_detectado = false

	# Detiene los sonidos que no deben continuar durante la muerte

	audio_pasos.stop()
	audio_ataque.stop()
	audio_dolor.stop()

	# Desactiva el área para evitar nuevas detecciones

	area_deteccion.set_deferred("monitoring", false)
	area_deteccion.set_deferred("monitorable", false)

	# Restaura el color original antes de reproducir la muerte

	animated_sprite.modulate = COLOR_NORMAL

	# Reproduce el sonido de muerte desde el principio

	if audio_muerte.stream != null:
		audio_muerte.stop()
		audio_muerte.play()

	# Inicia la animación de muerte
	animated_sprite.play("Animacion_Muerte")
# Mantiene el sonido de pasos mientras el Minotauro se mueve
func actualizar_sonido_pasos() -> void:
	var esta_moviendo: bool = absf(velocity.x) > 0.1

	# No reproduce pasos durante el ataque ni después de la muerte
	if muerto or atacando or not esta_moviendo:
		audio_pasos.stop()
		return

	# Inicia el sonido cuando el personaje empieza a desplazarse
	if audio_pasos.stream != null and not audio_pasos.playing:
		audio_pasos.play()


# Reinicia el sonido de pasos si el archivo termina mientras sigue caminando
func _on_audio_pasos_finished() -> void:
	if muerto or atacando:
		return

	if absf(velocity.x) > 0.1 and audio_pasos.stream != null:
		audio_pasos.play()


# Comprueba si ya terminaron tanto la animación como el sonido de muerte
func finalizar_muerte_si_corresponde() -> void:
	if not muerto or not animacion_muerte_terminada:
		return

	# Mantiene al personaje hasta que termine el sonido de muerte
	
	if audio_muerte.playing:
		return
	# Elimina al Minotauro cuando ya terminó la animación y el sonido
	
	queue_free()
# Comprueba si el sonido de muerte terminó antes o después de la animación

func _on_audio_muerte_finished() -> void:
	finalizar_muerte_si_corresponde()
