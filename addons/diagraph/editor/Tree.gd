tool
extends Tree

# ******************************************************************************

onready var ContextMenu = preload('res://addons/diagraph/utils/ContextMenu.gd')

var root: TreeItem = null
var convos: TreeItem = null
var chars: TreeItem = null

export var folder_icon: ImageTexture
export var file_icon: ImageTexture
export var card_icon: ImageTexture

signal folder_collapsed
signal create_folder(path)
signal rename_folder(old_path, new_path)
signal delete_folder(path)

signal change_conversation(path)
signal create_conversation(path)
signal delete_conversation(path)
signal rename_conversation(old_path, new_path)

signal select_node(path)
signal focus_node(path)
signal rename_node(id, new_path)
signal delete_node(id)
signal run_node

var folder_state = {}

var icon_colors = {
	'speech': Color.olivedrab,
	'branch': Color.tomato,
	'comment': Color.steelblue,
}

# ******************************************************************************

func _ready():
	hide_root = true
	allow_rmb_select = true

	connect('item_selected', self, '_on_item_selected')
	connect('gui_input', self, '_on_gui_input')
	connect('item_edited', self, '_on_item_edited')
	connect('item_activated', self, '_on_item_activated')

	if !is_connected('item_collapsed', self, '_on_item_collapsed'):
		connect('item_collapsed', self, '_on_item_collapsed')

var refresh_countdown = 0

func refresh():
	refresh_countdown = 10

func _physics_process(delta):
	if refresh_countdown:
		refresh_countdown -= 1
		if refresh_countdown == 0:
			_refresh()

func _refresh():
	if root:
		root.free()
	root = create_item()
	root.set_meta('path', '')
	root.set_meta('type', 'folder')

	if is_connected('item_collapsed', self, '_on_item_collapsed'):
		disconnect('item_collapsed', self, '_on_item_collapsed')

	var items := {}

	var dir = Directory.new()
	var files = Diagraph.get_all_files_and_folders(Diagraph.conversation_prefix)
	files.erase(Diagraph.conversation_prefix.trim_suffix('/'))
	files.erase(Diagraph.conversation_prefix)

	var file_data = []

	for file in files:
		var path = file.trim_prefix(Diagraph.conversation_prefix)
		if file == 'res://conversations':
			continue

		var parts = []
		if dir.dir_exists(file):
			parts = path.split('/')
		if dir.file_exists(file):
			parts = path.get_base_dir().split('/')

		var prev = root
		var chunk = ''

		for part in parts:
			chunk += part + '/'
			if chunk == '/':
				continue
			if chunk in items:
				prev = items[chunk]
				continue

			prev = create_folder_item(prev, file)
			items[chunk] = prev

		if !dir.file_exists(file):
			continue

		file_data.append({file = file, prev = prev, path = path})

	var current_conversation = ''
	if owner:
		current_conversation = owner.get('current_conversation')

	for data in file_data:
		var item = create_file_item(data.prev, data.path)
		item.disable_folding = false

		if data.path.get_file() == current_conversation:
			item.collapsed = false
			item.set_icon_modulate(0, Color.white)

		var nodes = Diagraph.load_conversation(data.path, {})

		var node_names = []
		var nodes_by_name = {}

		for node in nodes.values():
			nodes_by_name[node.name] = node
			node_names.append(node.name + ':' + str(node.id))

		node_names.sort()

		for node in node_names:
			var id = node.split(':')[1]
			create_node_item(item, data.file, nodes[id])

	if !is_connected('item_collapsed', self, '_on_item_collapsed'):
		connect('item_collapsed', self, '_on_item_collapsed')

func create_file_item(parent, path):
	var item = create_item(parent)
	item.set_meta('type', 'file')
	item.set_meta('path', path)
	item.set_meta('name', path.get_file())
	item.set_text(0, path.get_file())
	item.set_icon(0, file_icon)
	item.set_icon_modulate(0, Color.silver)
	item.set_tooltip(0, path)

	# item.disable_folding = true
	item.collapsed = true
	return item

