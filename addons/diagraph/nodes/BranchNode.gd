tool
extends 'BaseNode.gd'

# ******************************************************************************

var branches = []

# ******************************************************************************

func _ready():
	Edit.get_popup().connect('index_pressed', self, 'index_pressed')

	data['extra_choices'] = false
	set_extra_choices_enabled(false)
	Edit.get_popup().set_item_checked(0, false)

	for child in get_children():
		if 'Branch' in child.name:
			branches.append(child)

	data['branches'] = {}
	for b in branches:
		data['branches'][b.name] = {'condition': ''}
		b.Condition.connect('text_changed', self, 'on_change')

	for i in range(8):
		set_slot_color_right(i + 1, slot_colors[i])

func on_change(arg=null):
	emit_signal('changed')

func index_pressed(index):
	match Edit.get_popup().get_item_text(index):
		'Show Extra Branches':
			Edit.get_popup().toggle_item_checked(0)
			var state = Edit.get_popup().is_item_checked(0)
			data['extra_choices'] = state
			set_extra_choices_enabled(state)
			emit_signal('changed')

# ******************************************************************************

func set_extra_choices_enabled(state):
	$Branch5.visible = state
	$Branch6.visible = state
	$Branch7.visible = state
	$Branch8.visible = state
	
	set_slot_enabled_right(5, state)
	set_slot_enabled_right(6, state)
	set_slot_enabled_right(7, state)
	set_slot_enabled_right(8, state)

# ******************************************************************************

func get_data():
	var data = .get_data()
	data['next'] = 'branch'

	if !data['extra_choices']:
		data.erase('extra_choices')

	var connections = {}
	for to in data.connections:
		var num = str(data.connections[to][0] + 1)
		connections[num] = to
	
	if !data.connections:
		data.erase('connections')

	data['branches'] = {}
	for b in branches:
		var b_data = b.get_data()
		if b_data:
			data['branches'][b.name[6]] = b_data
			if b.name[6] in connections:
				data['branches'][b.name[6]]['next'] = connections[b.name[6]]
	if !data['branches']:
		data.erase('branches')

	return data

func set_data(new_data):
	if 'extra_choices' in new_data:
		var state = new_data['extra_choices']
		if state is String:
			state = {'True': true, 'False': false}[state]
		data['extra_choices'] = state
		set_extra_choices_enabled(state)
		Edit.get_popup().set_item_checked(0, state)
	if 'branches' in new_data:
		for b in branches:
			if b.name[6] in new_data['branches']:
				b.set_data(new_data['branches'][b.name[6]])
	.set_data(new_data)
