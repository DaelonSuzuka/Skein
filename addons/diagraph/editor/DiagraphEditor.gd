tool
extends Control

# ******************************************************************************

onready var GraphEdit = find_node('GraphEdit')

# ******************************************************************************

func _ready():
	$Toolbar/New.connect('pressed', GraphEdit, 'create_node')
	$Toolbar/Clear.connect('pressed', $ConfirmClear, 'popup')
	$ConfirmClear.connect('confirmed', GraphEdit, 'clear')
	$Toolbar/Save.connect('pressed', self, 'save_data')
	$Toolbar/Trace.connect('pressed', self, 'trace')
	$ContextMenu.connect('create_node', self, 'new_node_requested')

	if !Engine.editor_hint:
		load_data()

func _input(event):
	if event is InputEventMouseButton and event.button_index == 2 and event.pressed:
		# accept_event()
		$ContextMenu.show_context_menu(event)

func new_node_requested(type):
	var data = {
		type = type,
		offset = GraphEdit.get_offset_from_mouse()
	}
	if GraphEdit.use_snap:
		var snap = GraphEdit.snap_distance
		data.offset = data.offset.snapped(Vector2(snap, snap))
	GraphEdit.create_node(data)

# ******************************************************************************

var nodes = {}

func walk_tree(tree, node):
	tree[node.name] = {}
	if !nodes.has(node):
		nodes[node.name] = node
		
	for con in node.data.connections:
		walk_tree(tree[node.name], GraphEdit.nodes[con])

func trace():
	# print('tracing')

	nodes.clear()
	var tree = {}
	var selection = GraphEdit.get_selected_nodes()
	if selection.size() == 1:
		var node = selection[0]
		if 'entry' in node.data and node.data.entry:
			walk_tree(tree, node)
			$DialogBox.show()
			$DialogBox.connect('done', $HSplit, 'show')
			$HSplit.hide()
			$DialogBox.start(nodes, node.name)

# ******************************************************************************

var file_name = 'res://data.json'

func save_data():
	print('saving')
	var data = {
		nodes = {},
		scroll_offset = {
			x = GraphEdit.scroll_offset.x,
			y = GraphEdit.scroll_offset.y,
		},
		zoom = GraphEdit.zoom,
		snap = {
			on = GraphEdit.use_snap,
			step = GraphEdit.snap_distance,
		}
	}
	for node in GraphEdit.nodes.values():
		data.nodes[node.data.id] = node.get_data()

	save_json(data)

func load_data():
	var data = load_json()
	if data:
		for id in data.nodes:
			GraphEdit.create_node(data.nodes[id])
		for node in GraphEdit.nodes.values():
			for to in node.data.connections:
				var con = node.data.connections[to]
				GraphEdit.request_connection(node.name, con[0], to, con[1])
		if 'scroll_offset' in data:
			GraphEdit.scroll_offset.x = data.scroll_offset.x
			GraphEdit.scroll_offset.y = data.scroll_offset.y
		if 'zoom' in data:
			GraphEdit.zoom = data.zoom
		if 'snap' in data:
			GraphEdit.use_snap = data.snap.on
			GraphEdit.snap_distance = data.snap.step

# ******************************************************************************

func save_json(data):
	var f = File.new()
	f.open(file_name, File.WRITE)
	f.store_string(JSON.print(data, "\t"))
	f.close()

func load_json():
	var result = null
	var f = File.new()
	if f.file_exists(file_name):
		f.open(file_name, File.READ)
		var text = f.get_as_text()
		f.close()
		result = JSON.parse(text).result
	return result
