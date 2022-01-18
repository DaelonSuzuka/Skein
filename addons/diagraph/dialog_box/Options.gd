tool
extends HBoxContainer

# ******************************************************************************

var button_scene = load('res://addons/diagraph/dialog_box/OptionButton.tscn')

signal option_selected(option)
signal option_added(option_button)

# ******************************************************************************

func add_option(option, value=null):
	var button = button_scene.instance()

	var arg = value if value else option
	button.connect("pressed", self, "emit_signal", ['option_selected', arg])
	button.connect("pressed", self, "remove_options")
	button.text = option

	add_child(button)

## Removes all option buttons in scene
func remove_options() -> void:
	for child in get_children():
		if child is Button:
			child.queue_free()
