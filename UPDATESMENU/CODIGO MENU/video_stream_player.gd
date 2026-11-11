extends VideoStreamPlayer

func _ready() -> void:
	finished.connect(_ir_al_mapa)
	play()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_ir_al_mapa()

func _ir_al_mapa() -> void:
	get_tree().change_scene_to_file("res://escenaS/Mapa.tscn")
