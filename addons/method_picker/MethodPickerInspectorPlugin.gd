@tool
extends EditorInspectorPlugin

# ******************************************************************************

var plugin: EditorPlugin = null

var selected_object: Node

func _can_handle(object: Object):
	selected_object = null
	return true

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if hint_string == 'MethodPickerTarget':
		print('got target')

		var ep = EditorProperty.new()
		var vbox = VBox.new(ep)

		var target: LineEdit = vbox.add(LineEdit.new())
		target.placeholder_text = 'target'
		var method: LineEdit = vbox.add(LineEdit.new())
		method.placeholder_text = 'method'
		var args: LineEdit = vbox.add(LineEdit.new())
		args.placeholder_text = 'args'

		ep.label = name
		add_custom_control(ep)

		return true
		
	return false

# ******************************************************************************
# Custom container classes

class HBox:
	extends HBoxContainer

	func _init(parent=null):
		if parent:
			parent.add_child(self)

	func add(object):
		add_child(object)
		return object

class VBox:
	extends VBoxContainer

	func _init(parent=null):
		if parent:
			parent.add_child(self)

	func add(object):
		add_child(object)
		return object
