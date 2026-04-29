@tool
extends Node

# ******************************************************************************

var _assignment_enabled := false

# ******************************************************************************

var locals := {}

func clear_locals():
	locals.clear()

func add_local(name: String, value):
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

func get_locals() -> Dictionary:
	# Merge persistent locals, temp locals, and characters into one dict.
	# Temp locals override persistent locals with the same name.
	# Characters override both (last write wins).
	var _locals = {}
	for name in locals:
		_locals[name] = locals[name]
	for name in temp_locals:
		_locals[name] = temp_locals[name]
	for c in Skein.characters:
		_locals[c] = Skein.characters[c]
	return _locals

# ******************************************************************************
# eval context object
# ******************************************************************************/

## A lightweight config object for adding game-specific variables and methods
## to every EvalContext build. Set up once in your game's _ready(), then
## assign to Skein.Sandbox.user_context. The variables and methods here are
## merged into the script before per-eval (engine) additions.
##
## Example:
##   var ctx = Skein.Sandbox.UserContext.new()
##   ctx.variable("var inventory  # set via props")
##   ctx.method("func has_item(name):", ["return inventory.has(name)"])
##   Skein.Sandbox.user_context = ctx
##   Skein.Sandbox.user_props = {"inventory": player_inventory}
##
class UserContext:
	var variables: Array[String] = []
	var methods: Array[String] = []

	func variable(code: String):
		variables.append(code)

	func method(signature: String, body: Array[String] = []):
		var code = signature
		for line in body:
			code += "\n\t" + line
		methods.append(code)

	func reset():
		variables.clear()
		methods.clear()

## The global user context. Assign a UserContext to inject game-specific
## helpers into every expression eval without modifying Skein source.
var user_context: UserContext = null

## Runtime object references that need to be accessible inside UserContext
## method bodies. Set once in game setup — applied to every built context
## after add_child. Same mechanism as per-eval props: declare as uninitialized
## var in UserContext, provide the value here.
##
## Example: user_props = {"inventory": player_inventory}
var user_props: Dictionary = {}

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
		# Merge user_context declarations first (game code), then per-eval
		# declarations (engine). Per-eval takes precedence for same-name entries.
		if Skein.Sandbox.user_context:
			for v in Skein.Sandbox.user_context.variables:
				source += '\n' + v
			for m in Skein.Sandbox.user_context.methods:
				source += '\n' + m
				
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

	func eval(input: String, parent: Node = null, props: Dictionary = {}):
		var context = build({input=input, parent=parent})
		# Apply user_props first (game code), then per-eval props (engine)
		for key in Skein.Sandbox.user_props:
			context.set(key, Skein.Sandbox.user_props[key])
		for key in props:
			context.set(key, props[key])
		var result = Skein.Sandbox.evaluate(input, context)
		if context and is_instance_valid(context):
			context.queue_free()
		return result

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
