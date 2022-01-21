tool
extends EditorPlugin

# ******************************************************************************

var singleton_path = "res://addons/diagraph/DiagraphSingleton.gd"

const editor_class = preload("res://addons/diagraph/editor/DiagraphEditor.tscn")
var editor_instance
var editor_button

# ******************************************************************************

func _enter_tree():
	add_autoload_singleton('Diagraph', singleton_path)

	editor_instance = editor_class.instance()
	editor_instance.is_plugin = true
	editor_button = add_control_to_bottom_panel(editor_instance, 'Diagraph')

func _exit_tree():
	if editor_instance:
		remove_control_from_bottom_panel(editor_instance)
		editor_instance.queue_free()

func get_plugin_icon():
	return preload("resources/diagraph_icon.png")	
