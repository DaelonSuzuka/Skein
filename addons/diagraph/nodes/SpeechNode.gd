tool
extends 'BaseNode.gd'

# ******************************************************************************

func _ready():
	Edit.get_popup().add_item('test')
	Edit.get_popup().add_item('test2')

func get_data():
	var data = .get_data()
	data['text'] = $Body/Text/TextEdit.text
	return data

func set_data(new_data):
	if 'text' in new_data:
		$Body/Text/TextEdit.text = new_data.text
	.set_data(new_data)
