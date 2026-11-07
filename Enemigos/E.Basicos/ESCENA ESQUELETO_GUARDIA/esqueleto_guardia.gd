
extends CharacterBody2D

# =====================================================
# CONFIGURACIÓN DEL ENEMIGO
# =====================================================

@export var vida_maxima := 200
@export var velocidad_persecucion := 150.0
@export var gravedad := 1200.0
@export var distancia_ataque := 60.0
@export var alcance_vertical := 70.0
@export var dano_ataque := 25
@export var tiempo_entre_ataques := 1.2

# Probabilidad de bloquear un ataque recibido.
# 0.4 significa un 40 % de probabilidad.
@export_range(0.0, 1.0, 0.05) var probabilidad_bloqueo := 0.4

# Tiempo que espera después de terminar un bloqueo
# antes de poder volver a bloquear.
@export var tiempo_recuperacion_bloqueo := 0.8


# =====================================================
# VARIABLES DE ESTADO
# =====================================================

var vida_actual := 200

# Referencia al jugador detectado.
var jugador: Node2D = null

# Indica si el jugador está dentro del área de detección.
var jugador_detectado := false

# Indica si el enemigo está atacando.
var atacando := false

# Indica si el enemigo está bloqueando.
var bloqueando := false

# Controla cuándo puede volver a atacar.
var puede_atacar := true

# Controla cuándo puede volver a bloquear.
var puede_bloquear := true

# Indica si el enemigo ya murió.
var muerto := false

# Dirección hacia la que mira el enemigo.
# 1 = derecha, -1 = izquierda.
var direccion := 1

# Guarda los frames de ataque que ya causaron daño.
var frames_golpeados: Array[int] = []

# Frames de las animaciones que pueden causar daño.
const FRAMES_DANO := [1, 2, 3]


# =====================================================
# REFERENCIAS A LOS NODOS
# =====================================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_deteccion: Area2D = $AreaDeteccion

# Nodo que reproduce los pasos al correr.
@onready var audio_pasos: AudioStreamPlayer2D = $AudioPasos

# Nodo que reproduce el sonido de dolor.
@onready var audio_dolor: AudioStreamPlayer2D = $Audio_Dolor

# Nodo que reproduce el sonido de ataque.
@onready var audio_ataque: AudioStreamPlayer2D = $Audio_Ataque

# Nodo que reproduce el sonido de muerte.
@onready var audio_muerte: AudioStreamPlayer2D = $Audio_Muerte

# Nodo que reproduce el sonido de bloqueo.
@onready var audio_bloqueo: AudioStreamPlayer2D = $Audio_Bloqueo


# =====================================================
# INICIALIZACIÓN DEL ENEMIGO
# =====================================================

func _ready() -> void:
	# Restaura la vida al máximo al iniciar.
	vida_actual = vida_maxima

	# Añade el enemigo al grupo para identificarlo fácilmente.
	add_to_group("enemigos")

	# Evita que estas animaciones se repitan en bucle.
	var animaciones_sin_bucle := [
		"Animacion_Ataque",
		"Animacion_Ataque2",
		"Animacion_Bloqueo",
		"Animacion_Muerte"
	]

	for anim in animaciones_sin_bucle:
		if animated_sprite.sprite_frames.has_animation(anim):
			animated_sprite.sprite_frames.set_animation_loop(anim, false)

	# Conecta la detección de cuerpos que entran al área.
	if not area_deteccion.body_entered.is_connected(_on_body_entered):
		area_deteccion.body_entered.connect(_on_body_entered)

	# Conecta la detección de cuerpos que salen del área.
	if not area_deteccion.body_exited.is_connected(_on_body_exited):
		area_deteccion.body_exited.connect(_on_body_exited)

	# Detecta cuándo termina una animación.
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

	# Detecta los cambios de frame durante los ataques.
	if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
		animated_sprite.frame_changed.connect(_on_frame_changed)

	# Inicia al enemigo con la animación de estar quieto.
	animated_sprite.play("Animacion_Quieto")


# =====================================================
# MOVIMIENTO Y COMPORTAMIENTO PRINCIPAL
# =====================================================

