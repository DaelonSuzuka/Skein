tool
extends GraphEdit

# ******************************************************************************

onready var graph_node = load('res://addons/diagraph/DiagraphNode.tscn')

var connections = []
var nodes = []

# ******************************************************************************

func _ready():
	connect('connection_request', self, 'request_connection')
	connect('disconnection_request', self, 'request_disconnection')
	connect('connection_from_empty', self, 'on_connection_from_empty')
	connect('connection_to_empty', self, 'on_connection_to_empty')

# ******************************************************************************

func print_data():
	var data = {
		nodes = {},
		connections = connections,
	}
	for node in nodes:
		data.nodes[node.data.id] = node.get_data()

	print(data)


# ******************************************************************************

func create_node():
	var id = nodes.size() + 1
	var node = graph_node.instance()
	node.set_id(id)
	node.connect('close_request', self, 'delete_node', [node])
	nodes.append(node)
	add_child(node)
	return node
	
func delete_node(node):
	for con in get_connection_list():
		if con["from"] == node.name:
			request_disconnection(con["from"], con["from_port"], con["to"], con["to_port"])
		elif con["to"] == node.name:
			request_disconnection(con["from"], con["from_port"], con["to"], con["to_port"])
	nodes.erase(node)
	node.queue_free()
	print(node)

func request_connection(from, from_slot, to, to_slot):
	for con in get_connection_list():	
		if con["from"] == from:
			if con["from_port"] == from_slot:
				return false
	#only connect right side slot is free ->
	connections.push_back([from, from_slot, to, to_slot])
	connect_node(from, from_slot, to, to_slot)
	return true


func request_disconnection(from, from_slot, to, to_slot):
	print('request_disconnection')
	pass
# 	disconnect_node(from, from_slot, to, to_slot)
# 	all_connections.erase([from, from_slot, to, to_slot])

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
