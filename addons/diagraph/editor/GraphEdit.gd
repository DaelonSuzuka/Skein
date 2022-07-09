tool
extends GraphEdit

# ******************************************************************************

onready var ContextMenu = preload('res://addons/diagraph/utils/ContextMenu.gd')

onready var node_types = {
	# 'entry': load('res://addons/diagraph/nodes/EntryNode.tscn'),
	'comment': load('res://addons/diagraph/nodes/CommentNode.tscn'),
	# 'exit': load('res://addons/diagraph/nodes/ExitNode.tscn'),
	# 'base': load('res://addons/diagraph/nodes/SpeechNode.tscn'),
	'speech': load('res://addons/diagraph/nodes/SpeechNode.tscn'),
	'branch': load('res://addons/diagraph/nodes/BranchNode.tscn'),
	'jump': load('res://addons/diagraph/nodes/JumpNode.tscn'),
	# 'subgraph': load('res://addons/diagraph/nodes/SubgraphNode.tscn'),
}

var nodes := {}
var notify_changes := true

signal zoom_changed(zoom)

var zoom_scroll := false setget set_zoom_scroll

func set_zoom_scroll(state):
	zoom_scroll = state

signal node_created(node)
signal node_deleted(id)
signal node_renamed(old, new)
signal node_changed

# ******************************************************************************

func _ready() -> void:
	connect('connection_request', self, 'request_connection')
	connect('disconnection_request', self, 'request_disconnection')
	# connect('connection_from_empty', self, 'on_connection_from_empty')
	# connect('connection_to_empty', self, 'on_connection_to_empty')
	connect('duplicate_nodes_request', self, 'duplicate_nodes_request')
	connect('copy_nodes_request', self, 'copy_nodes_request')
	connect('delete_nodes_request', self, 'delete_nodes_request')
	connect('paste_nodes_request', self, 'paste_nodes_request')
	connect('popup_request', self, 'on_popup_request')

	connect('_begin_node_move', self, 'contents_changed')

func contents_changed():
	if notify_changes:
		emit_signal('node_changed')

# ******************************************************************************

var ctx = null
var ctx_position := Vector2()

func dismiss_ctx() -> void:
	if is_instance_valid(ctx):
		ctx.queue_free()
		ctx = null

func on_popup_request(position) -> void:
	dismiss_ctx()
	ctx = ContextMenu.new(self, 'new_node_requested')
	ctx.add_separator('New Node:')
	for type in node_types:
		ctx.add_item(type.capitalize())
	ctx_position = get_offset_from_mouse()
	ctx.open(position)

func new_node_requested(type: String) -> void:
	var data = {type = type.to_lower(), offset = ctx_position}
	if use_snap:
		var snap = snap_distance
		data.offset = data.offset.snapped(Vector2(snap, snap))
	data.offset = var2str(data.offset)
	create_node(data)

# ******************************************************************************

func clear() -> void:
	clear_connections()
	for node in nodes.values():
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	nodes.clear()
	used_ids.clear()

# ******************************************************************************

var used_ids = []

func get_id() -> int:
	var id = randi()
	if id in used_ids:
		id = get_id()
	used_ids.append(id)
	return id

func create_node(data=null) -> Node:
	var node
	if data:
		node = node_types[data.type].instance()
	else:
		node = node_types['speech'].instance()
		node.set_id(get_id())
	add_child(node)
	if data:
		if 'id' in data:
			used_ids.append(data.id)
		else:
			data.id = get_id()
		node.set_data(data)
	nodes[str(node.data.id)] = node
	emit_signal('node_created', node)

	node.connect('close_request', self, 'delete_node', [node])
	node.connect('changed', self, 'contents_changed')

	return node

func delete_node(node) -> void:
	# if we get passed a node id, get the actual node instead
	if str(node) in nodes:
		node = nodes[str(node)]

	for con in get_connection_list():
		if con['from'] == node.name or con['to'] == node.name:
			request_disconnection(con['from'], con['from_port'], con['to'], con['to_port'])
	var id = node.data.id
	nodes.erase(id)
	node.queue_free()
	emit_signal('node_deleted', id)

func rename_node(id, new_name):
	if str(id) in nodes:
		nodes[str(id)].rename(new_name)

