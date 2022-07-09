tool
extends HBoxContainer

# ******************************************************************************

onready var Choice = $Choice
onready var Condition = $Condition

# ******************************************************************************

func get_data():
	var data = {}
	if Choice.text:
		data.choice = Choice.text
	if Condition.text:
		data.condition = Condition.text
	return data

func set_data(data):
	Choice.text = data.get('choice', '')
	Condition.text = data.get('condition', '')
