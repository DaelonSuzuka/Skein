extends CanvasLayer

# ******************************************************************************

@onready var DictBox = find_child('DictBox')
@onready var DictEntry = find_child('DictEntry')
@onready var Key = find_child('Key')
@onready var Value = find_child('Value')
@onready var Add = find_child('Add')

var demo_vars := {
	'test': 'beep',
	'wallet': 100,
	'last_meal': 'pizza',
}
var demo_var_path = 'demo_vars.json'

# ******************************************************************************

func _ready():
	_restore_window.call_deferred()

	randomize()
	
	Add.disabled = false
	Key.text_changed.connect(self.key_text_changed)
	Value.text_changed.connect(self.value_text_changed)
	Add.pressed.connect(self.add_pressed)
	update_add_button()
	demo_vars = Skein.Files.load_json(demo_var_path, demo_vars)
	DictBox.remove_child(DictEntry)

	Skein.Sandbox.add_locals(demo_vars)
	Skein.Sandbox.add_local('Skein', Skein)
	for key in demo_vars:
		create_entry(key, demo_vars[key])

func _restore_window():
	var window: Window = get_tree().get_root().get_window()
	window.close_requested.connect(_on_close)

	var data = Skein.Files.load_json('user://window.json', {})

	if 'position' in data:
		window.position = str_to_var(data.position)
	if 'size' in data:
		window.size = str_to_var(data.size)
	if 'mode' in data:
		window.mode = str_to_var(data.mode)

func _on_close():
	var window: Window = get_tree().get_root().get_window()
	var data = {
		position = var_to_str(window.position),
		size = var_to_str(window.size),
		mode = var_to_str(window.mode),
	}
	Skein.Files.save_json('user://window.json', data)

func key_text_changed(new_text):
	update_add_button()

func value_text_changed(new_text):
	update_add_button()

func update_add_button():
	Add.disabled = !(Key.text and Value.text)

func check_string_types(text):
	var value = text
	if text.is_valid_int():
		value = text.to_int()
	elif text.is_valid_int():
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
	entry_value.text_changed.connect(self.entry_changed.bind(key))
	DictBox.add_child(entry)
	entry.show()

func entry_changed(new_text, key):
	var value = check_string_types(new_text)
	demo_vars[key] = value
	save_demo_vars()

func save_demo_vars():
	print(demo_vars)
	Skein.Files.save_json(demo_var_path, demo_vars)
	Skein.Sandbox.add_locals(demo_vars)
