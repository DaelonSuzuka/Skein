@tool
extends Node

# ******************************************************************************

var Utils := preload('./utils/Utils.gd').new()
var Files := preload('./utils/Files.gd').new()
var Yarn := preload('./utils/Yarn.gd').new()

var Sandbox := preload('./utils/Sandbox.gd').new()
var Watcher := preload('./utils/Watcher.gd').new()

@onready var canvas: SkeinCanvas = $SkeinCanvas

var characters := {}
var conversations := {}
var _conversations := {}
var _cache := {}

signal refreshed

# ******************************************************************************
# Conversation string parser
# Parses "Name[:Entry[:Line]]" into a dictionary.
# This is the single source of truth for the format — all callers should
# use this instead of splitting on ':' independently.
# ******************************************************************************/

static func parse_conversation_string(conversation_string: String) -> Dictionary:
	conversation_string = conversation_string.trim_prefix("res://").trim_prefix("user://")
	var parts = conversation_string.split(":")
	return {
		"conversation": parts[0],
		"entry": parts[1] if parts.size() >= 2 else "",
		"line": int(parts[2]) if parts.size() >= 3 else 0,
	}

# ******************************************************************************

func _ready():
	add_child(Utils)
	add_child(Files)
	add_child(Yarn)
	add_child(Sandbox)

	if Engine.is_editor_hint():
		add_child(Watcher)

	Files.validate_paths()
	refresh.call_deferred()

	if Engine.is_editor_hint():
		init_file_watcher()

func init_file_watcher():
	Watcher.add_scan_directory(Files.conversation_prefix)
	Watcher.add_scan_directory(Files.characters_prefix)

	Watcher.files_changed.connect(refresh)

func refresh():
	_cache.clear()
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
	var parsed = parse_conversation_string(path)
	var resolved = get_full_path(parsed.conversation)

	if resolved in _cache:
		return _cache[resolved].duplicate(true)

	var result = _load_conversation(resolved, default)
	if result:
		_cache[resolved] = result
		return result.duplicate(true)

	return default

func save_conversation(path: String, data: Dictionary):
	if data == null:
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