func _physics_process(delta: float) -> void:
	# Si está muerto, no continúa procesando el comportamiento.
	if muerto:
		return

	# Aplica gravedad cuando el enemigo está en el aire.
	if not is_on_floor():
		velocity.y += gravedad * delta

	# Comprueba que el jugador siga existiendo.
	if not is_instance_valid(jugador):
		jugador = null
		jugador_detectado = false

	# No permite moverse horizontalmente mientras ataca o bloquea.
	if atacando or bloqueando:
		velocity.x = 0.0

	# Persigue al jugador si está detectado.
	elif jugador_detectado:
		perseguir_jugador()

	# Si no detecta al jugador, se queda quieto.
	else:
		velocity.x = 0.0

		if animated_sprite.animation != "Animacion_Quieto":
			animated_sprite.play("Animacion_Quieto")

	# Aplica el movimiento y las colisiones.
	move_and_slide()

	# Reproduce los pasos solamente mientras corre por el suelo.
	if (
		is_on_floor()
		and abs(velocity.x) > 1.0
		and not atacando
		and not bloqueando
	):
		# Evita reiniciar el sonido en cada frame.
		if not audio_pasos.playing:
			audio_pasos.play()
	else:
		# Detiene los pasos si deja de correr.
		detener_pasos()


# =====================================================
# CONTROL DEL SONIDO DE LOS PASOS
# =====================================================

func detener_pasos() -> void:
	# Detiene el audio solamente si está reproduciéndose.
	if audio_pasos.playing:
		audio_pasos.stop()


# =====================================================
# PERSECUCIÓN DEL JUGADOR
# =====================================================

func perseguir_jugador() -> void:
	# No persigue si el jugador ya no existe.
	if not is_instance_valid(jugador):
		return

	# Calcula la distancia entre el enemigo y el jugador.
	var d := jugador.global_position - global_position

	# Actualiza la dirección horizontal del enemigo.
	if d.x != 0:
		direccion = 1 if d.x > 0 else -1

	# Hace que el sprite mire hacia el jugador.
	animated_sprite.flip_h = direccion < 0

	# Si está suficientemente cerca, intenta atacar.
	if (
		abs(d.x) <= distancia_ataque
		and abs(d.y) <= alcance_vertical
	):
		velocity.x = 0.0
		atacar()

	# Si está lejos, corre hacia el jugador.
	else:
		velocity.x = velocidad_persecucion * direccion

		# Evita reiniciar la animación de correr en cada frame.
		if animated_sprite.animation != "Animacion_Correr_Ataque":
			animated_sprite.play("Animacion_Correr_Ataque")


# =====================================================
# ATAQUE DEL ENEMIGO
# =====================================================

func atacar() -> void:
	# Comprueba que pueda iniciar un ataque.
	if muerto or atacando or bloqueando or not puede_atacar:
		return

	# Detiene el sonido de los pasos.
	detener_pasos()

	# Cambia el estado del enemigo a atacando.
	atacando = true
	puede_atacar = false

	# Limpia los frames de daño del ataque anterior.
	frames_golpeados.clear()

	# Detiene el movimiento horizontal.
	velocity.x = 0.0

	# Elige aleatoriamente una de las dos animaciones de ataque.
	var anim := (
		"Animacion_Ataque"
		if randi_range(1, 2) == 1
		else "Animacion_Ataque2"
	)

	# Inicia la animación de ataque.
	animated_sprite.play(anim)

	# Reproduce el sonido del ataque desde el principio.
	if audio_ataque.stream != null:
		audio_ataque.stop()
		audio_ataque.play()


# =====================================================
# DETECCIÓN DE LOS FRAMES DE IMPACTO
# =====================================================

func _on_frame_changed() -> void:
	# Ignora los frames si el enemigo murió o no está atacando.
	if muerto or not atacando:
		return

	# Solo procesa las dos animaciones de ataque.
	if animated_sprite.animation not in [
		"Animacion_Ataque",
		"Animacion_Ataque2"
	]:
		return

	# Obtiene el frame actual de la animación.
	var frame_actual := animated_sprite.frame

	# Aplica daño únicamente en los frames definidos.
	# Evita repetir daño varias veces en el mismo frame.
	if (
		frame_actual in FRAMES_DANO
		and frame_actual not in frames_golpeados
	):
		frames_golpeados.append(frame_actual)
		hacer_dano()


# =====================================================
# DAÑO CAUSADO AL JUGADOR
# =====================================================

func hacer_dano() -> void:
	# Comprueba que el jugador siga existiendo.
	if not is_instance_valid(jugador):
		return

	# Calcula la posición relativa del jugador.
	var d := jugador.global_position - global_position

	# Comprueba la distancia y que el jugador esté delante.
	if (
		abs(d.x) <= distancia_ataque
		and abs(d.y) <= alcance_vertical
		and d.x * direccion > 0
	):
		# Llama a la función de daño del jugador si existe.
		if jugador.has_method("recibir_dano"):
			jugador.call("recibir_dano", dano_ataque)

			print(
				"Guardia causó ",
				dano_ataque,
				" de daño en el frame ",
				animated_sprite.frame
			)


# =====================================================
# FINALIZACIÓN DE LAS ANIMACIONES
# =====================================================

