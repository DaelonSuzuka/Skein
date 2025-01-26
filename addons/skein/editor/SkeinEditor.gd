@tool
extends Control
class_name SkeinEditor

# ******************************************************************************

@onready var Run = find_child('Run')
# onready var Play = find_child('Play')
@onready var Refresh = find_child('Refresh')
@onready var Stop = find_child('Stop')
@onready var Next = find_child('Next')
@onready var Debug = find_child('Debug')
@onready var DialogBox = find_child('DialogBox')

@export var location := 'default'

var plugin: EditorPlugin = null
var current_conversation := ''
var editor_data := {}
var ignore_next_refresh := false

# ******************************************************************************

func _ready():
	if Engine.is_editor_hint() and !plugin:
		return

	Run.pressed.connect(self.run)
	Stop.pressed.connect(self.stop)
	Next.pressed.connect(self.next)
	Debug.toggled.connect($Preview/DialogBox/DebugLog.set_visible)

	%Preview.hide()
	# ConfirmDelete.popup_hide.connect(Skein.refresh)
	# ConfirmDelete.popup_hide.connect(ConfirmationDimmer.hide)
	%ConfirmDelete.confirmed.connect(self.really_delete_conversation)

	Refresh.pressed.connect(Skein.refresh)

	Skein.refreshed.connect(%Tree.refresh)
	%Tree.folder_collapsed.connect(self.save_editor_data)
	%Tree.run_node.connect(self.run)

	Skein.Utils.connect_all(%Tree, self)
	Skein.Utils.connect_all(%Tree, %GraphEdit)

	%ToggleLeftPanel.pressed.connect(self.toggle_left_panel)
	%ToggleRightPanel.pressed.connect(self.toggle_right_panel)

	# right sidebar should be closed by default
	%RightSidebar.hide()

	Skein.Utils.connect_all(%GraphEdit, self)

	if plugin:
		%SettingsMenu.add_item('Set as Preferred Editor', [plugin, 'set_preferred_editor', location])
	var sub = %SettingsMenu.create_submenu('Set Font Size', 'FontSize')
	sub.hide_on_item_selection = false
	%SettingsMenu.add_submenu_item('Font Size Reset', 'FontSize', [self, 'reset_font_size'])
	%SettingsMenu.add_submenu_item('Font Size +', 'FontSize', [self, 'set_font_size', 1])
	%SettingsMenu.add_submenu_item('Font Size -', 'FontSize', [self, 'set_font_size', -1])

	Skein.refreshed.connect(self.refresh)
	
	DialogBox.done.connect(self.dismiss_preview)
	DialogBox.line_started.connect(self.line_started)
	DialogBox.node_started.connect(self.node_started)

	$AutoSave.timeout.connect(self.autosave)

func refresh():
	if ignore_next_refresh:
		ignore_next_refresh = false
		return

	load_editor_data()
	var zoom_hbox = %GraphEdit.get_menu_hbox()
	var zoom_container = %GraphToolbar.find_child('ZoomContainer')
	zoom_hbox.get_parent().remove_child(zoom_hbox)
	zoom_container.add_child(zoom_hbox)

	if current_conversation:
		load_conversation(current_conversation, true)

func save():
	ignore_next_refresh = true
	save_conversation()
	save_editor_data()

func autosave():
	# save_conversation()
	save_editor_data()

func node_changed():
	save()

func toggle_left_panel():
	%LeftSidebar.visible = !%LeftSidebar.visible

func toggle_right_panel():
	%RightSidebar.visible = !%RightSidebar.visible

func reset_font_size():
	theme.default_font.size = 12

func set_font_size(amount):
	theme.default_font.size += amount

func dialog_font_minus():
	DialogBox.theme.default_font.size -= 1

func dialog_font_plus():
	DialogBox.theme.default_font.size += 1

# ******************************************************************************

func save_conversation():
	if current_conversation == '':
		return
	var nodes = %GraphEdit.get_nodes()
	if nodes:
		Skein.save_conversation(current_conversation, nodes)

