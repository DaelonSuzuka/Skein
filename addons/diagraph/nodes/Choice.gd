tool
extends HBoxContainer

# ******************************************************************************

func get_data():
	var data = {
		text = $Choice.text,
		condition = $Condition.text,
	}
	return data

func set_data(data):
	$Choice.text = data.text
	$Condition.text = data.condition