func select_node(node):
	# if we get passed a node id, get the actual node instead
	if str(node) in nodes:
		node = nodes[str(node)]
	if node is GraphNode:
		set_selected(node)

# ******************************************************************************

func request_connection(from, from_slot, to, to_slot) -> bool:
	for con in get_connection_list():
		if con['from'] == from:
			if con['from_port'] == from_slot:
				return false
	if !has_node(from):
		return false
	if !(from in nodes):
		return false
	if from == to:
		return false

	nodes[from].data.connections[to] = [from_slot, to_slot]
	connect_node(from, from_slot, to, to_slot)
	return true

func request_disconnection(from, from_slot, to, to_slot) -> void:
	disconnect_node(from, from_slot, to, to_slot)
	nodes[from].data.connections.erase(to)

func on_connection_from_empty(to, to_slot, release_position) -> void:
	var data = {type = 'speech', offset = get_offset_from_mouse()}
	if use_snap:
		var snap = snap_distance
		data.offset = data.offset.snapped(Vector2(snap, snap))
	data.offset = var2str(data.offset)
	var node = create_node(data)

	request_connection(node.name, 0, to, to_slot)

func on_connection_to_empty(from, from_slot, release_position) -> void:
	var data = {type = 'speech', offset = get_offset_from_mouse()}
	if use_snap:
		var snap = snap_distance
		data.offset = data.offset.snapped(Vector2(snap, snap))
	data.offset = var2str(data.offset)
	var node = create_node(data)

	if !request_connection(from, from_slot, node.name, 0):
		delete_node(node)

# ******************************************************************************

func delete_nodes_request() -> void:
	for node in get_selected_nodes():
		delete_node(node)

# ******************************************************************************

var copy_data = []

func duplicate_nodes_request() -> void:
	copy_nodes_request()
	paste_nodes_request()

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
		if 'id' in data:
			data.erase('id')
		var node = create_node(data)
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

func get_node_by_name(name: String):
	for node in nodes.values():
		if is_instance_valid(node) and node.data.name == name:
			return node
	return null

func focus_node(name: String):
	var node = null
	if name in nodes:
		node = nodes[name]
	else:
		node = get_node_by_name(name)
	if node:
		var node_center = (node.offset + (node.rect_size / 2)) * zoom
		scroll_offset = node_center - (rect_size / 2)

		while (node.rect_size.y) * zoom > (rect_size.y * 0.9):
			zoom -= zoom_step

		if zoom < 1.0:
			zoom = 1.0

		select_node(name)

# func focus_selected_nodes():
# 	var selected_nodes = get_selected_nodes()
# 	if selected_nodes:
# 		var center = Vector2()
# 		for node in selected_nodes:
# 			center += (node.offset + (node.rect_size / 2)) * zoom

# 		scroll_offset = center - (rect_size / 2)

# ******************************************************************************

func set_nodes(data: Dictionary) -> void:
	notify_changes = false
	for node_data in data.values():
		create_node(node_data)
	for node in nodes.values():
		node.update()
		for to in node.data.connections:
			var con = node.data.connections[to]
			request_connection(node.name, con[0], to, con[1])
	notify_changes = true

func get_nodes() -> Dictionary:
	var data := {}
	for node in nodes.values():
		if is_instance_valid(node):
			data[str(node.data.id)] = node.get_data()
	return data

# ******************************************************************************

func set_data(data: Dictionary) -> void:
	if 'scroll_offset' in data:
		scroll_offset = str2var(data.scroll_offset)
	if 'minimap_enabled' in data:
		minimap_enabled = data.minimap_enabled
	if 'minimap_opacity' in data:
		minimap_opacity = data.minimap_opacity
	if 'minimap_size' in data:
		minimap_size = str2var(data.minimap_size)
	if 'zoom' in data:
		zoom = data.zoom
	if 'snap' in data:
		use_snap = data.snap.on
		snap_distance = data.snap.step

func get_data() -> Dictionary:
	var data = {
		scroll_offset = var2str(scroll_offset),
		zoom = zoom,
		minimap_enabled = minimap_enabled,
		minimap_opacity = minimap_opacity,
		minimap_size = var2str(minimap_size),
		snap={
			on = use_snap,
			step = snap_distance,
		},
	}
	return data
