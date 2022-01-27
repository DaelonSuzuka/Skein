tool
extends Control

# ******************************************************************************

onready var GraphEdit: GraphEdit = find_node('GraphEdit')
onready var Tree: Tree = find_node('Tree')
onready var Toolbar = $Toolbar
onready var DialogBox = $Preview/DialogBox

var is_plugin = false
var current_conversation := ''
var editor_data := {}

# ******************************************************************************

func _ready():
	$Toolbar/New.connect('pressed', self, 'create_conversation')
	$Toolbar/Clear.connect('pressed', $ConfirmClear, 'popup')
	$ConfirmClear.connect('confirmed', GraphEdit, 'clear')
	$Toolbar/Save.connect('pressed', self, 'save_conversation')
	$Toolbar/Save.connect('pressed', self, 'save_editor_data')
	$Toolbar/Run.connect('pressed', self, 'run')
	$Preview/Stop.connect('pressed', self, 'stop')
	$Preview/Next.connect('pressed', self, 'next')
	$Preview/Debug.connect('toggled', $Preview/DialogBox/DebugLog, 'set_visible')
	DialogBox.connect('done', self, 'stop')

	$Preview/DialogBox.show()
	$Preview/Stop.show()
	$Preview/Debug.show()
	$Preview/Dimmer.show()
	$Preview.hide()

	Tree.connect('conversation_changed', self, 'change_conversation')
	Tree.connect('conversation_selected', self, 'conversation_selected')
	Tree.connect('conversation_created', self, 'create_conversation')
	Tree.connect('conversation_deleted', self, 'delete_conversation')
	Tree.connect('conversation_renamed', self, 'rename_conversation')
	Tree.connect('card_selected', self, 'card_selected')
	Tree.connect('card_renamed', self, 'card_renamed')

	if !Engine.editor_hint or is_plugin:
		load_editor_data()

		remove_child(Toolbar)
		GraphEdit.get_zoom_hbox().add_child(Toolbar)

	$AutoSave.connect('timeout', self, 'autosave')

func autosave():
	save_conversation()
	save_editor_data()

# ******************************************************************************

func save_conversation():
	if !current_conversation:
		return
	var nodes = GraphEdit.get_conversation()
	save_json(Diagraph.name_to_path(current_conversation), nodes)

func change_conversation(path):
	save_conversation()
	save_editor_data()
	load_conversation(path)

func load_conversation(path):
	var parts = path.split(':')
	var name = parts[0]
	if current_conversation == name:
		return
	print('loading convo: ', path)
	GraphEdit.clear()
	current_conversation = name

	if name in editor_data:
		GraphEdit.set_data(editor_data[name])
	else:
		editor_data[name] = {}
	var nodes = load_json(Diagraph.name_to_path(name), {})
	if nodes:
		GraphEdit.set_conversation(nodes)

func create_conversation(path):
	GraphEdit.clear()
	current_conversation = path
	Diagraph.load_conversations()

func delete_conversation(path):
	if current_conversation == path:
		GraphEdit.clear()
		current_conversation = ''
	editor_data.erase(path)
	save_editor_data()
	var dir = Directory.new()
	dir.remove(Diagraph.name_to_path(path))
	Diagraph.load_conversations()

func rename_conversation(old, new):
	if current_conversation == old:
		GraphEdit.clear()
		current_conversation = ''
	editor_data[new] = editor_data[old]
	editor_data.erase(old)
	save_editor_data()
	var dir = Directory.new()
	dir.rename(Diagraph.name_to_path(old), Diagraph.name_to_path(new))
	load_conversation(new)
	Diagraph.load_conversations()

func conversation_selected(path):
	pass
	# print('conversation_selected: ', path)

func card_selected(path):
	pass
	# print('conversation_selected: ', path)

func card_renamed(old, new):
	pass
	# prints('card_renamed:', old, new)

# ******************************************************************************

func character_added(path):
	var char_map = load_json(Diagraph.character_map_path, {})
	var c = load(path).instance()
	char_map[c.name] = path
	save_json(Diagraph.character_map_path, char_map)
	Diagraph.refresh()

# ******************************************************************************

func run():
	var selection = GraphEdit.get_selected_nodes()
	if selection.size() == 1:
		var node = selection[0]
		save_conversation()
		save_editor_data()
		$Preview.show()
		print('run ', current_conversation)
		DialogBox.start(current_conversation, node.name)
	
func stop():
	$Preview.hide()

func next():
	DialogBox.next()

# ******************************************************************************

var editor_data_file_name = 'user://editor_data.json'

func save_editor_data():
	if !current_conversation:
		return
	editor_data[current_conversation] = GraphEdit.get_data()
	editor_data['current_conversation'] = current_conversation
	save_json(editor_data_file_name, editor_data)

func load_editor_data():
	var data = load_json(editor_data_file_name)
	if data:
		editor_data = data
		if 'current_conversation' in editor_data:
			load_conversation(editor_data['current_conversation'])

# ******************************************************************************

func save_json(path, data):
	var f = File.new()
	f.open(path, File.WRITE)
	f.store_string(JSON.print(data, "\t"))
	f.close()

func load_json(path, default=null):
	var result = default
	var f = File.new()
	if f.file_exists(path):
		f.open(path, File.READ)
		var text = f.get_as_text()
		f.close()
		result = JSON.parse(text).result
	return result
