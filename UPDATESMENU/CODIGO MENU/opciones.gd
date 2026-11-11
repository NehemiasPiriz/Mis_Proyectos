extends Control

func _on_continuar_pressed() -> void:
	get_tree().paused = false
	hide()


func _on_salir_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(
        "res://escenas/main_menú.tscn"
	)


# Controla el volumen general del juego usando el Bus Master (10 de noviembre de 2026)
func _on_h_slider_value_changed(value: float) -> void:
	var bus_index = AudioServer.get_bus_index("Master")
	
	if value <= 0.001:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
