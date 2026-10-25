extends Area2D

@export var colision_pared: CollisionShape2D
@export var pantalla_negra: ColorRect 
@export var cancion_zona_final: AudioStream
@onready var reproductor: AudioStreamPlayer = %AudioStreamPlayer2D

var batalla_iniciada: bool = false

func _on_body_entered(body):
	if body.name == "PERSONAJE_PRINCIPAL" and not batalla_iniciada:
		batalla_iniciada = true
		comenzar_transicion(body)
		
func comenzar_transicion(body):
	#CAMBIAR CANCIÓN PARA LA ZONA FINAL
	if reproductor and cancion_zona_final:
		reproductor.stop()
		reproductor.stream = cancion_zona_final
		reproductor.play()
	#ACTIVACIÓN DE LA PARED INVISIBLE PARA BLOQUEAR LA SALIDA
	if colision_pared:
		colision_pared.set_deferred("disabled", false)
	#OSCURECER EL MAPA 
	var tween = create_tween()
	tween.tween_property(pantalla_negra, "modulate:a", 1.0, 0.8)
	await tween.finished
	
	#TRANSICION DEL PERSONAJE A LA ZONA FINAL
	body.global_position = Vector2(45476.2, 47.447)
	body.z_index = 10
	
	#TIEMPO DE 2 SEGUNDOS CON LA PANTALLA NEGRA DURANTE LA TRANSICION DEL PERSONAJE
	await get_tree().create_timer(2.0).timeout
	
	#VUELVE LA LUZ PERO CON ALGO DE OSCURIDAD
	if pantalla_negra:
		var tween2 = create_tween()
		tween2.tween_property(pantalla_negra, "modulate:a", 0.4, 1.5)
	
