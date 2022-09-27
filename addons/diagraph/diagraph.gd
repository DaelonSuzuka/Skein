tool
extends EditorPlugin

# ******************************************************************************

const singleton_path = 'res://addons/diagraph/DiagraphSingleton.tscn'

const inspector_class = 'res://addons/diagraph/DiagraphInspectorPlugin.gd'
var inspector_instance

const editor_class = 'res://addons/diagraph/editor/DiagraphEditor.tscn'

var editors = {
	top = null,
	bottom = null,
}
var bottom_editor_button

var preferred_editor = 'bottom'

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

	editors.top = load(editor_class).instance()
	editors.top.plugin = self
	editors.top.position = 'top'
	editors.top.visible = false
	get_editor_interface().get_editor_viewport().add_child(editors.top)

	editors.bottom = load(editor_class).instance()
	editors.bottom.plugin = self
	editors.bottom.position = 'bottom'
	bottom_editor_button = add_control_to_bottom_panel(editors.bottom, 'Diagraph')

func _exit_tree():
	if editors.top:
		editors.top.free()
	if editors.bottom:
		remove_control_from_bottom_panel(editors.bottom)
		editors.bottom.free()

	if inspector_instance:
		remove_inspector_plugin(inspector_instance)
		if inspector_instance.selector:
			inspector_instance.selector.queue_free()
		if inspector_instance.tree:
			inspector_instance.tree.queue_free()

# ******************************************************************************

func show_conversation(conversation):
	var editor = editors[preferred_editor]
	make_bottom_panel_item_visible(editor)
	editor.change_conversation(conversation)

func get_plugin_icon():
	return load('res://addons/diagraph/resources/diagraph_icon.png')

func get_plugin_name():
	return 'Diagraph'

func has_main_screen():
	return true

func make_visible(state):
	editors.top.visible = state

func apply_changes():
	editors.top.save_conversation()
	editors.top.save_editor_data()
	editors.bottom.save_conversation()
	editors.bottom.save_editor_data()
	bottom_editor_button.text = 'Diagraph'

func save_external_data():
	if is_instance_valid(editors.bottom):
		apply_changes()
	if is_instance_valid(editors.top):
		apply_changes()
