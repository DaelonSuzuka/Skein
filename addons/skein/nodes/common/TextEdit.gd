@tool
extends TextEdit

# ******************************************************************************

# func _ready():
# 	request_completion.connect(self.request_completion)

func request_completion():
	print('request_completion')

# ******************************************************************************
# internal helpers

func get_selection():
	var selection = {
		cur_line = get_caret_line(),
		cur_col = get_caret_column(),
		active = has_selection(),
		from_line = 0,
		from_col = 0,
		to_line = 0,
		to_col = 0,
	}
	if selection.active:
		selection.from_line = get_selection_from_line()
		selection.from_col = get_selection_from_column()
		selection.to_line = get_selection_to_line()
		selection.to_col = get_selection_to_column()
	return selection

func set_selection(sel):
	if sel.active:
		select(sel.from_line, sel.from_col, sel.to_line, sel.to_col)
	set_cursor(sel.cur_line, sel.cur_col)

func set_cursor(line, col):
	set_caret_line(line)
	set_caret_column(col)

func insert_text_at(_text, line, col):
	set_cursor(line, col)
	insert_text_at_caret(_text)

# ******************************************************************************

func surround_selection(start, end):
	var sel = get_selection()
	var lines = text.split('\n')

	lines[sel.from_line] = lines[sel.from_line].insert(sel.from_col, start)
	lines[sel.to_line] = lines[sel.to_line].insert(sel.to_col + 1, end)

	text = '\n'.join(lines)
	sel.from_col += 1
	sel.to_col += 1
	sel.cur_col += 1
	set_selection(sel)

var wrappers = {
	'{'.unicode_at(0): ['{', '}'],
	'['.unicode_at(0): ['[', ']'],
	'<'.unicode_at(0): ['<', '>'],
	'('.unicode_at(0): ['(', ')'],
	'|'.unicode_at(0): ['|', '|'],
	'"'.unicode_at(0): ['"', '"'],
	"'".unicode_at(0): ["'", "'"],
}

# ------------------------------------------------------------------------------

func move_line(direction):
	var sel = get_selection()
	var lines = Array(text.split('\n'))

	var target_lines = []
	if has_selection():
		for i in range(sel.from_line, sel.to_line + 1):
			target_lines.append(i)
	else:
		target_lines.append(sel.cur_line)

	var line_above = target_lines.front() - 1
	var line_below = target_lines.back() + 1

	if direction == -1:
		if target_lines.front() == 0:
			return
		lines.insert(line_below, lines[line_above])
		lines.pop_at(line_above)
	if direction == 1:
		if target_lines.back() == lines.size() - 1:
			return
		lines.insert(line_above + 1, lines[line_below])
		lines.pop_at(line_below + 1)

	text = '\n'.join(PackedStringArray(lines))

	sel.from_line += direction
	sel.to_line += direction
	sel.cur_line += direction

	set_selection(sel)

# ------------------------------------------------------------------------------

func copy_line(direction):
	var sel = get_selection()
	var lines = Array(text.split('\n'))

	var target_lines = []
	if has_selection():
		for i in range(sel.from_line, sel.to_line + 1):
			target_lines.append(i)
	else:
		target_lines.append(sel.cur_line)

	var line_above = target_lines.front() - 1
	var line_below = target_lines.back() + 1

	if direction == -1:
		for i in range(target_lines.size()):
			lines.insert(line_below + i, lines[target_lines[i]])
	if direction == 1:
		for i in range(target_lines.size()):
			lines.insert(line_above + 1 + i, lines[target_lines[i] + i])

	text = '\n'.join(PackedStringArray(lines))

	sel.from_line += direction * target_lines.size()
	sel.to_line += direction * target_lines.size()
	sel.cur_line += direction * target_lines.size() if direction == 1 else 0

	set_selection(sel)

# ------------------------------------------------------------------------------

func toggle_comment():
	var sel = get_selection()
	var lines = Array(text.split('\n'))

	var target_lines = []
	if has_selection():
		for i in range(sel.from_line, sel.to_line + 1):
			target_lines.append(i)
	else:
		target_lines.append(sel.cur_line)

	var comment = true
	if lines[target_lines[0]].lstrip(' \t').begins_with('#'):
		comment = false

	for line in target_lines:
		if comment:
			lines[line] = '# ' + lines[line]
		else:
			lines[line] = lines[line].trim_prefix('# ').trim_prefix('#')
			lines[line] = lines[line].trim_prefix('// ').trim_prefix('//')
	
	text = '\n'.join(PackedStringArray(lines))
	set_selection(sel)

# ******************************************************************************

func _input(event):
	if !visible or !has_focus():
		return
	if !(event is InputEventKey) or !event.pressed:
		return

	if event.as_text() == 'Shift+Alt+Up':
		copy_line(-1)
		accept_event()
		return
	if event.as_text() == 'Shift+Alt+Down':
		copy_line(1)
		accept_event()
		return
	if event.as_text() == 'Alt+Up':
		move_line(-1)
		accept_event()
		return
	if event.as_text() == 'Alt+Down':
		move_line(1)
		accept_event()
		return

	if event.as_text() in ['Control+Q', 'Control+/']:
		toggle_comment()
		accept_event()
		return

	if has_selection() and event.unicode in wrappers:
		var wrap = wrappers[event.unicode]
		surround_selection(wrap[0], wrap[1])
		accept_event()
		return

# ******************************************************************************

func refresh_colors():
	pass
	# clear_colors()

	# add_color_region('#', '', Color.FOREST_GREEN, true)
	# add_color_region('//', '', Color.FOREST_GREEN, true)

	# for name in Skein.characters:
	# 	if Skein.characters[name].get('color'):
	# 		add_keyword_color(name, Skein.characters[name].color)

	# add_color_region('{', '}', Color.GREEN)
	# add_color_region('<', '>', Color.DODGER_BLUE)
	# add_color_region('[', ']', Color.YELLOW)
	# add_color_region('(', ')', Color.ORANGE)
	# add_color_region('"', '"', Color.RED)
