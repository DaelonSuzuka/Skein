extends VBoxContainer
var button_group= ButtonGroup.new()
var current_graphs=[]
signal GT_choice_made
export(bool) var flat_buttons =0
export(int, "Left", "Center", "Right") var align_text=1
export(bool) var show_tooltips = true
export(bool) var clip_text=0
export(Texture) var icon

var GTD
func set_GTD():
	GTD=get_node("/root/GTD")


func _ready():
	set_GTD()
	for child in get_children():
		if child is Button:
			child.queue_free()
	var _err
	_err= GTD.connect("GT_set_choices", self ,"_on_GT_set_choices")
	_err= connect("GT_choice_made", GTD, "_on_GT_choice_made")



func _on_GT_set_choices(graphs:Array):	#[] of {"choice" "if" "next_nID"}
	button_group= ButtonGroup.new()
	for graph in graphs:
		if graph["choice"]!="" and graph["choice"]!=" " and graph["choice"]!="#":
			var button= Button.new()
			button.icon=icon
			button.flat= flat_buttons
			button.clip_text= clip_text
			button.align=align_text
			button.editor_description=String(graph["next_nID"])
			button.text=graph["choice"]
			if button.text=="": button.text="unnamed choice"
			if !GTD.check_if(graph["if"]) and show_tooltips:
				button.hint_tooltip="missing: "+graph["if"]
				button.disabled=true
			button.set_button_group(button_group)
			button.connect("pressed", self, "_on_Button_pressed")
			add_child(button)
			button.grab_focus()

		


func _on_Button_pressed():
	var next_nID = button_group.get_pressed_button().editor_description as int
	emit_signal("GT_choice_made",next_nID)
	for child in get_children():
		if child is Button:
			child.queue_free()
