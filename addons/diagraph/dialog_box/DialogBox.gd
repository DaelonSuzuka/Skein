tool
extends Control

# ******************************************************************************

export(String, FILE, '*.tscn,*.scn') var option_button_path = 'res://addons/diagraph/dialog_box/BaseOptionButton.tscn'

onready var OptionButton = load(option_button_path)

var TextTimer: Timer = null
var DismissTimer: Timer = null
var original_cooldown := 0.05
var next_char_cooldown := original_cooldown

signal done
signal line_finished
signal character_added(c)

signal actor_joined(actor)
signal actor_left(actor) # unimplemented

signal speaker_changed(new_speaker, prev_speaker)

# ******************************************************************************

# mandatory nodes
onready var Name = find_node('Name')
onready var NextIndicator = find_node('Next')
onready var TextBox = find_node('TextBox')
onready var Options = find_node('Options')
onready var Portrait = find_node('Portrait')

# possibly optional nodes
onready var NameOutline = find_node('NameOutline')
onready var TextBoxOutline = find_node('TextBoxOutline')

onready var DebugLog = find_node('DebugLog')

var waiting_for_choice := false
var active := false
var direct_input := true

# ******************************************************************************

func _ready():
	TextTimer = Timer.new()
	add_child(TextTimer)
	TextTimer.connect('timeout', self, 'next_char')
	TextTimer.one_shot = true
	DismissTimer = Timer.new()
	add_child(DismissTimer)
	DismissTimer.connect('timeout', self, 'next_line')
	DismissTimer.one_shot = true

# ------------------------------------------------------------------------------

# input handling shim
func _input(event):
	if direct_input:
		handle_input(event)

func handle_input(event):
	if !visible or !active or waiting_for_choice:
		return
	if event is InputEventKey and event.pressed:
		if event.as_text() == 'Enter':
			accept_event()
			next_line()

# ******************************************************************************

func add_option(option, value=null):
	var button = OptionButton.instance()

	var arg = value if value else option
	button.connect('pressed', self, 'option_selected', [arg])
	button.text = option

	Options.add_child(button)
	return button

func remove_options() -> void:
	for child in Options.get_children():
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
	if NameOutline:
		NameOutline.modulate = color
	if TextBoxOutline:
		TextBoxOutline.modulate = color

# ******************************************************************************

var nodes := {}
var current_node = 0
var current_line := 0
var current_data := {}
var continue_previous_line := false
var caller: Node = null
var line_count := 0
var length := -1
var popup := false
var popup_timeout := 1.0
var exec := true
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
	NextIndicator.visible = false
	change_outline_color(Color.white)
	remove_options()

	# parse conversation string
	conversation = conversation.trim_prefix(Diagraph.prefix)

	var parts = conversation.split(':')
	if parts.size() >= 2:
		entry = parts[1]
	if parts.size() >= 3:
		line_number = int(parts[2])

	nodes = Diagraph.load_conversation(conversation, {}).duplicate(true)

	# TODO: add safety here

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
	current_data = nodes[current_node]
	current_data.lines = split_text(current_data.text)

	line_count = 0
	current_line = line_number
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
					if block:
						if exec:
							var result = evaluate(block)
			# check for directive blocks
			elif line[cursor] == '<':
				if line[cursor + 1] == '<':
					var block = get_block('<<', '>>')
					if block:
						var cmd = decode_yarn(block)
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
			if !Portrait.is_a_parent_of(speaker):
				Diagraph.utils.reparent_node(speaker, Portrait)
				emit_signal('actor_joined', speaker)

			next_speaker = speaker
		else:
			name = ''

	if skip:
		current_line += 1
		next_line()
		return

	if current_speaker != next_speaker:
		emit_signal('speaker_changed', next_speaker, previous_speaker)
		for child in Portrait.get_children():
			child.hide()
		next_speaker.show()
		next_speaker.idle()
		current_speaker = next_speaker
	
	var color = Color.white
	if next_speaker.get('color'):
		color = next_speaker.color
	change_outline_color(color)
	
	Name.text = name if name_override == null else name_override
	Name.visible = (name != '') if show_name and !popup else false
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
				id = get_id(),
			}
			node.name = str(node.id)
			choices[c].next = str(node.id)
			for line in choices[c].body:
				node.lines += line + '\n'
			nodes[str(node.id)] = node
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
	if Options.get_child_count():
		Options.get_child(0).grab_focus()

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
		TextBox.bbcode_text = ''
	continue_previous_line = false
	DebugLog.text = ''
	NextIndicator.visible = false
	next_char_cooldown = original_cooldown
	TextTimer.start(next_char_cooldown)

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
		if 'erase' in options:
			line.erase(cursor, end - cursor + len(end_string))

	return result

func next_char(use_timer=true):
	if cursor >= line.length():
		if popup:
			line_active = false
			DismissTimer.start(popup_timeout)
			return
		emit_signal('line_finished')
		character_idle()
		TextTimer.stop()
		line_active = false
		NextIndicator.visible = true
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
					var cmd = decode_yarn(block)
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
					TextBox.bbcode_text += block
					next_char()
		'|':  # pipe denotes chunks of text that should pop all at once
			var end = line.findn('|', cursor + 1)
			if end != -1:
				var chunk = line.substr(cursor + 1, end - cursor - 1)
				TextBox.bbcode_text += chunk
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
		TextTimer.start(cooldown)

func print_char(c):
	character_talk(c)

	TextBox.bbcode_text += c
	emit_signal('character_added', c)

# ******************************************************************************
# directive stuff

var bool_directive = {
	'on': true,
	'off': false,
	'true': true,
	'false': false,
	'1': true,
	'0': false,
}

func parse_bool(value, default):
	if value in bool_directive:
		return bool_directive[value]
	return default

func decode_yarn(block):
	var parts = block.split(' ', true, 1)
	var result = {}
	match parts[0]:
		'jump':
			result['jump'] = parts[1]
		'speed':
			result['speed'] = float(parts[1])
		'exec':
			result['exec'] = parse_bool(parts[1], exec)
		'name':
			result['name'] = parse_bool(parts[1], show_name)
		'set_name':
			result['set_name'] = parts[1]
		'portrait':
			result['portrait'] = parse_bool(parts[1], show_portrait)
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
	if 'name' in dir:
		show_name = dir.name
		result = true
	if 'set_name' in dir:
		name_override = dir.set_name if dir.set_name != 'null' else null
		result = true
	if 'portrait' in dir:
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
	# ctx.variable('onready var scene = get_parent().caller.owner')

	ctx.variable('var _original_cooldown = ' + str(original_cooldown))
	ctx.method(
		'func speed(value=_original_cooldown):',
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

	var context = ctx.build(self)
	add_child(context)
	return Diagraph.sandbox.evaluate(input, context)
