@tool
extends 'BaseNode.gd'

# ******************************************************************************

@onready var color_picker = find_child('ColorPickerButton')
@onready var Tooltip = find_child('Tooltip')
@onready var TooltipBG = find_child('TooltipBG')

# ******************************************************************************

func _ready():
	color_picker.get_picker()
	color_picker.get_popup()
	color_picker.color_changed.connect(self.set_color)
	Tooltip.hide()
	Title.text_changed.connect(Tooltip.set_text)

	var parent = get_parent()
	if parent is GraphEdit:
		position_offset_changed.connect(self._position_offset_changed)
		parent.begin_node_move.connect(self.begin_move)
		parent.end_node_move.connect(self.end_move)
		parent.zoom_changed.connect(self.zoom_changed)
		zoom_changed(parent.zoom)

func set_color(color):
	self_modulate = color
	TooltipBG.modulate = color

# ******************************************************************************

var dragging := false
var start_pos := Vector2()
var drag_children := {}

func begin_move():
	if !selected:
		return
	dragging = true
	drag_children.clear()
	start_pos = position_offset

	var own_region = Rect2(position_offset, size)
	for node in get_parent().nodes.values():
		if node == self or !is_instance_valid(node):
			continue
		var node_region = Rect2(node.position_offset, node.size)
		if own_region.encloses(node_region):
			drag_children[node] = node.position_offset

func _position_offset_changed():
	var difference = start_pos - position_offset
	for child in drag_children:
		var start = drag_children[child]
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
	Tooltip.hide()

	var width = max(round(1 / zoom), 1) as int

	set_stylebox_borders(theme.get_stylebox('comment', 'GraphNode'), width)
	set_stylebox_borders(theme.get_stylebox('comment_focus', 'GraphNode'), width)
	# set_stylebox_borders(TooltipBG.get_stylebox('panel'), width)

	if zoom < .8:
		Tooltip.show()
		Tooltip.theme.default_font.size = round(16 / zoom)

# ******************************************************************************

func get_data():
	var data = super.get_data()
	data['color'] = color_picker.color.to_html()
	return data

func set_data(new_data):
	if 'name' in new_data:
		Tooltip.text = new_data.name
	if 'color' in new_data:
		self_modulate = Color(new_data.color)
		TooltipBG.modulate = Color(new_data.color)
		color_picker.color = Color(new_data.color)
	super.set_data(new_data)
