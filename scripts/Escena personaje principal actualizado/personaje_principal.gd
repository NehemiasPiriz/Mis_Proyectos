extends CharacterBody2D

# Configuración del movimiento y los ataques
const SPEED = 300.0
const VELOCIDAD_CORRER = 500.0
const JUMP_VELOCITY = -500.0
const DANO_ATAQUE = 40
const TIEMPO_COMBO = 0.6
const FRAMES_ATAQUE = [3, 4, 5]
const TIEMPO_ACTIVAR_SALTO = 0.2
const ALCANCE_ATAQUE_X = 100.0
const ALCANCE_ATAQUE_Y = 70.0

# Configuración de los sonidos de pasos
const VELOCIDAD_AUDIO_CAMINAR = 1.0
const VELOCIDAD_AUDIO_CORRER = 1.5

# Variables que controlan la vida del personaje
const VIDA_MAXIMA = 350
var vida_actual = VIDA_MAXIMA
var muerto = false

# Variables que controlan el bloqueo y su protección temporal
const TIEMPO_PROTECCION_TRAS_BLOQUEO = 0.3
var bloqueando = false
var bloqueo_anterior = false
var tiempo_proteccion_bloqueo = 0.0

# Configuración del efecto visual al recibir daño
const DURACION_DESTELLO = 0.15
const COLOR_NORMAL = Color.WHITE
const COLOR_DANO = Color(1.0, 0.15, 0.15, 1.0)
var tiempo_destello = 0.0

# Variables que controlan los ataques y los combos
var ataque = false
var combo = 0
var puede_continuar_combo = false
var tiempo_combo = 0.0
var direccion_ataque = 1
var corriendo = false
var tiempo_salto = 0.0
var objetivos_golpeados: Array[Node2D] = []

# Referencias a los nodos del personaje
@onready var personaje: Node2D = $Node2D
@onready var animated_sprite: AnimatedSprite2D = $Node2D/AnimatedSprite2D
@onready var area_ataque: Area2D = $Node2D/AnimatedSprite2D/Area2D
@onready var barra_vida: Range = $BarraVida
@onready var texto_vida: Label = $TextoVida

# Referencias a los sonidos del personaje
@onready var audio_pasos: AudioStreamPlayer2D = $AudioPasos
@onready var audio_grunido: AudioStreamPlayer2D = $AudioGruñido
@onready var audio_espada: AudioStreamPlayer2D = $Audio_Espada
@onready var audio_bloqueo: AudioStreamPlayer2D = $Audio_Bloqueo
@onready var audio_salto: AudioStreamPlayer2D = $Audio_Salto
@onready var audio_dolor: AudioStreamPlayer2D = $Audio_Dolor


# Configura el personaje cuando comienza la partida
func _ready() -> void:
	add_to_group("jugador")
	area_ataque.monitoring = false

	# Configura la barra y el texto de vida
	barra_vida.min_value = 0
	barra_vida.max_value = VIDA_MAXIMA
	barra_vida.value = vida_actual
	texto_vida.text = str(vida_actual) + " / " + str(VIDA_MAXIMA)

	# Establece el color normal del personaje
	animated_sprite.modulate = COLOR_NORMAL

	# Evita que la animación de muerte se repita
	if animated_sprite.sprite_frames.has_animation("Animacion_Muerte"):
		animated_sprite.sprite_frames.set_animation_loop("Animacion_Muerte", false)

	# Detiene los sonidos y configura el sonido de caminar
	audio_pasos.stop()
	audio_pasos.pitch_scale = VELOCIDAD_AUDIO_CAMINAR
	audio_grunido.stop()
	audio_espada.stop()
	audio_bloqueo.stop()
	audio_salto.stop()
	audio_dolor.stop()


# Cambia el color del personaje a rojo cuando recibe daño
func activar_destello_dano() -> void:
	if muerto:
		return

	tiempo_destello = DURACION_DESTELLO
	animated_sprite.modulate = COLOR_DANO


# Devuelve el color del personaje a la normalidad cuando termina el destello
func actualizar_destello_dano(delta: float) -> void:
	if tiempo_destello <= 0.0:
		return

	tiempo_destello = max(tiempo_destello - delta, 0.0)

	if tiempo_destello <= 0.0:
		animated_sprite.modulate = COLOR_NORMAL


