tool
extends EditorPlugin

# ******************************************************************************

const editor_class = preload("res://addons/diagraph/DiagraphEditor.tscn")
var editor_instance

# ******************************************************************************

func _enter_tree():
	editor_instance = editor_class.instance()
	get_editor_interface().get_editor_viewport().add_child(editor_instance)
	editor_instance.hide()

func _exit_tree():
	if editor_instance:
		editor_instance.queue_free()
	
func get_plugin_name():
	return "Diagraph"
	
func make_visible(visible):
	editor_instance.visible = visible

func has_main_screen():
	return true
	

func get_plugin_icon():
	return preload("diagraph_icon.png")	
