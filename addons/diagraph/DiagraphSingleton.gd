tool
extends Node

# ******************************************************************************

var prefix := 'user://' if OS.has_feature('HTML5') else 'res://'

var characters_path := 'characters/'
var characters_prefix := prefix + characters_path
var character_map_path := characters_path + 'other_characters.json'

var conversation_path := 'conversations/'
var conversation_prefix := prefix + conversation_path

var sandbox = load('res://addons/diagraph/Sandbox.gd').new()
var watcher = load('res://addons/diagraph/Watcher.gd').new()

var characters := {}
var conversations := {}
var _conversations := {}

signal refreshed

# ******************************************************************************

func _ready():
	validate_paths()
	call_deferred('refresh')

	add_child(sandbox)

	if OS.has_feature('HTML5'):
		load_builtin_conversations()
	else:
		init_file_watcher()

func init_file_watcher():
	add_child(watcher)

	for folder in get_all_folders(conversation_prefix):
		watcher.add_scan_directory(folder)

	for folder in get_all_folders(characters_prefix):
		watcher.add_scan_directory(folder)

	watcher.connect('files_changed', self, 'refresh')

func refresh():
	load_conversations()
	load_characters()
	emit_signal('refreshed')

func load_conversations():
	conversations.clear()
	var convos = get_all_files(conversation_prefix, ['.yarn', '.json'])
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
	for file in get_all_files('res://' + conversation_path, '.json'):
		var to_path = file.replace('res://', 'user://')
		save_json(to_path, load_json(file))
	for file in get_all_files('res://' + conversation_path, '.yarn'):
		var to_path = file.replace('res://', 'user://')
		save_yarn(to_path, load_yarn(file))

func load_characters():
	characters.clear()
	for file in get_all_files('res://' + characters_path, '.tscn'):
		var c = load(file).instance()
		characters[c.name] = c
		add_child(c)
		c.hide()

	# for folder in get_files('res://' + characters_path):
	# 	for file in get_files('res://' + characters_path + folder, '.tscn'):
	# 		var file = 'res://' + characters_path + folder + '/' + file
	# 		if dir.file_exists(file):
	# 			var c = load(file).instance()
	# 			characters[c.name] = c

	# var dir := Directory.new()
	# var char_map = load_json(character_map_path, {})
	# for name in char_map:
	# 	if dir.file_exists(char_map[name]):
	# 		characters[name] = load(char_map[name]).instance()

# ******************************************************************************

var loaders = {
	'yarn': 'load_yarn',
	'json': 'load_json',
}

func _load_conversation(path, default=null):
	var result = default

	if path.get_extension() in loaders:
		result = call('load_' + path.get_extension(), path, default)

	return result

# ------------------------------------------------------------------------------

func load_conversation(path, default=null):
	# sanitize path by removing node name and/or line number
	var has_prefix = path.begins_with(Diagraph.prefix)
	path = path.trim_prefix(Diagraph.prefix)
	path = path.split(':')[0]
	if has_prefix:
		path = Diagraph.ensure_prefix(path)

	if path in _conversations:
		path = _conversations[path]

	return _load_conversation(path, default)

func save_conversation(path, data):
	if !data:
		# print("can't save empty data")
		return
	if path.begins_with(prefix):
		if path.ends_with('.json'):
			save_json(path, data)
		if path.ends_with('.yarn'):
			save_yarn(path, data)
		return
	if path in conversations:
		if conversations[path].ends_with('.json'):
			save_json(conversations[path], data)
			# var path = conversations[path].replace('.json', '.yarn')
			# save_yarn(path, data)
		if conversations[path].ends_with('.yarn'):
			save_yarn(conversations[path], data)
	else:
		save_yarn(conversation_prefix + path + '.yarn', data)

# ******************************************************************************

func ensure_prefix(path):
	if path.begins_with(prefix):
		return path

	if path.begins_with(conversation_path):
		path = prefix.plus_file(path)
	else:
		path = conversation_prefix.plus_file(path)

	return path

func path_to_name(path):
	return path.trim_prefix(conversation_prefix)

