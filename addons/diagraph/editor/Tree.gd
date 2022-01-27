tool
extends Tree

# ******************************************************************************

onready var ContextMenu = preload('res://addons/diagraph/utils/ContextMenu.gd')

var root: TreeItem = null
var convos: TreeItem = null
var chars: TreeItem = null

signal conversation_changed(path)
signal conversation_selected(path)
signal conversation_created(path)
signal conversation_deleted(path)
signal conversation_renamed(old_path, new_path)

signal card_selected(path)
signal card_renamed(id, new_path)

# ******************************************************************************

func _ready():
	Diagraph.connect('refreshed', self, 'refresh')
	refresh()
		
	connect('item_selected', self, '_on_item_selected')
	connect('item_rmb_selected', self, '_on_item_rmb_selected')
	connect('gui_input', self, '_on_gui_input')
	connect('item_edited', self, '_on_item_edited')

func refresh():
	if root:
		root.free()
	root = create_item()

	for convo in Diagraph.conversations:
		var item = create_item(root)
		var text = convo
		var path = convo
		item.set_text(0, text)
		item.set_metadata(0, path)
		item.set_tooltip(0, path)

		var nodes = Diagraph.load_json(Diagraph.name_to_path(path), {})
		for node in nodes.values():
			var _item = create_item(item)
			_item.set_text(0, node.name)
			_item.set_metadata(0, node.id)
			# _item.set_tooltip(0, str(node.id))

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == 1:
		if event.pressed and event.doubleclick:
			change_conversation()

func change_conversation():
	var item = get_selected()
	var parent = item.get_parent()
	var path = get_item_path(item)

	emit_signal('conversation_changed', path)

# ******************************************************************************

func _start_rename():
	var item = get_selected()
	item.set_editable(0, true)
	edit_selected()

func _on_item_edited():
	var item = get_selected()
	item.set_editable(0, false)
	if item.get_parent() == root:
		var name = item.get_text(0)
		var path = item.get_metadata(0)
		var new_path = name
		if path:
			item.set_metadata(0, new_path)
			item.set_tooltip(0, new_path)
			emit_signal('conversation_renamed', path, new_path)
		else:
			item.set_metadata(0, new_path)
			item.set_tooltip(0, new_path)
			emit_signal('conversation_created', new_path)
	else:
		var name = item.get_text(0)
		var id = item.get_metadata(0)
		item.set_tooltip(0, name)
		emit_signal('card_renamed', id, name)

# ******************************************************************************

func get_item_path(item:TreeItem) -> String:
	var parent = item.get_parent()
	if parent == root:
		return item.get_text(0)
	else:
		return parent.get_text(0) + ':' + item.get_text(0)

func _on_item_selected() -> void:
	var item = get_selected()
	var parent = item.get_parent()
	var path = get_item_path(item)
	
	if parent == root:
		emit_signal('conversation_selected', path)
	else:
		emit_signal('card_selected', path)

# ******************************************************************************

var ctx = null

func _on_item_rmb_selected(position) -> void:
	if ctx:
		ctx.queue_free()
		ctx = null
	var item = get_selected()

	ctx = ContextMenu.new(self, '_on_ctx_item_selected')
	if item.get_parent() == root:
		ctx.add_item('New')
		ctx.add_item('Copy Path')
		ctx.add_item('Rename')
		ctx.add_item('Delete')
	else:
		ctx.add_item('Copy Path')
		# ctx.add_item('Copy Name')
		ctx.add_item('Rename')
		# ctx.add_item('Delete')
	ctx.open(get_global_mouse_position())

func _on_ctx_item_selected(selection:String) -> void:
	match selection:
		'New':
			var item = create_item(root)
			item.set_text(0, 'new')
			item.set_editable(0, true)
			item.select(0)
			call_deferred('edit_selected')
		'Copy Path':
			var item = get_selected()
			var path = get_item_path(item)
			OS.clipboard = path
		'Rename':
			_start_rename()
		'Delete':
			var item = get_selected()
			item.get_parent().remove_child(item)
			
			var path = item.get_metadata(0)
			if path:
				emit_signal('conversation_deleted', path)