func change_conversation(path: String):
	save_conversation()
	save_editor_data()
	load_conversation(path)

	var _path = path.trim_prefix(Skein.Files.conversation_prefix)
	var parts = _path.split(':')
	if len(parts) > 1:
		%GraphEdit.focus_node(parts[1])

func load_conversation(path: String, force:=false):
	var _path = path.trim_prefix(Skein.Files.conversation_prefix)
	var parts = _path.split(':')
	var name = parts[0]

	if !force and current_conversation == name:
		return
	%GraphEdit.clear()
	current_conversation = name

	var nodes = Skein.load_conversation(name, {})
	if nodes:
		%GraphEdit.set_nodes(nodes)
	if name in editor_data:
		%GraphEdit.set_data.call_deferred(editor_data[name])
	else:
		editor_data[name] = {}

# ******************************************************************************

func create_folder(path: String):
	DirAccess.make_dir_recursive_absolute(Skein.ensure_prefix(path))

func delete_folder(path: String):
	DirAccess.remove_absolute(Skein.ensure_prefix(path))
	Skein.refresh()

func rename_folder(old: String, new: String):
	DirAccess.rename_absolute(Skein.ensure_prefix(old), Skein.ensure_prefix(new))
	Skein.refresh()

# ------------------------------------------------------------------------------

func create_conversation(path: String):
	%GraphEdit.clear()
	path = Skein.ensure_prefix(path)
	current_conversation = path

	DirAccess.make_dir_recursive_absolute(path.get_base_dir())

	var f = FileAccess.open(path, FileAccess.WRITE)
	if f.is_open():
		f.store_string('')
	Skein.refresh()

var delete_path = null
@onready var original_size = %ConfirmDelete.size

func sort(a, b):
	return a.text.count('\n') > b.text.count('\n')

func delete_conversation(path: String):
	delete_path = path
	%ConfirmDelete.dialog_text = 'Really delete conversation "' + path.get_file() + '" ?\n'
	var nodes = Skein.load_conversation(path, {}).values()
	nodes.sort_custom(sort)
	var line_count = 0
	for i in range(nodes.size()):
		var count = nodes[i].text.split('\n').size()
		line_count += count
		if i < 5:
			%ConfirmDelete.dialog_text += ' - %s [%s lines]\n' % [nodes[i].name, count]
		if i == 5:
			%ConfirmDelete.dialog_text += 'plus ' + str(nodes.size() - i) + ' more..'
	if nodes.size() > 10 or line_count > 25:
		var ok_btn = %ConfirmDelete.get_ok_button()
		ok_btn.disabled = true
		ok_btn.text = '3..'
		get_tree().create_timer(1.0).timeout.connect(ok_btn.set_text.bind('2..'))
		get_tree().create_timer(2.0).timeout.connect(ok_btn.set_text.bind('1..'))
		get_tree().create_timer(3.0).timeout.connect(ok_btn.set_text.bind('Ok'))
		get_tree().create_timer(3.0).timeout.connect(ok_btn.set_disabled.bind([false]))
	%ConfirmDelete.popup_centered()
	%ConfirmDelete.size.y = 0
	%ConfirmationDimmer.show()

func really_delete_conversation():
	pass
	# if current_conversation == delete_path:
	# 	%GraphEdit.clear()
	# 	current_conversation = ''
	# editor_data.erase(delete_path)
	# save_editor_data()
	# if delete_path.begins_with(Skein.Files.prefix):
	# 	DirAccess.remove_at(delete_path)
	# if delete_path in Skein.conversations:
	# 	DirAccess.remove_at(Skein.conversations[delete_path])
	# Skein.refresh()

func rename_conversation(old: String, new: String):
	old = Skein.ensure_prefix(old)
	new = Skein.ensure_prefix(new)

	if current_conversation == old:
		%GraphEdit.clear()
		current_conversation = ''
	if old in editor_data:
		editor_data[new] = editor_data[old]
		editor_data.erase(old)
	save_editor_data()
	var dir := DirAccess.open(Skein.Files.conversation_prefix)
	dir.rename(old, new)
	load_conversation(new)
	Skein.refresh()

