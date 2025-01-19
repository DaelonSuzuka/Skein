@tool
extends GraphEdit

# ******************************************************************************

@onready var node_types = {
	'entry': load('res://addons/skein/nodes/EntryNode.tscn'),
	'exit': load('res://addons/skein/nodes/ExitNode.tscn'),
	# 'base': load('res://addons/skein/nodes/DialogNode.tscn'),
	'speech': load('res://addons/skein/nodes/DialogNode.tscn'),
	'dialog': load('res://addons/skein/nodes/DialogNode.tscn'),
	'comment': load('res://addons/skein/nodes/CommentNode.tscn'),
	'branch': load('res://addons/skein/nodes/BranchNode.tscn'),
	'jump': load('res://addons/skein/nodes/JumpNode.tscn'),
	'subgraph': load('res://addons/skein/nodes/SubgraphNode.tscn'),
}

var display_types = [
	'dialog',
	'comment',
	'branch',
	'jump',
]

var nodes := {}
var notify_changes := true

signal zoom_changed(zoom)

signal node_created(node)
signal node_deleted(id)
signal node_renamed(old, new)
signal node_changed

# ******************************************************************************

func _ready() -> void:
	connection_request.connect(self.request_connection)
	disconnection_request.connect(self.request_disconnection)
	# connection_from_empty.connect(self.on_connection_from_empty)
	# connection_to_empty.connect(self.on_connection_to_empty)
	duplicate_nodes_request.connect(self._duplicate_nodes_request)
	copy_nodes_request.connect(self._copy_nodes_request)
	delete_nodes_request.connect(self._delete_nodes_request)
	paste_nodes_request.connect(self._paste_nodes_request)
	popup_request.connect(self.on_popup_request)

	end_node_move.connect(self.contents_changed)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.as_text() == 'Ctrl+A' and event.pressed:
			for node in self.nodes.values():
				node.selected = true

func contents_changed():
	if notify_changes:
		emit_signal('node_changed')

# ******************************************************************************

var ctx: SkeinContextMenu = null
var ctx_position := Vector2()

func dismiss_ctx() -> void:
	if is_instance_valid(ctx):
		ctx.queue_free()
		ctx = null

func on_popup_request(position) -> void:
	dismiss_ctx()
	ctx = SkeinContextMenu.new(self, self.new_node_requested)
	ctx.add_separator('New Node:')
	for type in display_types:
		ctx.add_item(type.capitalize())
	ctx_position = get_offset_from_mouse()
	ctx.open(get_global_mouse_position())

func new_node_requested(type: String) -> void:
	var data = {type = type.to_lower(), offset = ctx_position, position_offset = Vector2()}
	
	if snapping_enabled:
		var snap = snapping_distance
		data.position_offset = data.position_offset.snapped(Vector2(snap, snap))
	data.position_offset = var_to_str(data.position_offset)
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
		node = node_types[data.type].instantiate()
	else:
		node = node_types['dialog'].instantiate()
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
	contents_changed()

	# node.close_request.connect(self.delete_node.bind(node))
	node.changed.connect(self.contents_changed)

	return node

func delete_node(node) -> void:
	# if we get passed a node id, get the actual node instead
	if str(node) in nodes:
		node = nodes[str(node)]

	for con in self.connections:
		if con['from_node'] == node.name or con['to_node'] == node.name:
			request_disconnection(con['from_node'], con['from_port'], con['to_node'], con['to_port'])
	var id = node.data.id
	nodes.erase(id)
	node.queue_free()
	emit_signal('node_deleted', id)

func rename_node(id, new_name):
	if str(id) in nodes:
		nodes[str(id)].rename(new_name)
		contents_changed()

func select_node(node):
	# if we get passed a node id, get the actual node instead
	if str(node) in nodes:
		node = nodes[str(node)]
	if node is GraphNode:
		set_selected(node)

# ******************************************************************************

