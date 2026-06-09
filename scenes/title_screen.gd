extends Control

func _ready():
	print("Title screen chargé !")
	print("Position Button : ", $Button.position)
	print("Size Button : ", $Button.size)

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		print("Clic à : ", event.position)

func _on_button_pressed() -> void:
	print("PLAY !")
	get_tree().change_scene_to_file("res://scenes/world/world.tscn")

func _on_button_donjon_pressed():
	get_tree().change_scene_to_file("res://scenes/donjon.tscn")
