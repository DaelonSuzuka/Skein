tool
extends Control

# ******************************************************************************

var OptionButton = preload('res://addons/diagraph/dialog_box/OptionButton.tscn')
var Eval = preload('res://addons/diagraph/utils/Eval.gd').new()

signal done

var TextTimer := Timer.new()
var original_cooldown := 0.05
var next_char_cooldown := original_cooldown

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

var nodes = {}
var current_node = 0
var current_line = 0
var current_data = null

var characters = {
	'Ash': load('res://characters/Ash/Ash.tscn').instance(),
	'Pico': load('res://characters/Pico/Pico.tscn').instance(),
}

# ******************************************************************************

func add_option(option, value=null):
	var button = OptionButton.instance()

	var arg = value if value else option
	button.connect("pressed", self, "option_selected", [arg])
	button.text = option

	$Options.add_child(button)

func remove_options() -> void:
	for child in $Options.get_children():
		if child is Button:
			child.queue_free()

# ******************************************************************************

func start(new_nodes, first):
	active = true
	$Name/Outline.modulate = Color.white
	$TextBox/Outline.modulate = Color.white
	nodes = new_nodes
	current_node = first
	current_line = 0
	current_data = nodes[current_node].parse()
	next()

func next():
	if current_line == current_data.text.size():
		if current_data.next == 'none':
			hide()
			active = false
			emit_signal('done')
			return
		if current_data.next == 'choice':
			waiting_for_choice = true
			for c in current_data.choices:
				if current_data.choices[c].choice:
					add_option(current_data.choices[c].choice, c)
			if $Options.get_child_count():
				$Options.get_child(0).grab_focus()
			return

		current_node = current_data.next
		current_data = nodes[current_node].parse()
		current_line = 0

	var line = current_data.text[current_line]
	var name = ''
	var parts = line.split(':')
	if parts.size() > 1:
		name = parts[0]
		line = parts[1]

	var color = Color.white

	if name in characters:
		var portrait = $Portrait.get_node_or_null(name)
		if !portrait:
			$Portrait.add_child(characters[name])
			portrait = $Portrait.get_node_or_null(name)
		for child in $Portrait.get_children():
			child.visible = child.name == name
		color = portrait.color

	$Name/Outline.modulate = color
	$TextBox/Outline.modulate = color
	$Name.text = name
	set_line(line)

	current_line += 1

func option_selected(choice):
	remove_options()
	waiting_for_choice = false
	current_node = current_data.choices[choice].next
	current_line = 0
	current_data = nodes[current_node].parse()
	next()

# ******************************************************************************


var next_line := ''
var line_index := 0

func set_line(line):
	next_line = line
	line_index = 0
	text_box.bbcode_text = ''
	$DebugLog.text = ''
	next_char_cooldown = original_cooldown
	TextTimer.start(next_char_cooldown)

func speed(value=original_cooldown):
	next_char_cooldown = value

func process_text():
	if line_index == next_line.length():
		emit_signal('line_finished')
		TextTimer.stop()
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
					$DebugLog.text += '\nexpansion: ' + command
			else:
				var end = next_line.findn('}', line_index)
				if end != -1:
					var command = next_line.substr(line_index, end - line_index + 1)
					line_index = end + 1
					var result = Eval.evaluate(command.lstrip('{').rstrip('}'), self)
					$DebugLog.text += '\ncommand: ' + command
					process_text()
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

	TextTimer.start(cooldown)