func request_connection(from, from_slot, to, to_slot) -> bool:
	for con in self.connections:
		if con['from_node'] == from:
			if con['from_port'] == from_slot:
				return false
	if !has_node(str(from)):
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
	var data = {type = 'dialog', position_offset = get_offset_from_mouse()}
	if snapping_enabled:
		var snap = snapping_distance
		data.position_offset = data.position_offset.snapped(Vector2(snap, snap))
	data.position_offset = var_to_str(data.position_offset)
	var node = create_node(data)

	request_connection(node.name, 0, to, to_slot)

func on_connection_to_empty(from, from_slot, release_position) -> void:
	var data = {type = 'dialog', position_offset = get_offset_from_mouse()}
	if snapping_enabled:
		var snap = snapping_distance
		data.position_offset = data.position_offset.snapped(Vector2(snap, snap))
	data.position_offset = var_to_str(data.position_offset)
	var node = create_node(data)

	if !request_connection(from, from_slot, node.name, 0):
		delete_node(node)

# ******************************************************************************

func _delete_nodes_request(_arg) -> void:
	for node in get_selected_nodes():
		delete_node(node)

# ******************************************************************************

var copy_data = []

func _duplicate_nodes_request() -> void:
	_copy_nodes_request()
	_paste_nodes_request()

func _copy_nodes_request() -> void:
	copy_data.clear()
	for node in get_selected_nodes():
		copy_data.append(node.get_data())

func _paste_nodes_request() -> void:
	for node in get_selected_nodes():
		node.selected = false

	var new_nodes = []
	var center = Vector2(0, 0)
	for data in copy_data:
		if 'id' in data:
			data.erase('id')
		var node = create_node(data)
		new_nodes.append(node)
		center += node.position_offset
	center /= new_nodes.size()

	var destination = get_offset_from_mouse()
	for node in new_nodes:
		node.position_offset += destination - center
		node.selected = true

	contents_changed()

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

func get_graphnode(id: String):
	if id in nodes:
		return nodes[id]
	else:
		for node in nodes.values():
			if node and node.data.name == name:
				return node
	return null

func focus_node(name: String) -> void:
	var node = get_graphnode(name)
	if node:
		var node_center: Vector2 = (node.position_offset + (node.size / 2)) * zoom
		scroll_offset = node_center - (size / 2)

		while (node.size.y) * zoom > (size.y * 0.9):
			zoom -= zoom_step

		if zoom < 1.0:
			zoom = 1.0

		select_node(name)

# func focus_selected_nodes():
# 	var selected_nodes = get_selected_nodes()
# 	if selected_nodes:
# 		var center = Vector2()
# 		for node in selected_nodes:
# 			center += (node.position_offset + (node.size / 2)) * zoom

# 		scroll_offset = center - (size / 2)

# ------------------------------------------------------------------------------

func unhighlight_all_nodes():
	for node in nodes.values():
		# node.overlay = GraphNode.OVERLAY_DISABLED
		if node.has_method('unhighlight_lines'):
			node.unhighlight_lines()

func highlight_node(name: String) -> void:
	unhighlight_all_nodes()
	var node = get_graphnode(name)
	if node:
		# node.overlay = GraphNode.OVERLAY_BREAKPOINT
		pass

# ******************************************************************************

func set_nodes(data: Dictionary) -> void:
	notify_changes = false
	for node_data in data.values():
		create_node(node_data)
	for node in nodes.values():
		node.queue_redraw()
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
	scroll_offset = str_to_var(data.get('scroll_offset', 'Vector2( 0, 0 )'))
	zoom = data.get('zoom', 1)
	
	minimap_enabled = data.get('minimap_enabled', true)
	minimap_opacity = data.get('minimap_opacity', 0.65)
	minimap_size = str_to_var(data.get('minimap_size', 'Vector2( 240, 160 )'))

	if 'snap' in data:
		snapping_enabled = data.snap.checked
		snapping_distance = data.snap.step

func get_data() -> Dictionary:
	var data = {
		scroll_offset = var_to_str(scroll_offset),
		zoom = zoom,
		minimap_enabled = minimap_enabled,
		minimap_opacity = minimap_opacity,
		minimap_size = var_to_str(minimap_size),
		snap = {
			checked = snapping_enabled,
			step = snapping_distance,
		},
	}
	return data
