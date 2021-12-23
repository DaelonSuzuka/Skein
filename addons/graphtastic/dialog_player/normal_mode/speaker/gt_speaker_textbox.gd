extends RichTextLabel


## only change speaker if there is a change
export(int, "Left", "Center", "Right", "None") var text_align = 0
export(bool) var speaker_persistent = true

var GTD
func set_GTD():
	GTD=get_node("/root/GTD")
	
	
func _ready():
	set_GTD()
	self.bbcode_enabled=true
	bbcode_text=""
	var _err= GTD.connect("GT_set_speaker", self, "_on_GT_set_speaker")
	_err= GTD.connect("GT_dialog_finished", self, "_on_GT_dialog_finished")

func _on_GT_set_speaker(speaker):
	if speaker_persistent:
		if bbcode_text!="" or bbcode_text!= " " or bbcode_text== "#":
			if speaker=="" or speaker==" ":
				#case for persistent here speaker "keeps speaking" till another speaker comes
				return
	
	if text_align==1: 	bbcode_text= "[center]"+speaker+"[/center]"
	if text_align==0: 	bbcode_text= "[left]"+speaker+"[/left]"
	if text_align==2: 	bbcode_text= "[right]"+speaker+"[/right]"
	else: 				bbcode_text= speaker

func _on_GT_dialog_finished():
	bbcode_text=""