# Controla el movimiento, los ataques, los saltos y el bloqueo
func _physics_process(delta: float) -> void:
	# Impide que el personaje se mueva cuando está muerto
	if muerto:
		velocity = Vector2.ZERO
		audio_pasos.stop()
		return

	actualizar_destello_dano(delta)

	# Aplica la gravedad cuando el personaje está en el aire
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Comprueba si el jugador está bloqueando
	bloqueo_anterior = bloqueando
	bloqueando = Input.is_action_pressed("bloqueo")

	# Reduce el tiempo de protección después de bloquear
	if tiempo_proteccion_bloqueo > 0.0:
		tiempo_proteccion_bloqueo = max(tiempo_proteccion_bloqueo - delta, 0.0)

	# Activa una protección breve cuando se suelta el bloqueo
	if bloqueo_anterior and not bloqueando:
		tiempo_proteccion_bloqueo = TIEMPO_PROTECCION_TRAS_BLOQUEO

	# Mientras bloquea, cancela los ataques y detiene el movimiento horizontal
	if bloqueando:
		ataque = false
		combo = 0
		puede_continuar_combo = false
		tiempo_combo = 0.0
		area_ataque.set_deferred("monitoring", false)
		velocity.x = 0
		audio_pasos.stop()

		# Reproduce la animación de bloqueo
		if animated_sprite.animation != "Animacion_Bloqueo":
			animated_sprite.play("Animacion_Bloqueo")

		move_and_slide()
		return

	# Hace saltar al personaje y reproduce el sonido del salto
	if Input.is_action_just_pressed("Salto") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		tiempo_salto = 0.0
		audio_salto.stop()
		audio_salto.play()

	# Obtiene la dirección horizontal pulsada por el jugador
	var direction := Input.get_axis("izquierda", "derecha")

	# Gira el personaje según la dirección del movimiento
	if not ataque:
		if direction > 0:
			personaje.scale.x = 1
		elif direction < 0:
			personaje.scale.x = -1

	# Comprueba si el jugador está corriendo
	corriendo = Input.is_action_pressed("correr")

	# Calcula la velocidad horizontal según la acción realizada
	if ataque:
		velocity.x = 0
	elif corriendo and direction != 0:
		velocity.x = direction * VELOCIDAD_CORRER
	elif direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Controla cuánto tiempo queda para continuar el combo
	if puede_continuar_combo:
		tiempo_combo -= delta

		if tiempo_combo <= 0:
			puede_continuar_combo = false
			ataque = false
			combo = 0
			tiempo_combo = 0.0

	# Inicia un ataque cuando se pulsa el botón correspondiente
	if Input.is_action_just_pressed("ataque"):
		iniciar_ataque()

	# Activa o desactiva el área que detecta los golpes
	actualizar_area_ataque()

	# Selecciona la animación según el estado del personaje
	if ataque:
		pass
	elif not is_on_floor():
		tiempo_salto += delta

		# Reproduce la animación de salto después de un pequeño retraso
		if tiempo_salto >= TIEMPO_ACTIVAR_SALTO:
			animated_sprite.play("Animacion_Salto")
	elif direction != 0:
		tiempo_salto = 0.0
		animated_sprite.play("Animacion_Correr" if corriendo else "Animacion_Caminar")
	else:
		tiempo_salto = 0.0
		animated_sprite.play("Animacion_Quieto")

	# Aplica el movimiento y actualiza los sonidos de pasos
	move_and_slide()
	actualizar_sonido_pasos()


# Reproduce el sonido de pasos y modifica su velocidad al correr
func actualizar_sonido_pasos() -> void:
	var caminando = (
		is_on_floor()
		and absf(velocity.x) > 10.0
		and not ataque
		and not bloqueando
	)

	if caminando:
		audio_pasos.pitch_scale = (
			VELOCIDAD_AUDIO_CORRER if corriendo
			else VELOCIDAD_AUDIO_CAMINAR
		)

		# Evita reiniciar el sonido en cada fotograma
		if not audio_pasos.playing:
			audio_pasos.play()
	else:
		audio_pasos.stop()


# Inicia el primer ataque o continúa el combo de tres golpes
func iniciar_ataque() -> void:
	if muerto or bloqueando:
		return

	# Comprueba si se puede ejecutar el siguiente golpe del combo
	if puede_continuar_combo:
		if combo == 1:
			combo = 2
		elif combo == 2:
			combo = 3
		else:
			return

		ataque = true
		velocity.x = 0
		puede_continuar_combo = false
		tiempo_combo = 0.0
		direccion_ataque = personaje.scale.x
		objetivos_golpeados.clear()

		# Reproduce la animación del golpe correspondiente
		animated_sprite.play("Animacion_Ataque" + str(combo))

		# Reproduce el sonido de la espada
		audio_espada.stop()
		audio_espada.play()

		# Reproduce un gruñido en el tercer golpe
		if combo == 3:
			audio_grunido.stop()
			audio_grunido.play()

	# Inicia el primer golpe si no hay un ataque en curso
	elif not ataque:
		ataque = true
		velocity.x = 0
		combo = 1
		direccion_ataque = personaje.scale.x
		objetivos_golpeados.clear()

		animated_sprite.play("Animacion_Ataque1")
		audio_espada.stop()
		audio_espada.play()


# Activa el área de ataque únicamente durante los fotogramas de impacto
func actualizar_area_ataque() -> void:
	if muerto or bloqueando or not ataque:
		area_ataque.set_deferred("monitoring", false)
		return

	var golpe_activo = animated_sprite.frame in FRAMES_ATAQUE

	if area_ataque.monitoring != golpe_activo:
		area_ataque.set_deferred("monitoring", golpe_activo)

	# Busca enemigos cuando el golpe puede causar daño
	if golpe_activo:
		buscar_jefes_cercanos()


