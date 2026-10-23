
extends CharacterBody2D

# Configuración de vida, movimiento y combate
@export var vida_maxima := 450
@export var velocidad_movimiento := 70.0
@export var velocidad_persecucion := 130.0
@export var gravedad := 1200.0
@export var distancia_ataque := 80.0
@export var alcance_vertical_ataque := 70.0
@export var dano_ataque := 150
@export var tiempo_entre_ataques := 0.5
@export var tiempo_invulnerabilidad := 0.25
@export var duracion_destello := 0.15

# Colores para el efecto visual al recibir daño
const COLOR_NORMAL := Color.WHITE
const COLOR_DANO := Color(1, 0.15, 0.15, 1)

# Variables que controlan los estados del Minotauro
var vida_actual := 450
var direccion := 1
var jugador: Node2D
var jugador_detectado := false
var atacando := false
var puede_atacar := true
var muerto := false
var tiempo_invulnerable := 0.0
var tiempo_destello := 0.0
var dano_aplicado := false

# Referencias a los nodos de la escena
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_deteccion: Area2D = $AreaDeteccion

# Inicializa al enemigo y conecta las señales necesarias
func _ready() -> void:
	vida_actual = vida_maxima
	add_to_group("enemigos")
	animated_sprite.modulate = COLOR_NORMAL

	# Evita que los ataques y la muerte se repitan en bucle
	for anim in ["Animacion_Ataque", "Animacion_Muerte"]:
		if animated_sprite.sprite_frames.has_animation(anim):
			animated_sprite.sprite_frames.set_animation_loop(anim, false)

	# Detecta cuándo entra o sale el jugador y cuándo cambian los frames
	area_deteccion.body_entered.connect(_on_body_entered)
	area_deteccion.body_exited.connect(_on_body_exited)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.play("Animacion_Quieto")

# Controla la gravedad, el movimiento y los estados del enemigo
func _physics_process(delta: float) -> void:
	if muerto:
		return

	if not is_on_floor():
		velocity.y += gravedad * delta

	# Actualiza los temporizadores de protección y destello
	tiempo_invulnerable = max(tiempo_invulnerable - delta, 0.0)
	tiempo_destello = max(tiempo_destello - delta, 0.0)

	if tiempo_destello == 0.0:
		animated_sprite.modulate = COLOR_NORMAL

	# Comprueba que el jugador siga existiendo
	if not is_instance_valid(jugador):
		jugador = null
		jugador_detectado = false

	# Elige entre perseguir y patrullar sin interrumpir el ataque
	if atacando:
		velocity.x = 0.0
	elif jugador_detectado:
		perseguir_jugador()
	else:
		patrullar()

	move_and_slide()

	# Cambia de dirección al chocar con una pared durante la patrulla
	if not jugador_detectado and is_on_wall():
		direccion *= -1
		animated_sprite.flip_h = direccion < 0

# Hace que el Minotauro camine de un lado a otro
func patrullar() -> void:
	velocity.x = velocidad_movimiento * direccion
	animated_sprite.flip_h = direccion < 0

	if animated_sprite.animation != "Animacion_Caminar":
		animated_sprite.play("Animacion_Caminar")

# Persigue al jugador y comienza el ataque cuando está cerca
func perseguir_jugador() -> void:
	if not is_instance_valid(jugador):
		return

	var d := jugador.global_position - global_position
	direccion = 1 if d.x > 0 else -1
	animated_sprite.flip_h = direccion < 0

	if abs(d.x) <= distancia_ataque and abs(d.y) <= alcance_vertical_ataque:
		velocity.x = 0.0
		atacar()
	else:
		velocity.x = velocidad_persecucion * direccion
		if animated_sprite.animation != "Animacion_Caminar":
			animated_sprite.play("Animacion_Caminar")

# Inicia el ataque y prepara el impacto para el frame 3
func atacar() -> void:
	if muerto or atacando or not puede_atacar or not is_instance_valid(jugador):
		return

	atacando = true
	puede_atacar = false
	dano_aplicado = false
	velocity.x = 0.0
	animated_sprite.play("Animacion_Ataque")

# Aplica daño una sola vez al llegar al frame 3 del ataque
func _on_frame_changed() -> void:
	if muerto or not atacando or dano_aplicado:
		return

	if animated_sprite.animation == "Animacion_Ataque" and animated_sprite.frame == 3:
		dano_aplicado = true
		hacer_dano()

# Comprueba el alcance y reduce la vida del jugador
func hacer_dano() -> void:
	if not is_instance_valid(jugador):
		return

	var d := jugador.global_position - global_position

	if abs(d.x) <= distancia_ataque and abs(d.y) <= alcance_vertical_ataque and d.x * direccion > 0:
		if jugador.has_method("recibir_dano"):
			jugador.call("recibir_dano", dano_ataque)
			print("Minotauro causó ", dano_ataque, " de daño.")

# Gestiona el final del ataque y el tiempo de espera antes del siguiente
func _on_animation_finished() -> void:
	if muerto:
		if animated_sprite.animation == "Animacion_Muerte":
			queue_free()
		return

	if animated_sprite.animation == "Animacion_Ataque":
		atacando = false
		animated_sprite.play("Animacion_Quieto")
		await get_tree().create_timer(tiempo_entre_ataques).timeout

		if not muerto:
			puede_atacar = true

# Detecta al jugador cuando entra en el área
func _on_body_entered(body: Node2D) -> void:
	if not muerto and body.is_in_group("jugador"):
		jugador = body
		jugador_detectado = true

# Deja de perseguir al jugador cuando sale del área
func _on_body_exited(body: Node2D) -> void:
	if body == jugador:
		jugador = null
		jugador_detectado = false

# Reduce la vida del Minotauro sin interrumpir su animación de ataque
func recibir_dano(cantidad: int) -> void:
	if muerto or cantidad <= 0 or tiempo_invulnerable > 0.0:
		return

	vida_actual = max(vida_actual - cantidad, 0)
	tiempo_invulnerable = tiempo_invulnerabilidad
	tiempo_destello = duracion_destello
	animated_sprite.modulate = COLOR_DANO

	print("Minotauro recibió ", cantidad, " de daño. Vida: ", vida_actual, "/", vida_maxima)

	# Solo cambia de estado si el Minotauro muere
	if vida_actual <= 0:
		morir()

# Permite recibir daño usando también la ñ en el nombre de la función
func recibir_daño(cantidad: int) -> void:
	recibir_dano(cantidad)

# Detiene al enemigo, desactiva su detección y reproduce la muerte
func morir() -> void:
	if muerto:
		return

	muerto = true
	velocity = Vector2.ZERO
	atacando = false
	puede_atacar = false
	jugador = null

	area_deteccion.set_deferred("monitoring", false)
	area_deteccion.set_deferred("monitorable", false)

	animated_sprite.modulate = COLOR_NORMAL
	animated_sprite.play("Animacion_Muerte")
