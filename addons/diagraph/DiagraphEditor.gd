tool
extends Control

# ******************************************************************************

onready var graph_node = load('res://addons/diagraph/DiagraphNode.tscn')
onready var context_menu = $ContextMenu
onready var graph = $VBox/GraphEdit

# ******************************************************************************

func _ready():
	$VBox/Toolbar/New.connect('pressed', graph, 'create_node')
	$VBox/Toolbar/Print.connect('pressed', graph, 'print_data')
	$VBox/Toolbar/Save.connect('pressed', self, 'save_data')
	load_data()

func _input(event):
	if event is InputEventMouseButton and event.button_index == 2 and event.pressed:
		$ContextMenu.show_context_menu(event)

# ******************************************************************************

var file_name = 'res://data.json'

func save_data():
	var data = {
		nodes = {},
		connections = graph.connections,
	}
	for node in graph.nodes:
		data.nodes[node.data.id] = node.get_data()

	var f = File.new()
	f.open(file_name, File.WRITE)
	f.store_string(JSON.print(data, "\t"))
	f.close()

func load_data():
	var result = null
	var f = File.new()
	if f.file_exists(file_name):
		f.open(file_name, File.READ)
		var text = f.get_as_text()
		f.close()
		result = JSON.parse(text).result
		if result:
			for id in result.nodes:
				var data = result.nodes[id]
				graph.create_node().set_data(data)
				for con in result.connections:
					graph.request_connection(con[0], con[1], con[2], con[3])
