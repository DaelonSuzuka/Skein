tool
extends HBoxContainer

# ******************************************************************************

onready var Condition = $Condition

# ******************************************************************************

func get_data():
	var data = {}
	if Condition.text:
		data.condition = Condition.text
	return data

func set_data(data):
	Condition.text = data.get('condition', '')