func create_node_item(parent, path, node):
	var item = create_item(parent)
	item.set_meta('type', 'node')
	item.set_meta('path', path + ':' + str(node.id))
	item.set_meta('id', node.id)
	item.set_meta('node', node)
	item.set_text(0, node.name)
	item.set_meta('name', node.name)
	item.set_icon(0, card_icon)
	item.set_icon_modulate(0, icon_colors[node.type])
	item.set_tooltip(0, node.type)
	return item

func create_folder_item(parent, path):
	var item = create_item(parent)

	var p = path.trim_prefix(Diagraph.conversation_prefix)
	if p in folder_state:
		item.collapsed = folder_state[p].collapsed
	else:
		folder_state[p] = {'collapsed': false}

	item.set_custom_color(0, Color.darkgray)
	item.set_meta('type', 'folder')
	item.set_meta('path', path.trim_prefix(Diagraph.conversation_prefix))
	item.set_text(0, path.get_file())
	item.set_meta('name', path.get_file())
	item.set_tooltip(0, path.trim_prefix(Diagraph.conversation_prefix))
	return item

# ******************************************************************************

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == 2:
			open_context_menu(event.position)

func _on_item_collapsed(item):
	var type = item.get_meta('type')
	if type == 'folder':
		var path = item.get_meta('path')
		folder_state[path] = {'collapsed': item.collapsed}

func _on_item_selected() -> void:
	var item = get_selected()
	var type = item.get_meta('type')
	if item.has_meta('path'):
		var path = item.get_meta('path')

		match type:
			'file':
				pass
			'folder':
				pass
			'node':
				emit_signal('select_node', item.get_meta('id'))

func _on_item_activated():
	var item = get_selected()
	var path = item.get_meta('path')
	var type = item.get_meta('type')

	match type:
		'file':
			emit_signal('change_conversation', path)
		'folder':
			pass
		'node':
			emit_signal('focus_node', path)

# ******************************************************************************

func _start_rename():
	var item = get_selected()
	item.set_editable(0, true)
	edit_selected()

func _on_item_edited():
	var item = get_selected()
	var name = item.get_text(0)
	var type = item.get_meta('type')
	item.set_editable(0, false)
	var path := ''
	var new := false
	if item.has_meta('path'):
		path = item.get_meta('path')
	else:
		new = true
		var parent = item.get_parent()
		while parent != root:
			path = parent.get_text(0) + '/' + path
			parent = parent.get_parent()

		path += name
		path = path.trim_prefix('/')
		item.set_meta('path', path)
		item.set_meta('name', name)
		item.set_tooltip(0, path)

	match type:
		'file':
			if new:
				emit_signal('create_conversation', Diagraph.conversation_prefix + path)
			else:
				var new_path = path.trim_suffix(item.get_meta('name')) + name
				item.set_meta('path', new_path)
				item.set_tooltip(0, new_path)
				emit_signal('rename_conversation', path, new_path)
		'folder':
			if new:
				folder_state[Diagraph.conversation_prefix + path] = {'collapsed': false}
				emit_signal('create_folder', Diagraph.conversation_prefix + path)
			else:
				var new_path = path.trim_suffix(path.get_file()) + name + '/'
				item.set_meta('path', new_path)
				item.set_tooltip(0, new_path)
				emit_signal('rename_folder', path, new_path)
		'node':
			var id = item.get_meta('id')
			item.set_tooltip(0, name)
			emit_signal('rename_node', id, name)

# ******************************************************************************

func get_item_path(item: TreeItem) -> String:
	var parent = item.get_parent()
	if parent == root:
		return item.get_text(0)
	else:
		return parent.get_text(0) + ':' + item.get_text(0)

func select_item(path):
	pass

func delete_item(id):
	var item = root.get_children()
	while true:
		if item == null:
			break
		if item.get_text(0) == owner.current_conversation:
			var card = item.get_children()
			while true:
				if card == null:
					break
				if str(card.get_metadata(0)) == str(id):
					item.remove_child(card)
					card.free()
					break
				card = card.get_next()
			break
		item = item.get_next()

