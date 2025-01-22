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
