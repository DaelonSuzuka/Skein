extends RichTextLabel

signal GT_dialog_started
signal GT_dialog_finished
signal GT_text_changed
signal GT_text_animation_finished
signal GT_text_animation_started
signal GT_set_speaker
signal GT_set_pictures
signal GT_set_choices
signal GT_variables_were_changed
signal GT_preparing_chapter_change_to
signal GT_custom_signal					#(name) or (name, value)


export(String, FILE, "*.tsv") var resource_path
export(int, 1, 9999) var chapterID = 1
export(int, 1, 9999) var startID = 1
export(float, 0.01, 1) var textspeed =0.15
export(InputEventKey) var contine_key
export(InputEventKey) var another_key

const anim_playertscn = preload("gt_animation_player.tscn")
const story_file_helpergd = preload("res://addons/graphtastic/helper_classes/gt_story_file_helper.gd")
var anim_player = anim_playertscn.instance()
var story_helper =story_file_helpergd.new()
var next_graphs = []
var is_waiting_for_choice=false 
var is_animation_finished=false
var GTD

func set_GTD():
	GTD=get_node("/root/GTD")


func _ready():
	set_GTD()
	self.bbcode_enabled=true
	anim_player.playback_speed=textspeed*20
	if !story_helper.load_from_tsv(resource_path):
		
		#dialog_finished()
		return
	add_child(anim_player)
	if !story_helper.set_startpoint(chapterID, startID): 
		dialog_finished()
		return
	setup_signals()
	emit_signal("GT_dialog_started")
	main_loop()


func _input(event):			#player input handling
	if is_animation_finished and !is_waiting_for_choice:	
		if event is InputEventKey:
			if contine_key == null :
				if event.scancode == KEY_SPACE or event.scancode == KEY_ENTER:
					if event.pressed == true: main_move_to_next_graph()
			elif event.scancode == another_key.scancode and event.pressed == true:
				main_move_to_next_graph()
			elif event.scancode == contine_key.scancode and event.pressed == true:
				main_move_to_next_graph()


func dialog_finished():
	emit_signal("GT_dialog_finished")
	queue_free()


func setup_signals():
	var _err
	#ingoing:
	_err = anim_player.connect("animation_finished", self ,"_on_Body_AnimationPlayer_animation_finished")
	_err = GTD.connect("GT_choice_made", self ,"_on_GT_choice_made")	
	#outgoing: (all to GTD- singleton who forwards them)
	_err = connect("GT_dialog_started", GTD ,"_on_GT_dialog_started")
	_err = connect("GT_set_choices", GTD, "_on_GT_set_choices")
	_err = connect("GT_set_pictures", GTD, "_on_GT_set_pictures")
	_err = connect("GT_set_speaker", GTD, "_on_GT_set_speaker")
	_err = connect("GT_dialog_finished", GTD, "_on_GT_dialog_finished")
	_err = connect("GT_text_animation_started", GTD, "_on_GT_text_animation_started")
	_err = connect("GT_text_animation_finished", GTD, "_on_GT_text_animation_finished")
	_err = connect("GT_variables_were_changed", GTD, "_on_GT_variables_were_changed")
	_err = connect("GT_custom_signal", GTD, "_on_GT_custom_signal")
	_err = connect("GT_preparing_chapter_change_to", GTD, "_on_GT_preparing_chapter_change_to")
	
	

func main_loop():
	#set datasets
	var current = story_helper.get_current_data() ###  {"nid": 1, "dialogtext" "speaker "pictures" "choices" "connects"}
	do_dialogtext(current["dialogtext"])
	do_speaker(current["speaker"])
	do_pictures(current["pictures"])
	next_graphs = do_choices_connects(current["choices"], current["connects"])
	if next_graphs.size() == 1:### only 1 next graph: ###
		var choice= next_graphs[0]["choice"]
		if choice=="" or choice==" " or choice == "#":
			is_waiting_for_choice=false
		else: is_waiting_for_choice=true
	elif next_graphs.size() >1:#### multiple selections to choose from
		is_waiting_for_choice=true
	else:
		next_graphs=[]			
		is_waiting_for_choice=false
		
	if next_graphs==[]: do_chapter(bbcode_text)	
	if do_skip(bbcode_text) and !is_waiting_for_choice: 
			main_move_to_next_graph()
			return
	is_animation_finished=false
	emit_signal("GT_text_animation_started")
	anim_player.play("TextFadeIn")
	

func main_move_to_next_graph(nextID=0):
	if next_graphs.size()==0:
		dialog_finished()
	elif next_graphs.size()==1:
		story_helper.change_current_to(next_graphs[0]["next_nID"])
		emit_signal("GT_text_changed")
		main_loop()
	else: 		##### graphsize >1
		story_helper.change_current_to(nextID)
		main_loop()


func do_dialogtext(dialog:String):
	var current_text=dialog
	if "<if>" in current_text:
		current_text=_parse_if_conditions(current_text)
	if "<change>" in current_text:
		current_text = _parse_change_variables(current_text)
	if "<signal>" in current_text:
		current_text = _parse_custom_signals(current_text)	
	#do inject variables between #()#
	current_text=GTD.inject_variables(current_text)
	bbcode_text=current_text


func do_speaker(speaker:String):
	emit_signal("GT_set_speaker", speaker)
	
	
func do_pictures(pictures:String):
	emit_signal("GT_set_pictures", pictures)
	

