tool
extends Node

# ******************************************************************************

var characters_path = 'res://characters/'
var characters := {}

var conversation_path := 'res://conversations/'
var conversations := []

var dialog_target = null

signal refreshed

# ******************************************************************************

func _ready():
	validate_paths()
	call_deferred('refresh')

	# start_dialog('convo') # [convo]
	# start_dialog('convo:entry') # [convo, entry]
	# start_dialog('convo:entry:1') # [convo, entry, 1]
	# start_dialog('convo:entry', 1) # [convo, entry, 1]
	# start_dialog('convo', 'entry', 1) # [convo, entry, 1]
	# start_dialog('convo', 1) # [convo, , 1]
	# start_dialog('convo::1') # [convo, , 1]

func refresh():
	# print('refresh')
	load_conversations()
	load_characters()
	emit_signal('refreshed')

func load_conversations():
	# print('load_conversations')
	conversations.clear()
	conversations = get_files(conversation_path)

func load_characters():
	# print('load_characters')
	characters.clear()
	for path in get_files(characters_path):
		# print(path)
		for file in get_files(characters_path + path, '.tscn'):
			# print(file)
			var c = load(characters_path + path + '/' + file).instance()
			characters[c.name] = c

# ******************************************************************************

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

	var name = name_to_path(parts[0])
	var entry = ''
	var line = 0
	if parts.size() >= 1:
		entry = parts[1]
	if parts.size() >= 2:
		line = int(parts[2])

	if dialog_target:
		dialog_target.show()
		dialog_target.start(name, entry, line)

# ******************************************************************************

func name_to_path(name):
	return conversation_path + name + '.json'

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

func validate_paths():
	var dir = Directory.new()
	if !dir.dir_exists(characters_path):
		dir.make_dir_recursive(characters_path)
	if !dir.dir_exists(conversation_path):
		dir.make_dir_recursive(conversation_path)

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
