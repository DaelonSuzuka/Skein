@tool
extends Control

# ******************************************************************************

signal done
signal line_finished
signal character_added(c)
signal line_started(id, line_number)
signal node_started(id)
signal yielded
signal resumed

signal actor_joined(actor)
signal actor_left(actor) # unimplemented

signal speaker_changed(new_speaker, prev_speaker)

# ******************************************************************************

@export var option_button_path = 'res://addons/diagraph/dialog_box/BaseOptionButton.tscn' # (String, FILE, '*.tscn,*.scn')
@onready var option_button = load(option_button_path)

# ------------------------------------------------------------------------------

class DialogTimer extends Timer:
	func _init(obj,method):
		connect('timeout', Callable(obj,method))
		one_shot = true
		obj.call_deferred('add_child', self)

@onready var text_timer := DialogTimer.new(self, 'next_char')
@onready var dismiss_timer := DialogTimer.new(self, 'next_line')

# ------------------------------------------------------------------------------

# mandatory nodes
@onready var name_box = find_child('Name')
@onready var next_indicator = find_child('Next')
@onready var text_box = find_child('TextBox')
@onready var options_container = find_child('Options')
@onready var portrait_container = find_child('Portrait')

# possibly optional nodes
@onready var name_box_outline = find_child('NameOutline')
@onready var text_box_outline = find_child('TextBoxOutline')

# configurable settings
@export var primary_action := 'ui_accept'
@export var secondary_action  := 'ui_cancel'
@export var direct_input := true
@export var text_cooldown := 0.05

# ******************************************************************************

# internal state 
var next_char_cooldown := text_cooldown
var waiting_for_choice := false
var active := false
var yielding := false

# ******************************************************************************

# input handling shim
func _input(event):
	if direct_input:
		handle_input(event)

func handle_input(event):
	if !visible or !active or waiting_for_choice:
		return

	if event.is_action(primary_action) and event.pressed:
		if event is InputEvent:
			accept_event()
		next_line()

	if event.is_action(secondary_action) and event.pressed:
		if event is InputEvent:
			accept_event()
		# do secondary input things

# ******************************************************************************

func add_option(option, value=null):
	var button = option_button.instantiate()

	var arg = value if value else option
	button.connect('pressed', Callable(self,'option_selected').bind(arg))
	button.text = option

	options_container.add_child(button)
	return button

func remove_options() -> void:
	for child in options_container.get_children():
		if child is Button:
			child.queue_free()

# ******************************************************************************

var current_speaker = null
var previous_speaker = null

func character_talk(c):
	if current_speaker and current_speaker.has_method('talk'):
		current_speaker.talk(c)

func character_idle():
	if current_speaker and current_speaker.has_method('idle'):
		current_speaker.idle()

# ******************************************************************************
# utils

func strip_name(text):
	return text.split(':', true, 1)[1].trim_prefix(':').trim_prefix(' ')

func split_text(text):
	var parts = text.split('\n')

	# text preprocess stages
	parts = preprocess_random_lines(parts)

	return parts

func preprocess_random_lines(lines):
	var output = []
	var choices = []

	for line in lines:
		if line.begins_with('%'):
			choices.append(line)
		else:
			if choices:
				line = choices[randi() % choices.size() - 1].lstrip('% ')
				choices = []
			output.append(line)
	
	# required in case last line is %random
	if choices:
		line = choices[randi() % choices.size() - 1].lstrip('% ')
		output.append(line)

	return output

func change_outline_color(color):
	if name_box_outline:
		name_box_outline.modulate = color
	if text_box_outline:
		text_box_outline.modulate = color

# ******************************************************************************

var nodes := {}
var current_node = null
var current_line := 0
var current_data := {}
var continue_previous_line := false
var caller: Node = null
var line_count := 0
var length := -1
var popup := false
var popup_timeout := 1.0
var exec := true
var assignment := true
var show_name := true
var name_override = null
var color_override = null
var show_portrait := true
var speed := 1.0

