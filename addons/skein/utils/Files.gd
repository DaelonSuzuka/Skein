@tool
extends Node

# ******************************************************************************

var prefix := 'user://' if OS.has_feature('HTML5') else 'res://'

func ensure_prefix(path: String):
	if path.begins_with(prefix):
		return path

	if path.begins_with(conversation_path):
		path = prefix + path
	else:
		path = conversation_prefix + path

	return path

# ------------------------------------------------------------------------------

var characters_path := 'characters/'
var characters_prefix := prefix + characters_path
var character_map_path := characters_path + 'other_characters.json'

var conversation_path := 'conversations/'
var conversation_prefix := prefix + conversation_path

func validate_paths():
	if !DirAccess.dir_exists_absolute(characters_prefix):
		DirAccess.make_dir_recursive_absolute(characters_prefix)
	if !DirAccess.dir_exists_absolute(conversation_prefix):
		DirAccess.make_dir_recursive_absolute(conversation_prefix)

# ******************************************************************************

func check_extension(file: String, ext=null) -> bool:
	if ext:
		if ext is String:
			if file.ends_with(ext):
				return true
		elif ext is Array:
			for e in ext:
				if file.ends_with(e):
					return true
	return false

## get all files in given directory with optional extension filter
func get_files(path: String, ext=null) -> Array[String]:
	var _files: Array[String] = []

	var dir := DirAccess.open(path)
	if !dir:
		return []
	dir.list_dir_begin()

	var file = dir.get_next()
	while file != '':
		var file_path = dir.get_current_dir().path_join(file)
		if !dir.current_is_dir():
			if ext:
				if check_extension(file_path, ext):
					_files.append(file_path)
			else:
				_files.append(file_path)
		file = dir.get_next()

	dir.list_dir_end()

	return _files

## get all files in given directory(and subdirectories, to a given depth) with optional extension filter
func get_all_files(path: String, ext=null, max_depth:=10, _depth:=0, _files: Array[String]=[]) -> Array[String]:
	if _depth >= max_depth:
		return []

	var dir := DirAccess.open(path)
	if !dir:
		return []
	dir.list_dir_begin()

	var file = dir.get_next()
	while file != '':
		var file_path = dir.get_current_dir().path_join(file)
		if dir.current_is_dir():
			get_all_files(file_path, ext, max_depth, _depth + 1, _files)
		else:
			if ext:
				if check_extension(file_path, ext):
					_files.append(file_path)
			else:
				_files.append(file_path)
		file = dir.get_next()
	dir.list_dir_end()
	return _files

## get all files AND folders in a given directory(and subdirectories, to a given depth)
func get_all_files_and_folders(path: String, max_depth:=10, _depth:=0, _files: Array[String]=[]) -> Array[String]:
	if _depth >= max_depth:
		return []

	var dir := DirAccess.open(path)
	if !dir:
		return []
	dir.list_dir_begin()

	var file = dir.get_next()
	while file != '':
		var file_path = dir.get_current_dir().path_join(file)
		_files.append(file_path)
		if dir.current_is_dir():
			get_all_files_and_folders(file_path, max_depth, _depth + 1, _files)
		file = dir.get_next()
	dir.list_dir_end()
	return _files

## get all folders in a given directory(and subdirectories, to a given depth)
func get_all_folders(path: String, max_depth:=10, _depth:=0, _files: Array[String]=[]) -> Array[String]:
	if _depth >= max_depth:
		return []

	var dir := DirAccess.open(path)
	if !dir:
		return []
	dir.list_dir_begin()

	var file = dir.get_next()
	while file != '':
		var file_path = dir.get_current_dir().path_join(file)
		if dir.current_is_dir():
			_files.append(file_path)
			get_all_folders(file_path, max_depth, _depth + 1, _files)
		file = dir.get_next()
	dir.list_dir_end()
	return _files

# ******************************************************************************

func _ensure_suffix(path: String, suffix:='.json'):
	if path.ends_with(suffix):
		return path

	return path + suffix

## save a godot object to a json file
func save_json(path: String, data) -> void:
	if data == null or data == {}:
		return
	if !path.begins_with('res://') and !path.begins_with('user://'):
		path = prefix + path
	path = _ensure_suffix(path)

	DirAccess.make_dir_recursive_absolute(path.get_base_dir())

	var f = FileAccess.open(path, FileAccess.WRITE)
	if f and f.is_open():
		f.store_string(JSON.stringify(data, '\t', true))

## loads a json file from disk
func load_json(path: String, default=null):
	if !path.begins_with('res://') and !path.begins_with('user://'):
		path = prefix + path
	path = _ensure_suffix(path)
	var result = default

	var f := FileAccess.open(path, FileAccess.READ)
	if f and f.is_open():
		var text = f.get_as_text()

		var parse = JSON.parse_string(text)
		if parse is Dictionary:
			result = parse
	return result
