@tool
extends 'BaseNode.gd'

# ******************************************************************************

@onready var text_edit = find_child('TextEdit')
var scrollbar = null

@onready var choices = [
	$Choice1,
	$Choice2,
	$Choice3,
	$Choice4,
]

# ******************************************************************************

func _ready():
	edit_menu.get_popup().index_pressed.connect(self.index_pressed)

	data['show_choices'] = false
	set_choices_enabled(false)
	edit_menu.get_popup().set_item_checked(0, false)

	data['choices'] = {}
	for c in choices:
		data['choices'][str(c.name)[6]] = {}

	# text_edit.refresh_colors()
	# Skein.refreshed.connect(text_edit.refresh_colors)
	# text_edit.text_changed.connect(self.on_change)
	for c in choices:
		c.choice.text_changed.connect(self.on_change)
		c.condition.text_changed.connect(self.on_change)

	for child in text_edit.get_children():
		if child is VScrollBar:
			scrollbar = child

	set_slot_color_right(1, slot_colors[0])
	set_slot_color_right(2, slot_colors[1])
	set_slot_color_right(3, slot_colors[2])
	set_slot_color_right(4, slot_colors[3])

var has_mouse := false

func _input(event: InputEvent) -> void:
	if !(event is InputEventMouseMotion):
		return

	# if !scrollbar.visible:
	# 	return

	var local_event = make_input_local(event)

	if Rect2(Vector2(), size).has_point(local_event.position):
		if !has_mouse:
			has_mouse = true
			# get_parent().zoom_step = 1.0
	else:
		if has_mouse:
			has_mouse = false
			# get_parent().zoom_step = 1.1

func on_change(arg=null):
	changed.emit()

func index_pressed(index):
	match edit_menu.get_popup().get_item_text(index):
		'Choices':
			edit_menu.get_popup().toggle_item_checked(0)
			var state = edit_menu.get_popup().is_item_checked(0)
			data['show_choices'] = state
			set_choices_enabled(state)
			changed.emit()

func highlight_line(line_number: int):
	text_edit.highlight_current_line = true
	text_edit.set_caret_line(line_number)

func unhighlight_lines():
	text_edit.highlight_current_line = false
	text_edit.deselect()

# ******************************************************************************

func get_data():
	var data = super.get_data()
	data['text'] = text_edit.text
	if data['show_choices']:
		data['next'] = 'choice'
	else:
		data.erase('show_choices')

	var connections = {}
	for to in data.connections:
		var num = str(data.connections[to][0] + 1)
		connections[num] = to
	
	if data.connections == {}:
		data.erase('connections')

	data['choices'] = {}
	for c in choices:
		var c_data = c.get_data()
		if c_data:
			data['choices'][str(c.name)[6]] = c_data
			data['choices'][str(c.name)[6]]['next'] = ''
			if str(c.name)[6] in connections:
				data['choices'][str(c.name)[6]]['next'] = connections[str(c.name)[6]]
	if data['choices'] == {}:
		data.erase('choices')

	return data

func set_data(new_data):
	if 'text' in new_data:
		text_edit.text = new_data.text
	if 'show_choices' in new_data:
		var state = new_data['show_choices']
		if state is String:
			state = {'true': true, 'false': false}[state.to_lower()]
		data['show_choices'] = state
		set_choices_enabled(state)
		edit_menu.get_popup().set_item_checked(0, state)
	if 'choices' in new_data:
		for c in choices:
			if str(c.name)[6] in new_data['choices']:
				c.set_data(new_data['choices'][str(c.name)[6]])

	super.set_data(new_data)

# ******************************************************************************

func set_choices_enabled(state):
	$Choice1.visible = state
	$Choice2.visible = state
	$Choice3.visible = state
	$Choice4.visible = state

	set_slot_enabled_right(0, !state)
	set_slot_enabled_right(1, state)
	set_slot_enabled_right(2, state)
	set_slot_enabled_right(3, state)
	set_slot_enabled_right(4, state)
