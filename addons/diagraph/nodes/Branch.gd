tool
extends HBoxContainer

# ******************************************************************************

func get_data():
	var data = {
		condition = $Condition.text,
	}
	return data

func set_data(data):
	$Condition.text = data.condition
