@tool
extends GraphNode

# ******************************************************************************

var ContextMenu = preload('../utils/ContextMenu.gd')

var data := {
	id = 0,
	type = 'base',
	name = '',
	text = '',
	next = 'none',
	default = false,
	position = '',
	connections = {}
}

var slot_colors := [
	Color.AQUA,
	Color.ORANGE_RED,
	Color.GREEN,
	Color.YELLOW,
	Color.FUCHSIA,
	Color.RED,
	Color.TEAL,
	Color.LIME,
]

@onready var Edit = $Body/Toolbar/Edit
@onready var CloseButton = $Body/Toolbar/Close
@onready var Toolbar = $Body/Toolbar
@onready var Title = $Body/Toolbar/Title
@onready var Id = $Body/Toolbar/Id
@onready var Parent = get_parent()

signal changed

# ******************************************************************************

func _ready() -> void:
	CloseButton.pressed.connect(self.emit_signal.bind('close_request'))
	resize_request.connect(self._resize_request)
	gui_input.connect(self._gui_input)

	Title.text_changed.connect(self.renamed)

func _resize_request(new_minsize: Vector2) -> void:
	emit_signal('changed')
	if get_parent().use_snap:
		var snap = get_parent().get_snap()
		size = new_minsize.snapped(Vector2(snap, snap))
	else:
		size = new_minsize

# ******************************************************************************
# Context Menu trigger

func _gui_input(event: InputEvent) -> void:
	if !visible:
		return
	if !(event is InputEventMouseButton) or !event.pressed:
		return

	var title_rect = Rect2(Toolbar.global_position, Toolbar.size * Parent.zoom)
	if title_rect.has_point(event.global_position):
		if event.button_index == 2:
			title_bar_ctx(event.global_position)
			return

	var body_rect = Rect2(global_position, size * Parent.zoom)
	if body_rect.has_point(event.global_position):
		if event.button_index == 2:
			body_ctx(event.global_position)
			return

# ******************************************************************************
# Context Menu override stuff

# Override this
func get_title_bar_ctx_items() -> Array:
	return []

func title_bar_ctx_selection(selection: String):
	pass

# Override this
func get_body_ctx_items() -> Array:
	return []

func body_ctx_selection(selection: String):
	pass

# ******************************************************************************
# Context Menu spawner

func title_bar_ctx(pos: Vector2) -> void:
	Parent.dismiss_ctx()
	Parent.ctx = ContextMenu.new(self, '_title_bar_ctx_selection')
	Parent.ctx.add_check_item('Default')
	Parent.ctx.set_item_checked(0, bool(data.default))
	Parent.ctx.add_item('Copy Path3D')
	Parent.ctx.add_item('Copy Name')
	Parent.ctx.add_item('Copy ID')
	for item in self.get_title_bar_ctx_items():
		Parent.ctx.add_item(item)
	Parent.ctx.open(pos)
	accept_event()

func _title_bar_ctx_selection(selection: String):
	match selection:
		'Default':
			data.default = !data.default
			if data.default:
				for node in Parent.nodes.values():
					node.data.default = false
				data.default = true
		'Copy Path3D':
			var path = '%s:%s' % [Parent.owner.current_conversation, data.name]
			OS.clipboard = path
		'Copy Name':
			OS.clipboard = data.name
		'Copy ID':
			OS.clipboard = str(data.id)

	self.title_bar_ctx_selection(selection)

func body_ctx(pos: Vector2) -> void:
	Parent.dismiss_ctx()
	Parent.ctx = ContextMenu.new(self, '_body_ctx_selection')
	var items = self.get_body_ctx_items()
	for item in items:
		Parent.ctx.add_item(item)
	if items:
		Parent.ctx.open(pos)
	accept_event()

func _body_ctx_selection(selection: String):
	# default body options go here

	self.body_ctx_selection(selection)

# ******************************************************************************

func set_id(id) -> void:
	data.id = id
	name = str(id)
	Id.text = str(data.id)

func rename(new_name):
	Title.text = new_name
	renamed(new_name)

func renamed(new_name):
	emit_signal('changed')
	Parent.emit_signal('node_renamed', data.name, new_name)
	data.name = new_name

# ******************************************************************************

func get_data() -> Dictionary:
	var _data = data.duplicate(true)
	_data.position = var_to_str(Rect2(position_offset.round(), size.round()))
	_data.name = Title.text
	if _data.next == 'none':
		_data.erase('next')
	if _data.default == false:
		_data.erase('default')
	return _data

func set_data(new_data: Dictionary) -> GraphNode:
	if 'type' in new_data:
		data.type = new_data.type
	if 'connections' in new_data:
		for con in new_data.connections:
			data.connections[con] = []
			data.connections[con].append(int(new_data.connections[con][0]))
			data.connections[con].append(int(new_data.connections[con][1]))
	if 'default' in new_data:
		var state = new_data['default']
		if state is String:
			state = {'true': true, 'false': false}[state.to_lower()]
		data.default = state
	if 'next' in new_data:
		data.next = new_data.next
	if 'id' in new_data:
		set_id(new_data.id)
	if 'name' in new_data:
		data.name = new_data.name
		rename(new_data.name)
	if 'position' in new_data:
		var rect = str_to_var(new_data.position)
		position_offset = rect.position.round()
		size = rect.size.round()
	else:
		if 'position_offset' in new_data:
			position_offset = str_to_var(new_data.position_offset)
		if 'size' in new_data:
			size = str_to_var(new_data.size)
	return self
