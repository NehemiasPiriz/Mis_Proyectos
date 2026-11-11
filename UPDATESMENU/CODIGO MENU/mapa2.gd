extends Node2D

@onready var opciones: Control = $CanvasLayer/opciones


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	get_tree().paused = false

	opciones.process_mode = Node.PROCESS_MODE_ALWAYS
	opciones.hide()

	print("========== MAPA ==========")
	print("ESCENA: ", scene_file_path)
	print("OPCIONES: ", opciones.get_path())
	print("VISIBLE: ", opciones.visible)
	print("PAUSADO: ", get_tree().paused)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and not event.is_echo():
		opciones.visible = not opciones.visible
		get_tree().paused = opciones.visible
		print("OPCIONES VISIBLES: ", opciones.visible)
		print("JUEGO PAUSADO: ", get_tree().paused)
		get_viewport().set_input_as_handled()
