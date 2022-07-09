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
	data['branches'] = {}
	for b in branches:
		data['branches'][b.name] = {'condition': ''}

	set_slot_color_right(1, slot_colors[0])
	set_slot_color_right(2, slot_colors[1])
	set_slot_color_right(3, slot_colors[2])
	set_slot_color_right(4, slot_colors[3])

func get_data():
	var data = .get_data()
	data['next'] = 'branch'

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
	if 'branches' in new_data:
		for b in branches:
			if b.name[6] in new_data['branches']:
				b.set_data(new_data['branches'][b.name[6]])
	.set_data(new_data)