func start(conversation, options={}):
	# reset stuff
	var entry = ''
	var line_number = 0
	name_override = null
	active = true
	caller = null
	next_indicator.visible = false
	change_outline_color(Color.WHITE)
	remove_options()

	# parse conversation string
	conversation = conversation.trim_prefix(Diagraph.prefix)

	var parts = conversation.split(':')
	if parts.size() >= 2:
		entry = parts[1]
	if parts.size() >= 3:
		line_number = int(parts[2])

	nodes = Diagraph.load_conversation(conversation, {}).duplicate(true)

	if nodes.size() == 0:
		push_error('loading conversation "%s"failed: is this a real conversation?' % [conversation])
		return

	# identify starting node
	current_node = null
	if entry:
		for node in nodes.values():
			if node.name == entry:
				current_node = str(node.id)
		if !current_node:
			current_node = entry
	else:
		current_node = nodes.keys()[0]
		for node in nodes.values():
			if node.get('default', false):
				current_node = str(node.id)

	# set up initial data
	set_node(current_node)
	if line_number == -1 or line_number > current_data.lines.size():
		current_line = current_data.lines.size() - 1

	# parse options
	if 'caller' in options:
		caller = options.caller

	apply_directive(options)

	if 'popup' in options:
		popup = true
		popup_timeout = options.popup

	length = -1
	if 'length' in options:
		length = options.length
	if 'len' in options:
		length = options.len

	next_line()
	show()

func _resume():
	emit_signal('resumed')

func _yield(object=null, sig="nothing"):
	# TODO: make this not explode without args
	active = false
	yielding = true
	text_timer.paused = true
	emit_signal('yielded')

	object.connect(sig, Callable(self,'_resume').bind(),CONNECT_ONE_SHOT)

	await self.resumed

	text_timer.paused = false
	active = true
	yielding = false

func stop():
	active = false
	hide()
	remove_options()
	emit_signal('done')

# ******************************************************************************

func get_id() -> int:
	var id = randi()
	if str(id) in nodes:
		id = get_id()
	return id

func set_node(next_node):
	if next_node in nodes:
		current_node = next_node
	else:
		for node in nodes:
			if next_node == nodes[node].name:
				current_node = str(nodes[node].id)
	current_line = 0
	current_data = nodes[current_node].duplicate(true)
	current_data.lines = split_text(current_data.text)
	emit_signal('node_started', current_data.id)

func check_next_line(line_number):
	if length > 0 and line_count >= length:
		return
	if line_number == current_data.lines.size():
		if current_data.next == 'choice':
			display_choices()
		return

	var new_line = current_data.lines[line_number]

	var skip := false
	if new_line.length() == 0 or new_line.begins_with('#') or new_line.begins_with('//'):
		check_next_line(line_number + 1)
		return

	var marker = null
	if new_line.begins_with('->'):
		marker = '->'
	elif new_line.begins_with('-'):
		marker = '-'

	if marker:
		current_line = line_number
		current_data.choices = process_inline_choices(marker)
		display_choices()

