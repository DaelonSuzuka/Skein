tool
extends Control
onready var graph_paneltscn = preload("grapheditor/graph_panel.tscn")
var graph_panel
onready var filedialog = get_node("FileDialog")
onready var chaptermenu = get_node("VBoxContainer/MainMenu/ChapterMenuButton")
onready var label_filename = get_node("VBoxContainer/MainMenu/LabelFilename")
onready var quicksave = get_node("VBoxContainer/MainMenu/Quicksave")
var chapterdata = [{"chapterID": 1, "chaptername": "chapter1", "poolstrings": []}]
var current_chapterID: int = 0
var copy_graphs_takeover = null
const story_file_helpergd = preload("res://addons/graphtastic/helper_classes/gt_story_file_helper.gd")
var story_helper =story_file_helpergd.new()


#this data should never get changed on runtime:
var empty_chapter_template 					#= {"chapterID": 1, "chaptername": "unnamed", "poolstrings": []}
var headerinfo_chapter: PoolStringArray 	#= ["<- chaptername", "<- chapterID"]
var headerinfo: PoolStringArray 			#= ["nID", "slots", "name", "dialogtext", "speaker", "facepice", "off_x", "off_y", "choices", "connects"]



func _ready():
	empty_chapter_template = story_helper.empty_chapter_template
	headerinfo_chapter = story_helper.headerinfo_chapter
	headerinfo = story_helper.headerinfo
	chaptermenu.get_popup().connect("id_pressed", self, "_on_ChapterMenuButton_selected")
	get_node("NewChapterPopup").register_text_enter(get_node("NewChapterPopup/LineEdit"))
	get_node("RenameChapterPopup").register_text_enter(get_node("RenameChapterPopup/LineEdit"))
	set_current_chapter(1)


func set_current_chapter(newID):
	if newID == current_chapterID:
		return
	for chapter in chapterdata:
		if chapter["chapterID"] == newID:
			current_chapterID = newID
			setupChapterMenuButton()
			create_new_graphedit_from_current_chapter()
			return
	print("GT-error: set_current_chapter went wrong!")


func setupChapterMenuButton(): 	
	chaptermenu.get_popup().clear()
	chaptermenu.get_popup().add_item("add New Chapter")
	chaptermenu.get_popup().add_item("change Name of Chapter")
	chaptermenu.get_popup().add_item("delete current Chapter")
	chaptermenu.get_popup().add_separator()
	for chapter in chapterdata:
		chaptermenu.get_popup().add_item(String(chapter["chapterID"])+" | "+chapter["chaptername"])	
		if chapter["chapterID"] == current_chapterID:
			chaptermenu.text= String(chapter["chapterID"])+" | "+chapter["chaptername"]


func create_new_graphedit_from_current_chapter(): 	#basically just extension of setupChapterMenuButton()
	if graph_panel != null:
		graph_panel.free()
	graph_panel = graph_paneltscn.instance()
	get_node("VBoxContainer").add_child(graph_panel)
	if copy_graphs_takeover != null:
		graph_panel.get_node("Vbox/GraphEdit").copy_d_graphs=copy_graphs_takeover
	
	var poolstrings
	for chapter in chapterdata:
		if chapter["chapterID"] ==current_chapterID:
			poolstrings= chapter["poolstrings"]
	graph_panel.get_node("Vbox/GraphEdit").set_data_from_poolstrings(poolstrings)


func load_current_chapter_from_graphedit():	
	copy_graphs_takeover=graph_panel.get_node("Vbox/GraphEdit").copy_d_graphs
	var poolstrings = graph_panel.get_node("Vbox/GraphEdit").get_data_from_poolstrings()
	for chapter in chapterdata:
		if chapter["chapterID"]==current_chapterID:
			chapter["poolstrings"] = poolstrings


#######     funcs to load and save to tsv       			 ###########
func _on_SaveTsv_pressed():
	filedialog.mode=4
	filedialog.invalidate()
	filedialog.popup_centered_ratio(0.7)
func _on_LoadTsv_pressed():
	filedialog.mode=0
	filedialog.invalidate()
	filedialog.popup_centered_ratio(0.7)
func _on_FileDialog_file_selected(filepath):
	if filedialog.mode==0:
		load_from_tsv(filepath)
	elif filedialog.mode==4:
		save_as_tsv(filepath)


