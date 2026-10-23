
extends CharacterBody2D

# Configuración del enemigo
@export var vida_maxima := 200
@export var velocidad_persecucion := 150.0
@export var gravedad := 1200.0
@export var distancia_ataque := 60.0
@export var alcance_vertical := 70.0
@export var dano_ataque := 25
@export var tiempo_entre_ataques := 1.2

# Probabilidad de bloquear y tiempo de recuperación
@export_range(0.0, 1.0, 0.05) var probabilidad_bloqueo := 0.4
@export var tiempo_recuperacion_bloqueo := 0.8

# Estados del guardia
var vida_actual := 200
var jugador: Node2D = null
var jugador_detectado := false
var atacando := false
var bloqueando := false
var puede_atacar := true
var puede_bloquear := true
var muerto := false
var direccion := 1
var frames_golpeados: Array[int] = []
const FRAMES_DANO := [1, 2, 3]

# Referencias a los nodos
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_deteccion: Area2D = $AreaDeteccion

# Inicializa al guardia y conecta las señales
func _ready() -> void:
	vida_actual = vida_maxima
	add_to_group("enemigos")

	for anim in ["Animacion_Ataque", "Animacion_Ataque2", "Animacion_Bloqueo", "Animacion_Muerte"]:
		if animated_sprite.sprite_frames.has_animation(anim):
			animated_sprite.sprite_frames.set_animation_loop(anim, false)

	if not area_deteccion.body_entered.is_connected(_on_body_entered):
		area_deteccion.body_entered.connect(_on_body_entered)

	if not area_deteccion.body_exited.is_connected(_on_body_exited):
		area_deteccion.body_exited.connect(_on_body_exited)

	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

	if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
		animated_sprite.frame_changed.connect(_on_frame_changed)

	animated_sprite.play("Animacion_Quieto")

# Controla gravedad, movimiento y comportamiento
func _physics_process(delta: float) -> void:
	if muerto:
		return

	if not is_on_floor():
		velocity.y += gravedad * delta

	if not is_instance_valid(jugador):
		jugador = null
		jugador_detectado = false

	if atacando or bloqueando:
		velocity.x = 0.0
	elif jugador_detectado:
		perseguir_jugador()
	else:
		velocity.x = 0.0
		if animated_sprite.animation != "Animacion_Quieto":
			animated_sprite.play("Animacion_Quieto")

	move_and_slide()

# Persigue al jugador y ataca cuando está cerca
func perseguir_jugador() -> void:
	if not is_instance_valid(jugador):
		return

	var d := jugador.global_position - global_position
	if d.x != 0:
		direccion = 1 if d.x > 0 else -1

	animated_sprite.flip_h = direccion < 0

	if abs(d.x) <= distancia_ataque and abs(d.y) <= alcance_vertical:
		velocity.x = 0.0
		atacar()
	else:
		velocity.x = velocidad_persecucion * direccion
		if animated_sprite.animation != "Animacion_Correr_Ataque":
			animated_sprite.play("Animacion_Correr_Ataque")

# Inicia uno de los dos ataques
func atacar() -> void:
	if muerto or atacando or bloqueando or not puede_atacar:
		return

	atacando = true
	puede_atacar = false
	frames_golpeados.clear()
	velocity.x = 0.0

	var anim := "Animacion_Ataque" if randi_range(1, 2) == 1 else "Animacion_Ataque2"
	animated_sprite.play(anim)

# Aplica daño una sola vez en cada frame de impacto
func _on_frame_changed() -> void:
	if muerto or not atacando:
		return

	if animated_sprite.animation not in ["Animacion_Ataque", "Animacion_Ataque2"]:
		return

	var frame_actual := animated_sprite.frame

	if frame_actual in FRAMES_DANO and frame_actual not in frames_golpeados:
		frames_golpeados.append(frame_actual)
		hacer_dano()

# Comprueba la distancia y aplica daño al jugador
func hacer_dano() -> void:
	if not is_instance_valid(jugador):
		return

	var d := jugador.global_position - global_position

	if abs(d.x) <= distancia_ataque and abs(d.y) <= alcance_vertical and d.x * direccion > 0:
		if jugador.has_method("recibir_dano"):
			jugador.call("recibir_dano", dano_ataque)
			print("Guardia causó ", dano_ataque, " de daño en el frame ", animated_sprite.frame)

# Gestiona el final de los ataques y bloqueos
func _on_animation_finished() -> void:
	if muerto:
		if animated_sprite.animation == "Animacion_Muerte":
			queue_free()
		return

	if animated_sprite.animation in ["Animacion_Ataque", "Animacion_Ataque2"]:
		atacando = false
		animated_sprite.play("Animacion_Quieto")
		await get_tree().create_timer(tiempo_entre_ataques).timeout
		if not muerto:
			puede_atacar = true

	elif animated_sprite.animation == "Animacion_Bloqueo":
		bloqueando = false
		await get_tree().create_timer(tiempo_recuperacion_bloqueo).timeout

		if muerto:
			return

		puede_bloquear = true

		if jugador_detectado and is_instance_valid(jugador):
			perseguir_jugador()
		else:
			animated_sprite.play("Animacion_Quieto")

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

# Decide si bloquea el golpe o recibe daño
func recibir_dano(cantidad: int) -> void:
	if muerto or cantidad <= 0 or bloqueando:
		return

	if puede_bloquear and randf() < probabilidad_bloqueo:
		bloqueando = true
		puede_bloquear = false
		atacando = false
		velocity.x = 0.0
		animated_sprite.play("Animacion_Bloqueo")
		print("¡El guardia bloqueó el ataque!")
		return

	vida_actual = max(vida_actual - cantidad, 0)
	print("Guardia recibió ", cantidad, " de daño. Vida: ", vida_actual, "/", vida_maxima)

	if vida_actual <= 0:
		morir()

# Permite recibir daño usando también la ñ
func recibir_daño(cantidad: int) -> void:
	recibir_dano(cantidad)

# Detiene al guardia y reproduce la animación de muerte
func morir() -> void:
	if muerto:
		return

	muerto = true
	velocity = Vector2.ZERO
	atacando = false
	bloqueando = false
	puede_atacar = false
	puede_bloquear = false
	jugador = null

	area_deteccion.set_deferred("monitoring", false)
	area_deteccion.set_deferred("monitorable", false)
	animated_sprite.play("Animacion_Muerte")
