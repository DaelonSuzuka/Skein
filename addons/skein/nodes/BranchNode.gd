@tool
extends 'BaseNode.gd'

# ******************************************************************************

var Branch = preload('Branch.tscn')

var branches = []
var extra_branches = []

# ******************************************************************************

func _ready():
	edit_menu.get_popup().index_pressed.connect(self.index_pressed)

	for i in range(8):
		set_slot_enabled_right(i + 1, true)
		set_slot_color_right(i + 1, slot_colors[i])
	data['extra_choices'] = false
	
	if !Engine.is_editor_hint():
		set_extra_choices_enabled(false)
	edit_menu.get_popup().set_item_checked(0, false)

	for child in get_children():
		if 'Branch' in child.name:
			branches.append(child)

	data['branches'] = {}
	for b in branches:
		data['branches'][b.name] = {'condition': ''}
		b.condition.text_changed.connect(self.on_change)

func on_change(arg=null):
	changed.emit()

func index_pressed(index):
	match edit_menu.get_popup().get_item_text(index):
		'Show Extra Branches':
			edit_menu.get_popup().toggle_item_checked(0)
			var state = edit_menu.get_popup().is_item_checked(0)
			data['extra_choices'] = state
			set_extra_choices_enabled(state)
			changed.emit()

# ******************************************************************************

func set_extra_choices_enabled(state):
	if state:
		for i in range(5, 9):
			var branch = Branch.instantiate()
			branch.number = i
			add_child(branch)
			extra_branches.append(branch)
	else:
		for branch in extra_branches:
			remove_child(branch)
		extra_branches.clear()

	# reset the node's size
	size.y = 0
	move_child($Control, get_child_count())
	
	for i in range(5, 9):
		set_slot_enabled_right(i, state)

# ******************************************************************************

func get_data():
	var data = super.get_data()
	data['next'] = 'branch'

	if !data['extra_choices']:
		data.erase('extra_choices')

	var connections = {}
	for to in data.connections:
		var num = str(data.connections[to][0] + 1)
		connections[num] = to
	
	if data.connections == {}:
		data.erase('connections')

	data['branches'] = {}
	for b in branches:
		var b_data = b.get_data()
		if b_data:
			data['branches'][str(b.name)[6]] = b_data
			if str(b.name)[6] in connections:
				data['branches'][str(b.name)[6]]['next'] = connections[str(b.name)[6]]
	if data['branches'] == {}:
		data.erase('branches')

	return data

func set_data(new_data):
	if 'extra_choices' in new_data:
		var state = new_data['extra_choices']
		if state is String:
			state = {'true': true, 'false': false}[state.to_lower()]
		data['extra_choices'] = state
		set_extra_choices_enabled(state)
		edit_menu.get_popup().set_item_checked(0, state)
	if 'branches' in new_data:
		for b in branches:
			if str(b.name)[6] in new_data['branches']:
				b.set_data(new_data['branches'][str(b.name)[6]])
	super.set_data(new_data)