# Busca objetivos cercanos que puedan recibir daño
func buscar_jefes_cercanos() -> void:
	var escena = get_tree().current_scene

	if escena == null:
		return

	# Recorre los nodos de tipo Node2D de la escena actual
	for objetivo in escena.find_children("*", "Node2D", true, false):
		# Ignora al propio jugador, los objetivos incompatibles y los ya golpeados
		if objetivo == self or not objetivo.has_method("recibir_dano") or objetivos_golpeados.has(objetivo):
			continue

		var diferencia = objetivo.global_position - global_position

		# Comprueba si el objetivo está dentro del alcance del ataque
		if abs(diferencia.x) > ALCANCE_ATAQUE_X or abs(diferencia.y) > ALCANCE_ATAQUE_Y:
			continue

		# Comprueba que el objetivo esté delante del personaje
		if diferencia.x * direccion_ataque <= 0:
			continue

		aplicar_dano_a_objetivo(objetivo)


# Aplica daño al objetivo y evita golpearlo varias veces en el mismo ataque
func aplicar_dano_a_objetivo(objetivo: Node2D) -> void:
	if muerto or bloqueando or objetivo == self or objetivos_golpeados.has(objetivo):
		return

	if objetivo.has_method("recibir_dano"):
		objetivos_golpeados.append(objetivo)
		objetivo.call("recibir_dano", DANO_ATAQUE)
		print("Golpe confirmado. Daño: ", DANO_ATAQUE, " | Objetivo: ", objetivo.name)
	elif objetivo.has_method("recibir_daño"):
		objetivos_golpeados.append(objetivo)
		objetivo.call("recibir_daño", DANO_ATAQUE)


# Detecta cuándo termina una animación de ataque
func _on_animated_sprite_2d_animation_finished() -> void:
	if muerto:
		return

	# Permite continuar el combo después del primer o segundo golpe
	if animated_sprite.animation in ["Animacion_Ataque1", "Animacion_Ataque2"]:
		terminar_ataque(true)
	elif animated_sprite.animation == "Animacion_Ataque3":
		terminar_ataque(false)


# Finaliza el golpe y determina si se puede continuar el combo
func terminar_ataque(continuar_combo: bool) -> void:
	ataque = false
	area_ataque.set_deferred("monitoring", false)

	if continuar_combo:
		puede_continuar_combo = true
		tiempo_combo = TIEMPO_COMBO
	else:
		combo = 0
		puede_continuar_combo = false
		tiempo_combo = 0.0


# Comprueba si el personaje está protegido contra los ataques enemigos
func esta_protegido() -> bool:
	return (
		muerto
		or bloqueando
		or Input.is_action_pressed("bloqueo")
		or tiempo_proteccion_bloqueo > 0.0
	)
# Reduce la vida del personaje cuando recibe daño
func recibir_dano(cantidad: int) -> void:
	if muerto or vida_actual <= 0:
		return

	# Anula el daño si el jugador está bloqueando y reproduce el sonido del impacto
	if bloqueando or Input.is_action_pressed("bloqueo"):
		if audio_bloqueo.stream != null:
			audio_bloqueo.stop()
			audio_bloqueo.play()

		print("¡Ataque enemigo bloqueado!")
		return

	# Evita el daño durante la protección temporal posterior al bloqueo
	if tiempo_proteccion_bloqueo > 0.0:
		print("Daño evitado por protección de bloqueo.")
		return

	# Activa el efecto visual y el sonido de dolor
	activar_destello_dano()
	audio_dolor.stop()
	audio_dolor.play()

	# Actualiza la vida y la interfaz
	vida_actual = max(vida_actual - cantidad, 0)
	barra_vida.value = vida_actual
	texto_vida.text = str(vida_actual) + " / " + str(VIDA_MAXIMA)

	print("Vida del personaje: ", vida_actual, "/", VIDA_MAXIMA)

	# Mata al personaje cuando se queda sin vida
	if vida_actual <= 0:
		morir()

# Detiene al personaje y reproduce su animación de muerte
func morir() -> void:
	if muerto:
		return

	muerto = true
	velocity = Vector2.ZERO
	ataque = false
	bloqueando = false
	puede_continuar_combo = false
	combo = 0
	tiempo_proteccion_bloqueo = 0.0
	tiempo_destello = 0.0

	# Detiene todos los sonidos
	audio_pasos.stop()
	audio_grunido.stop()
	audio_espada.stop()
	audio_bloqueo.stop()
	audio_salto.stop()
	audio_dolor.stop()

	# Desactiva el área de ataque y restaura el color original
	animated_sprite.modulate = COLOR_NORMAL
	area_ataque.set_deferred("monitoring", false)
	animated_sprite.stop()

	# Reproduce la animación de muerte sin repetirla
	if animated_sprite.sprite_frames.has_animation("Animacion_Muerte"):
		animated_sprite.sprite_frames.set_animation_loop("Animacion_Muerte", false)
		animated_sprite.play("Animacion_Muerte")

	print("El personaje ha muerto.")

	# Espera a que termine la animación de muerte
	await animated_sprite.animation_finished
	velocity = Vector2.ZERO
