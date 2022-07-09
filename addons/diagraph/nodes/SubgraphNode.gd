tool
extends 'BaseNode.gd'

# ******************************************************************************

onready var GraphEdit = find_node('GraphEdit')

# ******************************************************************************

func get_data():
	var data = .get_data()
	data['nodes'] = GraphEdit.get_nodes()
	data['data'] = GraphEdit.get_data()
	return data

func set_data(new_data):
	if 'nodes' in new_data:
		GraphEdit.set_nodes(new_data['nodes'])
	if 'data' in new_data:
		GraphEdit.set_data(new_data['data'])
	.set_data(new_data)
