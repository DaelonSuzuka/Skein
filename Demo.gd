extends CanvasLayer

# ******************************************************************************

onready var DictBox = find_node('DictBox')
onready var DictEntry = find_node('DictEntry')
onready var Key = find_node('Key')
onready var Value = find_node('Value')
onready var Add = find_node('Add')

var demo_vars := {
	'test': 'beep',
	'wallet': 100,
	'last_meal': 'pizza',
}
var demo_var_path = 'demo_vars.json'

# ******************************************************************************

func _ready():
	randomize()
	
	Add.disabled = false
	Key.connect('text_changed', self, 'key_text_changed')
	Value.connect('text_changed', self, 'value_text_changed')
	Add.connect('pressed', self, 'add_pressed')
	update_add_button()
	demo_vars = Diagraph.load_json(demo_var_path, demo_vars)
	DictBox.remove_child(DictEntry)

	Diagraph.sandbox.add_locals(demo_vars)
	for key in demo_vars:
		create_entry(key, demo_vars[key])

func key_text_changed(new_text):
	update_add_button()

func value_text_changed(new_text):
	update_add_button()

func update_add_button():
	Add.disabled = !(Key.text and Value.text)

func check_string_types(text):
	var value = text
	if text.is_valid_integer():
		value = text.to_int()
	elif text.is_valid_integer():
		value = text.to_float()
	return value

func add_pressed():
	var value = check_string_types(Value.text)
	create_entry(Key.text, value)
	Key.clear()
	Value.clear()
	save_demo_vars()

func create_entry(key, value):
	demo_vars[key] = value
	var entry = DictEntry.duplicate(true)
	var entry_key = entry.get_node('DictKey')
	var entry_value = entry.get_node('DictValue')
	entry_key.text = key
	entry_value.text = str(value)
	entry_value.connect('text_changed', self, 'entry_changed', [key])
	DictBox.add_child(entry)
	entry.show()

func entry_changed(new_text, key):
	var value = check_string_types(new_text)
	demo_vars[key] = value
	save_demo_vars()

func save_demo_vars():
	print(demo_vars)
	Diagraph.save_json(demo_var_path, demo_vars)
	Diagraph.sandbox.add_locals(demo_vars)
