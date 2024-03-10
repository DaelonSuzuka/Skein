tool
extends HBoxContainer

# ******************************************************************************

onready var Condition = $Condition
onready var Label = $Label

export var number = 1 setget set_number
func set_number(value):
	number = value
	if is_inside_tree():
		Label.text = str(value)


# ******************************************************************************

func _ready() -> void:
	set_number(number)

# ******************************************************************************

func get_data():
	var data = {}
	if Condition.text:
		data.condition = Condition.text
	return data

func set_data(data):
	Condition.text = data.get('condition', '')
