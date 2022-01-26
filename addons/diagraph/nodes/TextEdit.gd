tool
extends TextEdit

# ******************************************************************************

func _ready():
	connect('request_completion', self, 'request_completion')

func request_completion():
	print('request_completion')

# ******************************************************************************

func get_selection():
	var selection = {
		cur_line = cursor_get_line(),
		cur_col = cursor_get_column(),
		from_line = get_selection_from_line(),
		from_col = get_selection_from_column(),
		to_line = get_selection_to_line(),
		to_col = get_selection_to_column(),
	}
	return selection

func set_cursor(line, col):
	cursor_set_line(line)
	cursor_set_column(col)

func insert_text_at(_text, line, col):
	set_cursor(line, col)
	insert_text_at_cursor(_text)

func surround_selection(start, end):
	var sel = get_selection()
	deselect()
	insert_text_at(start, sel.from_line, sel.from_col)
	insert_text_at(end, sel.to_line + 1, sel.to_col + 1)
	select(sel.from_line + 1, sel.from_col + 1, sel.to_line + 1, sel.to_col + 1)
	set_cursor(sel.cur_line + 1, sel.cur_col + 1)

var wrappers = {
	ord('{'): ['{', '}'],
	ord('['): ['[', ']'],
	ord('<'): ['<', '>'],
	ord('('): ['(', ')'],
	ord('|'): ['|', '|'],
}

func _input(event):
	if !visible or !has_focus():
		return
	if !(event is InputEventKey) or !event.pressed:
		return
	if !is_selection_active():
		return

	if event.unicode in wrappers:
		var wrap = wrappers[event.unicode]
		surround_selection(wrap[0], wrap[1])
		accept_event()

# ******************************************************************************

func refresh_colors():
	clear_colors()

	add_color_region('#', '', Color.forestgreen, true)

	for name in Diagraph.characters:
		if Diagraph.characters[name].get('color'):
			add_keyword_color(name, Diagraph.characters[name].color)

	# add_color_region('{', '}', Color.green)
	# add_color_region('<', '>', Color.dodgerblue)
	# add_color_region('[', ']', Color.yellow)
	# add_color_region('(', ')', Color.orange)
	# add_color_region('"', '"', Color.red)