func next_line():
	if line_active:
		while line_active:
			next_char(false)
		return

	if waiting_for_choice:
		return

	if length > 0 and line_count >= length:
		stop()
		return

	if current_line == current_data.lines.size():
		if current_data.type == 'branch':
			for b in current_data.branches:
				var branch = current_data.branches[b]
				if branch.next:
					if branch.condition:
						var result = evaluate(branch.condition)
						if !(result is String) and result == true:
							current_data.next = branch.next
							break
					else:
						current_data.next = branch.next
						break
		if current_data.next == 'none':
			stop()
			return
		if current_data.next == 'choice':
			display_choices()
			return

		set_node(current_data.next)

	var new_line = current_data.lines[current_line]

	# check for line skip
	var skip := false
	if new_line.length() == 0 or new_line.begins_with('#') or new_line.begins_with('//'):
		skip = true

	var skip2 = true
	if !skip:
		cursor = 0
		line = new_line
		while cursor < line.length():
			# check for code blocks
			if line[cursor] == '{':
				if line[cursor + 1] == '{':
					var block = get_block('{{', '}}', ['erase'])
					if block:
						# if exec:
						# 	var result = evaluate(block)
						# 	line = line.insert(cursor, str(result))
						skip2 = false
						break
				else:
					var block = get_block('{', '}')
					if block and exec:
						evaluate(block)
			# check for directive blocks
			elif line[cursor] == '<':
				if line[cursor + 1] == '<':
					var block = get_block('<<', '>>')
					if block:
						var cmd = parse_directive(block)
						if 'jump' in cmd:
							jump_to(cmd.jump)
							return
						apply_directive(cmd)
			elif !(line[cursor] in [' ', '\t']):
				skip2 = false
			cursor += 1

	if skip2:
		skip = true

	var marker = null
	if new_line.begins_with('->'):
		marker = '->'
	elif new_line.begins_with('-'):
		marker = '-'

	if marker:
		current_data.choices = process_inline_choices(marker)
		display_choices()
		return

	# do character stuff
	var name = ''
	var parts = new_line.split(':')

	previous_speaker = current_speaker

	var next_speaker = null

	# figure out who's speaking the new line
	if parts.size() > 1:
		name = parts[0]
		if '.' in name:
			var subparts = name.split('.')
			evaluate(name)
			name = subparts[0]

		# if '/' in name:
		# 	print('multiple characters not yet supported')

		if name in Diagraph.characters:
			new_line = strip_name(new_line)

			var speaker = Diagraph.characters[name]
			if !portrait_container.is_ancestor_of(speaker):
				Diagraph.utils.reparent_node(speaker, portrait_container)
				emit_signal('actor_joined', speaker)

			next_speaker = speaker
		else:
			name = ''

	if skip:
		if yielding:
			await self.resumed
		current_line += 1
		next_line()
		return

	if current_speaker != next_speaker:
		emit_signal('speaker_changed', next_speaker, previous_speaker)
		for child in portrait_container.get_children():
			child.hide()
		if next_speaker:
			next_speaker.show()
			next_speaker.idle()
		current_speaker = next_speaker
	
	var color = Color.WHITE
	if next_speaker and next_speaker.get('color'):
		color = next_speaker.color
	change_outline_color(color)

	name_box.text = name if name_override == null else name_override
	name_box.visible = (name != '') if show_name and !popup else false
	set_line(new_line)

	line_count += 1
	current_line += 1

func process_inline_choices(marker):
	var c_num = 0
	var choices = {}
	for i in range(current_line, current_data.lines.size()):
		var _line = current_data.lines[i]
		if _line.begins_with(marker):
			c_num += 1

			var parts = _line.lstrip(' ' + marker).split('=>')
			var choice = parts[0]
			var next = ''
			if parts.size() == 2:
				next = parts[1].lstrip(' ')
			choices[str(c_num)] = {
				choice = choice,
				condition = '',
				next = next,
				body = [],
				location = i,
			}
		if _line.begins_with('    '):
			choices[str(c_num)].body.append(_line.trim_prefix('    '))
		if _line.begins_with('\t'):
			choices[str(c_num)].body.append(_line.trim_prefix('\t'))

	for c in choices:
		if choices[c].body:
			var node = {
				name = '',
				text = '',
				lines = [],
				next = 'none',
				type = 'dialog',
				id = str(get_id()),
				original_node = current_node,
				line_offset = choices[c].location + 1
			}

			if 'original_node' in current_data:
				node.original_node = current_data.original_node
				node.line_offset += current_data.line_offset
			node.name = node.id
			choices[c].next = node.id
			for line in choices[c].body:
				node.text += line + '\n'
			nodes[node.id] = node
	return choices

func display_choices():
	waiting_for_choice = true
	for c in current_data.choices:
		if current_data.choices[c].choice:
			var result = true
			var condition = current_data.choices[c].get('condition')
			if condition:
				result = evaluate(condition)
			var option = add_option(current_data.choices[c].choice, c)
			if !result:
				option.set_disabled(true)
	if options_container.get_child_count():
		options_container.get_child(0).grab_focus()

