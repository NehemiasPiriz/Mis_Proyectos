
extends CharacterBody2D

# Movimiento y ataque
const SPEED = 300.0
const VELOCIDAD_CORRER = 450.0
const JUMP_VELOCITY = -500.0
const DANO_ATAQUE = 40
const TIEMPO_COMBO = 0.6
const FRAMES_ATAQUE = [3, 4, 5]
const TIEMPO_ACTIVAR_SALTO = 0.2
const ALCANCE_ATAQUE_X = 100.0
const ALCANCE_ATAQUE_Y = 70.0

# Vida
const VIDA_MAXIMA = 350
var vida_actual = VIDA_MAXIMA
var muerto = false

# Bloqueo
const TIEMPO_PROTECCION_TRAS_BLOQUEO = 0.3
var bloqueando = false
var bloqueo_anterior = false
var tiempo_proteccion_bloqueo = 0.0

# Efecto de daño
const DURACION_DESTELLO = 0.15
const COLOR_NORMAL = Color.WHITE
const COLOR_DANO = Color(1.0, 0.15, 0.15, 1.0)
var tiempo_destello = 0.0

# Estado
var ataque = false
var combo = 0
var puede_continuar_combo = false
var tiempo_combo = 0.0
var direccion_ataque = 1
var corriendo = false
var tiempo_salto = 0.0
var objetivos_golpeados: Array[Node2D] = []

# Referencias
@onready var personaje = $Node2D
@onready var animated_sprite = $Node2D/AnimatedSprite2D
@onready var area_ataque = $Node2D/AnimatedSprite2D/Area2D
@onready var barra_vida = $BarraVida
@onready var texto_vida: Label = $TextoVida

func _ready() -> void:
	add_to_group("jugador")
	area_ataque.monitoring = false
	barra_vida.min_value = 0
	barra_vida.max_value = VIDA_MAXIMA
	barra_vida.value = vida_actual
	animated_sprite.modulate = COLOR_NORMAL
	texto_vida.text = str(vida_actual) + " / " + str(VIDA_MAXIMA)
	if animated_sprite.sprite_frames.has_animation("Animacion_Muerte"):
		animated_sprite.sprite_frames.set_animation_loop("Animacion_Muerte", false)

	print("Personaje preparado.")

# Efecto rojo al recibir daño
func activar_destello_dano() -> void:
	if muerto:
		return
	tiempo_destello = DURACION_DESTELLO
	animated_sprite.modulate = COLOR_DANO

func actualizar_destello_dano(delta: float) -> void:
	if tiempo_destello <= 0.0:
		return
	tiempo_destello = max(tiempo_destello - delta, 0.0)
	if tiempo_destello <= 0.0:
		animated_sprite.modulate = COLOR_NORMAL

# Movimiento y física
func _physics_process(delta: float) -> void:
	if muerto:
		velocity = Vector2.ZERO
		return

	actualizar_destello_dano(delta)

	if not is_on_floor():
		velocity += get_gravity() * delta

	bloqueo_anterior = bloqueando
	bloqueando = Input.is_action_pressed("bloqueo")

	if tiempo_proteccion_bloqueo > 0.0:
		tiempo_proteccion_bloqueo = max(tiempo_proteccion_bloqueo - delta, 0.0)

	if bloqueo_anterior and not bloqueando:
		tiempo_proteccion_bloqueo = TIEMPO_PROTECCION_TRAS_BLOQUEO

	if bloqueando:
		ataque = false
		combo = 0
		puede_continuar_combo = false
		tiempo_combo = 0.0
		area_ataque.set_deferred("monitoring", false)
		velocity.x = 0

		if animated_sprite.animation != "Animacion_Bloqueo":
			animated_sprite.play("Animacion_Bloqueo")

		move_and_slide()
		return

	if Input.is_action_just_pressed("Salto") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		tiempo_salto = 0.0

	var direction := Input.get_axis("izquierda", "derecha")

	if not ataque:
		if direction > 0:
			personaje.scale.x = 1
		elif direction < 0:
			personaje.scale.x = -1

	corriendo = Input.is_action_pressed("correr")

	if ataque:
		velocity.x = 0
	elif corriendo and direction != 0:
		velocity.x = direction * VELOCIDAD_CORRER
	elif direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if puede_continuar_combo:
		tiempo_combo -= delta
		if tiempo_combo <= 0:
			puede_continuar_combo = false
			ataque = false
			combo = 0
			tiempo_combo = 0.0

	if Input.is_action_just_pressed("ataque"):
		iniciar_ataque()

	actualizar_area_ataque()

	if ataque:
		pass
	elif not is_on_floor():
		tiempo_salto += delta
		if tiempo_salto >= TIEMPO_ACTIVAR_SALTO:
			animated_sprite.play("Animacion_Salto")
	elif direction != 0:
		tiempo_salto = 0.0
		animated_sprite.play("Animacion_Correr" if corriendo else "Animacion_Caminar")
	else:
		tiempo_salto = 0.0
		animated_sprite.play("Animacion_Quieto")

	move_and_slide()

