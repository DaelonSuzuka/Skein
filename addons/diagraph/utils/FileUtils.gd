@tool
extends Node

# ******************************************************************************

func check_extension(file, ext=null) -> bool:
	if ext:
		if ext is String:
			if file.ends_with(ext):
				return true
		elif ext is Array:
			for e in ext:
				if file.ends_with(e):
					return true
	return false

# get all files in given directory with optional extension filter
func get_files(path: String, ext='') -> Array:
	var _files = []
	var dir := DirAccess.open(path)
	dir.list_dir_begin()

	var file = dir.get_next()
	while true:
		var file_path = dir.get_current_dir().path_join(file)
		if file == '':
			break
		if ext:
			if check_extension(file, ext):
				_files.append(file_path)
		else:
			_files.append(file_path)
		file = dir.get_next()

	dir.list_dir_end()

	return _files

# get all files in given directory(and subdirectories, to a given depth) with optional extension filter
func get_all_files(path: String, ext='', max_depth:=10, _depth:=0, _files:=[]) -> Array:
	if _depth >= max_depth:
		return []

	var dir := DirAccess.open(path)
	dir.list_dir_begin()

	var file = dir.get_next()
	while file != '':
		var file_path = dir.get_current_dir().path_join(file)
		if dir.current_is_dir():
			get_all_files(file_path, ext, max_depth, _depth + 1, _files)
		else:
			if ext:
				if check_extension(file, ext):
					_files.append(file_path)
			else:
				_files.append(file_path)
		file = dir.get_next()
	dir.list_dir_end()
	return _files

# get all files AND folders in a given directory(and subdirectories, to a given depth)
func get_all_files_and_folders(path: String, max_depth:=10, _depth:=0, _files:=[]) -> Array:
	if _depth >= max_depth:
		return []

	var dir := DirAccess.open(path)
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

# get all folders in a given directory(and subdirectories, to a given depth)
func get_all_folders(path: String, max_depth:=10, _depth:=0, _files:=[]) -> Array:
	if _depth >= max_depth:
		return []

	var dir := DirAccess.open(path)
	dir.list_dir_begin() # TODOGODOT4 fill missing arguments https://github.com/godotengine/godot/pull/40547

	var file = dir.get_next()
	while file != '':
		var file_path = dir.get_current_dir().path_join(file)
		if dir.current_is_dir():
			_files.append(file_path)
			get_all_folders(file_path, max_depth, _depth + 1, _files)
		file = dir.get_next()
	dir.list_dir_end()
	return _files