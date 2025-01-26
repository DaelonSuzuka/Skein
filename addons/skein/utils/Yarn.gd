@tool
extends Node

# ******************************************************************************

func save_yarn(path, data):
	if data == null or data == {}:
		return
	if !path.begins_with('res://') and !path.begins_with('user://'):
		path = Skein.Files.prefix + path

	DirAccess.make_dir_recursive_absolute(path.get_base_dir())

	var out = convert_nodes_to_yarn(data)

	var f = FileAccess.open(path, FileAccess.WRITE)
	if f and f.is_open():
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

func load_yarn(path: String, default=null):
	var result = default

	var f = FileAccess.open(path, FileAccess.READ)
	if f and f.is_open():
		var text = f.get_as_text()
		var nodes = parse_yarn(text)
		if nodes:
			result = nodes
	return result

func parse_yarn(text: String):
	var nodes := {}
	var mode := 'header'

	var header := []
	var body := []
	var i := 0
	var lines = text.split('\n')
	while i < lines.size():
		var line = lines[i]
		if line == '===': # end of node
			var node = create_node(header, body)
			nodes[str(node.id)] = node
			
			header.clear()
			body.clear()
			mode = 'header'
		elif line == '---': # end of header
			mode = 'body'
		else:
			if mode == 'header':
				header.append(line)
			if mode == 'body':
				body.append(line)
		i += 1
	return nodes

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
