tool
extends Node

# ******************************************************************************

var characters_path = 'res://characters/'
var characters := {}

var conversation_path := 'res://conversations'
var conversations := []

func _ready():
	conversations = get_files(conversation_path)
	
	for path in get_files(characters_path):
		for file in get_files(characters_path + path, '.tscn'):
			var c = load(characters_path + path + '/' + file).instance()
			characters[c.name] = c


	# save_conversation('user://diagraph/test.json', {'test': 'penis'})

	# start_dialog('convo') # [convo]
	# start_dialog('convo:entry') # [convo, entry]
	# start_dialog('convo:entry:1') # [convo, entry, 1]
	# start_dialog('convo:entry', 1) # [convo, entry, 1]
	# start_dialog('convo', 'entry', 1) # [convo, entry, 1]
	# start_dialog('convo', 1) # [convo, , 1]
	# start_dialog('convo::1') # [convo, , 1]

func start_dialog(convo, arg1=null, arg2=null):
	if arg1 != null:
		if arg1 is String:
			convo += ':'
		if arg1 is int:
			if convo.count(':') == 0:
				convo += '::'
			if convo.count(':') == 1:
				convo += ':'
		convo += str(arg1)
	if arg2 != null:
		if convo.count(':') == 1:
			convo += ':'
		convo += str(arg2)

	var parts = convo.split(':')

	print(parts)

# ******************************************************************************

func save_conversation(name, data) -> void:
	var f = File.new()
	f.open(name, File.WRITE)
	f.store_string(JSON.print(data, "\t"))
	f.close()

func load_conversation(name) -> Dictionary:
	var result = null
	var f = File.new()
	if f.file_exists(name):
		f.open(name, File.READ)
		var text = f.get_as_text()
		f.close()
		result = JSON.parse(text).result
	return result

# ******************************************************************************

func get_files(path, ext='') -> Array:
	var files = []
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin()

	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			if ext:
				if file.ends_with(ext):
					files.append(file)
			else:
				files.append(file)

	dir.list_dir_end()

	return files
