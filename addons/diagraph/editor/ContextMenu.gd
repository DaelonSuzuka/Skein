extends PopupMenu

# ******************************************************************************

var node_types = [
	'Entry',
	'Exit',
	'Speech',
	'Branch',
	'Jump',
]

# ******************************************************************************

func _ready():
	connect('index_pressed', self, 'context_menu_item_pressed')

signal create_node(type)

# ******************************************************************************

var context_menu_event = null
var context_menu_active = false

func add_metadata(metadata):
	set_item_metadata(get_item_count() - 1, metadata)

func show_context_menu(event):
	context_menu_event = event
	clear()
	rect_size.y = 0

	add_separator('New Node:')
	for type in node_types:
		add_item(type)

	rect_position = event.position + Vector2(6, 6)
	context_menu_active = true
	popup()

func context_menu_item_pressed(index):
	if context_menu_active:
		context_menu_active = false
		var item = get_item_text(index)
		
		if item in node_types:
			emit_signal('create_node', item.to_lower())
