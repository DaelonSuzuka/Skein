tool
extends Control

# ******************************************************************************

onready var choices = {
	'Choice1': $Choices/Choice1,
	'Choice2': $Choices/Choice2,
	'Choice3': $Choices/Choice3,
	'Choice4': $Choices/Choice4,
}

signal done

# ******************************************************************************

func _ready():
	for c in choices:
		choices[c].connect('pressed', self, 'pressed', [c])


func _input(event):
	if !visible:
		return
	if event is InputEventKey and event.pressed:
		if event.as_text() == 'Enter':
			accept_event()
			next()

var nodes = {}
var current_node = 0
var current_index = 0
var current_data = null

func start(new_nodes, first):
	nodes = new_nodes
	current_node = first
	current_index = 0
	current_data = nodes[current_node].parse()
	next()

func next():
	$Choices.hide()
	if current_index == current_data.text.size():
		if current_data.next == 'none':
			hide()
			emit_signal('done')
			return
		if current_data.next == 'choice':
			$Choices.show()
			for c in current_data.choices:
				choices[c].text = current_data.choices[c].choice

			return
		current_node = current_data.next
		current_data = nodes[current_node].parse()
		current_index = 0

	$TextBox/RichTextLabel.text = current_data.text[current_index]
	current_index += 1

func pressed(choice):
	current_node = current_data.choices[choice].next
	current_index = 0
	current_data = nodes[current_node].parse()
	next()