func do_skip(txt:String):
	if "<skip>" in txt:
		var variable_count = txt.count("<skip>")
		for _i in range(variable_count):
			txt.erase(txt.find("<skip>"), "<skip>".length())
		bbcode_text=txt
		return true
	return false
	

func do_chapter(txt:String):
	if !"<chapter>" in txt:
		return false
	var split = _get_tagged_text("chapter", txt).split(":", true, 1)
	var start_index = txt.find("<chapter>")
	var end_index = txt.find("</chapter>") + "</chapter>".length()
	txt.erase(start_index, end_index - start_index)
	bbcode_text=txt
	if split.size()<2:
		return false
	var next=[story_helper.set_startpoint(GTD.parse_expr(split[0])as int, GTD.parse_expr(split[1])as int)]
	if !next: return false
	next_graphs=[{"next_nID": GTD.parse_expr(split[1])as int}]
	emit_signal("GT_preparing_chapter_change_to",GTD.parse_expr(split[0])as int,GTD.parse_expr(split[1])as int)


func do_choices_connects(choices:Array, connects:Array):
	### if >1 choices do texbox
	### if only 1 choice prio that over only ifs
	### if only ifs check and take first
	### else []
	var next_connections = get_valid_next_connections(choices,connects)
	var counter_true_choices = 0
	for connection in next_connections:
		if GTD.check_if(connection["if"]):
			if !connection["choice"]=="" and !connection["choice"]==" " and !connection["choice"]=="#":
				counter_true_choices+=1
	if counter_true_choices>1: return next_connections
	elif counter_true_choices==1: return next_connections
	#else:
	for connection in next_connections:
		if GTD.check_if(connection["if"]):
			return [connection]
	return []


func get_valid_next_connections(choices:Array, connects:Array):
	var all_valid_connections=[]
	for connection in connects:
		var dict = {"next_nID": connection[1] as int,
		"choice": choices[connection[0]][0],
		"if": choices[connection[0]][1]
		}
		all_valid_connections.push_back(dict)
	return all_valid_connections 
	#[{"choice": "red potion", "if": "3==3", "next_nID": 2},{"choice": "blue potion", "if": "10>4", "next_nID":3},{"choice": "blue potion", "if": "10>4", "next_nID":4}]



#####			incomming signals:				####
func _on_Body_AnimationPlayer_animation_finished(_anim_name):
	is_animation_finished = true
	emit_signal("GT_text_animation_finished")
	if is_waiting_for_choice: emit_signal("GT_set_choices",next_graphs)


func _on_GT_choice_made(next_nID:int):
	main_move_to_next_graph(next_nID)
	

### 			text manipulation functions:		####
func _get_tagged_text(tag : String, txt : String) -> String:
	var start_tag = "<"+tag+">"
	var end_tag = "</"+tag+">"
	var start_index = txt.find(start_tag) + start_tag.length()
	var end_index = txt.find(end_tag)
	var substr_length = end_index - start_index
	return txt.substr(start_index, substr_length)


func _parse_change_variables(txt : String) -> String:
	var variable_count = txt.count("<change>")
	var changes=[]
	for _i in range(variable_count):
		var splitcommand = _get_tagged_text("change", txt).split("=", true, 1)
		var start_index = txt.find("<change>")
		var end_index = txt.find("</change>") + "</change>".length()
		var substr_length = end_index - start_index
		txt.erase(start_index, substr_length)
		if splitcommand.size()>1 and splitcommand[0]!="":
			var _error = GTD.change_variable_to(splitcommand[0], splitcommand[1])
			var onechange={"variable": splitcommand[0],
			"changed_to": GTD.parse_expr(splitcommand[1])}
			if _error: changes.push_back(onechange)
	if changes.size()>0: emit_signal("GT_variables_were_changed", changes)
	return txt


func _parse_custom_signals(txt: String) -> String:
	var variable_count = txt.count("<signal>")
	for _i in range(variable_count):
		var splitcommand = _get_tagged_text("signal", txt).split("{", true, 1)
		var start_index = txt.find("<signal>")
		var end_index = txt.find("</signal>") + "</signal>".length()
		txt.erase(start_index, end_index - start_index)
		var value
		if splitcommand.size()==1:value="default"
		elif splitcommand[1]=="}": value="default"
		else: value = GTD.parse_expr(splitcommand[1].trim_suffix("}"))
		var signalkey=splitcommand[0]
		if String(value)=="default": emit_signal("GT_custom_signal", signalkey)
		else: emit_signal("GT_custom_signal", signalkey, value)
	return txt


func _parse_if_conditions(txt: String):
	var variable_count = txt.count("<if>")
	for _i in range(variable_count):
		var splitcommand = _get_tagged_text("if", txt).split("{", true, 1)
		var start_index = txt.find("<if>")
		var end_index = txt.find("</if>") + "</if>".length()
		
		if splitcommand.size()==1: 
			txt.erase(start_index, end_index - start_index)
		elif splitcommand[1]=="}":
			txt.erase(start_index, end_index - start_index)
		elif GTD.parse_expr(splitcommand[0]):
			txt.erase(start_index, "<if>".length()+splitcommand[0].length()+"{".length())
			txt.erase(start_index-1+splitcommand[1].length(), "}</if>".length())
		else: 
			txt.erase(start_index, end_index - start_index)
	return txt
	
