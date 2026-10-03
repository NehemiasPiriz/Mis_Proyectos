extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# DAÑO
const DAÑO_ATAQUE = 10

# REFERENCIAS
@onready var personaje = $Node2D
@onready var animated_sprite = $Node2D/AnimatedSprite2D
@onready var area_ataque = $Node2D/AnimatedSprite2D/Area2D
# COMBO
var ataque = false
var combo = 0
# Tiempo disponible para continuar el combo
var puede_continuar_combo = false
var tiempo_combo = 0.0
const TIEMPO_COMBO = 0.6

# Dirección del ataque
var direccion_ataque = 1
# BLOQUEO
var bloqueando = false
func _ready() -> void:
	# La Area2D comienza apagada
	area_ataque.monitoring = false

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

		# Desactivar Area2D
		area_ataque.monitoring = false

		# Detener solamente el movimiento horizontal
		velocity.x = 0

		animated_sprite.play("Animacion_Bloqueo")

		move_and_slide()
		return

	# SALTO
	if Input.is_action_just_pressed("Salto") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# MOVIMIENTO
	var direction := Input.get_axis("izquierda", "derecha")
	# Dirección del personaje
	if direction > 0:
		personaje.scale.x = 1
	elif direction < 0:
		personaje.scale.x = -1
	# Movimiento
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	# TIEMPO DEL COMBO
	if puede_continuar_combo:
		tiempo_combo -= delta
		if tiempo_combo <= 0:
			puede_continuar_combo = false
			ataque = false
			combo = 0
			tiempo_combo = 0.0

			# ATAQUE
	if Input.is_action_just_pressed("ataque"):
		# ATAQUE 1
		if not ataque:
			ataque = true
			combo = 1
			direccion_ataque = personaje.scale.x
			animated_sprite.play("Animacion_Ataque1")
		# ATAQUE 2
		elif combo == 1 and puede_continuar_combo:
			combo = 2
			puede_continuar_combo = false
			tiempo_combo = 0.0
			animated_sprite.play("Animacion_Ataque2")
		# ATAQUE 3
		elif combo == 2 and puede_continuar_combo:
			combo = 3
			puede_continuar_combo = false
			tiempo_combo = 0.0
			animated_sprite.play("Animacion_Ataque3")

	# MANTENER DIRECCIÓN DURANTE EL ATAQUE
	if ataque:
		personaje.scale.x = direccion_ataque
	# ACTIVAR AREA2D DURANTE EL GOLPE
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
		animated_sprite.play("Animacion_Caminar")
	else:
		animated_sprite.play("Animacion_Quieto")
	move_and_slide()

# ACTIVAR AREA2D
func actualizar_area_ataque() -> void:
	# PARA PROBAR SI LA HITBOX FUNCIONA: print("Frame: ", animated_sprite.frame, " | Area activa: ", area_ataque.monitoring)
	# Primero apagamos el Area2D
	area_ataque.monitoring = false
	# Si no estamos atacando, no se activa
	if not ataque:
		return
	# ATAQUE 1
	if animated_sprite.animation == "Animacion_Ataque1":
		if animated_sprite.frame in [3, 4, 5]:
			area_ataque.monitoring = true
	# ATAQUE 2
	elif animated_sprite.animation == "Animacion_Ataque2":
		if animated_sprite.frame in [3, 4, 5]:
			area_ataque.monitoring = true
	# ATAQUE 3
	elif animated_sprite.animation == "Animacion_Ataque3":
		if animated_sprite.frame in [3, 4, 5]:
			area_ataque.monitoring = true

# TERMINÓ UNA ANIMACIÓN
func _on_animated_sprite_2d_animation_finished() -> void:

	# ATAQUE 1 TERMINADO
	if animated_sprite.animation == "Animacion_Ataque1":
		puede_continuar_combo = true
		tiempo_combo = TIEMPO_COMBO
	# ATAQUE 2 TERMINADO
	elif animated_sprite.animation == "Animacion_Ataque2":
		puede_continuar_combo = true
		tiempo_combo = TIEMPO_COMBO
	# ATAQUE 3 TERMINADO
	elif animated_sprite.animation == "Animacion_Ataque3":
		ataque = false
		combo = 0
		puede_continuar_combo = false
		tiempo_combo = 0.0
		# Asegurarse de que el Area2D quede apagada
		area_ataque.monitoring = false