func option_selected(choice):
	remove_options()
	waiting_for_choice = false
	var next_node = current_data.choices[choice].next
	if !next_node:
		stop()
		return

	jump_to(next_node)

func jump_to(node):
	set_node(node)
	next_line()

# ******************************************************************************

var line := ''
var cursor := 0
var line_active := false

func set_line(_line):
	line_active = true
	line = _line
	cursor = 0
	if !continue_previous_line:
		text_box.text = ''
	continue_previous_line = false
	next_indicator.visible = false
	next_char_cooldown = text_cooldown
	text_timer.start(next_char_cooldown)
	
	if 'original_node' in current_data:
		emit_signal('line_started', current_data.original_node, current_data.line_offset + current_line)
	else:
		emit_signal('line_started', current_node, current_line)

func skip_space():
	if cursor < line.length():
		if line[cursor] == ' ':
			cursor += 1

func get_block(start_string, end_string, options=[]):
	var result = null
	var end = line.findn(end_string, cursor)
	if end != -1:
		result = line.substr(cursor, end - cursor + len(end_string))
		cursor = end + len(end_string)
		skip_space()
		if !('nostrip' in options):
			result = result.lstrip(start_string).rstrip(end_string)
		# if 'erase' in options:
		# 	line.erase(cursor, end - cursor + len(end_string))

	return result

func next_char(use_timer=true):
	if cursor >= line.length():
		if popup:
			line_active = false
			dismiss_timer.start(popup_timeout)
			return
		emit_signal('line_finished')
		character_idle()
		text_timer.stop()
		line_active = false
		next_indicator.visible = true
		check_next_line(current_line)
		return

	var this_char = line[cursor]
	var next_chars = ['', '', '', '', '', '', '', '', '', '', '', '', '']

	next_chars[0] = this_char
	next_chars[1] = line[cursor + 1] if cursor + 1 < line.length() - 1 else ''
	next_chars[2] = line[cursor + 2] if cursor + 2 < line.length() - 2 else ''
	next_chars[3] = line[cursor + 3] if cursor + 3 < line.length() - 3 else ''
	next_chars[4] = line[cursor + 4] if cursor + 4 < line.length() - 4 else ''

	var cooldown = next_char_cooldown / speed

	match this_char:
		# future feature
		# '=':
		# 	if next_chars[1] == '>': # jump
		# 		if next_chars[2] == '<': # jump/return
		# 			var dst = line.split('=>< ')
		# 			print(dst)
		# 			jump_to(dst[1])
		# 			cursor += 3
		# 			next_char()
		# 			return
					
		# 		var dst = line.split('=> ')
		# 		print(dst)
		# 		jump_to(dst[1])
		# 		cursor += 2
		# 		next_char()
		# 		return
		'{':  # detect commands
			if next_chars[1] == '{':
				var block = get_block('{{', '}}', ['erase'])
				if block:
					if exec:
						var result = evaluate(block)
						line = line.insert(cursor, str(result))
					next_char()
			else:
				var block = get_block('{', '}')
				if block:
					if exec:
						var result = evaluate(block)
					cursor += 1
					next_char()
		'<':
			if next_chars[1] == '<':
				var block = get_block('<<', '>>')
				if block:
					var cmd = parse_directive(block)
					if 'jump' in cmd:
						jump_to(cmd.jump)
						cursor = line.length()
						next_char()
						return
					if apply_directive(cmd):
						cursor = line.length()
						next_char()
						return
			else:
				var block = get_block('<', '>', ['nostrip'])
				if block:
					print(block)
		'[':
			if next_chars[1] == '[': # inline random dialog
				var block = get_block('[[', ']]', ['erase'])
				if block:
					var parts = block.split('|')
					var selection = parts[randi() % parts.size() - 1]
					line = line.insert(cursor, str(selection))
					next_char()
			else: # detect chunks of bbcode
				var block = get_block('[', ']', ['nostrip'])
				if block:
					text_box.text += block
					next_char()
		'|':  # pipe denotes chunks of text that should pop all at once
			var end = line.findn('|', cursor + 1)
			if end != -1:
				var chunk = line.substr(cursor + 1, end - cursor - 1)
				text_box.text += chunk
				cursor = end + 1
		'_':  # pause
			cooldown = 0.25
			character_idle()
			cursor += 1
		'\\':  # escape the next character
			cursor += 1
			if cursor < line.length():
				print_char(line[cursor])
				cursor += 1
			else: # last char in line is backslash
				continue_previous_line = true
				print_char('\n')

		_:  # not a special character, just print it
			print_char(this_char)
			cursor += 1

	if use_timer:
		text_timer.start(cooldown)