func focus_node(path: String):
	var _path = path.trim_prefix(Skein.Files.conversation_prefix)
	var parts = _path.split(':')
	if parts[0] != current_conversation:
		save_conversation()
		save_editor_data()
		load_conversation(parts[0])
	if len(parts) > 1:
		%GraphEdit.focus_node(parts[1])

func node_selected(node):
	var path = current_conversation + '/' + node.data.name
	%Tree.select_item(path)

func node_deleted(id: String):
	%Tree.delete_item(id)
	save()

func node_renamed(old: String, new: String):
	%Tree.refresh()

func node_created(node):
	%Tree.refresh()

func select_card(path: String):
	prints('select_card', path)
	# %GraphEdit

# ******************************************************************************

func character_added(path: String):
	var char_map = Skein.Files.load_json(Skein.character_map_path, {})
	var c = load(path).instantiate()
	char_map[c.name] = path
	Skein.Files.save_json(Skein.character_map_path, char_map)
	Skein.refresh()

# ******************************************************************************

func run():
	Skein.load_characters()
	var selection = %GraphEdit.get_selected_nodes()

	var conversation = current_conversation
	var entry = ''
	if selection.size() == 1:
		var node = selection[0]
		entry = str(node.name)
	else:
		for node in %GraphEdit.nodes.values():
			if node.data.default:
				entry = str(node.name)

	if entry:
		conversation += ':' + entry
	save_conversation()
	save_editor_data()
	$Preview.show()

	DialogBox.start(conversation, {exec=false})

func stop():
	DialogBox.stop()
	dismiss_preview()

func dismiss_preview():
	$Preview.hide()
	%GraphEdit.unhighlight_all_nodes()

func next():
	DialogBox.next_line()

func line_started(id: String, line_number: int):
	var node = %GraphEdit.get_graphnode(id)
	if node and node.has_method('highlight_line'):
		node.highlight_line(line_number)

func node_started(id: String):
	%GraphEdit.focus_node(id)
	%GraphEdit.highlight_node(id)

# ******************************************************************************

var editor_data_file_name = 'user://skein/editor_data.json'

func save_editor_data():
	if current_conversation == '':
		return
	var data = Skein.Files.load_json(editor_data_file_name, {})
	if !(location in data):
		data[location] = {
			'conversation_data': {}
		}
	
	data[location]['folder_state'] = %Tree.folder_state
	data[location]['current_conversation'] = current_conversation
	# data[location]['font_size'] = theme.default_font.size
	data[location]['left_panel_size'] = %LeftPanelSplit.split_offset
	data[location]['left_panel_collapsed'] = %LeftSidebar.visible
	data[location]['right_panel_size'] = %RightPanelSplit.split_offset
	data[location]['right_panel_collapsed'] = %RightSidebar.visible
	data[location]['conversation_data'][current_conversation] = %GraphEdit.get_data()
	Skein.Files.save_json(editor_data_file_name, data)

func load_editor_data():
	var data = Skein.Files.load_json(editor_data_file_name, {})
	if data == {} or !(location in data):
		editor_data['current_conversation'] = '0 Introduction'
		load_conversation(editor_data['current_conversation'])
		return
	editor_data = data[location]

	if 'folder_state' in editor_data:
		%Tree.folder_state = editor_data['folder_state']
	if 'current_conversation' in editor_data:
		load_conversation(editor_data['current_conversation'])

	# if 'font_size' in editor_data:
	# 	theme.default_font.size = editor_data['font_size']

	if 'left_panel_size' in editor_data:
		%LeftPanelSplit.split_offset = editor_data['left_panel_size']
	if 'left_panel_collapsed' in editor_data:
		%LeftSidebar.visible = editor_data['left_panel_collapsed']

	if 'right_panel_size' in editor_data:
		%RightPanelSplit.split_offset = editor_data['right_panel_size']
	if 'right_panel_collapsed' in editor_data:
		%RightSidebar.visible = editor_data['right_panel_collapsed']
