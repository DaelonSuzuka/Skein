tool
extends Control

# ******************************************************************************

var OptionButton = preload('res://addons/diagraph/dialog_box/OptionButton.tscn')
var Eval = preload('res://addons/diagraph/utils/Eval.gd').new()

var TextTimer := Timer.new()
var original_cooldown := 0.05
var next_char_cooldown := original_cooldown

signal done
signal line_finished
signal character_added(c)

onready var text_box = $TextBox

var waiting_for_choice := false
var active := false

# ******************************************************************************

func _ready():
	add_child(TextTimer)
	TextTimer.connect('timeout', self, 'process_text')
	TextTimer.one_shot = true

func _input(event):
	if !visible or !active or waiting_for_choice:
		return
	if event is InputEventKey and event.pressed:
		if event.as_text() == 'Enter':
			accept_event()
			next()

# ******************************************************************************

func add_option(option, value=null):
	var button = OptionButton.instance()

	var arg = value if value else option
	button.connect("pressed", self, "option_selected", [arg])
	button.text = option

	$Options.add_child(button)
	return button

func remove_options() -> void:
	for child in $Options.get_children():
		if child is Button:
			child.queue_free()

# ******************************************************************************

var nodes = {}
var current_node = 0
var current_line = 0
var current_data = null
var caller = null
var line_count = 0
var length = -1

func start(conversation, options={}):
	var name = ''
	var entry = ''
	var line = 0
	remove_options()

	if conversation.begins_with('res://'):
		name = conversation
	else:
		var parts = conversation.split(':')
		name = Diagraph.name_to_path(parts[0])
		if parts.size() >= 2:
			entry = parts[1]
		if parts.size() >= 3:
			line = int(parts[2])

	active = true
	caller = null
	$Name/Outline.modulate = Color.white
	$TextBox/Outline.modulate = Color.white

	nodes = Diagraph.load_json(name, {})

	current_node = null
	if entry:
		for node in nodes.values():
			if node.name == entry:
				current_node = str(node.id)
		if !current_node:
			current_node = entry
	else:
		current_node = nodes.keys()[0]

	current_data = nodes[current_node]
	current_data.text = current_data.text.split('\n')
	
	line_count = 0
	current_line = line
	if line == -1:
		current_line = current_data.text.size() - 1

	if 'caller' in options:
		caller = options.caller

	length = -1
	if 'length' in options:
		length = options.length
	if 'len' in options:
		length = options.len

	next()
	show()

func stop():
	active = false
	hide()
	remove_options()
	emit_signal('done')

func next():
	if line_active:
		while line_active:
			process_text(false)
		return

	if length > 0 and line_count >= length:
		stop()
		return

	if current_line == current_data.text.size():
		if current_data.next == 'none':
			stop()
			return
		if current_data.next == 'choice':
			waiting_for_choice = true
			for c in current_data.choices:
				if current_data.choices[c].choice:
					var result = true
					var condition = current_data.choices[c].condition
					if condition:
						result = Eval.evaluate(condition, self, Diagraph.get_locals())
					var option = add_option(current_data.choices[c].choice, c)
					if !result:
						option.set_disabled(true)
			if $Options.get_child_count():
				$Options.get_child(0).grab_focus()
			return

		current_node = current_data.next
		current_data = nodes[current_node]
		current_line = 0

	var line = current_data.text[current_line]
	if line.length() == 0 or line.begins_with('#'):
		current_line += 1
		next()
		return

	var name = ''
	var parts = line.split(':')
	if parts.size() > 1:
		name = parts[0]
		line = line.lstrip(parts[0] + ':')

	var color = Color.white

	if name in Diagraph.characters:
		var portrait = $Portrait.get_node_or_null(name)
		if !portrait:
			$Portrait.add_child(Diagraph.characters[name])
			portrait = $Portrait.get_node_or_null(name)
		for child in $Portrait.get_children():
			child.visible = child.name == name
		if portrait.get('color'):
			color = portrait.color

	$Name/Outline.modulate = color
	$TextBox/Outline.modulate = color
	$Name.text = name
	$Name.visible = name != ''
	set_line(line)

	line_count += 1
	current_line += 1

func option_selected(choice):
	remove_options()
	waiting_for_choice = false
	current_node = current_data.choices[choice].next
	current_line = 0
	current_data = nodes[current_node].duplicate(true)
	current_data.text = current_data.text.split('\n')
	next()

# ******************************************************************************

var next_line := ''
var line_index := 0
var line_active := false

func set_line(line):
	line_active = true
	next_line = line
	line_index = 0
	text_box.bbcode_text = ''
	$DebugLog.text = ''
	next_char_cooldown = original_cooldown
	TextTimer.start(next_char_cooldown)

func speed(value=original_cooldown):
	next_char_cooldown = value

func process_text(use_timer=true):
	if line_index == next_line.length():
		emit_signal('line_finished')
		TextTimer.stop()
		line_active = false
		return 

	var next_char = next_line[line_index]
	var cooldown = next_char_cooldown

	match next_char:
		'{': # detect commands
			if next_line[line_index + 1] == '{':
				var end = next_line.findn('}}', line_index)
				if end != -1:
					var command = next_line.substr(line_index, end - line_index + 2)
					line_index = end + 2
					var cmd = command.lstrip('{{').rstrip('}}')
					var result = Eval.evaluate(cmd, self, Diagraph.get_locals())
					next_line.erase(line_index, end - line_index + 2)
					next_line = next_line.insert(line_index, str(result))
					$DebugLog.text += '\nexpansion: ' + str(result)
					# process_text()
			else:
				var end = next_line.findn('}', line_index)
				if end != -1:
					var command = next_line.substr(line_index, end - line_index + 1)
					line_index = end + 1
					var cmd = command.lstrip('{').rstrip('}')
					var result = Eval.evaluate(cmd, self, Diagraph.get_locals())
					$DebugLog.text += '\ncommand: ' + command
					# process_text()
		'<': # reserved for future use
			var end = next_line.findn('>', line_index)
			if end != -1:
				var block = next_line.substr(line_index, end - line_index + 1)
				$DebugLog.text += '\nangle_brackets: ' + block
				line_index = end + 1
		'[': # detect chunks of bbcode
			var end = next_line.findn(']', line_index)
			if end != -1:
				var block = next_line.substr(line_index, end - line_index + 1)
				$DebugLog.text += '\nbbcode: ' + block
				text_box.bbcode_text += block
				line_index = end + 1
				process_text()
		'|': # pipe denotes chunks of text that should pop all at once
			var end = next_line.findn('|', line_index + 1)
			if end != -1:
				var chunk = next_line.substr(line_index + 1 , end - line_index - 1)
				$DebugLog.text += '\npop: ' + chunk
				text_box.bbcode_text += chunk
				line_index = end + 1
		'_': # pause
			cooldown = 0.25
			$DebugLog.text += '\npause'
			line_index += 1
		'\\': # escape the next character
			$DebugLog.text += '\nescape'
			line_index += 1
			text_box.bbcode_text += next_line[line_index]
			emit_signal('character_added', next_line[line_index])
			line_index += 1
		_: # not a special character, just print it
			text_box.bbcode_text += next_char
			emit_signal('character_added', next_char)
			line_index += 1

	if use_timer:
		TextTimer.start(cooldown)
