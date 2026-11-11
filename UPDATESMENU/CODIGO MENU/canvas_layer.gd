extends CanvasLayer

@onready var menu_pausa: Control = $opciones

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_pausa.hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():

		var abrir = not menu_pausa.visible

		menu_pausa.visible = abrir
		get_tree().paused = abrir

		get_viewport().set_input_as_handled()
		
