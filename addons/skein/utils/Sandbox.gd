@tool
extends Node

# ******************************************************************************

var _assignment_enabled := false

# ******************************************************************************

var locals := {}

func clear_locals():
	locals.clear()

func add_local(name: String, value, temp:=false):
	locals[name] = value

func add_locals(dict: Dictionary):
	for name in dict:
		add_local(name, dict[name])

# ------------------------------------------------------------------------------

var temp_locals := {}

func clear_temp_locals():
	temp_locals.clear()

func add_temp_local(name: String, value):
	temp_locals[name] = value

func add_temp_locals(dict: Dictionary):
	for name in dict:
		add_temp_local(name, dict[name])

# ------------------------------------------------------------------------------

func get_locals():
	var _locals = locals.duplicate(true)
	var _temp_locals = temp_locals.duplicate(true)

	for name in temp_locals:
		_locals[name] = _temp_locals[name]

	for c in Skein.characters:
		_locals[c] = Skein.characters[c]

	return _locals

# ******************************************************************************
# eval context object

class EvalContext:
	extends Node
	var script_template = """
extends Node
"""

	var variables: Array[String] = []
	var methods: Array[String] = []

	func reset_script():
		methods.clear()
		variables.clear()

	func variable(code):
		variables.append(code)

	func method(signature='', body=[]):
		var code = signature
		for line in body:
			code += '\n\t' + line
		methods.append(code)

	## build({parent=parent, input=input})
	func build(args:={}):
		var input = args.get('input', '')
		var parent = args.get('parent', null)

		var is_assignment = false
		if Skein.Sandbox._assignment_enabled and '=' in input:
			var re = RegEx.new()
			re.compile('[^=][=][^=]')
			if re.search(input):
				is_assignment = true
				method(
					'func _do_assignment():',
					[
						input,
					]
				)

		var source = script_template
				
		for v in variables:
			source += '\n' + v

		for m in methods:
			source += '\n' + m

		var script = GDScript.new()
		script.source_code = source
		script.reload()

		var node = Node.new()
		node.script = script
		node.name = 'EvalContext'

		if is_assignment:
			node.set_meta('is_assignment', true)

		if parent:
			parent.add_child(node)

		return node

	func eval(input: String, parent: Node = null):
		var context = build({input=input, parent=parent})
		return Skein.Sandbox.evaluate(input, context)

	func evaluate(input: String, context=null):
		return Skein.Sandbox.evaluate(input, context)

func get_context():
	return EvalContext.new()

func evaluate(input: String, context=null):
	var _locals = get_locals()

	if _assignment_enabled:
		if context and context.get_meta('is_assignment', false):
			input = '_do_assignment()'

	var expression = Expression.new()
	var result = null

	var error = expression.parse(input, PackedStringArray(_locals.keys()))
	if error != OK:
		push_warning(expression.get_error_text())
		
		result = input
	else:
		result = expression.execute(_locals.values(), context)
		if expression.has_execute_failed():
			push_warning(expression.get_error_text())
			result = input

	return result
