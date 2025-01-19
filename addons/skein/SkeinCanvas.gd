extends CanvasLayer

# ******************************************************************************

func _ready():
	for child in get_children():
		child.hide()

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
			popup.position = pos

func _register_popup(popup, object):
	add_child(popup)
	_popups[popup] = object

func popup_dialog(object, conversation, options={}):
	var popup = load('res://addons/skein/dialog_box/PopupDialogBox.tscn').instantiate()
	_register_popup(popup, object)
	options['caller'] = object
	popup.start(conversation, options)

	popup.connect("done", Callable(self,'_popup_over'))

	# Skein.Utils.try_connect(popup, Callable('line_finished',object).bind('line_finished'))
	# Skein.Utils.try_connect(popup, Callable('done',object).bind('popup_over'))

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

	dialog.done.connect(Skein.Sandbox.clear_temp_locals ,CONNECT_ONE_SHOT)
	
	# TODO disconnect this when done?
	# Skein.Utils.try_connect(dialog, Callable('line_finished',object).bind('line_finished'))
	# Skein.Utils.try_connect(dialog, Callable('done',object).bind('done'),[],CONNECT_ONE_SHOT)

	return dialog
