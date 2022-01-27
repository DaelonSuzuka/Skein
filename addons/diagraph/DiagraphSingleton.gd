tool
extends Node

# ******************************************************************************

var characters_path = 'res://characters/'
var character_map_path = characters_path + 'other_characters.json'
var characters := {}

var conversation_path := 'res://conversations/'
var conversations := []

var dialog_target = null

signal refreshed

# ******************************************************************************

func start_dialog(conversation, options={}):
	if dialog_target:
		dialog_target.start(conversation, options)
		dialog_target.connect('done', self, 'clear_temp_locals', [], CONNECT_ONESHOT)

# ******************************************************************************

var locals := {}

func add_local(name, value):
	locals[name] = value

func add_locals(dict):
	for name in dict:
		add_local(name, dict[name])

# ------------------------------------------------------------------------------

var temp_locals := {}

func clear_temp_locals():
	temp_locals.clear()

func add_temp_local(name, value):
	temp_locals[name] = value

func add_temp_locals(dict):
	for name in dict:
		add_temp_local(name, dict[name])

# ------------------------------------------------------------------------------

func get_locals():
	var _locals = locals.duplicate(true)
	if dialog_target and dialog_target.get('caller'):
		_locals['caller'] = dialog_target.caller
		if dialog_target.caller.owner:
			_locals['scene'] = dialog_target.caller.owner
	for name in temp_locals:
		_locals[name] = temp_locals[name]
	for c in Diagraph.characters:
		_locals[c] = Diagraph.characters[c]
	return _locals

# ******************************************************************************

func _ready():
	validate_paths()
	call_deferred('refresh')

func refresh():
	load_conversations()
	load_characters()
	emit_signal('refreshed')

func load_conversations():
	conversations.clear()
	var _conversations = get_files(conversation_path)
	for convo in _conversations:
		conversations.append(convo.substr(0, convo.length() - '.json'.length()))

func load_characters():
	characters.clear()
	var dir := Directory.new()
	for folder in get_files(characters_path):
		for file in get_files(characters_path + folder, '.tscn'):
			var file_name = characters_path + folder + '/' + file
			if dir.file_exists(file_name):
				var c = load(file_name).instance()
				characters[c.name] = c

	var char_map = load_json(character_map_path, {})
	for name in char_map:
		if dir.file_exists(char_map[name]):
			characters[name] = load(char_map[name]).instance()

# ******************************************************************************

func name_to_path(name):
	return conversation_path + name + '.json'

func validate_paths():
	var dir = Directory.new()
	if !dir.dir_exists(characters_path):
		dir.make_dir_recursive(characters_path)
	if !dir.dir_exists(conversation_path):
		dir.make_dir_recursive(conversation_path)

func get_files(path, ext='') -> Array:
	var files = []
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin()

	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			if ext:
				if file.ends_with(ext):
					files.append(file)
			else:
				files.append(file)
	dir.list_dir_end()
	return files

func save_json(path, data):
	var f = File.new()
	f.open(path, File.WRITE)
	f.store_string(JSON.print(data, "\t"))
	f.close()

func load_json(path, default=null):
	var result = default
	var f = File.new()
	if f.file_exists(path):
		f.open(path, File.READ)
		var text = f.get_as_text()
		f.close()
		result = JSON.parse(text).result
	return result
