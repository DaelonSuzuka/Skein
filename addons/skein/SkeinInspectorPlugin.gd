@tool
extends EditorInspectorPlugin
class_name SkeinInspector

# ******************************************************************************

var plugin: EditorPlugin = null

# ******************************************************************************

func _can_handle(object):
	return true

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if hint_string == 'SkeinConversation':
		var prop = CustomProperty.new(object, name)

		prop.select.pressed.connect(self.select_conversation.bind(prop))
		prop.show.pressed.connect(self.open_conversation.bind(prop))

		add_property_editor(name, prop)
		return true

	return false

class CustomProperty:
	extends EditorProperty

	var hbox := HBox.new(self)
	var selection: Label = hbox.add(Label.new())
	var select: Button = hbox.add(Button.new())
	var show: Button = hbox.add(Button.new())

	func _init(object: Object, name: String) -> void:
		label = name
		set_object_and_property(object, name)

	func _ready():
		selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select.tooltip_text = 'Select Conversation'
		select.flat = true
		select.icon = preload('./resources/folder_tree.svg')
		show.tooltip_text = 'Show Selected Conversation'
		show.flat = true
		show.icon = preload('./resources/magnifying_glass.svg')
		show.disabled = true

	func update_selection(value: SkeinConversation):
		if value == null:
			show.disabled = true
			selection.text = ''
		if value is SkeinConversation:
			show.disabled = false
			selection.text = value.make_path()

	func set_value(value: SkeinConversation):
		update_selection(value)
		get_edited_object().set(get_edited_property(), value)
		
	func get_value() -> SkeinConversation:
		return get_edited_object().get(get_edited_property())

	func _update_property() -> void:
		var value = get_value()
		update_selection(value)
		emit_changed(get_edited_property(), value)
		
var selector = null
var tree = null
var root = null

func select_conversation(prop: CustomProperty):
	if selector:
		selector.queue_free()
		selector = null
		tree = null
		root = null

	selector = ConfirmationDialog.new()
	selector.title = 'Select a Conversation'

	tree = load('res://addons/skein/editor/Tree.gd').new()
	tree.anchor_right = 1.0
	tree.anchor_bottom = 1.0
	selector.add_child(tree)
	tree.refresh()

	# tree.item_activated.connect(self.accepted.bind(prop))

	plugin.get_editor_interface().get_editor_main_screen().add_child(selector)
	selector.get_ok_button().pressed.connect(self.accepted.bind(prop))
	selector.popup_centered(Vector2(1000, 985))

func accepted(prop: CustomProperty):
	var item = tree.get_selected()
	var path = item.get_meta('path')

	match item.get_meta('type'):
		'file':
			var convo = SkeinConversation.new()
			convo.file = path
			prop.set_value(convo)
		'folder':
			return
		'node':
			var convo = SkeinConversation.new()
			var parts = path.split(':')
			convo.file = parts[0]

			var node = item.get_meta('node')
			if node.name.to_lower() != node.type.to_lower():
				convo.node = node.name
			else:
				convo.node = node.id
			
			prop.set_value(convo)

	selector.hide()

func open_conversation(prop: CustomProperty):
	var conv := prop.get_value()
	if conv == null:
		return

	prints('open_conversation', conv, conv.make_path())

	plugin.show_conversation(conv.make_path())

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
