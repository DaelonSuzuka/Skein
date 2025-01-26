@tool
extends EditorInspectorPlugin

# ******************************************************************************

var plugin: EditorPlugin = null

# ******************************************************************************

func _can_handle(object):
	return true

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if hint_string == 'SkeinConversation':
		
		var prop = CustomProperty.new(object, name)

		prop.select.pressed.connect(self.select_conversation.bind(prop))
		prop.edit.pressed.connect(self.open_conversation.bind(prop))

		add_property_editor(name, prop)
		return true

	return false

class CustomProperty:
	extends EditorProperty

	var hbox := HBox.new(self)
	var selection: Label = hbox.add(Label.new())
	var select: Button = hbox.add(Button.new())
	var edit: Button = hbox.add(Button.new())

	func _init(object: Object, name: String) -> void:
		label = name
		set_object_and_property(object, name)

	func _ready():
		selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select.tooltip_text = 'Select Conversation'
		edit.tooltip_text = 'Show Selected Conversation'
		select.icon = preload('./resources/folder_tree.svg')
		edit.icon = preload('./resources/magnifying_glass.svg')

	func update_selection(value: SkeinConversation):
		if value == null:
			selection.text = ''
		if value is SkeinConversation:
			selection.text = value.path

	func set_value(value: SkeinConversation):
		update_selection(value)
		get_edited_object().set(get_edited_property(), value)
		
	func get_value():
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

	tree.item_activated.connect(self.accepted.bind(prop))

	plugin.get_editor_interface().get_editor_main_screen().add_child(selector)
	selector.get_ok_button().pressed.connect(self.accepted.bind(prop))
	selector.popup_centered(Vector2(1000, 985))

func accepted(prop: CustomProperty):
	var item = tree.get_selected()
	var path = item.get_meta('path')
	path = path.trim_prefix(Skein.Files.conversation_prefix)

	match item.get_meta('type'):
		'file':
			var convo = SkeinConversation.new()
			convo.path = path.replace('.yarn', '')
			prop.set_value(convo)
		'folder':
			return
		'node':
			var parts = path.split(':')
			var value = parts[0].replace('.yarn', '')

			var node = item.get_meta('node')
			if node.name.to_lower() != node.type.to_lower():
				value += ':' + node.name
			else:
				value += ':' + node.id
			
			var convo = SkeinConversation.new()
			convo.path = value
			prop.set_value(convo)

	selector.hide()

func open_conversation(prop: CustomProperty):
	prints('open_conversation', prop.get_value())
	pass

	# plugin.show_conversation(prop.get_value())

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
