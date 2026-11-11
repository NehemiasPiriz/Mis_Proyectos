

extends Control

@onready var boton_reintentar: Button = $CanvasLayer/VBoxContainer/Reintentar
@onready var boton_menu: Button = $CanvasLayer/VBoxContainer/Menú
@onready var boton_salir: Button = $CanvasLayer/VBoxContainer/Salir

const RUTA_MAPA = "res://escenas/Mapa.tscn"
const RUTA_MENU = "res://escenas/main_menú.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	boton_reintentar.pressed.connect(_on_reintentar_pressed)
	boton_menu.pressed.connect(_on_menu_pressed)
	boton_salir.pressed.connect(_on_salir_pressed)


func _on_reintentar_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(RUTA_MAPA)


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(RUTA_MENU)


func _on_salir_pressed() -> void:
	get_tree().quit()
