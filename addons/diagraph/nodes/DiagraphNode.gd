tool
extends GraphNode

# ******************************************************************************

enum {
	DIALOG,
	COMMENT,
	ENTRY,
	EXIT,
	JUMP,
}

var data := {
	id = 0,
	type = DIALOG,
	name = '',
	text = '',
	rect_size = {x = 0, y = 0},
	offset = {x = 0, y = 0},
	number_of_slots = 1,
	slots = [],
}

var choices := []

var editing := false

var slot_colors := [
	Color.blue,
	Color.red,
	Color.green,
	Color.yellow,
]

# ******************************************************************************

func _ready():
	update_title()
	$Body/Toolbar/Close.connect('pressed', self, 'emit_signal', ['close_request'])
	$Body/Text/Toolbar/Choices.connect('value_changed', self, 'slots_changed')
	connect('resize_request', self, 'resize_request')

func resize_request(new_minsize):
	rect_size = new_minsize

# ******************************************************************************

func set_id(id):
	data.id = id
	update_title()
	name = str(id)

func update_title():
	$Body/Toolbar/Id.text = str(data.id) + " | "
	$Body/Toolbar/Title.text = data.name

func get_data():
	data.text = $Body/Text/TextEdit.text
	data.offset.x = offset.x
	data.offset.y = offset.y
	data.rect_size.x = rect_size.x
	data.rect_size.y = rect_size.y
	data.name = $Body/Toolbar/Title.text
	return data

func set_data(new_data):
	$Body/Text/TextEdit.text = new_data.text
	$Body/Toolbar/Title.text = new_data.name
	offset.x = new_data.offset.x
	offset.y = new_data.offset.y
	if 'rect_size' in new_data:
		rect_size.x = new_data.rect_size.x
		rect_size.y = new_data.rect_size.y
	slots_changed(new_data.number_of_slots)
	data.type = new_data.type
	data.name = new_data.name
	return self

# ******************************************************************************

func add_choice():
	pass

func slots_changed(number):
	if number == data.number_of_slots:
		return

	while number > data.number_of_slots:
		data.number_of_slots += 1
		var new_choice = $Choice.duplicate()
		new_choice.get_node("Label").text = str(data.number_of_slots)
		add_child(new_choice)
		add_slot(data.number_of_slots)
		choices.push_back(new_choice)

	while number < data.number_of_slots:
		data.number_of_slots -= 1
		remove_slot(data.number_of_slots)
		choices.pop_back().queue_free()

	$Body/Text/Toolbar/Choices.value = number

func add_slot(index):
	set_slot(index, false, 0, Color.white, true, 0, slot_colors[index - 1])

func remove_slot(index):
	set_slot(index + 1, false, 0, Color.white, false, 0, Color.white)
