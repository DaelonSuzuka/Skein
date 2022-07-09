tool
extends MenuButton

# ******************************************************************************

onready var popup: PopupMenu = get_popup()
var callbacks := {}

signal item_selected(item)

# ******************************************************************************

func _ready() -> void:
	popup.clear()
	for child in popup.get_children():
		child.queue_free()
	popup.connect('index_pressed', self, '_on_index_pressed')

func create_submenu(label: String, submenu_name: String) -> PopupMenu:
	var submenu: PopupMenu = PopupMenu.new()
	submenu.name = submenu_name
	submenu.connect('index_pressed', self, '_on_index_pressed', [submenu_name])
	popup.add_child(submenu)
	popup.add_submenu_item(label, submenu_name)
	return submenu

func add_item(label: String, cb:=[]) -> void:
	popup.add_item(label)

	if cb:
		callbacks[label] = cb

func add_check_item(label: String, cb:=[]):
	popup.add_check_item(label)

	if cb:
		callbacks[label] = cb

func set_item_checked(item_text, state):
	for i in popup.get_item_count():
		if popup.get_item_text(i) == item_text:
			if popup.is_item_checked(i) != state:
				popup.toggle_item_checked(i)
				return

func add_submenu_item(label: String, submenu_name: String, cb:=[]) -> void:
	var submenu: PopupMenu = popup.get_node(submenu_name)
	submenu.add_item(label)

	if cb:
		callbacks[submenu_name + '/' + label] = cb

func _on_index_pressed(idx: int, submenu_name:='') -> void:
	var menu = popup
	var item = ''
	if submenu_name:
		menu = popup.get_node(submenu_name)
		item += menu.name + '/'
	item += menu.get_item_text(idx)

	if item in callbacks:
		var cb = callbacks[item]
		var obj = cb[0]
		var method = cb[1]
		if obj.has_method(method):
			if menu.is_item_checkable(idx):
				menu.toggle_item_checked(idx)
				var checked = menu.is_item_checked(idx)
				if len(cb) == 2:
					obj.call(method, checked)
				if len(cb) == 3:
					obj.call(method, checked, cb[2])
			else:
				if len(cb) == 2:
					obj.call(method)
				if len(cb) == 3:
					obj.call(method, cb[2])

	emit_signal('item_selected', item)
