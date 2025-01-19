@tool
extends Node

# ******************************************************************************

var prefix := 'user://' if OS.has_feature('HTML5') else 'res://'

var characters_path := 'characters/'
var characters_prefix := prefix + characters_path
var character_map_path := characters_path + 'other_characters.json'

var conversation_path := 'conversations/'
var conversation_prefix := prefix + conversation_path

@onready var sandbox = $Sandbox
@onready var watcher = $Watcher
@onready var canvas = $SkeinCanvas

var characters := {}
var conversations := {}
var _conversations := {}

@onready var utils = $Utils
@onready var files = $Files

signal refreshed

# ******************************************************************************

func _ready():
	validate_paths()
	call_deferred('refresh')

	init_file_watcher()

func init_file_watcher():
	pass
	# watcher.add_scan_directory(conversation_prefix)
	# for folder in files.get_all_folders(conversation_prefix):
	# 	watcher.add_scan_directory(folder)

	# watcher.add_scan_directory(characters_prefix)
	# for folder in files.get_all_folders(characters_prefix):
	# 	watcher.add_scan_directory(folder)

	# watcher.pressed.connect(self.refresh)

func refresh():
	load_conversations()
	load_characters()
	refreshed.emit()

func load_conversations():
	conversations.clear()
	var convos = files.get_all_files(conversation_prefix, ['.yarn', '.json'])
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
	for file in files.get_all_files('res://' + conversation_path, '.json'):
		var to_path = file.replace('res://', 'user://')
		save_json(to_path, load_json(file))
	for file in files.get_all_files('res://' + conversation_path, '.yarn'):
		var to_path = file.replace('res://', 'user://')
		save_yarn(to_path, load_yarn(file))

func load_characters():
	characters.clear()
	for file in files.get_all_files('res://' + characters_path, '.tscn'):
		var c = load(file).instantiate()
		characters[c.name] = c
		add_child(c)
		c.hide()

	# for folder in files.get_files('res://' + characters_path):
	# 	for file in files.get_files('res://' + characters_path + folder, '.tscn'):
	# 		var file = 'res://' + characters_path + folder + '/' + file
	# 		if DirAccess.file_exists(file):
	# 			var c = load(file).instantiate()
	# 			characters[c.name] = c

	# var char_map = load_json(character_map_path, {})
	# for name in char_map:
	# 	if DirAccess.file_exists(char_map[name]):
	# 		characters[name] = load(char_map[name]).instantiate()

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

func get_full_path(path: String) -> String:
	if path in _conversations:
		path = _conversations[path]
	return path

func load_conversation(path, default=null):
	# sanitize path by removing node name and/or line number
	path = path.trim_prefix(Skein.prefix)
	path = path.split(':')[0]
	path = get_full_path(path)

	return _load_conversation(path, default)

func save_conversation(path, data):
	if data == null or data == {}:
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
		path = prefix + path
	else:
		path = conversation_prefix + path

	return path

func path_to_name(path):
	return path.trim_prefix(conversation_prefix)

func validate_paths():
	if !DirAccess.dir_exists_absolute(characters_prefix):
		DirAccess.make_dir_recursive_absolute(characters_prefix)
	if !DirAccess.dir_exists_absolute(conversation_prefix):
		DirAccess.make_dir_recursive_absolute(conversation_prefix)

# ******************************************************************************

func save_json(path, data):
	if data == null or data == {}:
		return
	if !path.begins_with('res://') and !path.begins_with('user://'):
		path = Skein.prefix + path

	DirAccess.make_dir_recursive_absolute(path.get_base_dir())

	var f = FileAccess.open(path, FileAccess.WRITE)
	if f.is_open():
		f.store_string(JSON.stringify(data, '\t'))

func load_json(path, default=null):
	if !path.begins_with('res://') and !path.begins_with('user://'):
		path = Skein.prefix + path
	var result = default

	var f := FileAccess.open(path, FileAccess.READ)
	if f and f.is_open():
		var text = f.get_as_text()

		var parse = JSON.parse_string(text)
		# var test_json_conv = JSON.new()
		# test_json_conv.parse(text)
		# var parse = test_json_conv.get_data()
		if parse is Dictionary:
			result = parse
	return result

# ******************************************************************************

func save_yarn(path, data):
	if data == null or data == {}:
		return
	if !path.begins_with('res://') and !path.begins_with('user://'):
		path = Skein.prefix + path

	DirAccess.make_dir_recursive_absolute(path.get_base_dir())

	var out = convert_nodes_to_yarn(data)

	var f = FileAccess.open(path, FileAccess.WRITE)
	if f.is_open():
		f.store_string(out)

func convert_nodes_to_yarn(data):
	var out = ''

	for id in data:
		var node = data[id]

		node['title'] = node['name']
		node.erase('name')

		var text = node['text']
		node.erase('text')

		node.erase('size')
		node.erase('offset')

		if 'connections' in node:
			node.connections = var_to_str(node.connections).replace('\n', '')
		if 'choices' in node:
			node.choices = var_to_str(node.choices).replace('\n', '')
		if 'branches' in node:
			node.branches = var_to_str(node.branches).replace('\n', '')

		for field in node:
			out += field + ': ' + str(node[field]) + '\n'

		out += '---' + '\n'

		out += text + '\n'
		out += '===' + '\n'

	return out

# ------------------------------------------------------------------------------

func load_yarn(path, default=null):
	var result = default

	var f = FileAccess.open(path, FileAccess.READ)
	if f.is_open():
		var text = f.get_as_text()
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
			var node = create_node(header, body)
			nodes[str(node.id)] = node
			
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

	node.type = fields.get('type', 'dialog')
	fields.erase('type')

	# old speech type is now dialog
	if node.type == 'speech':
		node.type = 'dialog'
		if node.name == 'Speech':
			node.name = 'Dialog'

	for field in fields:
		node[field] = fields[field]

	if 'connections' in node:
		node.connections = str_to_var(node.connections)
	if 'choices' in node:
		node.choices = str_to_var(node.choices)
	if 'branches' in node:
		node.branches = str_to_var(node.branches)

	var _body = body[0]
	var i = 1
	while i < body.size():
		_body += '\n' + body[i]
		i += 1
	node['text'] = _body

	return node
