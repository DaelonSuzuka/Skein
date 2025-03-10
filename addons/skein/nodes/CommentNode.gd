@tool
extends GraphFrame

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

@onready var parent = get_parent()

signal changed

# ******************************************************************************

func _ready():
	%ColorPickerButton.get_picker()
	%ColorPickerButton.get_popup()
	%ColorPickerButton.color_changed.connect(self.set_color)
	%Tooltip.hide()
	%Title.text_changed.connect(%Tooltip.set_text)

	if parent is GraphEdit:
		position_offset_changed.connect(self._position_offset_changed)
		parent.begin_node_move.connect(self.begin_move)
		parent.end_node_move.connect(self.end_move)
		parent.zoom_changed.connect(self.zoom_changed)
		zoom_changed(parent.zoom)

	%Close.pressed.connect(self.delete_request.emit)
	resize_request.connect(self._resize_request)
	# gui_input.connect(self._gui_input)

	%Title.text_changed.connect(self.renamed)

func _resize_request(new_minsize: Vector2) -> void:
	self.changed.emit()
	if parent.snapping_enabled:
		var snap: int = parent.snapping_distance
		size = new_minsize.snapped(Vector2(snap, snap))
	else:
		size = new_minsize

func set_color(color):
	self_modulate = color
	%TooltipBG.modulate = color

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

	if zoom < .8:
		%Tooltip.show()
		# %Tooltip.theme.default_font.size = round(16 / zoom)

# ******************************************************************************

func set_id(id) -> void:
	data.id = id
	name = str(id)
	%Id.text = str(data.id)

func rename(new_name: String):
	%Title.text = new_name
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
	_data['color'] = %ColorPickerButton.color.to_html()
	return _data

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
		rename(new_data.name)
		%Tooltip.text = new_data.name
	if 'position' in new_data:
		var rect = str_to_var(new_data.position)
		position_offset = rect.position.round()
		size = rect.size.round()
	else:
		if 'position_offset' in new_data:
			position_offset = str_to_var(new_data.position_offset)
		if 'size' in new_data:
			size = str_to_var(new_data.size)
	if 'color' in new_data:
		self_modulate = Color(new_data.color)
		%TooltipBG.modulate = Color(new_data.color)
		%ColorPickerButton.color = Color(new_data.color)

	return self
