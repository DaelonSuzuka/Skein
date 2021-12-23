tool
extends GraphEdit

# ******************************************************************************

onready var graph_node = load('res://addons/diagraph/nodes/DiagraphNode.tscn')

var connections = []
var nodes = []

# ******************************************************************************

func _ready():
	connect('connection_request', self, 'request_connection')
	connect('disconnection_request', self, 'request_disconnection')
	connect('connection_from_empty', self, 'on_connection_from_empty')
	connect('connection_to_empty', self, 'on_connection_to_empty')
	connect('copy_nodes_request', self, 'copy_nodes_request')
	connect('delete_nodes_request', self, 'delete_nodes_request')
	connect('paste_nodes_request', self, 'paste_nodes_request')

# ******************************************************************************

func print_data():
	var data = {
		nodes = {},
		connections = connections,
	}
	for node in nodes:
		data.nodes[node.data.id] = node.get_data()

	print(data)

func clear():
	clear_connections()
	connections.clear()
	for node in nodes:
		node.queue_free()
	nodes.clear()


# ******************************************************************************

func create_node(data=null):
	var id = nodes.size() + 1
	var node = graph_node.instance()
	node.set_id(id)
	if data:
		node.set_data(data)
	node.connect('close_request', self, 'delete_node', [node])
	nodes.append(node)
	add_child(node)
	return node
	
func delete_node(node):
	for con in get_connection_list():
		if con["from"] == node.name or con["to"] == node.name:
			request_disconnection(con["from"], con["from_port"], con["to"], con["to_port"])
	nodes.erase(node)
	node.queue_free()

# ******************************************************************************

func request_connection(from, from_slot, to, to_slot):
	for con in get_connection_list():	
		if con["from"] == from:
			if con["from_port"] == from_slot:
				return false
	connections.push_back([from, from_slot, to, to_slot])
	connect_node(from, from_slot, to, to_slot)
	return true

func request_disconnection(from, from_slot, to, to_slot):
	disconnect_node(from, from_slot, to, to_slot)
	connections.erase([from, from_slot, to, to_slot])

func on_connection_from_empty(to, to_slot, release_position):
	var node = create_node()
	node.offset = release_position + scroll_offset - Vector2(node.rect_size.x, 0.8 * node.rect_size.y)
	node.offset = node.offset.snapped(Vector2(get_snap(), get_snap()))
	request_connection(node.name, 0, to, to_slot)

func on_connection_to_empty(from, from_slot, release_position):
	var node = create_node()
	node.offset = release_position + scroll_offset - Vector2(0,0.8 * node.rect_size.y)
	node.offset = node.offset.snapped(Vector2(get_snap(), get_snap()))
	if !request_connection(from, from_slot, node.name, 0):
		delete_node(node)

# ******************************************************************************

func delete_nodes_request():
	for node in get_selected_nodes():
		delete_node(node)

# ******************************************************************************

var copy_data = []

func copy_nodes_request():
	copy_data.clear()
	for node in get_selected_nodes():
		copy_data.push_back(node.get_data())

func paste_nodes_request():
	for node in get_selected_nodes():
		node.selected = false

	var new_nodes = []
	var center = Vector2(0, 0)
	for data in copy_data:
		var node = create_node(data)
		new_nodes.append(node)
		center += node.offset
	center /= new_nodes.size()

	var destination = get_offset_from_mouse()
	for node in new_nodes:
		node.offset += destination - center
		node.selected = true

# ******************************************************************************

func get_offset_from_mouse():
	var offset = Vector2(0, 0)
	offset += (scroll_offset + get_local_mouse_position()) / zoom
	return offset

func get_selected_nodes():
	var selected_nodes = []
	for child in get_children():
		if child is GraphNode and child.is_selected():
			selected_nodes.append(child)
	return selected_nodes
