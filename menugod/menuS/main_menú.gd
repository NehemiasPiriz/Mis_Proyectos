extends Control
class_name main_menú

func _on_comenzar_pressed():
	get_tree().change_scene_to_file("res://escenas/Mapa.tscn")

func _on_salir_pressed() -> void:
	get_tree().quit()

func _on_opciones_pressed() -> void:
	get_tree().change_scene_to_file("res://escenas/opciones.tscn")

	