# Iniciar ataques y combos
func iniciar_ataque() -> void:
	if muerto or bloqueando:
		return

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
		animated_sprite.play("Animacion_Ataque" + str(combo))
	elif not ataque:
		ataque = true
		velocity.x = 0
		combo = 1
		direccion_ataque = personaje.scale.x
		objetivos_golpeados.clear()
		animated_sprite.play("Animacion_Ataque1")

# Actualizar hitbox
func actualizar_area_ataque() -> void:
	if muerto or bloqueando or not ataque:
		area_ataque.set_deferred("monitoring", false)
		return

	var golpe_activo = animated_sprite.frame in FRAMES_ATAQUE
	if area_ataque.monitoring != golpe_activo:
		area_ataque.set_deferred("monitoring", golpe_activo)
	if golpe_activo:
		buscar_jefes_cercanos()

# Buscar objetivos
func buscar_jefes_cercanos() -> void:
	var escena = get_tree().current_scene
	if escena == null:
		return

	for objetivo in escena.find_children("*", "Node2D", true, false):
		if objetivo == self or not objetivo.has_method("recibir_dano") or objetivos_golpeados.has(objetivo):
			continue

		var diferencia = objetivo.global_position - global_position
		if abs(diferencia.x) > ALCANCE_ATAQUE_X or abs(diferencia.y) > ALCANCE_ATAQUE_Y:
			continue
		if diferencia.x * direccion_ataque <= 0:
			continue

		aplicar_dano_a_objetivo(objetivo)

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

# Fin de animación de ataque
func _on_animated_sprite_2d_animation_finished() -> void:
	if muerto:
		return

	if animated_sprite.animation in ["Animacion_Ataque1", "Animacion_Ataque2"]:
		terminar_ataque(true)
	elif animated_sprite.animation == "Animacion_Ataque3":
		terminar_ataque(false)

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

# Protección
func esta_protegido() -> bool:
	return muerto or bloqueando or Input.is_action_pressed("bloqueo") or tiempo_proteccion_bloqueo > 0.0

# Recibir daño
func recibir_dano(cantidad: int) -> void:
	texto_vida.text = str(vida_actual) + " / " + str(VIDA_MAXIMA)
	if muerto or vida_actual <= 0:
		return
	if esta_protegido():
		print("Daño bloqueado.")
		return

	activar_destello_dano()
	vida_actual = max(vida_actual - cantidad, 0)
	barra_vida.value = vida_actual
	print("Vida del personaje: ", vida_actual, "/", VIDA_MAXIMA)

	if vida_actual <= 0:
		morir()

func recibir_daño(cantidad: int) -> void:
	recibir_dano(cantidad)

# Muerte
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

	animated_sprite.modulate = COLOR_NORMAL
	area_ataque.set_deferred("monitoring", false)
	animated_sprite.stop()
	animated_sprite.sprite_frames.set_animation_loop("Animacion_Muerte", false)
	animated_sprite.play("Animacion_Muerte")
	print("El personaje ha muerto.")

	await animated_sprite.animation_finished
	velocity = Vector2.ZERO
