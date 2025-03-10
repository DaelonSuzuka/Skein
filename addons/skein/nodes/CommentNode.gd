@tool
extends GraphFrame

# ******************************************************************************

var data := {
	id = 0,
	type = 'comment',
	name = '',
	text = '',
	next = 'none',
	default = false,
	position = '',
	connections = {}
}

@onready var parent = get_parent()

signal changed

# ******************************************************************************

func _ready():
	%BGColor.color_changed.connect(self.set_color)
	%Tooltip.hide()
	%Title.text_changed.connect(%TooltipLabel.set_text)
	%Title.text_changed.connect(self.renamed)

	if parent is GraphEdit:
		position_offset_changed.connect(self._position_offset_changed)
		parent.begin_node_move.connect(self.begin_move)
		parent.end_node_move.connect(self.end_move)
		# parent.zoom_changed.connect(self.zoom_changed)
		zoom_changed(parent.zoom)

	%Close.pressed.connect(self.delete_request.emit)
	resize_request.connect(self._resize_request)

func _resize_request(new_minsize: Vector2) -> void:
	self.changed.emit()
	if parent.snapping_enabled:
		var snap: int = parent.snapping_distance
		size = new_minsize.snapped(Vector2(snap, snap))
	else:
		size = new_minsize

func set_color(color: Color):
	tint_color = color
	# %Tooltip.self_modulate = color

# ******************************************************************************

var dragging := false
var start_pos := Vector2()
var drag_children: Dictionary[Node, Vector2] = {}

func begin_move():
	if !selected:
		return
	dragging = true
	drag_children.clear()
	start_pos = position_offset

	var own_region := Rect2(position_offset, size)
	for node in get_parent().nodes.values():
		if node == self or !is_instance_valid(node):
			continue
		var node_region := Rect2(node.position_offset, node.size)
		if own_region.encloses(node_region):
			drag_children[node] = node.position_offset

func _position_offset_changed():
	var difference := start_pos - position_offset
	for child in drag_children:
		var start := drag_children[child]
		child.position_offset = start - difference

func end_move():
	if !selected:
		return
	dragging = false

# ******************************************************************************

func set_stylebox_borders(stylebox: StyleBox, width):
	stylebox.border_width_bottom = width
	stylebox.border_width_top = width
	stylebox.border_width_left = width
	stylebox.border_width_right = width

func zoom_changed(zoom):
	%Tooltip.hide()

	var width := max(round(1 / zoom), 1) as int

	# set_stylebox_borders(theme.get_stylebox('comment', 'GraphNode'), width)
	# set_stylebox_borders(theme.get_stylebox('comment_focus', 'GraphNode'), width)
	# set_stylebox_borders(tooltip_bg.get_stylebox('panel'), width)

	if zoom < .5:
		%Tooltip.show()
		# %Tooltip.theme.default_font.size = round(16 / zoom)

# ******************************************************************************

func set_id(id) -> void:
	data.id = id
	name = str(id)
	%Id.text = str(data.id)

func rename(new_name: String):
	%Title.text = new_name
	%TooltipLabel.text = new_name
	renamed(new_name)

func renamed(new_name: String):
	changed.emit()
	parent.node_renamed.emit(data.name, new_name)
	data.name = new_name

# ******************************************************************************

func get_data():
	var _data := data.duplicate(true)
	_data.position = var_to_str(Rect2(position_offset.round(), size.round()))
	_data.name = %Title.text
	_data.color = %BGColor.color.to_html()
	return _data

func decode_data(input):
	if input is String:
		return str_to_var(input)
	return input

func set_data(new_data: Dictionary) -> GraphElement:
	if 'type' in new_data:
		data.type = new_data.type
	if 'default' in new_data:
		var state = new_data['default']
		if state is String:
			state = {'true': true, 'false': false}[state.to_lower()]
		data.default = state
	if 'id' in new_data:
		set_id(new_data.id)
	if 'name' in new_data:
		data.name = new_data.name
		%Title.text = new_data.name
		%TooltipLabel.text = new_data.name
	if 'position' in new_data:
		var rect = decode_data(new_data.position)
		position_offset = rect.position.round()
		size = rect.size.round()
	else:
		if 'position_offset' in new_data:
			position_offset = decode_data(new_data.position_offset)
		if 'size' in new_data:
			size = decode_data(new_data.size)
	if 'color' in new_data:
		set_color(Color(new_data.color))
		%BGColor.color = Color(new_data.color)

	return self
