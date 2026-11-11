extends Node2D

@onready var opciones: Control = $CapaPausa/menúPausa

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		opciones.visible = not opciones.visible
		get_tree().paused = opciones.visible
		get_viewport().set_input_as_handled()
