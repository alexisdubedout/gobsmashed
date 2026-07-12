@tool
extends EditorPlugin

var toolbar_btn : Button
var win         : Window

func _enter_tree() -> void:
	toolbar_btn = Button.new()
	toolbar_btn.text = "LPC Creator"
	toolbar_btn.pressed.connect(_open)
	add_control_to_container(CONTAINER_TOOLBAR, toolbar_btn)

func _exit_tree() -> void:
	if toolbar_btn:
		remove_control_from_container(CONTAINER_TOOLBAR, toolbar_btn)
		toolbar_btn.queue_free()
	if win and is_instance_valid(win):
		win.queue_free()

func _open() -> void:
	if not win or not is_instance_valid(win):
		win = load("res://addons/lpc_creator/lpc_window.gd").new()
		EditorInterface.get_base_control().add_child(win)
	win.popup_centered(Vector2i(960, 680))
