@tool
extends EditorPlugin

# ******************************************************************************

const settings_prefix := "interface/skein/"
var settings

const singleton_path := 'res://addons/skein/SkeinSingleton.tscn'

const SkeinInspector := preload('./SkeinInspectorPlugin.gd')
var inspector_instance

const SkeinEditor := preload('./editor/SkeinEditor.tscn')

var editors := {
	top = null,
	bottom = null,
}

var enabled := true

const _plugin_name := 'Skein'

# ******************************************************************************

func _enable_plugin():
	add_autoload_singleton('Skein', singleton_path)

func _disable_plugin():
	remove_autoload_singleton('Skein')

func _enter_tree():
	name = self._plugin_name

	settings = get_editor_interface().get_editor_settings()

	var property_info = {
		"name": "preferred_editor",
		"value": 'bottom',
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "top,bottom"
	}
	add_setting(property_info)

	if self.enabled:
		inspector_instance = SkeinInspector.new()
		inspector_instance.plugin = self
		add_inspector_plugin(inspector_instance)

		editors.top = SkeinEditor.instantiate()
		editors.top.plugin = self
		editors.top.location = 'top'
		editors.top.visible = false
		get_editor_interface().get_editor_main_screen().add_child(editors.top)

		editors.bottom = SkeinEditor.instantiate()
		editors.bottom.plugin = self
		editors.bottom.location = 'bottom'
		add_control_to_bottom_panel(editors.bottom, 'Skein')

func _exit_tree():
	remove_tool_menu_item('Skein')

	if enabled:
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
	var preferred_editor = get_setting('preferred_editor')
	var editor = editors[preferred_editor]
	if preferred_editor == 'top':
		get_editor_interface().set_main_screen_editor('Skein')
		editor.change_conversation(conversation)
	elif preferred_editor == 'bottom':
		make_bottom_panel_item_visible(editor)
		editor.change_conversation(conversation)

func set_preferred_editor(editor):
	set_setting('preferred_editor', editor)

func _get_plugin_icon():
	return load('res://addons/skein/resources/skein_icon.png')

func _get_plugin_name():
	return self._plugin_name

func _has_main_screen():
	return self.enabled

func _make_visible(state):
	if self.enabled:
		if editors.top:
			editors.top.visible = state

func _apply_changes():
	if self.enabled:
		editors.top.save_conversation()
		editors.top.save_editor_data()
		editors.bottom.save_conversation()
		editors.bottom.save_editor_data()

func _save_external_data():
	if is_instance_valid(editors.bottom):
		_apply_changes()
	if is_instance_valid(editors.top):
		_apply_changes()

# ******************************************************************************

func add_setting(property_info):
	property_info.name = settings_prefix + property_info.name
	settings.add_property_info(property_info)
	if settings.has_setting(property_info.name):
		return
	settings.set(property_info.name, property_info.value)

func set_setting(name: String, value) -> void:
	settings.set(settings_prefix + name, value)

func get_setting(name: String):
	return settings.get(settings_prefix + name)
