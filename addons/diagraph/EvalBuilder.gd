extends Node2D

# ******************************************************************************

var source = 'extends Node\n\n'

func reset():
	source = 'extends Node\n\n'

func variable(name, code):
	source += 'var %s = %s\n' % [name, code]

func function(name, code):
	source += 'func %s(): return %s\n' % [name, code]

func build():
	var script = GDScript.new()
	script.source_code = source
	script.reload()

	var node = Node.new()
	node.script = script
	return node

# ******************************************************************************

func _ready():
	function('test', 'true')
	function('test1', 'Engine.editor_hint')
	function('test2', 'OS.get_unix_time()')

	print(source)

	var node = build()
	print(node.test())
	print(node.test1())
	print(node.test2())
