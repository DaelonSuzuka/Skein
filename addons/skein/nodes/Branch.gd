@tool
extends HBoxContainer

# ******************************************************************************

@onready var condition = $Condition
@onready var label = $Label

@export var number = 1 : set = set_number
func set_number(value):
	number = value
	if is_inside_tree():
		label.text = str(value)


# ******************************************************************************

func _ready() -> void:
	set_number(number)

# ******************************************************************************

func get_data():
	var data = {}
	if condition.text:
		data.condition = condition.text
	return data

func set_data(data):
	condition.text = data.get('condition', '')
