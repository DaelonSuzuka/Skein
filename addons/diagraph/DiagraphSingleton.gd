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

func _ready():
	validate_paths()
	call_deferred('refresh')

func refresh():
	load_conversations()
	load_characters()
	emit_signal('refreshed')

func load_conversations():
	conversations.clear()
	conversations = get_files(conversation_path)

func load_characters():
	characters.clear()
	var dir := Directory.new()
	for folder in get_files(characters_path):
		for file in get_files(characters_path + folder, '.tscn'):
			var file_name = characters_path + folder + '/' + file
			if dir.file_exists(file_name):
				var c = load(file_name).instance()
				characters[c.name] = c

	var char_map = load_json(character_map_path)
	for name in char_map:
		if dir.file_exists(char_map[name]):
			characters[name] = load(char_map[name]).instance()

# ******************************************************************************

func start_dialog(conversation, options={}):
	if dialog_target:
		dialog_target.start(conversation, options)

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
