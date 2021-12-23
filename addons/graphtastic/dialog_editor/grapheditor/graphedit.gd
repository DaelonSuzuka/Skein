tool
extends GraphEdit
var graphnode = preload("graphnode/graphnode.tscn")
var all_graphnodes = []
var all_connections= []
var copy_d_graphs = []

var debug = []

######+			public functions going to main_panel, handling saving/loading basically	#######
func get_data_from_poolstrings():
	var all_poolstrings: Array = []
	for graph in all_graphnodes:
		var single_poolstring: PoolStringArray = []
		single_poolstring.push_back(graph.nID_data) 					#0	nID	
		single_poolstring.push_back(graph.connection_count_data)		#1	connection count
		single_poolstring.push_back(graph.nodename_data)				#2	nodename
		single_poolstring.push_back(graph.dialogtxt_data)				#3	dialogtxt
		single_poolstring.push_back(graph.speaker_data)					#4	speaker
		single_poolstring.push_back(to_json(graph.facepic_data))					#5	facepic
		single_poolstring.push_back(graph.get_offset().x)				#6	off_x
		single_poolstring.push_back(graph.get_offset().y)				#7	off_y
		single_poolstring.push_back(get_graph_choices_ifs(graph))		#8	[choices, ifs][...]
		single_poolstring.push_back(get_graph_outgoing_connects(graph))	#9	[socket, to, tosocket][...]
		all_poolstrings.push_back(single_poolstring)
	return all_poolstrings

func set_data_from_poolstrings(all_poolstrings):
	var saved_connections = []
	for single_pool in all_poolstrings:
		var new_graph = create_new_node(single_pool[0] as int, single_pool[1] as int, single_pool[6] as int, single_pool[7] as int)
		new_graph.set_nodename_data(single_pool[2])
		new_graph.set_dialogtxt_data(single_pool[3])
		new_graph.speaker_data= single_pool[4]
		new_graph.facepic_data= parse_json(single_pool[5])
		set_graph_choices_ifs(new_graph, single_pool[8])
		var all_connects_outgoing = parse_json(single_pool[9])
		for con in all_connects_outgoing:
			var new_connection = [String(new_graph.name), con[0] as int, String(con[1]), con[2] as int]
			saved_connections.push_back(new_connection)
	#handle connections in extra loop:
	for connection in saved_connections:
		request_connect(connection[0], connection[1], connection[2], connection[3])


######				helper funcs for the 2 above public funcs:
func get_graph_choices_ifs(graph):
	var all_slots = []
	for hbox in graph.slot_container:
		var one_slot =[hbox.get_node("LineEditChoice").text, hbox.get_node("LineEditIf").text]
		all_slots.push_back(one_slot)
	return to_json(all_slots)


func set_graph_choices_ifs(graph, all_slots_data):
	var all_slots = parse_json(all_slots_data)
	for hbox in graph.slot_container:
		var one_slot = all_slots.pop_front()
		hbox.get_node("LineEditChoice").text=one_slot[0]
		hbox.get_node("LineEditIf").text=one_slot[1]
		
		
func get_graph_outgoing_connects(graph):
	var all_connects_outgoing= []
	for con in all_connections:
		if con[0] == graph.name:
			var one_connection=[con[1],con[2],con[3]]
			all_connects_outgoing.push_back(one_connection)
	return to_json(all_connects_outgoing)
	
	
######+          private helper functions    creating and deleting nodes and connections        ##########
func create_new_node(nID:int=0, slot_count:int=1, offset_x:int=50, offset_y:int=50): 
	var new_node= graphnode.instance()
	new_node.offset=Vector2(offset_x, offset_y).snapped(Vector2(get_snap(),get_snap()))
	new_node.nID_data=nID as int
	add_child(new_node,true)
	if !slot_count==1:
		new_node.update_connection_count(slot_count)
	all_graphnodes.push_back(new_node)
	return new_node


func delete_node(node):
	for child in get_children():
		if child is GraphNode:
			if child == node:
				for con in get_connection_list():
					if con["from"] == child.name:
						request_disconect(con["from"], con["from_port"], con["to"], con["to_port"])
					elif con["to"] == child.name:
						request_disconect(con["from"], con["from_port"], con["to"], con["to_port"])
				all_graphnodes.erase(node)
				child.free()


