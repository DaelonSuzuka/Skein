tool
extends EditorPlugin

# ******************************************************************************

const settings_prefix = "interface/diagraph/"
var settings

const singleton_path = 'res://addons/diagraph/DiagraphSingleton.tscn'

const inspector_class = 'res://addons/diagraph/DiagraphInspectorPlugin.gd'
var inspector_instance

const editor_class = 'res://addons/diagraph/editor/DiagraphEditor.tscn'

var editors = {
	top = null,
	bottom = null,
}

var enabled := true

# ******************************************************************************

func enable_plugin():
	add_autoload_singleton('Diagraph', singleton_path)

func disable_plugin():
	remove_autoload_singleton('Diagraph')

func _enter_tree():
	name = 'Diagraph'
	# Diagraph.plugin = self

	add_tool_menu_item('Download Master', self, 'update_diagraph')
	add_tool_menu_item('Unzip Archive', self, 'unzip_archive')

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
		add_control_to_bottom_panel(editors.bottom, 'Diagraph')

func _exit_tree():
	remove_tool_menu_item('Download Master')
	remove_tool_menu_item('Unzip Archive')

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
		get_editor_interface().set_main_screen_editor('Diagraph')
		editor.change_conversation(conversation)
	elif preferred_editor == 'bottom':
		make_bottom_panel_item_visible(editor)
		editor.change_conversation(conversation)

func set_preferred_editor(editor):
	set_setting('preferred_editor', editor)

func get_plugin_icon():
	return load('res://addons/diagraph/resources/diagraph_icon.png')

func get_plugin_name():
	return 'Diagraph'

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

const diagraph_url = 'https://raw.githubusercontent.com/DaelonSuzuka/Diagraph/master/addons/diagraph/'
const master_zip_url = 'https://github.com/DaelonSuzuka/Diagraph/archive/refs/heads/master.zip'
const master_zip_path = 'res://master.zip'

func update_diagraph(ud):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.download_file = master_zip_path
	http_request.use_threads = true
	http_request.connect("request_completed", self, "_http_request_completed")

	var error = http_request.request(master_zip_url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _http_request_completed(result, response_code, headers, body):
	print('_http_request_completed')
	print(body.get_string_from_ascii())
	unzip_archive(0)

func unzip_archive(ud):
	print('unzipping')
	var unzip = load('res://addons/diagraph/utils/GDUnzip.gd').new()
	var loaded = unzip.load(master_zip_path)

	var files = {}

	for f in unzip.files:
		if f.begins_with('Diagraph-master/addons/diagraph'):
			if f.ends_with('/'): # skip folders
				continue
			files[f] = unzip.uncompress(f)

	for f in files:
		var path = f.replace('Diagraph-master/', 'res://')

		var file = File.new()
		if file.file_exists(path):
			if file.open(path, File.READ) == OK:
				var new = files[f]
				var existing = file.get_buffer(file.get_len())

				if new == existing:
					continue

				if file.open(path, File.WRITE) == OK:
					file.store_buffer(files[f])
		else:
			if file.open(path, File.WRITE) == OK:
				file.store_buffer(files[f])

		file.close()
