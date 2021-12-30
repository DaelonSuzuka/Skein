tool
extends Control

# ******************************************************************************

export var text := '' setget set_text
func set_text(new_text):
	text = new_text
	if is_inside_tree():
		$Label.text = text
		$LineEdit.text = text

signal text_changed(new_text)

# ******************************************************************************

func _ready():
	set_text(text)
	$LineEdit.hide()
	$LineEdit.connect('focus_exited', self, 'reject')
	$LineEdit.connect('gui_input', self, 'line_edit_input')

func line_edit_input(event):
	if event is InputEventKey and event.pressed:
		match event.as_text():
			'Escape':
				reject()
			'Enter':
				accept()

func _input(event):
	if event is InputEventMouseButton:
		if event.doubleclick:
			start_editing()

# ******************************************************************************

func start_editing():
	$LineEdit.text = $Label.text
	$Label.hide()
	$LineEdit.show()
	
func accept():
	text = $LineEdit.text
	$Label.text = text
	$Label.show()
	$LineEdit.hide()
	emit_signal('text_changed', text)

func reject():
	$Label.show()
	$LineEdit.hide()
