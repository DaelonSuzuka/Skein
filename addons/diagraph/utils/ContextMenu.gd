tool
extends PopupMenu

# ******************************************************************************

signal item_selected(item)

# ******************************************************************************

func _init(obj=null, cb=null):
	set_hide_on_window_lose_focus(true)

	if obj:
		obj.add_child(self)

	if obj and cb:
		connect('item_selected', obj, cb)

	connect('index_pressed', self, '_on_index_pressed')

func open(pos=null):
	if pos:
		rect_position = pos
	popup()

func _on_index_pressed(idx):
	var item = get_item_text(idx)
	emit_signal('item_selected', item)