func print_char(c):
	character_talk(c)

	text_box.text += c
	emit_signal('character_added', c)

# ******************************************************************************
# directive stuff

var bool_directive = {
	'checked': true,
	'unchecked': false,
	'true': true,
	'false': false,
	'1': true,
	'0': false,
}

func parse_bool(value, default):
	if value in bool_directive:
		return bool_directive[value]
	return default

func parse_directive(block):
	var parts = block.split(' ', true, 1)
	var result = {}

	# TODO: this entire section is brittle
	match parts[0]:
		'jump':
			result['jump'] = parts[1]
		'show':
			result['show'] = true
		'hide':
			result['hide'] = true
		'speed':
			result['speed'] = float(parts[1])
		'exec':
			result['exec'] = parse_bool(parts[1], exec)
		'assignment':
			result['assignment'] = parse_bool(parts[1], assignment)
		'show_name':
			result['show_name'] = parse_bool(parts[1], show_name)
		'set_name':
			result['set_name'] = parts[1]
		'show_portrait':
			result['show_portrait'] = parse_bool(parts[1], show_portrait)
	return result

func apply_directive(dir):
	var result = false
	# if 'jump' in dir:
	# 	exec = dir.jump
	# 	result = true
	# if 'wait' in dir:
	# 	exec = dir.jump
	# 	result = true
	if 'exec' in dir:
		exec = dir.exec
		result = true
	if 'show' in dir:
		show()
		result = true
	if 'hide' in dir:
		hide()
		result = true
	if 'assignment' in dir:
		assignment = dir.assignment
		result = true
	if 'show_name' in dir:
		show_name = dir.name
		result = true
	if 'set_name' in dir:
		name_override = dir.set_name if dir.set_name != 'null' else null
		result = true
	if 'show_portrait' in dir:
		show_portrait = dir.portrait
		result = true
	if 'speed' in dir:
		speed = dir.speed
		result = true
	return result

# ******************************************************************************

func evaluate(input: String=''):
	var ctx = Diagraph.sandbox.get_eval_context()

	ctx.variable('onready var caller = get_parent().caller')
	ctx.variable('onready var dialog = get_parent()')
	# ctx.variable('onready var scene = get_parent().caller.owner')

	ctx.variable('var _text_cooldown = ' + str(text_cooldown))
	ctx.method(
		'func speed(value=_text_cooldown):',
		[
			'get_parent().next_char_cooldown = value',
		]
	)
	ctx.method(
		'func jump(node):',
		[
			'get_parent().jump_to(node)',
		]
	)
	ctx.method(
		'func await object=null.sig=nothing:',
		[
			'get_parent()._await object.sig',
		]
	)
	ctx.method(
		'func timer(duration):',
		[
			'return get_tree().create_timer(duration)',
		]
	)


	var is_assignment = false
	if assignment and '=' in input:
		var re = RegEx.new()
		re.compile('[^=][=][^=]')
		if re.search(input):
			is_assignment = true
			ctx.method(
				'func _do_assignment():',
				[
					input,
				]
			)

	var context = ctx.build(self)
	add_child(context)

	if assignment and is_assignment:
		return Diagraph.sandbox.evaluate('_do_assignment()', context)

	return Diagraph.sandbox.evaluate(input, context)
