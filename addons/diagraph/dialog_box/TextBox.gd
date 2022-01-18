tool
extends RichTextLabel

# ******************************************************************************

var Eval = preload('res://addons/diagraph/utils/Eval.gd').new()

var TextTimer := Timer.new()
var original_cooldown := 0.05
var next_char_cooldown := original_cooldown

signal line_finished
signal character_added(c)

# ******************************************************************************

func _ready():
	add_child(TextTimer)
	TextTimer.connect('timeout', self, 'process_text')
	TextTimer.one_shot = true

var next_line := ''
var line_index := 0

func set_line(line):
	next_char_cooldown = original_cooldown
	$DebugLog.text = ''
	line_index = 0
	bbcode_text = ''
	next_line = line
	TextTimer.start(next_char_cooldown)

func speed(value=original_cooldown):
	next_char_cooldown = value

class EvalContext:
	pass

	# func speed(value):
	# 	next_char_cooldown = value

func process_text():
	if line_index == next_line.length():
		emit_signal('line_finished')
		TextTimer.stop()
		return

	var next_char = next_line[line_index]
	var cooldown = next_char_cooldown

	match next_char:
		'{': # detect commands
			var end = next_line.findn('}', line_index)
			if end != -1:
				var command = next_line.substr(line_index, end - line_index + 1)
				line_index = end + 1
				var result = Eval.evaluate(command.lstrip('{').rstrip('}'), self)
				$DebugLog.text += '\ncommand: ' + command
		'[': # detect chunks of bbcode
			var end = next_line.findn(']', line_index)
			if end != -1:
				var block = next_line.substr(line_index, end - line_index + 1)
				$DebugLog.text += '\nbbcode: ' + block
				bbcode_text += block
				line_index = end + 1
		'|': # pipe denotes chunks of text that should pop all at once
			var end = next_line.findn('|', line_index + 1)
			if end != -1:
				var chunk = next_line.substr(line_index + 1 , end - line_index - 1)
				$DebugLog.text += '\npop: ' + chunk
				bbcode_text += chunk
				line_index = end + 1
		'_': # pause
			cooldown = 0.25
			$DebugLog.text += '\npause'
			line_index += 1
		'\\': # escape the next character
			$DebugLog.text += '\nescape'
			line_index += 1
			bbcode_text += next_line[line_index]
			emit_signal('character_added', next_line[line_index])
			line_index += 1
		_: # not a special character, just print it
			bbcode_text += next_char
			emit_signal('character_added', next_char)
			line_index += 1

	TextTimer.start(cooldown)
