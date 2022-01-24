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

	Tree.connect('conversation_selected', self, 'change_conversation')
	Tree.connect('conversation_created', self, 'create_conversation')
	Tree.connect('conversation_deleted', self, 'delete_conversation')
	Tree.connect('conversation_renamed', self, 'rename_conversation')

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
	save_json(current_conversation, nodes)

func change_conversation(path):
	save_conversation()
	save_editor_data()
	load_conversation(path)

func load_conversation(path):
	GraphEdit.clear()
	current_conversation = path

	if path in editor_data:
		GraphEdit.set_data(editor_data[path])
	else:
		editor_data[path] = {}
	
	var nodes = load_json(path)
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
	dir.remove(path)
	Diagraph.load_conversations()

func rename_conversation(old, new):
	if current_conversation == old:
		GraphEdit.clear()
		current_conversation = ''
	editor_data[new] = editor_data[old]
	editor_data.erase(old)
	save_editor_data()
	var dir = Directory.new()
	dir.rename(old, new)
	load_conversation(new)
	Diagraph.load_conversations()

# ******************************************************************************

func run():
	var selection = GraphEdit.get_selected_nodes()
	if selection.size() == 1:
		var node = selection[0]
		if 'entry' in node.data and node.data.entry:
			save_conversation()
			save_editor_data()
			var nodes = load_json(current_conversation)
			$Preview.show()
			print('run ', current_conversation)
			DialogBox.start(nodes, node.name)
	
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
	editor_data = load_json(editor_data_file_name)
	if 'current_conversation' in editor_data:
		load_conversation(editor_data['current_conversation'])

# ******************************************************************************

func save_json(name, data):
	var f = File.new()
	f.open(name, File.WRITE)
	f.store_string(JSON.print(data, "\t"))
	f.close()

func load_json(name):
	var result = null
	var f = File.new()
	if f.file_exists(name):
		f.open(name, File.READ)
		var text = f.get_as_text()
		f.close()
		result = JSON.parse(text).result
	return result
