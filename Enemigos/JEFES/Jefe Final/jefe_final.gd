extends CharacterBody2D

# =========================
# VARIABLES DEL JEFE
# =========================

@export var vida_maxima: int = 1000
var vida_actual: int = vida_maxima

@export var velocidad_movimiento: float = 100.0
@export var velocidad_correr: float = 180.0

@export var velocidad_ataque: float = 1.5
@export var dano_ataque: int = 25

@export var gravedad: float = 1200.0

# Distancia a la que comienza a atacar
@export var distancia_ataque: float = 80.0
@export var dano_ataque1: int = 30
@export var dano_ataque2: int = 35
@export var dano_ataque3: int = 50

# =========================
# DIRECCIÓN
# =========================

var direccion := 1
var puede_girar := true
var pared_detectada := false

# =========================
# DETECCIÓN DEL JUGADOR
# =========================

var jugador_detectado: bool = false
var jugador: Node2D = null
var muerto: bool = false

# =========================
# ATAQUE
# =========================

var puede_atacar: bool = true


func _physics_process(delta):
	if muerto:
		return
	# GRAVEDAD
	if not is_on_floor():
		velocity.y += gravedad * delta

	# COMPORTAMIENTO
	if jugador_detectado and jugador != null:
		perseguir_jugador()
	else:
		patrullar()

	# APLICAR MOVIMIENTO Y ACTUALIZAR COLISIONES
	move_and_slide()

	# DETECTAR PARED DURANTE LA PATRULLA
	if not jugador_detectado:
		if is_on_wall() and not pared_detectada:
			direccion *= -1
			$AnimatedSprite2D.flip_h = direccion < 0
			pared_detectada = true
		elif not is_on_wall():
			pared_detectada = false




# =========================================================
# PATRULLAR
# =========================================================

func patrullar():
	velocity.x = velocidad_movimiento * direccion

	# Animación de caminar
	$AnimatedSprite2D.play("caminar")

	# Mirar hacia donde camina
	$AnimatedSprite2D.flip_h = direccion < 0


# =========================================================
# PERSEGUIR AL JUGADOR
# =========================================================

func perseguir_jugador():

	var distancia = global_position.distance_to(jugador.global_position)


	# Mirar hacia el jugador
	if jugador.global_position.x > global_position.x:

		direccion = 1
		$AnimatedSprite2D.flip_h = false

	else:

		direccion = -1
		$AnimatedSprite2D.flip_h = true


	# =========================
	# ATACAR
	# =========================

	if distancia <= distancia_ataque:

		velocity.x = 0

		atacar()

	else:

		# =========================
		# CORRER
		# =========================

		velocity.x = velocidad_correr * direccion

		$AnimatedSprite2D.play("correr")


# =========================================================
# ATAQUE
# =========================================================

func atacar():
	if not puede_atacar:
		return

	puede_atacar = false

	var ataque = randi_range(1, 3)

	match ataque:
		1:
			$AnimatedSprite2D.play("ataque1")
			hacer_dano(dano_ataque1)

		2:
			$AnimatedSprite2D.play("ataque2")
			hacer_dano(dano_ataque2)

		3:
			$AnimatedSprite2D.play("ataque3")
			hacer_dano(dano_ataque3)

	await get_tree().create_timer(velocidad_ataque).timeout
	puede_atacar = true


func hacer_dano(dano: int):

	if jugador == null:
		return

	if jugador.has_method("recibir_dano"):
		jugador.recibir_dano(dano)
		print("El jefe hizo ", dano, " de daño")
	else:
		print("ERROR: el jugador no tiene la función recibir_dano()")


# JUGADOR ENTRA EN EL ÁREA
func _on_areade_deteccion_body_entered(body: Node2D) -> void:
	print("ENTRÓ AL ÁREA: ", body.name)

	if body.is_in_group("jugador"):

		jugador_detectado = true
		jugador = body

		print("¡JUGADOR DETECTADO!")

# JUGADOR SALE DEL ÁREA
func _on_areade_deteccion_body_exited(body: Node2D) -> void:
	if body == jugador:

		jugador_detectado = false
		jugador = null

		print("Jugador salió del área")

# funcion para que el jefe reciba daño
func recibir_dano(cantidad: int):
	vida_actual -= cantidad
	vida_actual = max(vida_actual, 0)

	print("Vida del jefe: ", vida_actual, "/", vida_maxima)

	if vida_actual <= 0:
		morir()
#funcion para que el jefe muera
func morir():
	# Evitar que el jefe muera varias veces
	if muerto:
		return

	muerto = true

	# Detener el movimiento
	velocity = Vector2.ZERO

	# Reproducir animación de muerte
	$AnimatedSprite2D.play("muerte")

	# Esperar a que termine la animación
	await $AnimatedSprite2D.animation_finished

	# Eliminar al jefe de la escena
	print("¡El jefe ha sido derrotado!")
	queue_free()
