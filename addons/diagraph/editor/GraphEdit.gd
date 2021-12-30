tool
extends GraphEdit

# ******************************************************************************

onready var node_types = {
	'entry': load('res://addons/diagraph/nodes/EntryNode.tscn'),
	'exit': load('res://addons/diagraph/nodes/ExitNode.tscn'),
	'speech': load('res://addons/diagraph/nodes/SpeechNode.tscn'),
	'jump': load('res://addons/diagraph/nodes/JumpNode.tscn'),
}

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

func clear() -> void:
	clear_connections()
	connections.clear()
	for node in nodes:
		node.queue_free()
	nodes.clear()

# ******************************************************************************

func create_node(data=null) -> Node:
	var node
	if data:
		node = node_types[data.type].instance()
	else:
		node = node_types['speech'].instance()
		node.set_id(nodes.size() + 1)
	node.connect('close_request', self, 'delete_node', [node])
	add_child(node)
	if data:
		if !('id' in data):
			data.id = nodes.size() + 1
		node.set_data(data)
	nodes.append(node)
	return node
	
func delete_node(node) -> void:
	for con in get_connection_list():
		if con["from"] == node.name or con["to"] == node.name:
			request_disconnection(con["from"], con["from_port"], con["to"], con["to_port"])
	nodes.erase(node)
	node.queue_free()

# ******************************************************************************

func request_connection(from, from_slot, to, to_slot) -> bool:
	for con in get_connection_list():	
		if con["from"] == from:
			if con["from_port"] == from_slot:
				return false
	if !has_node(from):
		return false
	connections.push_back([from, from_slot, to, to_slot])
	connect_node(from, from_slot, to, to_slot)
	return true

func request_disconnection(from, from_slot, to, to_slot) -> void:
	disconnect_node(from, from_slot, to, to_slot)
	connections.erase([from, from_slot, to, to_slot])

func on_connection_from_empty(to, to_slot, release_position) -> void:
	var node = create_node()
	node.offset = release_position + scroll_offset - Vector2(node.rect_size.x, 0.8 * node.rect_size.y)
	node.offset = node.offset.snapped(Vector2(get_snap(), get_snap()))
	request_connection(node.name, 0, to, to_slot)

func on_connection_to_empty(from, from_slot, release_position) -> void:
	var node = create_node()
	node.offset = release_position + scroll_offset - Vector2(0,0.8 * node.rect_size.y)
	node.offset = node.offset.snapped(Vector2(get_snap(), get_snap()))
	if !request_connection(from, from_slot, node.name, 0):
		delete_node(node)

# ******************************************************************************

func delete_nodes_request() -> void:
	for node in get_selected_nodes():
		delete_node(node)

# ******************************************************************************

var copy_data = []

func copy_nodes_request() -> void:
	copy_data.clear()
	for node in get_selected_nodes():
		copy_data.append(node.get_data())

func paste_nodes_request() -> void:
	for node in get_selected_nodes():
		node.selected = false

	var new_nodes = []
	var center = Vector2(0, 0)
	for data in copy_data:
		var node = create_node()
		node.set_data(data)
		new_nodes.append(node)
		center += node.offset
	center /= new_nodes.size()

	var destination = get_offset_from_mouse()
	for node in new_nodes:
		node.offset += destination - center
		node.selected = true

# ******************************************************************************

func get_offset_from_mouse() -> Vector2:
	var offset = Vector2(0, 0)
	offset += (scroll_offset + get_local_mouse_position()) / zoom
	return offset

func get_selected_nodes() -> Array:
	var selected_nodes = []
	for child in get_children():
		if child is GraphNode and child.is_selected():
			selected_nodes.append(child)
	return selected_nodes