func save_as_tsv(file_path:String):
	load_current_chapter_from_graphedit()
	var save = File.new()
	save.open(file_path, File.WRITE)
	save.store_csv_line(headerinfo, "	")
	for chapter in chapterdata:
		var info: PoolStringArray = [chapter["chaptername"], 
		headerinfo_chapter[0], String(chapter["chapterID"]), headerinfo_chapter[1], ]
		save.store_csv_line(info, "	")
		for poolstring in chapter["poolstrings"]:
			save.store_csv_line(poolstring, "	")
	save.close()
	label_filename.text=file_path
	quicksave.disabled=false


func load_from_tsv(file_path):
	var new_chapterdata=story_helper.load_from_file(file_path)	
	if !new_chapterdata: return									
	chapterdata=new_chapterdata
	current_chapterID=0
	set_current_chapter(new_chapterdata[0]["chapterID"])
	label_filename.text=file_path
	quicksave.disabled=false
	

###########		new- file/chapter	delete		changename		###########


func _on_NewFile_pressed():
	get_node("CreateNewFilePopup").popup_centered()
func _on_CreateNewFilePopup_confirmed():
	label_filename.text="new unsaved file"
	quicksave.disabled=true
	chapterdata=[] ###empty chapter data
	current_chapterID=0
	var empty_chapter = empty_chapter_template.duplicate()
	chapterdata.push_back(empty_chapter)
	set_current_chapter(1)


func _on_ChapterMenuButton_selected(listnr):
	if listnr == 0:_on_NewChapter_pressed()
	elif listnr == 1: _on_ChanngeChapterName_pressed()
	elif listnr == 2: _on_DeleteChapter_pressed() 
	else:
		var newid = chapterdata[listnr-4]["chapterID"]
		load_current_chapter_from_graphedit()
		set_current_chapter(newid)


func _on_NewChapter_pressed():
	get_node("NewChapterPopup").popup_centered()
	get_node("NewChapterPopup/LineEdit").grab_focus()
func _on_NewChapterPopup_confirmed():
	load_current_chapter_from_graphedit()
	var new_chapter_name = get_node("NewChapterPopup/LineEdit").text
	if new_chapter_name == "": new_chapter_name = "unnamed"
	var empty_chapter = empty_chapter_template.duplicate()
	for position in chapterdata.size():
		if chapterdata[position]["chapterID"] != (position+1):
			chapterdata.insert(position ,empty_chapter)
			chapterdata[position]["chapterID"]=position+1
			chapterdata[position]["chaptername"]=new_chapter_name
			set_current_chapter(position+1)
			return
	chapterdata.push_back(empty_chapter)
	chapterdata[chapterdata.size()-1]["chapterID"]=chapterdata.size()
	chapterdata[chapterdata.size()-1]["chaptername"]=new_chapter_name
	set_current_chapter(chapterdata.size())



func _on_DeleteChapter_pressed():
	get_node("DeleteChapterPopup").popup_centered()
func _on_DeleteChapterPopup_confirmed():
	if chapterdata.size() > 1:
		for chapter in chapterdata:
			if chapter["chapterID"] == current_chapterID:
				chapterdata.erase(chapter)
		set_current_chapter(chapterdata[0]["chapterID"])
	else: _on_CreateNewFilePopup_confirmed() 
		#cant delete last chapter so make new file instead
	


func _on_ChanngeChapterName_pressed():
	get_node("RenameChapterPopup").popup_centered()
	for chapter in chapterdata:
		if chapter["chapterID"] == current_chapterID:
			get_node("RenameChapterPopup/LineEdit").text=chapter["chaptername"]
	get_node("RenameChapterPopup/LineEdit").select_all()	#grab_focus()
	get_node("RenameChapterPopup/LineEdit").grab_focus()
func _on_RenameChapterPopup_confirmed():
	var new_chapter_name = get_node("RenameChapterPopup/LineEdit").text
	if new_chapter_name == "": new_chapter_name = "unnamed"
	for chapter in chapterdata:
			if chapter["chapterID"] == current_chapterID:
				chapter["chaptername"] = new_chapter_name
				setupChapterMenuButton()
				return
	print("error couldnt properly rename")




func _on_CloseEditor_pressed():
	get_parent().get_node("Start").visible=true
	self.queue_free()


func _on_Quicksave_pressed():
	save_as_tsv(label_filename.text)


func _on_Quickplay_pressed():
	var old_file_path = label_filename.text
	save_as_tsv("res://addons/graphtastic/userdata/quickplay.tsv")
	var quickplay_tscn=preload("res://addons/graphtastic/dialog_player/toolmode/popup_ineditor.tscn")
	var quickplay=quickplay_tscn.instance()
	add_child(quickplay)
	quickplay.popup_centered_ratio(0.5)
	label_filename.text = old_file_path
