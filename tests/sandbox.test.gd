extends GutTest

func test_sandbox():
	var ctx = Skein.Sandbox.get_context()

	ctx.variable('var one = 1')
	ctx.variable('@onready var parent = get_parent()')

	assert_eq(ctx.eval('one'), 1)
	assert_eq(ctx.eval('one + one'), 2)

	var context = ctx.build({parent=self})
	
	assert_true(context == ctx.evaluate('self', context))
	assert_true(self == ctx.evaluate('parent', context))

# ------------------------------------------------------------------------------

class Local:
	func hello(who:="world"):
		return "hello {who}".format({who=who})

var local = Local.new()

func test_locals():
	var ctx = Skein.Sandbox.get_context()
	
	var one = 1

	Skein.Sandbox.add_temp_local('one', one)
	assert_eq(ctx.eval('one'), 1)
	Skein.Sandbox.clear_temp_locals()

	assert_eq(ctx.eval('one'), 'one')
	Skein.Sandbox.clear_temp_locals()

	Skein.Sandbox.add_temp_locals({'one': one})
	assert_eq(ctx.eval('one + one'), 2)

	Skein.Sandbox.add_local('local', local)
	assert_eq(ctx.eval('local.hello()'), 'hello world')
	assert_eq(ctx.eval('local.hello("robot")'), 'hello robot')
	Skein.Sandbox.clear_locals()

# ------------------------------------------------------------------------------

func test_methods():
	var ctx = Skein.Sandbox.get_context()

	ctx.method(
		'func hello(who:="world"):',
		[
			'return "hello {who}".format({who=who})',
		]
	)

	assert_eq(ctx.eval('hello()'), 'hello world')
	assert_eq(ctx.eval('hello("robot")'), 'hello robot')

# ------------------------------------------------------------------------------

# var object = Value.new()

# func test_assignment():
# 	var ctx = Skein.Sandbox.get_context()

# 	Skein.Sandbox.add_temp_local('object', object)

# 	assert_true(object == ctx.eval('object'))

# 	var input = 'object.value = 2'
# 	var context = ctx.build({input=input, parent=self})

# 	assert_true(context.get_meta('is_assignment', false))

# 	var result = ctx.evaluate(input, context)
# 	# assert_eq(result, null)

# 	# assert_eq(2, object.value)

# ******************************************************************************
# Error handling
# ******************************************************************************/

func test_invalid_expression_returns_input_string():
	var ctx = Skein.Sandbox.get_context()
	var result = ctx.eval("this is not valid gdscript!!}")
	assert_eq(result, "this is not valid gdscript!!}", "Invalid expression should return the input string")

func test_undefined_variable_returns_input_string():
	var ctx = Skein.Sandbox.get_context()
	Skein.Sandbox.clear_temp_locals()
	var result = ctx.eval("nonexistent_variable")
	# When the variable name isn't in locals, Expression.parse should fail
	# and the sandbox returns the raw input string
	assert_eq(result, "nonexistent_variable", "Undefined variable should return the input string")

# ******************************************************************************
# Locals context isolation
# ******************************************************************************/

func test_temp_locals_isolated_between_evals():
	Skein.Sandbox.add_temp_local("alpha", 10)
	assert_eq(Skein.Sandbox.get_context().eval("alpha"), 10, "alpha should be 10")
	Skein.Sandbox.clear_temp_locals()
	# After clearing, alpha is no longer a local — eval returns it as a string
	var result = Skein.Sandbox.get_context().eval("alpha")
	assert_eq(result, "alpha", "alpha should be gone after clear_temp_locals")

func test_persistent_locals_survive_temp_clear():
	Skein.Sandbox.add_local("persistent", 42)
	Skein.Sandbox.add_temp_local("temp", 7)
	assert_eq(Skein.Sandbox.get_context().eval("persistent"), 42, "persistent local should be 42")
	Skein.Sandbox.clear_temp_locals()
	assert_eq(Skein.Sandbox.get_context().eval("persistent"), 42, "persistent local should survive clear_temp_locals")
	Skein.Sandbox.clear_locals()

func test_clear_locals_does_not_clear_temp_locals():
	Skein.Sandbox.add_local("a", 1)
	Skein.Sandbox.add_temp_local("b", 2)
	# clear_locals() only clears persistent locals, not temp locals
	Skein.Sandbox.clear_locals()
	var result_a = Skein.Sandbox.get_context().eval("a")
	assert_eq(result_a, "a", "a should not resolve after clear_locals")
	# b is a temp local and should still be there
	var result_b = Skein.Sandbox.get_context().eval("b")
	assert_eq(result_b, 2, "b should still resolve after clear_locals (temp locals are separate)")
	Skein.Sandbox.clear_temp_locals()

