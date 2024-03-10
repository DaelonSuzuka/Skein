tool
extends EditorPlugin

# ******************************************************************************

const settings_prefix := "interface/skein/"
var settings: EditorSettings

const singleton_path := 'res://addons/skein/SkeinSingleton.tscn'

const inspector_class := 'res://addons/skein/SkeinInspectorPlugin.gd'
var inspector_instance

const editor_class := 'res://addons/skein/editor/SkeinEditor.tscn'

var editors = {
	top = null,
	bottom = null,
}

var enabled := true

# ******************************************************************************

func enable_plugin():
	add_autoload_singleton('Skein', singleton_path)

func disable_plugin():
	remove_autoload_singleton('Skein')

func _enter_tree():
	name = 'Skein'
	# Skein.plugin = self

	var menu = preload('utils/ContextMenu.gd').new(self, 'tool_submenu_selected')
	menu.add_item('Check for Updates')

	remove_child(menu)
	add_tool_submenu_item('Skein', menu)

	settings = get_editor_interface().get_editor_settings()

	var property_info = {
		"name": "preferred_editor",
		"value": 'bottom',
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "top,bottom"
	}
	add_setting(property_info)

	if enabled:
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

func get_plugin_icon():
	return load('res://addons/skein/resources/skein_icon.png')

func get_plugin_name():
	return 'Skein'

func has_main_screen():
	return enabled

func make_visible(state):
	if enabled:
		editors.top.visible = state

func apply_changes():
	if enabled:
		editors.top.save_conversation()
		editors.top.save_editor_data()
		editors.bottom.save_conversation()
		editors.bottom.save_editor_data()

func save_external_data():
	if is_instance_valid(editors.bottom):
		apply_changes()
	if is_instance_valid(editors.top):
		apply_changes()

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

# ******************************************************************************

func tool_submenu_selected(selected):
	if selected == 'Check for Updates':
		check_for_updates()

var updater
var update_dialog
var status_label
var progress_bar

func check_for_updates():
	update_dialog = AcceptDialog.new()
	var vbox = VBox.new(update_dialog)
	status_label = vbox.add(Label.new())
	progress_bar = vbox.add(ProgressBar.new())

	# progress_bar.visible = false
	update_dialog.get_ok().disabled = true
	update_dialog.window_title = 'Skein Self-Update'

	get_editor_interface().get_editor_viewport().add_child(update_dialog)
	update_dialog.popup_centered(Vector2(400, 250))

	updater = preload('utils/Updater.gd').new()
	updater.connect('download_complete', self, 'download_complete', [], CONNECT_ONESHOT)
	updater.connect('update_complete', self, 'update_complete', [], CONNECT_ONESHOT)
	add_child(updater)
	updater.get_file_list(status_label, progress_bar)

func download_complete():
	status_label.text = 'Download complete, updating Skein'

func update_complete():
	status_label.text = 'Update complete'
	update_dialog.get_ok().disabled = false

# ******************************************************************************

class VBox:
	extends VBoxContainer

	func _init(parent=null):
		if parent:
			parent.add_child(self)

	func add(object):
		add_child(object)
		return object
