extends CanvasLayer

# ******************************************************************************

func _ready():
	for child in get_children():
		child.hide()

# help method for connecting signals
func try_connect(src, sig, dest, method, args=[], flags=0):
	if dest.has_method(method):
		if !src.is_connected(sig, dest, method):
			src.connect(sig, dest, method, args, flags)

# ******************************************************************************
# popup handler

var _popups = {}

func _process(delta):
	for popup in _popups:
		var object = _popups[popup]
		if is_instance_valid(object):
			var pos = object.get_global_transform_with_canvas().origin
			if object.get('tooltip_offset'):
				pos.y += object.tooltip_offset
			popup.rect_position = pos

func _register_popup(popup, object):
	add_child(popup)
	_popups[popup] = object

func popup_dialog(object, conversation, options={}):
	var popup = load('res://addons/diagraph/dialog_box/PopupDialogBox.tscn').instance()
	_register_popup(popup, object)
	options['caller'] = object
	popup.start(conversation, options)

	popup.connect("done", self, '_popup_over')

	try_connect(popup, 'line_finished', object, 'line_finished')
	try_connect(popup, 'done', object, 'popup_over')

	return popup

func _popup_over(popup=null):
	if popup:
		_popups.erase(popup)
		remove_child(popup)
		popup.queue_free()

# ******************************************************************************

func start_dialog(object, conversation, options={}):
	var dialog = get_node('DialogBox')
	options['caller'] = object
	dialog.start(conversation, options)

	dialog.connect('done', Diagraph.sandbox, 'clear_temp_locals', [], CONNECT_ONESHOT)
	
	try_connect(dialog, 'line_finished', object, 'line_finished')
	try_connect(dialog, 'done', object, 'done', [], CONNECT_ONESHOT)

	return dialog
