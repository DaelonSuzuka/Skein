	extends CanvasLayer

# ******************************************************************************

onready var DictBox = find_node('DictBox')
onready var DictEntry = find_node('DictEntry')
onready var Key = find_node('Key')
onready var Value = find_node('Value')
onready var Add = find_node('Add')

var demo_vars := {}
var demo_var_path = 'demo_vars.json'

# ******************************************************************************

func _ready():
	Add.disabled = false
	Key.connect('text_changed', self, 'key_text_changed')
	Value.connect('text_changed', self, 'value_text_changed')
	Add.connect('pressed', self, 'add_pressed')
	update_add_button()
	demo_vars = Diagraph.load_json(demo_var_path, {})
	DictBox.remove_child(DictEntry)

func key_text_changed(new_text):
	update_add_button()

func value_text_changed(new_text):
	update_add_button()

func update_add_button():
	Add.disabled = !(Key.text and Value.text)

func add_pressed():
	demo_vars[Key.text] = Value.text
	var entry = DictEntry.duplicate(true)
	var key = entry.get_node('DictKey')
	var value = entry.get_node('DictValue')
	entry.get_node('DictKey').text = Key.text
	entry.get_node('DictValue').text = Value.text
	DictBox.add_child(entry)
	entry.show()

func save_demo_vars():
	for entry in DictBox.get_children():
		pass
		# entry.get_node('DictKey').text
		# entry.get_node('DictValue').text
