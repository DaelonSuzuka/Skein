tool
extends Control

# ******************************************************************************

func _ready():
	$Toolbar/New.connect('pressed', $GraphEdit, 'create_node')
	$Toolbar/Print.connect('pressed', $GraphEdit, 'print_data')
	$Toolbar/Clear.connect('pressed', $GraphEdit, 'clear')
	$Toolbar/Save.connect('pressed', self, 'save_data')
	load_data()
	$ContextMenu.graph = $GraphEdit

func _input(event):
	if event is InputEventMouseButton and event.button_index == 2 and event.pressed:
		$ContextMenu.show_context_menu(event)

# ******************************************************************************

var file_name = 'res://data.json'

func save_data():
	var data = {
		nodes = {},
		connections = $GraphEdit.connections,
		scroll_offset = {
			x = $GraphEdit.scroll_offset.x,
			y = $GraphEdit.scroll_offset.y,
		},
		zoom = $GraphEdit.zoom,
	}
	for node in $GraphEdit.nodes:
		data.nodes[node.data.id] = node.get_data()

	save_json(data)

func load_data():
	var data = load_json()
	if data:
		for id in data.nodes:
			$GraphEdit.create_node().set_data(data.nodes[id])
		for con in data.connections:
			$GraphEdit.request_connection(con[0], con[1], con[2], con[3])
		if 'scroll_offset' in data:
			$GraphEdit.scroll_offset.x = data.scroll_offset.x
			$GraphEdit.scroll_offset.y = data.scroll_offset.y
		if 'zoom' in data:
			$GraphEdit.zoom = data.zoom

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