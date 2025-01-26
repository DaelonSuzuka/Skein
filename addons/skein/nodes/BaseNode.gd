@tool
extends GraphNode

# ******************************************************************************

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

@onready var edit_menu: MenuButton = $Body/Toolbar/Edit
@onready var close_button: Button = $Body/Toolbar/Close
@onready var toolbar: HBoxContainer = $Body/Toolbar
@onready var title_label = $Body/Toolbar/Title
@onready var id_label: Label = $Body/Toolbar/Id
@onready var parent = get_parent()

signal changed

# ******************************************************************************

func _ready() -> void:
	close_button.pressed.connect(self.emit_signal.bind('delete_request'))
	resize_request.connect(self._resize_request)
	gui_input.connect(self._gui_input)

	title_label.text_changed.connect(self.renamed)

func _resize_request(new_minsize: Vector2) -> void:
	self.changed.emit()
	if get_parent().snapping_enabled:
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

	var title_rect = Rect2(toolbar.global_position, toolbar.size * parent.zoom)
	if title_rect.has_point(event.global_position):
		if event.button_index == 2:
			title_bar_ctx(event.global_position)
			return

	var body_rect = Rect2(global_position, size * parent.zoom)
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
	parent.dismiss_ctx()
	parent.ctx = SkeinContextMenu.new(self, self._title_bar_ctx_selection)
	parent.ctx.add_check_item('Default')
	parent.ctx.set_item_checked(0, bool(data.default))
	parent.ctx.add_item('Copy Path')
	parent.ctx.add_item('Copy Name')
	parent.ctx.add_item('Copy ID')
	for item in self.get_title_bar_ctx_items():
		parent.ctx.add_item(item)
	parent.ctx.open(get_global_mouse_position())
	accept_event()

func _title_bar_ctx_selection(selection: String):
	match selection:
		'Default':
			data.default = !data.default
			if data.default:
				for node in parent.nodes.values():
					node.data.default = false
				data.default = true
		'Copy Path':
			var path = '%s:%s' % [parent.owner.current_conversation, data.name]
			DisplayServer.clipboard_set(path)
		'Copy Name':
			DisplayServer.clipboard_set(data.name)
		'Copy ID':
			DisplayServer.clipboard_set(str(data.id))

	self.title_bar_ctx_selection(selection)

func body_ctx(pos: Vector2) -> void:
	parent.dismiss_ctx()
	parent.ctx = SkeinContextMenu.new(self, self._body_ctx_selection)
	var items = self.get_body_ctx_items()
	for item in items:
		parent.ctx.add_item(item)
	if items:
		parent.ctx.open(get_global_mouse_position())
	accept_event()

func _body_ctx_selection(selection: String):
	# default body options go here

	self.body_ctx_selection(selection)

# ******************************************************************************

func set_id(id) -> void:
	data.id = id
	name = str(id)
	id_label.text = str(data.id)

func rename(new_name):
	title_label.text = new_name
	renamed(new_name)

func renamed(new_name):
	emit_signal('changed')
	parent.emit_signal('node_renamed', data.name, new_name)
	data.name = new_name

# ******************************************************************************

func get_data() -> Dictionary:
	var _data = data.duplicate(true)
	_data.position = var_to_str(Rect2(position_offset.round(), size.round()))
	_data.name = title_label.text
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
