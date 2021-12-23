tool
extends GraphNode
####     variables with _data get passed arround to graphedit and value_editor:
var nID_data = 1
var nodename_data: String= ""
var dialogtxt_data: String = ""
var speaker_data: String = ""
var facepic_data: Array = ["", "", ""]
var connection_count_data: int = 1
signal delete_pressed(value)
signal deleted_slot(value, value)
onready var spinbox = get_node("HBoxMain/SpinBox")
onready var hbox = get_node("HBox")
onready var button = get_node("HBoxMain/Button_Value_Edit")
onready var slot_container = [hbox]
var right_color: Color

func _ready():
	right_color = self.get_slot_color_right(1)
	if nID_data != 0: self.name = String(nID_data)
	else: nID_data = self.name as int
	update_connection_count(connection_count_data)
	set_nodename_data(nodename_data)
	self.connect("delete_pressed", get_parent(), "_on_delete_pressed")
	self.connect("deleted_slot", get_parent(), "_on_deleted_slot")


func set_dialogtxt_data(textstring: String = ""):
	dialogtxt_data=textstring
	if textstring.length()>300:
		textstring= textstring.left(299)
	self.hint_tooltip=textstring
	


func set_nodename_data(name: String = "default"):
	nodename_data=name
	self.title = self.name + " | " + nodename_data


func _on_SpinBox_value_changed(value):
	update_connection_count(value)


func update_connection_count(new_number_of_slots:int):
	if new_number_of_slots>connection_count_data:
		for counter in (new_number_of_slots-connection_count_data):
			var new_Hbox = hbox.duplicate()
			new_Hbox.get_node("LineEditChoice").text=""
			new_Hbox.get_node("LineEditIf").text=""
			new_Hbox.get_node("Label").text=String(connection_count_data+counter+1)
			self.add_child(new_Hbox)
			self.set_slot(connection_count_data+counter+1, false, 0, right_color, true, 0, right_color, null, null)
			slot_container.push_back(new_Hbox)
	elif new_number_of_slots<connection_count_data:
		for counter in (connection_count_data-new_number_of_slots):
			clear_slot(connection_count_data-counter)
			slot_container.pop_back().free()
			emit_signal("deleted_slot", self, connection_count_data-counter-1)
			rect_size=Vector2(10,10)
	connection_count_data=new_number_of_slots
	spinbox.value=new_number_of_slots


func _exit_tree():
	pass
	disconnect("delete_pressed", get_parent(), "_on_delete_pressed")
	disconnect("deleted_slot", get_parent(), "_on_deleted_slot")


func _on_GraphNode_close_request():
	emit_signal("delete_pressed", self)


func _on_Button_Value_Edit_pressed():
	var value_editortscn = preload("value_editor/value_editor.tscn")
	var value_editor= value_editortscn.instance()
	add_child(value_editor)
	for node in slot_container:
		var double = node.duplicate()
		value_editor.vboxchoices.add_child(double)
	value_editor.set_nodename(nodename_data)
	value_editor.set_dialogtxt(dialogtxt_data)
	value_editor.set_speaker(speaker_data)
	value_editor.set_facepic(facepic_data)
	value_editor.set_nID_data(nID_data)
	value_editor.popup_centered_ratio(0.87)
	value_editor.nodename_line_edit.grab_focus()