# ******************************************************************************

var ctx = null

func open_context_menu(position) -> void:
	if ctx:
		ctx.queue_free()
		ctx = null

	var item = get_item_at_position(position)

	ctx = ContextMenu.new(self, 'context_menu_item_selected')
	if item:
		var type = item.get_meta('type')
		match type:
			'file':
				if item.get_meta('path').ends_with('json'):
					ctx.add_item('Convert to Yarn')
				ctx.add_item('Copy Path')
				ctx.add_item('Rename')
				ctx.add_item('Delete')
			'folder':
				ctx.add_item('New File')
				ctx.add_item('New Folder')
				ctx.add_item('Rename')
				ctx.add_item('Delete')
			'node':
				ctx.add_item('Run')
				ctx.add_item('Copy Path')
				ctx.add_item('Rename')
				ctx.add_item('Delete')
	else:
		ctx.add_item('New File')
		ctx.add_item('New Folder')
	ctx.open(get_global_mouse_position())

var ge = null

func context_menu_item_selected(selection: String) -> void:
	match selection:
		'Convert to Yarn':
			var item = get_selected()
			var path = item.get_meta('path')
			var nodes = Diagraph.load_conversation(path)
			if !ge:
				ge = load('res://addons/diagraph/editor/GraphEdit.gd').new()
				add_child(ge)
			ge.set_nodes(nodes)
			nodes = ge.get_nodes()
			if nodes:
				Diagraph.save_yarn(Diagraph.conversation_prefix + path.replace('.json', '.yarn'), nodes)
			Diagraph.refresh()
		'New File':
			var item = create_item(get_selected())
			item.set_text(0, 'new')
			item.set_meta('name', 'new')
			item.set_meta('type', 'file')
			item.set_icon(0, file_icon)
			item.set_icon_modulate(0, Color.silver)
			item.set_editable(0, true)
			item.set_icon(0, file_icon)
			item.select(0)
			call_deferred('edit_selected')
		'New Folder':
			var item = create_item(get_selected())
			item.set_text(0, 'new')
			item.set_meta('name', 'new')
			item.set_meta('type', 'folder')
			item.set_editable(0, true)
			item.select(0)
			call_deferred('edit_selected')
		'Copy Path':
			var item = get_selected()
			var path = item.get_meta('path')
			path = path.replace('.yarn', '')
			path = path.replace('.json', '')
			OS.clipboard = path.trim_prefix(Diagraph.conversation_prefix)
		'Rename':
			_start_rename()
		'Run':
			emit_signal('run_node')
		'Delete':
			var item = get_selected()
			var path = item.get_meta('path')
			var type = item.get_meta('type')

			match type:
				'file':
					emit_signal('delete_conversation', path)
				'folder':
					emit_signal('delete_folder', path)
				'node':
					emit_signal('delete_node', item.get_meta('id'))

			if is_instance_valid(item):
				item.get_parent().remove_child(item)

# ******************************************************************************

func get_drag_data(position):
	set_drop_mode_flags(DROP_MODE_INBETWEEN | DROP_MODE_ON_ITEM)

	var preview = Label.new()
	preview.text = get_selected().get_text(0)
	set_drag_preview(preview)

	return get_selected()

func can_drop_data(position, data) -> bool:
	if !(data is TreeItem):
		return false
	var to_item = get_item_at_position(position)

	var shift = get_drop_section_at_position(position)
	if shift != 0:
		to_item = to_item.get_parent()

	if to_item:
		var type = to_item.get_meta('type')
		if type != 'folder':
			return false
	return true

func drop_data(position, item):
	var to_item = get_item_at_position(position)

	var shift = get_drop_section_at_position(position)
	if shift != 0:
		to_item = to_item.get_parent()

	var to_path = ''
	if to_item:
		to_path = to_item.get_meta('path')

	var type = item.get_meta('type')
	if type in ['file', 'folder']:
		var path = item.get_meta('path')
		var new_path = to_path.plus_file(path.get_file())

		emit_signal('rename_conversation', path, new_path)
