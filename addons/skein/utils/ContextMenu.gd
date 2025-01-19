@tool
extends PopupMenu

# ******************************************************************************

signal item_selected(item)

# ******************************************************************************

func _init(obj=null, cb=null, arg1=null, arg2=null):
	# set_hide_on_window_lose_focus(true)

	if obj:
		obj.add_child(self)

	# if cb != null:
	# 	item_selected.connect(cb)

	var args = []
	if arg1:
		args.append(arg1)
	if arg2:
		args.append(arg2)

	index_pressed.connect(self._on_index_pressed.bind(args))

func open(pos=null):
	if pos:
		position = pos
	popup()

func _on_index_pressed(idx, args=[]):
	var item = get_item_text(idx)
	if args:
		emit_signal('item_selected', item, args)
	else:
		emit_signal('item_selected', item)
