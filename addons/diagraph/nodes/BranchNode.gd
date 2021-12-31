tool
extends 'BaseNode.gd'

# ******************************************************************************

onready var branches = [
	$Branch1,
	$Branch2,
	$Branch3,
	$Branch4,
]

var slot_colors := [
	Color.aqua,
	Color.orangered,
	Color.green,
	Color.yellow,
]

# ******************************************************************************

func _ready():
	Edit.get_popup().connect('index_pressed', self, 'index_pressed')
	
	data['branches'] = {}
	for b in branches:
		data['branches'][b.name] = {'condition': ''}

	data['entry'] = false
	
	set_slot_color_right(1, slot_colors[0])
	set_slot_color_right(2, slot_colors[1])
	set_slot_color_right(3, slot_colors[2])
	set_slot_color_right(4, slot_colors[3])

func get_data():
	var data = .get_data()
	
	for b in branches:
		data['branches'][b.name] = b.get_data()
	return data

func set_data(new_data):
	if 'entry' in new_data:
		data['entry'] = new_data['entry']
		Edit.get_popup().set_item_checked(0, new_data['entry'])
	if 'branches' in new_data:
		for b in branches:
			b.set_data(new_data['branches'][b.name])
	.set_data(new_data)

func index_pressed(index):
	match Edit.get_popup().get_item_text(index):
		'Entry':
			Edit.get_popup().toggle_item_checked(0)
			var state = Edit.get_popup().is_item_checked(0)
			data['entry'] = state
			prints('entry:', state)
