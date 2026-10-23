extends Control


func _on_salir_pressed() -> void:
	get_tree().change_scene_to_file("res://escenas/main_menú.tscn")
