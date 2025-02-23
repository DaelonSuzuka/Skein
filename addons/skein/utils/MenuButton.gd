@tool
extends MenuButton

# ******************************************************************************

@onready var popup: PopupMenu = get_popup()

var callbacks := {}

signal item_selected(item: String)

# ******************************************************************************

func _ready() -> void:
	popup.clear()
	for child in popup.get_children():
		child.queue_free()
	popup.index_pressed.connect(self._on_index_pressed)

class Submenu:
	extends PopupMenu
	var parent = null
	var menu = null

	func _init(_parent, _menu):
		parent = _parent
		menu = _menu
		
	func item(label: String, cb=null):
		add_item(label)
		if cb:
			parent.callbacks[self.name + '/' + label] = cb

	func check_item(label: String, checked:=false, cb=null):
		add_check_item(label)
		set_item_checked(item_count, checked)
		if cb:
			parent.callbacks[self.name + '/' + label] = cb

func submenu(label: String) -> Submenu:
	var submenu := Submenu.new(self, popup)
	popup.add_child(submenu)
	popup.add_submenu_item(label, submenu.name)
	submenu.index_pressed.connect(self._on_index_pressed.bind(submenu.name))
	return submenu

func item(label: String, cb=null) -> void:
	popup.add_item(label)
	if cb:
		callbacks[label] = cb

func check_item(label: String, checked:=false, cb=null) -> void:
	popup.add_check_item(label)
	popup.set_item_checked(item_count - 1, checked)
	if cb:
		callbacks[label] = cb

func _on_index_pressed(idx: int, submenu: Submenu = null) -> void:
	var menu = popup
	var item = ''
	if submenu:
		menu = submenu
		item += submenu.name + '/'
	item += menu.get_item_text(idx)

	item_selected.emit(item)
	
	if menu.is_item_checkable(idx):
		menu.toggle_item_checked(idx)

	if item in callbacks:
		if menu.is_item_checkable(idx):
			var checked = menu.is_item_checked(idx)
			callbacks[item].call(checked)
		else:
			callbacks[item].call()