func test_clear_temp_locals_does_not_clear_persistent_locals():
	Skein.Sandbox.add_local("a", 1)
	Skein.Sandbox.add_temp_local("b", 2)
	Skein.Sandbox.clear_temp_locals()
	var result_a = Skein.Sandbox.get_context().eval("a")
	assert_eq(result_a, 1, "a should still resolve after clear_temp_locals")
	var result_b = Skein.Sandbox.get_context().eval("b")
	assert_eq(result_b, "b", "b should not resolve after clear_temp_locals")
	Skein.Sandbox.clear_locals()

func test_clear_both_locals():
	Skein.Sandbox.add_local("a", 1)
	Skein.Sandbox.add_temp_local("b", 2)
	Skein.Sandbox.clear_locals()
	Skein.Sandbox.clear_temp_locals()
	var result_a = Skein.Sandbox.get_context().eval("a")
	var result_b = Skein.Sandbox.get_context().eval("b")
	assert_eq(result_a, "a", "a should not resolve after clearing both")
	assert_eq(result_b, "b", "b should not resolve after clearing both")

# ******************************************************************************
# Object references in eval
# ******************************************************************************/

class TestObj:
	extends Node
	var my_value := 99

func test_eval_can_access_object_properties():
	var obj = TestObj.new()
	add_child(obj)
	Skein.Sandbox.add_temp_local("obj", obj)
	var ctx = Skein.Sandbox.get_context()
	var result = ctx.eval("obj.my_value")
	assert_eq(result, 99, "Should be able to access properties on a temp local object")
	obj.queue_free()
	Skein.Sandbox.clear_temp_locals()

func test_eval_can_call_object_methods():
	var obj = Local.new()
	Skein.Sandbox.add_temp_local("greeter", obj)
	var ctx = Skein.Sandbox.get_context()
	assert_eq(ctx.eval("greeter.hello()"), "hello world", "Should be able to call methods on a temp local object")
	assert_eq(ctx.eval('greeter.hello("Godot")'), "hello Godot", "Should pass arguments to methods on temp local object")
	Skein.Sandbox.clear_temp_locals()

# ******************************************************************************
# UserContext (game-side extension point)
# ******************************************************************************/

class FakeInventory:
	var items := {"sword": true, "shield": true, "potion": 3}
	func has(thing: String) -> bool:
		return thing in items
	func count(thing: String) -> int:
		return items.get(thing, 0)

func test_user_context_variables_and_methods():
	var uc = Skein.Sandbox.UserContext.new()
	uc.variable("var inventory  # set via props")
	uc.method("func has_item(name):", ["return inventory.has(name)"])
	uc.method("func count_item(name):", ["return inventory.count(name)"])
	Skein.Sandbox.user_context = uc
	Skein.Sandbox.user_props = {"inventory": FakeInventory.new()}

	Skein.Sandbox.add_temp_local("inventory", Skein.Sandbox.user_props["inventory"])
	var ctx = Skein.Sandbox.get_context()
	# Also need dialog var so the engine's per-eval stamp doesn't conflict
	# but for a pure sandbox test we just test user_context methods directly
	var result = ctx.eval("has_item('sword')", self, {"inventory": Skein.Sandbox.user_props["inventory"]})
	assert_eq(result, true, "UserContext method has_item should work via props")
	result = ctx.eval("count_item('potion')", self, {"inventory": Skein.Sandbox.user_props["inventory"]})
	assert_eq(result, 3, "UserContext method count_item should work via props")

	Skein.Sandbox.user_context = null
	Skein.Sandbox.user_props = {}
	Skein.Sandbox.clear_temp_locals()

func test_user_context_persists_across_evals():
	var uc = Skein.Sandbox.UserContext.new()
	uc.variable("var game_time = 42")
	Skein.Sandbox.user_context = uc

	var ctx = Skein.Sandbox.get_context()
	var result = ctx.eval("game_time", self)
	assert_eq(result, 42, "UserContext variable should persist across evals")

	# Second eval should still see it
	ctx = Skein.Sandbox.get_context()
	result = ctx.eval("game_time", self)
	assert_eq(result, 42, "UserContext variable should persist in second eval")

	Skein.Sandbox.user_context = null
