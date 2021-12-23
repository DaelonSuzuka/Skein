tool
extends WindowDialog
var player
var player_tscn = load("res://addons/graphtastic/dialog_player/toolmode/toolmode_dialog_player.tscn")
onready var control= get_node("Control")
onready var variables_text_edit = get_node("Control/VBox/HBoxContainer/VBoxContainer/TextEditVariables")
onready var pictures_text_edit = get_node("Control/VBox/HBoxContainer/VBoxContainer2/TextEditPictures")


func _on_Button_pressed():
	player = player_tscn.instance()
	if parsecheck(variables_text_edit.text): 
		player.variables=parsecheck(variables_text_edit.text)
	else: print("GT-error: variables is not in string format")
	if parsecheck(pictures_text_edit.text): 
		player.pictures=parsecheck(variables_text_edit.text)
	else: print("GT-error: pictures is not in string format")
	player.resource= "res://addons/graphtastic/userdata/quickplay.tsv"
	player.chapterID=get_node("Control/VBox/HBoxContainer/VBoxContainer/chapterID").value as int
	player.startID=get_node("Control/VBox/HBoxContainer/VBoxContainer2/nodeID").value as int
	for child in control.get_children():
		child.queue_free()
	control.add_child(player)
	player.connect("Dialog_Finished", self, "_on_Dialog_Finished")


func _on_Dialog_Finished(dict):
	var text = "Finished with the following variables:  "+String(dict)
	text.replace(",", ",\n" )
	for child in control.get_children():
		child.queue_free()
	var butn=Button.new()
	butn.text=text
	butn.clip_text=true
	butn.size_flags_horizontal=3
	butn.size_flags_vertical=3
	butn.set_anchors_preset(15)
	control.add_child(butn)
	butn.connect("pressed" ,self,"_on_Exit_Button_pressed")


func _on_WindowDialog_popup_hide():
	self.queue_free()


func _on_Exit_Button_pressed():
	self.queue_free()


func parsecheck(txt:String):
	var parse = JSON.parse(txt)
	if typeof(parse.result) == TYPE_DICTIONARY:
		return parse.result
	return false