func validate_paths():
	var dir = Directory.new()
	if !dir.dir_exists(characters_prefix):
		dir.make_dir_recursive(prefix + characters_path)
	if !dir.dir_exists(conversation_prefix):
		dir.make_dir_recursive(conversation_prefix)

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
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin(true, true)

	var file = dir.get_next()
	while true:
		var file_path = dir.get_current_dir().plus_file(file)
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

	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin(true, true)

	var file = dir.get_next()
	while file != '':
		var file_path = dir.get_current_dir().plus_file(file)
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

	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin(true, true)

	var file = dir.get_next()
	while file != '':
		var file_path = dir.get_current_dir().plus_file(file)
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

	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin(true, true)

	var file = dir.get_next()
	while file != '':
		var file_path = dir.get_current_dir().plus_file(file)
		if dir.current_is_dir():
			_files.append(file_path)
			get_all_folders(file_path, max_depth, _depth + 1, _files)
		file = dir.get_next()
	dir.list_dir_end()
	return _files

# ******************************************************************************

func save_json(path, data):
	if !data:
		return
	if !path.begins_with('res://') and !path.begins_with('user://'):
		path = Diagraph.prefix + path

	var dir = Directory.new()
	dir.make_dir_recursive(path.get_base_dir())

	var f = File.new()
	f.open(path, File.WRITE)
	f.store_string(JSON.print(data, '\t'))
	f.close()

func load_json(path, default=null):
	if !path.begins_with('res://') and !path.begins_with('user://'):
		path = Diagraph.prefix + path
	var result = default
	var f = File.new()
	if f.file_exists(path):
		f.open(path, File.READ)
		var text = f.get_as_text()
		f.close()
		var parse = JSON.parse(text)
		if parse.result is Dictionary:
			result = parse.result
	return result

# ******************************************************************************

func save_yarn(path, data):
	if !data:
		return
	if !path.begins_with('res://') and !path.begins_with('user://'):
		path = Diagraph.prefix + path

	var dir = Directory.new()
	dir.make_dir_recursive(path.get_base_dir())

	var out = convert_nodes_to_yarn(data)

	var f = File.new()
	f.open(path, File.WRITE)
	f.store_string(out)
	f.close()

func convert_nodes_to_yarn(data):
	var out = ''

	for id in data:
		var node = data[id]

		node['title'] = node['name']
		node.erase('name')

		var text = node['text']
		node.erase('text')

		node.erase('rect_size')
		node.erase('offset')

		if 'connections' in node:
			node.connections = var2str(node.connections).replace('\n', '')
		if 'choices' in node:
			node.choices = var2str(node.choices).replace('\n', '')
		if 'branches' in node:
			node.branches = var2str(node.branches).replace('\n', '')

		for field in node:
			out += field + ': ' + str(node[field]) + '\n'

		out += '---' + '\n'

		out += text + '\n'
		out += '===' + '\n'

	return out

# ------------------------------------------------------------------------------

func load_yarn(path, default=null):
	var result = default

	var f = File.new()
	if f.file_exists(path):
		f.open(path, File.READ)
		var text = f.get_as_text()
		f.close()
		parse_yarn(text)
		if nodes:
			result = nodes
	return result

var nodes := {}

func parse_yarn(text):
	nodes.clear()
	var mode := 'header'

	var header := []
	var body := []
	var i := 0
	var lines = text.split('\n')
	while i < lines.size():
		var line = lines[i]
		if line == '===':  # end of node
			create_node(header, body)
			header.clear()
			body.clear()
			mode = 'header'
		elif line == '---':  # end of header
			mode = 'body'
		else:
			if mode == 'header':
				header.append(line)
			if mode == 'body':
				body.append(line)
		i += 1

var used_ids = []

func get_id() -> int:
	var id = randi()
	if id in used_ids:
		id = get_id()
	used_ids.append(id)
	return id

func create_node(header, body):
	var node := {
		id = 0,
		type = '',
		name = '',
		text = '',
		next = 'none',
	}

	var fields := {}
	for line in header:
		var parts = line.split(':', true, 1)
		if parts.size() != 2:
			continue
		fields[parts[0]] = parts[1].lstrip(' ')

	node.name = fields.title
	fields.erase('title')

	node.id = fields.get('id', get_id())
	fields.erase('id')

	node.type = fields.get('type', 'speech')
	fields.erase('type')

	for field in fields:
		node[field] = fields[field]

	if 'connections' in node:
		node.connections = str2var(node.connections)
	if 'choices' in node:
		node.choices = str2var(node.choices)
	if 'branches' in node:
		node.branches = str2var(node.branches)

	var _body = body[0]
	var i = 1
	while i < body.size():
		_body += '\n' + body[i]
		i += 1
	node['text'] = _body

	nodes[str(node.id)] = node
