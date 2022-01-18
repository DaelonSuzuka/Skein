tool
extends Control

# ******************************************************************************

var OptionButton = preload('res://addons/diagraph/dialog_box/OptionButton.tscn')

signal done

var waiting_for_choice := false
var active := false

# ******************************************************************************

func _ready():
	pass

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
	$TextBox.set_line(line)

	current_line += 1

func option_selected(choice):
	remove_options()
	waiting_for_choice = false
	current_node = current_data.choices[choice].next
	current_line = 0
	current_data = nodes[current_node].parse()
	next()