func request_connect(from, from_slot, to, to_slot):
	for con in get_connection_list():	
		if con["from"] == from:
			if con["from_port"] == from_slot:
				return false
	#only connect right side slot is free ->
	all_connections.push_back([from, from_slot, to, to_slot])
	connect_node(from, from_slot, to, to_slot)
	return true


func request_disconect(from, from_slot, to, to_slot):
	disconnect_node(from, from_slot, to, to_slot)
	all_connections.erase([from, from_slot, to, to_slot])



######+          BUTTONS         ##########
func _on_Quicksave_pressed():
	debug = get_data_from_poolstrings()
	print(debug)
	print("debug saved")


func _on_Quickplay_pressed():
	#fee all children:
	for child in get_children():
		delete_node(child)
	print(debug)
	print("debug loaded:->")
	set_data_from_poolstrings(debug)


func _on_New_pressed():
	var new_node =create_new_node()
	new_node.offset=new_node.offset+scroll_offset/zoom
	new_node.button.grab_focus()


######+          custom Signals from graphnode         ##########
func _on_delete_pressed(node):
	yield(get_tree(),"idle_frame")			#idleframe
	delete_node(node)
	

func _on_deleted_slot(node, slot):
	for con in get_connection_list():
		if con["from"] == node.name and con["from_port"] == slot:
			request_disconect(con["from"], con["from_port"], con["to"], con["to_port"])


######+          GRAPHEDIT - FUNCTIONS    			like copy / paste / deletekeyboard....     ##########
func _on_GraphEdit_connection_request(from, from_slot, to, to_slot):
	request_connect(from, from_slot, to, to_slot)


func _on_GraphEdit_disconnection_request(from, from_slot, to, to_slot):
	request_disconect(from, from_slot, to, to_slot)


func _on_GraphEdit_connection_from_empty(to, to_slot, release_position):	#to left
	var new_node= create_new_node()
	new_node.offset = release_position+scroll_offset-Vector2(new_node.rect_size.x, 0.8*new_node.rect_size.y)
	new_node.offset = new_node.offset.snapped(Vector2(get_snap(),get_snap()))
	request_connect(new_node.name, 0, to, to_slot)
	new_node.button.grab_focus()


func _on_GraphEdit_connection_to_empty(from, from_slot, release_position):	#to right
	var new_node= create_new_node()
	new_node.offset = release_position+scroll_offset-Vector2(0,0.8*new_node.rect_size.y)
	new_node.offset = new_node.offset.snapped(Vector2(get_snap(),get_snap()))
	new_node.button.grab_focus()
	if !request_connect(from, from_slot, new_node.name, 0):
		delete_node(new_node)


func _on_GraphEdit_delete_nodes_request():
	for graph in get_children():
		if graph is GraphNode and graph.is_selected(): delete_node(graph)


func _on_GraphEdit_copy_nodes_request():
	copy_d_graphs = []
	for graph in get_children():
		if graph is GraphNode and graph.is_selected():
			var copy = [
			graph.connection_count_data, 
			graph.nodename_data,
			graph.dialogtxt_data,
			graph.speaker_data,
			graph.facepic_data,
			get_graph_choices_ifs(graph)]
			copy_d_graphs.push_back(copy)


func _on_GraphEdit_paste_nodes_request():
	var offset = Vector2(0,0)+(self.scroll_offset+get_local_mouse_position())/zoom ##get_viewport().get_mouse_position()
	for copy in copy_d_graphs:
		var new_node = create_new_node(0, copy[0])
		new_node.set_nodename_data(copy[1])
		new_node.set_dialogtxt_data(copy[2])
		new_node.speaker_data=copy[3]
		new_node.facepic_data=copy[4]
		set_graph_choices_ifs(new_node, copy[5])
		new_node.offset = (offset-Vector2(0, new_node.rect_size.y)).snapped(Vector2(get_snap(),get_snap()))
		offset+=Vector2(get_snap(),get_snap())



