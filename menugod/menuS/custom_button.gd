extends Button
class_name custom_button

@onready var click: AudioStreamPlayer= $click
@onready var onhover: AudioStreamPlayer= $onhover

func _on_pressed() -> void:
	click.play()

func _on_mouse_entered() -> void:
	onhover.play()
