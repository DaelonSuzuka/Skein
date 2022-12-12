@tool
extends 'BaseNode.gd'

# ******************************************************************************

@onready var graph_edit = find_child('GraphEdit')

# ******************************************************************************

func get_data():
	var data = super.get_data()
	data['nodes'] = graph_edit.get_nodes()
	data['data'] = graph_edit.get_data()
	return data

func set_data(new_data):
	if 'nodes' in new_data:
		graph_edit.set_nodes(new_data['nodes'])
	if 'data' in new_data:
		graph_edit.set_data(new_data['data'])
	super.set_data(new_data)
