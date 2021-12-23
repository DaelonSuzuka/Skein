extends Reference
var empty_chapter_template= {"chapterID": 1, "chaptername": "unnamed", "poolstrings": []}
var headerinfo_chapter: PoolStringArray = ["<- chaptername", "<- chapterID"]
var headerinfo: PoolStringArray = ["nID", "slots", "name", "dialogtext", "speaker", "pictures", "off_x", "off_y", "choices", "connects"]

var chapterdata=[]
var current_index 	#### of chapter!! NOT graph cough cough
var graph_list 		###	[] of {"nid": 1, "dialogtext" "speaker "pictures" "choices" "connects"}
var current_graph   ###  {"nid": 1, "dialogtext" "speaker "pictures" "choices" "connects"}


func change_current_to(new_id:int):
	for graph in graph_list:
		if new_id == graph["nID"]:
			current_graph=graph


func get_current_data():
	var data:Dictionary = current_graph.duplicate()
	return data


func set_startpoint(chapterID, nodeID):
	var index= false
	for chapter in chapterdata.size():
		if chapterdata[chapter]["chapterID"] == chapterID: index=chapter+1
	if !index:
		print("graphtastic_error: cant find chapter: "+String(chapterID)+" in file")
		return false
	current_index=index-1
	
	graph_list= []
	current_graph= false
	for one_graph in chapterdata[current_index]["poolstrings"]:
		var choices = parse_json(one_graph[8])
		var connects= parse_json(one_graph[9])
		var dictionary = {
			"nID": one_graph[0] as int,
			"dialogtext": one_graph[3],
			"speaker": one_graph[4],
			"pictures": one_graph[5],
			"choices": choices,
			"connects": connects
		}
		graph_list.push_back(dictionary)
		for graph in graph_list:
			if graph["nID"]==nodeID:
				current_graph= graph
	if !current_graph: print("graphtastic_error: cant find nID: "+String(nodeID)+" in chapter: "+String(chapterID))
	return current_graph

func load_from_tsv(file_path):
	chapterdata=load_from_file(file_path)
	return chapterdata


func load_from_file(file_path):
	if file_path==null: return false
	var new_chapterdata = []
	var save = File.new()
	if not save.file_exists(file_path):
		#print("graphtastic_error: no file to load")
		return false
	save.open(file_path, File.READ)
	var loadedheader = save.get_csv_line("	")
	if loadedheader != headerinfo:
		print("graphtastic_error: headercheck error, file is corrupt and cant be loaded")
		save.close()
		return false
	if save.eof_reached():
		print("graphtastic_error:, file empty cant load")
		save.close()
		return false
	var nextline = save.get_csv_line("	")
	if nextline.size() != 2*headerinfo_chapter.size():
		print("graphtastic_error: first chapter data size is wrong")
		save.close()
		return false
	elif (nextline[1]==headerinfo_chapter[0] and nextline[3]==headerinfo_chapter[1]):
		var new_chapter = empty_chapter_template.duplicate()
		new_chapter["chapterID"]=nextline[2] as int
		new_chapter["chaptername"]=nextline[0]
		new_chapter["poolstrings"]=empty_chapter_template["poolstrings"].duplicate()
		new_chapterdata.push_back(new_chapter)
	else:
		print("graphtastic_error: no first chapter exists in file")
		save.close()
		return false
	nextline = save.get_csv_line("	")
	while !save.eof_reached():
		if nextline.size() != headerinfo.size() and nextline.size() != 2*headerinfo_chapter.size():
			print("graphtastic_error file data of wrong column-size when loading the line: "+String(nextline))
			save.close()
			return false
		elif nextline[1]==headerinfo_chapter[0] and nextline[3]==headerinfo_chapter[1]:
			var new_chapter = empty_chapter_template.duplicate()
			new_chapter["chapterID"]=nextline[2] as int
			new_chapter["chaptername"]=nextline[0]
			new_chapter["poolstrings"]=empty_chapter_template["poolstrings"].duplicate()
			new_chapterdata.push_back(new_chapter)
		else:
			new_chapterdata[new_chapterdata.size()-1]["poolstrings"].push_back(nextline)
		nextline = save.get_csv_line("	")
	save.close()
	return new_chapterdata
