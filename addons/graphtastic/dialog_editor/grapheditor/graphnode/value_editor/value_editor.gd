tool
extends WindowDialog
onready var vboxchoices = get_node("ScrollContainer/VBoxContainer/VBoxChoices")
onready var nodename_line_edit = get_node("ScrollContainer/VBoxContainer/VBoxContainerTop/HBoxName/NODENAME")
onready var dialogtxt_text_edit = get_node("ScrollContainer/VBoxContainer/HSplitContainer/DIALOGTXT")
onready var speaker_line_edit = get_node("ScrollContainer/VBoxContainer/VBoxContainerTop/HBoxSpeaker/SPEAKER")
onready var center_picture_line_edit = get_node("ScrollContainer/VBoxContainer/VBoxContainerTop/HBoxSpeaker/CENTER_PIC")
onready var right_picture_line_edit = get_node("ScrollContainer/VBoxContainer/VBoxContainerTop/HBoxSpeaker2/RIGHT_PIC")
onready var left_picture_line_edit = get_node("ScrollContainer/VBoxContainer/VBoxContainerTop/HBoxSpeaker2/LEFT_PIC")
onready var nID_data_label = get_node("ScrollContainer/VBoxContainer/VBoxContainerTop/HBoxName/NID")


func _ready():
	dialogtxt_text_edit.add_color_region("<[", "/]>", Color(0.764337, 0.929688, 0.759003))
	dialogtxt_text_edit.add_color_region("[", "]", Color(0.508355, 0.506744, 0.527344))
	dialogtxt_text_edit.add_color_region("<", ">", Color(0.972656, 0.787018, 0.569916))
	


func set_nodename(data):
	nodename_line_edit.text = data
func set_dialogtxt(data):
	dialogtxt_text_edit.text = data
func set_speaker(data):
	speaker_line_edit.text = data
func set_facepic(data):
	left_picture_line_edit.text = data[0]
	center_picture_line_edit.text = data[1]
	right_picture_line_edit.text = data	[2]
func set_nID_data(data):
	nID_data_label.text ="nID: "+ String(data) +" | "+ nID_data_label.text


func _on_ValueEdit_popup_hide():
	var parent = get_parent()
	for node_nr in parent.slot_container.size():
		parent.slot_container[node_nr].get_node("LineEditChoice").text= vboxchoices.get_child(node_nr+1).get_node("LineEditChoice").text
		parent.slot_container[node_nr].get_node("LineEditIf").text= vboxchoices.get_child(node_nr+1).get_node("LineEditIf").text
	parent.set_nodename_data( nodename_line_edit.text)
	parent.set_dialogtxt_data(dialogtxt_text_edit.text)
	parent.speaker_data = speaker_line_edit.text
	var facepic_data=[left_picture_line_edit.text,center_picture_line_edit.text,right_picture_line_edit.text]
	parent.facepic_data = facepic_data
	queue_free()

func insert_text(text:String="", move_cursor_back:int=0):
	if (get_focus_owner() is TextEdit):
		get_focus_owner().insert_text_at_cursor(text)
		get_focus_owner().cursor_set_column (get_focus_owner().cursor_get_column()-move_cursor_back)
		#cursor_set_line ( int line, bool adjust_viewport=true, bool can_be_hidden=true, int wrap_index=0 )
	elif (get_focus_owner() is LineEdit):
		get_focus_owner().append_at_cursor(text)


func _on_ButtonBB_img_pressed():
	insert_text("[img][/img]",6)
func _on_ButtonBB_color_pressed():
	insert_text("[color=Red][/color]",8)
func _on_ButtonBB_Italics_pressed():
	insert_text("[i][/i]",4)
func _on_ButtonBB_Bold_pressed():
	insert_text("[b][/b]",4)
func _on_ButtonChangeChapter_pressed():
	insert_text("<chapter></chapter>",10)
func _on_ButtonHoverOver_pressed():
	insert_text("<hover>{}</hover>",10)
func _on_ButtonSignal_pressed():
	insert_text("<signal></signal>",9)
func _on_ButtonIf_pressed():
	insert_text("<if>{}</if>",7)
func _on_ButtonChangeVar_pressed():
	insert_text("<change></change>",9)
func _on_ButtonInsertVar_pressed():
	insert_text("#()#",2)
func _on_ButtonStart_pressed():
	insert_text("<skip>")
