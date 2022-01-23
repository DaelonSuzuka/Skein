tool
extends GraphNode

# ******************************************************************************

var data := {
	id = 0,
	type = 'base',
	name = '',
	next = 'none',
	rect_size = {x = 0, y = 0},
	offset = {x = 0, y = 0},
	connections = {}
}

onready var Edit = $Body/Toolbar/Edit

# ******************************************************************************

func _ready():
	$Body/Toolbar/Close.connect('pressed', self, 'emit_signal', ['close_request'])
	connect('resize_request', self, 'resize_request')

func resize_request(new_minsize):
	if get_parent().use_snap:
		var snap = get_parent().get_snap()
		rect_size = new_minsize.snapped(Vector2(snap, snap))
	else:
		rect_size = new_minsize

# ******************************************************************************

func set_id(id):
	data.id = id
	name = str(id)
	$Body/Toolbar/Id.text = str(data.id) + " | "

func update_title():
	$Body/Toolbar/Title.text = data.name

# ******************************************************************************

func get_data():
	data.offset = var2str(offset)
	data.rect_size = var2str(rect_size)
	data.name = $Body/Toolbar/Title.text
	return data.duplicate(true)

func set_data(new_data):
	if 'type' in new_data:
		data.type = new_data.type
	if 'connections' in new_data:
		for con in new_data.connections:
			data.connections[con] = []
			data.connections[con].append(int(new_data.connections[con][0]))
			data.connections[con].append(int(new_data.connections[con][1]))
	if 'id' in new_data:
		set_id(new_data.id)
	if 'name' in new_data:
		data.name = new_data.name
		update_title()
	if 'offset' in new_data:
		offset = str2var(new_data.offset)
	if 'rect_size' in new_data:
		rect_size = str2var(new_data.rect_size)
	return self
