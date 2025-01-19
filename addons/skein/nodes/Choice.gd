@tool
extends HBoxContainer

# ******************************************************************************

@onready var choice = $Choice
@onready var condition = $Condition

# ******************************************************************************

func get_data():
	var data = {}
	if choice.text:
		data.choice = choice.text
	if condition.text:
		data.condition = condition.text
	return data

func set_data(data):
	choice.text = data.get('choice', '')
	condition.text = data.get('condition', '')
