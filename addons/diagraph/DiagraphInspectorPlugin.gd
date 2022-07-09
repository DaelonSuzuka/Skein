tool
extends EditorInspectorPlugin

# ******************************************************************************

var plugin: EditorPlugin = null

# ******************************************************************************

var selected_object: Node
var ep = null
var select_button = null
var edit_button = null

func can_handle(object):
	selected_object = null
	return object is Node and object.get('conversation') != null

func parse_property(object, type, path, hint, hint_text, usage) -> bool:
	if path == 'conversation':
		selected_object = object
		add_control()

	return false

func add_control():
	ep = EditorProperty.new()
	var hbox = HBox.new()

	select_button = hbox.add(Button.new())
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_button.text = 'Select'
	select_button.connect('pressed', self, 'select_conversation')

	edit_button = hbox.add(Button.new())
	edit_button.text = 'Show'
	edit_button.connect('pressed', self, 'open_conversation')

	ep.add_child(hbox)
	ep.label = 'Conversation'

	add_custom_control(ep)

var selector = null
var tree = null
var root = null

func select_conversation():
	if selector:
		selector.queue_free()
		selector = null
		tree = null
		root = null

	selector = ConfirmationDialog.new()
	selector.window_title = 'Select a Conversation'

	tree = load('res://addons/diagraph/editor/Tree.gd').new()
	tree.anchor_right = 1.0
	tree.anchor_bottom = 1.0
	selector.add_child(tree)
	tree.refresh()

	plugin.get_editor_interface().get_editor_viewport().add_child(selector)
	selector.get_ok().connect('pressed', self, 'accepted')
	selector.popup_centered(Vector2(1000, 985))

func accepted():
	var item = tree.get_selected()
	var type = item.get_meta('type')
	var path = item.get_meta('path')
	path = path.trim_prefix(Diagraph.conversation_prefix)
	match type:
			'file':
				selected_object.conversation = path
				selected_object.entry = ''
			'folder':
				pass
			'node':
				var parts = path.split(':')
				selected_object.conversation = parts[0]
				selected_object.entry = parts[1]
				var node = item.get_meta('node')
				if node.name != node.type:
					selected_object.entry = node.name

	plugin.get_editor_interface().get_inspector().refresh()

func open_conversation():
	var obj = selected_object
	var convo = '%s:%s:%d' % [obj.conversation, obj.entry, obj.line]
	plugin.show_conversation(convo)

# ******************************************************************************
# Custom container classes

class HBox:
	extends HBoxContainer

	func add(object):
		add_child(object)
		return object
