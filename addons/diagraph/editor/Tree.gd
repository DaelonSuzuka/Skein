tool
extends Tree

# ******************************************************************************

onready var ContextMenu = preload('res://addons/diagraph/utils/ContextMenu.gd')

var root: TreeItem = null
var convos: TreeItem = null
var chars: TreeItem = null

signal conversation_selected(path)
signal conversation_created(path)
signal conversation_deleted(path)
signal conversation_renamed(old_path, new_path)

# ******************************************************************************

func _ready():
	root = create_item()

	convos = create_item(root)
	convos.set_text(0, 'Conversations')
	for convo in Diagraph.conversations:
		var item = create_item(convos)
		item.set_text(0, convo.rstrip('.json'))
		var path = Diagraph.conversation_path + convo
		item.set_metadata(0, path)
		item.set_tooltip(0, path)

	chars = create_item(root)
	chars.set_text(0, 'Characters')
	for character in Diagraph.characters:
		var item = create_item(chars)
		item.set_text(0, character)
		
	connect('item_selected', self, '_on_item_selected')
	connect('item_rmb_selected', self, '_on_item_rmb_selected')
	connect('gui_input', self, '_on_gui_input')
	connect('item_edited', self, '_on_item_edited')

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == 1:
		if event.is_pressed() and event.doubleclick:
			_start_rename()

func _start_rename():
	var item = get_selected()
	if item.get_parent() == convos:
		edit_selected()
		var path = item.get_metadata(0)
		if path:
			item.set_editable(0, true)

func _on_item_edited():
	var item = get_selected()
	item.set_editable(0, false)
	if item.get_parent() == convos:
		var name = item.get_text(0)
		var path = item.get_metadata(0)
		var new_path = Diagraph.conversation_path + name + '.json'
		if path:
			item.set_metadata(0, new_path)
			item.set_tooltip(0, new_path)
			emit_signal('conversation_renamed', path, new_path)
		else:
			item.set_metadata(0, new_path)
			item.set_tooltip(0, new_path)
			emit_signal('conversation_created', new_path)

# ******************************************************************************

func _on_item_selected():
	var item = get_selected()
	
	if item.get_parent() == convos:
		var path = item.get_metadata(0)
		if path:
			emit_signal('conversation_selected', path)

var ctx = null

func _on_item_rmb_selected(position):
	if ctx:
		ctx.queue_free()
		ctx = null
	var item = get_selected()

	if item == convos:
		ctx = ContextMenu.new(self, 'item_selected')
		ctx.add_item('New')
		# ctx.add_item('Create Subfolder')
		# ctx.add_item('Delete Folder')
		ctx.open(position)
		return

	if item.get_parent() == convos:
		ctx = ContextMenu.new(self, 'item_selected')
		ctx.add_item('New')
		# ctx.add_item('Copy Name')
		ctx.add_item('Rename')
		ctx.add_item('Delete')
		ctx.open(position)
		return
	
	# ctx = ContextMenu.new(self, 'item_selected')
	# if item == chars:
	# 	ctx.add_item('chars')
	# if item.get_parent() == chars:
	# 	ctx.add_item('char')
	# ctx.open(position)

func item_selected(selection):

	match selection:
		'New':
			print('create convo')
			var item = create_item(convos)
			item.set_text(0, 'new')
			item.set_editable(0, true)
			item.select(0)
			call_deferred('edit_selected')
		'Copy Name':
			var item = get_selected()
			print(item.get_text(0))
		'Rename':
			_start_rename()
		'Delete':
			var item = get_selected()
			item.get_parent().remove_child(item)
			
			var path = item.get_metadata(0)
			if path:
				emit_signal('conversation_deleted', path)

