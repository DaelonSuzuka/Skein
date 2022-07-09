tool
extends EditorPlugin

# ******************************************************************************

const singleton_path = 'res://addons/diagraph/DiagraphSingleton.gd'

const inspector_class = 'res://addons/diagraph/DiagraphInspectorPlugin.gd'
var inspector_instance

const editor_class = 'res://addons/diagraph/editor/DiagraphEditor.tscn'
var editor_instance
var editor_button

# ******************************************************************************

func enable_plugin():
	add_autoload_singleton('Diagraph', singleton_path)

func disable_plugin():
	remove_autoload_singleton('Diagraph')

func _enter_tree():
	name = 'Diagraph'
	# Diagraph.plugin = self

	inspector_instance = load(inspector_class).new()
	inspector_instance.plugin = self
	add_inspector_plugin(inspector_instance)

	editor_instance = load(editor_class).instance()
	editor_instance.plugin = self
	editor_button = add_control_to_bottom_panel(editor_instance, 'Diagraph')

func _exit_tree():
	if editor_instance:
		remove_control_from_bottom_panel(editor_instance)
		editor_instance.free()

	if inspector_instance:
		remove_inspector_plugin(inspector_instance)
		if inspector_instance.selector:
			inspector_instance.selector.queue_free()
		if inspector_instance.tree:
			inspector_instance.tree.queue_free()

func show_conversation(conversation):
	make_bottom_panel_item_visible(editor_instance)
	editor_instance.change_conversation(conversation)

func get_plugin_icon():
	return load('resources/diagraph_icon.png')

func apply_changes():
	editor_instance.save_conversation()
	editor_instance.save_editor_data()
	editor_button.text = 'Diagraph'
