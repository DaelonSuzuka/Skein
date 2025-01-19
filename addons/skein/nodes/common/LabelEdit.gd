@tool
extends Control

# ******************************************************************************

@export var text := '' : set = set_text

func set_text(new_text):
	text = new_text
	if is_inside_tree():
		label.text = text
		line_edit.text = text

signal text_changed(new_text)

@onready var line_edit = $LineEdit
@onready var label = $Label

# ******************************************************************************

func _ready():
	set_text(text)
	line_edit.hide()
	line_edit.focus_exited.connect(self.reject)
	line_edit.gui_input.connect(self.line_edit_input)
	label.gui_input.connect(self.label_gui_input)

func line_edit_input(event):
	if event is InputEventKey and event.pressed:
		match event.as_text():
			'Escape':
				reject()
				accept_event()
			'Enter':
				accept()
				accept_event()

func label_gui_input(event):
	if event is InputEventMouseButton and event.button_index == 1:
		if event.double_click:
			start_editing()
			accept_event()

# ******************************************************************************

func start_editing():
	line_edit.text = label.text
	label.hide()
	line_edit.show()
	line_edit.grab_focus()
	line_edit.caret_column = line_edit.text.length()
	line_edit.select_all()

func accept():
	text = line_edit.text
	label.text = text
	label.show()
	line_edit.hide()
	emit_signal('text_changed', text)

func reject():
	label.show()
	line_edit.hide()
