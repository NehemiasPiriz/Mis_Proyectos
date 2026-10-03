extends CharacterBody2D


# VARIABLES Y CONSTANTES

const SPEED = 300.0
const VELOCIDAD_CORRER = 550.0
const JUMP_VELOCITY = -500.0
const DAÑO_ATAQUE = 10

const TIEMPO_COMBO = 0.6
const FRAMES_ATAQUE = [3, 4, 5]

var ataque = false
var combo = 0
var puede_continuar_combo = false
var tiempo_combo = 0.0

var direccion_ataque = 1
var bloqueando = false
var corriendo = false


# REFERENCIAS

@onready var personaje = $Node2D
@onready var animated_sprite = $Node2D/AnimatedSprite2D
@onready var area_ataque = $Node2D/AnimatedSprite2D/Area2D


# INICIO

func _ready() -> void:
	area_ataque.monitoring = false


# FÍSICA Y MOVIMIENTO

func _physics_process(delta: float) -> void:

	# GRAVEDAD
	if not is_on_floor():
		velocity += get_gravity() * delta


	# BLOQUEO
	bloqueando = Input.is_action_pressed("bloqueo")

	if bloqueando:
		ataque = false
		combo = 0
		puede_continuar_combo = false
		tiempo_combo = 0.0
		area_ataque.monitoring = false
		velocity.x = 0
		animated_sprite.play("Animacion_Bloqueo")

		move_and_slide()
		return


	# SALTO
	if Input.is_action_just_pressed("Salto") and is_on_floor():
		velocity.y = JUMP_VELOCITY


	# MOVIMIENTO
	var direction := Input.get_axis("izquierda", "derecha")


	# DIRECCIÓN DEL PERSONAJE
	if direction > 0:
		personaje.scale.x = 1

	elif direction < 0:
		personaje.scale.x = -1


	# CORRER
	corriendo = Input.is_action_pressed("correr")

	if corriendo and direction:
		velocity.x = direction * VELOCIDAD_CORRER

	elif direction:
		velocity.x = direction * SPEED

	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)


	# COMBO
	if puede_continuar_combo:
		tiempo_combo -= delta

		if tiempo_combo <= 0:
			puede_continuar_combo = false
			ataque = false
			combo = 0
			tiempo_combo = 0.0


	# ATAQUE
	if Input.is_action_just_pressed("ataque"):
		iniciar_ataque()


	# DIRECCIÓN DEL ATAQUE
	if ataque:
		personaje.scale.x = direccion_ataque


	# HITBOX
	actualizar_area_ataque()


	# ANIMACIONES
	if ataque:
		pass

	elif not is_on_floor():

		if velocity.y < 0:
			animated_sprite.play("Animacion_Salto")
		else:
			animated_sprite.play("Animacion_Caida")

	elif direction:

		if corriendo:
			animated_sprite.play("Animacion_Correr")
		else:
			animated_sprite.play("Animacion_Caminar")

	else:
		animated_sprite.play("Animacion_Quieto")


	move_and_slide()


# ATAQUES

func iniciar_ataque() -> void:

	if puede_continuar_combo:

		if combo == 1:
			combo = 2

		elif combo == 2:
			combo = 3

		else:
			return

		ataque = true
		puede_continuar_combo = false
		tiempo_combo = 0.0
		direccion_ataque = personaje.scale.x

		animated_sprite.play("Animacion_Ataque" + str(combo))

		return


	if not ataque:
		ataque = true
		combo = 1
		direccion_ataque = personaje.scale.x

		animated_sprite.play("Animacion_Ataque1")


# AREA2D DEL ATAQUE

func actualizar_area_ataque() -> void:

	area_ataque.monitoring = false

	if not ataque:
		return

	if animated_sprite.frame in FRAMES_ATAQUE:
		area_ataque.monitoring = true


# ANIMACIÓN TERMINADA

func _on_animated_sprite_2d_animation_finished() -> void:

	if animated_sprite.animation == "Animacion_Ataque1":
		terminar_ataque(true)

	elif animated_sprite.animation == "Animacion_Ataque2":
		terminar_ataque(true)

	elif animated_sprite.animation == "Animacion_Ataque3":
		terminar_ataque(false)


# TERMINAR ATAQUE

func terminar_ataque(continuar_combo: bool) -> void:

	ataque = false
	area_ataque.monitoring = false

	if continuar_combo:
		puede_continuar_combo = true
		tiempo_combo = TIEMPO_COMBO
	else:
		combo = 0
		puede_continuar_combo = false
		tiempo_combo = 0.0