func _on_animation_finished() -> void:
	# Si murió, elimina al enemigo al terminar su animación de muerte.
	if muerto:
		if animated_sprite.animation == "Animacion_Muerte":
			queue_free()
		return

	# Si terminó cualquiera de los ataques, inicia la recuperación.
	if animated_sprite.animation in [
		"Animacion_Ataque",
		"Animacion_Ataque2"
	]:
		atacando = false

		# Vuelve a la animación de estar quieto.
		animated_sprite.play("Animacion_Quieto")

		# Espera antes de permitir otro ataque.
		await get_tree().create_timer(tiempo_entre_ataques).timeout

		# Reactiva el ataque si no murió durante la espera.
		if not muerto:
			puede_atacar = true

	# Si terminó el bloqueo, inicia su recuperación.
	elif animated_sprite.animation == "Animacion_Bloqueo":
		bloqueando = false

		await get_tree().create_timer(
			tiempo_recuperacion_bloqueo
		).timeout

		# No continúa si murió durante la espera.
		if muerto:
			return

		# Permite volver a bloquear.
		puede_bloquear = true

		# Reanuda la persecución si el jugador sigue detectado.
		if jugador_detectado and is_instance_valid(jugador):
			perseguir_jugador()
		else:
			animated_sprite.play("Animacion_Quieto")


# =====================================================
# DETECCIÓN DEL JUGADOR
# =====================================================

func _on_body_entered(body: Node2D) -> void:
	# Detecta únicamente cuerpos del grupo "jugador".
	if not muerto and body.is_in_group("jugador"):
		jugador = body
		jugador_detectado = true


func _on_body_exited(body: Node2D) -> void:
	# Deja de perseguir cuando el jugador sale del área.
	if body == jugador:
		jugador = null
		jugador_detectado = false


# =====================================================
# DAÑO RECIBIDO POR EL ENEMIGO
# =====================================================

func recibir_dano(cantidad: int) -> void:
	# Ignora el daño si ya murió, es inválido o está bloqueando.
	if muerto or cantidad <= 0 or bloqueando:
		return

	# Decide aleatoriamente si el enemigo bloquea el golpe.
	if puede_bloquear and randf() < probabilidad_bloqueo:
		bloqueando = true
		puede_bloquear = false
		atacando = false
		velocity.x = 0.0

		# Detiene los pasos durante el bloqueo.
		detener_pasos()

		# Reproduce la animación de bloqueo.
		animated_sprite.play("Animacion_Bloqueo")

		# Reproduce el sonido del bloqueo.
		if audio_bloqueo.stream != null:
			audio_bloqueo.stop()
			audio_bloqueo.play()

		print("¡El guardia bloqueó el ataque!")

		# No recibe daño si bloqueó el golpe.
		return

	# Reproduce el sonido de dolor cuando recibe daño real.
	if audio_dolor.stream != null:
		audio_dolor.stop()
		audio_dolor.play()

	# Resta la cantidad de daño sin permitir vida negativa.
	vida_actual = max(vida_actual - cantidad, 0)

	print(
		"Guardia recibió ",
		cantidad,
		" de daño. Vida: ",
		vida_actual,
		"/",
		vida_maxima
	)

	# Si la vida llega a cero, muere.
	if vida_actual <= 0:
		morir()


# =====================================================
# COMPATIBILIDAD CON EL NOMBRE DE FUNCIÓN CON Ñ
# =====================================================

func recibir_daño(cantidad: int) -> void:
	# Redirige la llamada a la función principal de daño.
	recibir_dano(cantidad)


# =====================================================
# MUERTE DEL ENEMIGO
# =====================================================

func morir() -> void:
	# Evita ejecutar la muerte más de una vez.
	if muerto:
		return

	# Cambia el estado para impedir acciones posteriores.
	muerto = true

	# Detiene completamente el movimiento.
	velocity = Vector2.ZERO

	# Cancela el ataque y el bloqueo.
	atacando = false
	bloqueando = false

	# Impide volver a atacar o bloquear.
	puede_atacar = false
	puede_bloquear = false

	# Elimina la referencia al jugador.
	jugador = null
	jugador_detectado = false

	# Detiene los sonidos de movimiento y combate.
	detener_pasos()

	if audio_ataque.playing:
		audio_ataque.stop()

	if audio_dolor.playing:
		audio_dolor.stop()

	if audio_bloqueo.playing:
		audio_bloqueo.stop()

	# Reproduce el sonido de muerte.
	if audio_muerte.stream != null:
		audio_muerte.play()

	# Desactiva el área de detección.
	area_deteccion.set_deferred("monitoring", false)
	area_deteccion.set_deferred("monitorable", false)

	# Inicia la animación de muerte.
	animated_sprite.play("Animacion_Muerte")
