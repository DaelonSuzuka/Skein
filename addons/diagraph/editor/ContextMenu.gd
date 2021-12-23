extends PopupMenu

# ******************************************************************************

var graph

func _ready():
	connect('index_pressed', self, 'context_menu_item_pressed')

# ******************************************************************************

var context_menu_event = null
var context_menu_active = false

func add_metadata(metadata):
	set_item_metadata(get_item_count() - 1, metadata)

func show_context_menu(event):
	context_menu_event = event
	clear()
	rect_size.y = 0

	add_item('New Node')
	add_item('Test2')
	add_item('Test3')

	rect_position = event.position + Vector2(6, 6)
	context_menu_active = true
	popup()


func context_menu_item_pressed(index):
	if context_menu_active:
		context_menu_active = false
		var item = get_item_text(index)

		match item:
			'New Node':
				var node = graph.create_node()
				node.offset = graph.get_offset_from_mouse()
				return