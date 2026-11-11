extends Control

@onready var video: VideoStreamPlayer = $VideoStreamPlayer

var transicionando: bool = false


func _ready() -> void:
	print("========== CINEMATICA ==========")
	print("ESCENA ACTUAL: ", scene_file_path)

	if not video.finished.is_connected(_ir_al_mapa):
		video.finished.connect(_ir_al_mapa)
		
	video.play()


func _input(event: InputEvent) -> void:
	if transicionando:
		return

	if event.is_action_pressed("ui_accept") and not event.is_echo():
		print("CINEMATICA SALTADA POR EL USUARIO")
		_ir_al_mapa()


func _ir_al_mapa() -> void:
	if transicionando:
		return

	transicionando = true
	set_process_input(false)
	video.stop()

	# Usamos exactamente la ruta que nos da el panel de archivos de Godot
	var ruta_mapa = "res://escenaS/Mapa.tscn"

	print("========== COMPROBANDO MAPA ==========")
	print("RUTA: ", ruta_mapa)
	print("¿EXISTE EL ARCHIVO?: ", ResourceLoader.exists(ruta_mapa))

	var error = get_tree().change_scene_to_file(ruta_mapa)
	
	if error != OK:
		print("ERROR: NO SE PUDO CARGAR EL MAPA. Código de error: ", error)
	else:
		print("MAPA CARGADO CORRECTAMENTE")
