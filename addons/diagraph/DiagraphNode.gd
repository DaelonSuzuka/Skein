tool
extends GraphNode

# ******************************************************************************

var data := {
	id = 0,
	type = '',
	name = '',
	text = '',
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
	# $Body/Editor.visible = false
	# $Body/TextEdit.visible = true
	$Body/Toolbar/Choices.connect('value_changed', self, 'slots_changed')
	# $Body/Toolbar/Edit.connect('pressed', self, 'toggle_editing')
	connect('resize_request', self, 'resize_request')

func resize_request(new_minsize):
	rect_min_size = new_minsize
	$Body.rect_min_size.x = new_minsize.x - 50

func set_id(id):
	data.id = id
	update_title()
	name = str(id)

func get_data():
	data.text = $Body/TextEdit.text
	data.offset.x = offset.x
	data.offset.y = offset.y
	return data

func set_data(new_data):
	$Body/TextEdit.text = new_data.text
	offset.x = new_data.offset.x
	offset.y = new_data.offset.y
	slots_changed(new_data.number_of_slots)
	data = new_data

# func toggle_editing():
# 	editing = !editing
# 	$Body/Editor.visible = editing
# 	$Body/TextEdit.visible = !editing

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
		rect_size=Vector2(10, 10)

func add_slot(index):
	print('adding slot ', index)
	set_slot(index, false, 0, Color.white, true, 0, slot_colors[index - 1])

func remove_slot(index):
	print('removing slot ', index)
	set_slot(index + 1, false, 0, Color.white, false, 0, Color.white)


func update_title():
	self.title = str(data.id) + " | " + data.name

func to_json():
	pass

