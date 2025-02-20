@tool
extends PopupMenu
class_name SkeinContextMenu

# ******************************************************************************

var callbacks = {}

signal item_selected(item: String)

# ******************************************************************************

func _init(obj=null, cb=null):
	if obj:
		obj.add_child(self)

	if cb != null:
		item_selected.connect(cb)

	index_pressed.connect(self._on_index_pressed)

func open(pos=null):
	if pos:
		position = pos
	popup()

func _on_index_pressed(idx: int):
	var label = get_item_text(idx)

	if label in callbacks:
		callbacks[label].call()

	item_selected.emit(label)

func item(label: String, cb=null):
	add_item(label)
	if cb:
		callbacks[label] = cb

func check_item(label: String, checked:=false, cb=null):
	add_check_item(label)
	set_item_checked(0, checked)

	if cb:
		callbacks[label] = cb
