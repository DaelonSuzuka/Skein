@tool
extends Node

# ******************************************************************************

var Utils := preload('./utils/Utils.gd').new()
var Files := preload('./utils/Files.gd').new()
var Yarn := preload('./utils/Yarn.gd').new()

var Sandbox := preload('./utils/Sandbox.gd').new()
var Watcher := preload('./utils/Watcher.gd').new()

@onready var canvas = $SkeinCanvas

var characters := {}
var conversations := {}
var _conversations := {}

signal refreshed

# ******************************************************************************

func _ready():
	Files.validate_paths()
	call_deferred('refresh')

	init_file_watcher()

func init_file_watcher():
	pass
	# Watcher.add_scan_directory(conversation_prefix)
	# for folder in Files.get_all_folders(conversation_prefix):
	# 	Watcher.add_scan_directory(folder)

	# Watcher.add_scan_directory(characters_prefix)
	# for folder in Files.get_all_folders(characters_prefix):
	# 	Watcher.add_scan_directory(folder)

	# Watcher.pressed.connect(refresh)

func refresh():
	load_conversations()
	load_characters()
	refreshed.emit()

func load_conversations():
	conversations.clear()
	var convos = Files.get_all_files(Files.conversation_prefix, ['.yarn', '.json'])
	for convo in convos:
		conversations[path_to_name(convo)] = convo
		_conversations[path_to_name(convo)] = convo

		var filename = path_to_name(convo).get_file()
		if !(filename in _conversations):
			_conversations[filename] = convo

		var basename = path_to_name(convo).get_basename()
		if !(basename in _conversations):
			_conversations[basename] = convo

		var basefilename = path_to_name(convo).get_file().get_basename()
		if !(basefilename in _conversations):
			_conversations[basefilename] = convo

func load_builtin_conversations():
	for file in Files.get_all_files('res://' + Files.conversation_path, '.json'):
		var to_path = file.replace('res://', 'user://')
		Files.save_json(to_path, Files.load_json(file))
	for file in Files.get_all_files('res://' + Files.conversation_path, '.yarn'):
		var to_path = file.replace('res://', 'user://')
		Yarn.save_yarn(to_path, Yarn.load_yarn(file))

func load_characters():
	characters.clear()
	for file in Files.get_all_files('res://' + Files.characters_path, '.tscn'):
		var c = load(file).instantiate()
		characters[c.name] = c
		add_child(c)
		c.hide()

	# for folder in Files.get_files('res://' + characters_path):
	# 	for file in Files.get_files('res://' + characters_path + folder, '.tscn'):
	# 		var file = 'res://' + characters_path + folder + '/' + file
	# 		if DirAccess.file_exists(file):
	# 			var c = load(file).instantiate()
	# 			characters[c.name] = c

	# var char_map = load_json(character_map_path, {})
	# for name in char_map:
	# 	if DirAccess.file_exists(char_map[name]):
	# 		characters[name] = load(char_map[name]).instantiate()

# ******************************************************************************

func _load_conversation(path: String, default=null):
	var result = default

	if path.ends_with('.json'):
		result = Files.load_json(path, default)
	if path.ends_with('.yarn'):
		result = Yarn.load_yarn(path, default)
	return result

# ------------------------------------------------------------------------------

func get_full_path(path: String) -> String:
	if path in _conversations:
		path = _conversations[path]
	return path

func load_conversation(path: String, default=null):
	# sanitize path by removing node name and/or line number
	path = path.trim_prefix(Files.prefix)
	path = path.split(':')[0]
	path = get_full_path(path)

	return _load_conversation(path, default)

func save_conversation(path: String, data):
	if data == null or data == {}:
		# print("can't save empty data")
		return
	if path.begins_with(Files.prefix):
		if path.ends_with('.json'):
			Files.save_json(path, data)
		if path.ends_with('.yarn'):
			Yarn.save_yarn(path, data)
		return
	if path in conversations:
		if conversations[path].ends_with('.json'):
			Files.save_json(conversations[path], data)
			# var path = conversations[path].replace('.json', '.yarn')
			# save_yarn(path, data)
		if conversations[path].ends_with('.yarn'):
			Yarn.save_yarn(conversations[path], data)
	else:
		Yarn.save_yarn(Files.conversation_prefix + path + '.yarn', data)

# ******************************************************************************

func path_to_name(path: String):
	return path.trim_prefix(Files.conversation_prefix)
