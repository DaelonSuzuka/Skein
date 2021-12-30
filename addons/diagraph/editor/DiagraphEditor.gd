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
	$ContextMenu.connect('create_node', self, 'new_node_requested')

	if !Engine.editor_hint:
		load_data()

func _input(event):
	if event is InputEventMouseButton and event.button_index == 2 and event.pressed:
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

var file_name = 'res://data.json'

func save_data():
	var data = {
		nodes = {},
		connections = GraphEdit.connections,
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
	for node in GraphEdit.nodes:
		data.nodes[node.data.id] = node.get_data()

	save_json(data)

func load_data():
	var data = load_json()
	if data:
		for id in data.nodes:
			GraphEdit.create_node(data.nodes[id])
		for con in data.connections:
			GraphEdit.request_connection(con[0], con[1], con[2], con[3])
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
