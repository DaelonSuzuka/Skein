extends CanvasLayer

# ******************************************************************************

class ConsoleCommand:
	var function: Callable
	var param_count: int
	var name: String
	var description: String
	var parameters := []

	func _init(in_name: String, in_function: Callable, in_param_count: int):
		self.name = in_name
		self.function = in_function
		self.param_count = in_param_count

	func add_argument(name, type=null, description=null):
		# self.parameters.append()
		return self

	func set_description(text):
		self.description = text
		return self

	func describe():
		Console.print_line('NAME')
		Console.print_line(self.name)
		Console.print_line()

		if self.description:
			Console.print_line(self.description)

# ******************************************************************************

signal console_opened
signal console_closed
signal console_unknown_command

@onready var control := Control.new()
@onready var rich_label := RichTextLabel.new()
@onready var line_edit := LineEdit.new()

var console_commands := {}
var console_history := []
var console_history_index := 0
var exec_locals := {}

# ******************************************************************************

func _ready() -> void:
	self.layer = 3

	control.anchor_bottom = 1.0
	control.anchor_right = 1.0
	self.add_child(control)

	rich_label.bbcode_enabled = true
	rich_label.scroll_following = true
	rich_label.anchor_right = 1.0
	rich_label.anchor_bottom = 0.5

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 0.843137)
	rich_label.add_theme_stylebox_override('normal', stylebox)

	control.add_child(rich_label)

	line_edit.anchor_top = 0.5
	line_edit.anchor_right = 1.0
	line_edit.anchor_bottom = 0.5
	control.add_child(line_edit)
	line_edit.text_submitted.connect(on_text_entered)
	line_edit.text_changed.connect(reset_autocomplete)

	# handle console url clicks
	rich_label.meta_clicked.connect(line_edit.set_text)

	control.visible = false
	process_mode = PROCESS_MODE_ALWAYS

	# Show startup message
	var v = Engine.get_version_info()
	var app_name = ProjectSettings.get_setting("application/config/name")
	self.print_line(app_name + " (Godot %s.%s.%s %s)" % [str(v.major), str(v.minor), str(v.patch), v.status])
	self.print_line("Initializing Consulate v1.0.0")
	self.print_line("Type [color=#ffff66][url=help]help[/url][/color] to get more information about usage")

	# add builtins
	add_command('quit', quit)
	add_command('exit', quit)
	add_command('clear', clear)
	add_command('delete_history', delete_history)
	add_command('help', help, 1)
	add_command('commands', commands_list)

func _input(event: InputEvent) -> void:
	if !(event is InputEventKey):
		return

	if !event.pressed:
		return

	if event.physical_keycode == KEY_QUOTELEFT:
		get_tree().get_root().set_input_as_handled()
		if event.ctrl_pressed:
			toggle_size()
			if control.visible:
				return
		toggle_console()
		return

	if !control.visible:
		return

	match event.get_physical_keycode_with_modifiers():
		KEY_ESCAPE:
			get_tree().get_root().set_input_as_handled()
			toggle_console()
		KEY_UP:
			get_tree().get_root().set_input_as_handled()
			history_up()
		KEY_DOWN:
			get_tree().get_root().set_input_as_handled()
			history_down()
		KEY_PAGEUP:
			get_tree().get_root().set_input_as_handled()
			var scroll := rich_label.get_v_scroll_bar()
			scroll.value -= scroll.page - scroll.page * 0.1
		KEY_PAGEDOWN:
			get_tree().get_root().set_input_as_handled()
			var scroll := rich_label.get_v_scroll_bar()
			scroll.value += scroll.page - scroll.page * 0.1
		KEY_TAB:
			get_tree().get_root().set_input_as_handled()
			autocomplete()

# ******************************************************************************

func history_up():
	if console_history_index > 0:
		console_history_index -= 1
		if console_history_index >= 0:
			line_edit.text = console_history[console_history_index]
			line_edit.caret_column = line_edit.text.length()
			reset_autocomplete()

func history_down():
	if console_history_index < console_history.size():
		console_history_index += 1
		if console_history_index < console_history.size():
			line_edit.text = console_history[console_history_index]
			line_edit.caret_column = line_edit.text.length()
			reset_autocomplete()
		else:
			line_edit.text = ''
			reset_autocomplete()

# ******************************************************************************

var suggestions := []
var current_suggest := 0
var suggesting := false

func autocomplete() -> void:
	if suggesting:
		for i in range(suggestions.size()):
			if current_suggest == i:
				line_edit.text = str(suggestions[i])
				line_edit.caret_column = line_edit.text.length()
				if current_suggest == suggestions.size() - 1:
					current_suggest = 0
				else:
					current_suggest += 1
				return
	else:
		suggesting = true

		var sorted_commands := []
		for command in console_commands:
			sorted_commands.append(str(command))
		sorted_commands.sort()
		sorted_commands.reverse()

		var prev_index := 0
		for command in sorted_commands:
			if command.contains(line_edit.text):
				var index: int = command.find(line_edit.text)
				if index <= prev_index:
					suggestions.push_front(command)
				else:
					suggestions.push_back(command)
				prev_index = index
		autocomplete()

func reset_autocomplete(arg=null) -> void:
	suggestions.clear()
	current_suggest = 0
	suggesting = false

func toggle_size() -> void:
	if control.anchor_bottom == 1.0:
		control.anchor_bottom = 1.9
	else:
		control.anchor_bottom = 1.0

func toggle_console() -> void:
	control.visible = !control.visible
	if control.visible:
		get_tree().paused = true
		line_edit.grab_focus()
		self.console_opened.emit()
	else:
		scroll_to_bottom()
		reset_autocomplete()
		get_tree().paused = false
		self.console_closed.emit()

func scroll_to_bottom() -> void:
	var scroll: ScrollBar = rich_label.get_v_scroll_bar()
	scroll.value = scroll.max_value - scroll.page

# ******************************************************************************

func print(arg1=null, arg2=null, arg3=null, arg4=null, arg5=null) -> void:
	var args = [arg1, arg2, arg3, arg4, arg5]
	var message = ''
	for arg in args:
		if arg:
			message += str(arg)

	self.print_line(message)

func prints(arg1='', arg2='', arg3='', arg4='', arg5='') -> void:
	var args = [arg1, arg2, arg3, arg4, arg5]
	var message = ''
	for arg in args:
		if arg:
			message += str(arg)
			message += ' '
	message = message.trim_suffix(' ')
	self.print_line(message)

func print_line(text: String='') -> void:
	if !self.rich_label:  # Tried to print something before the console was loaded.
		call_deferred('print_line', text)
	else:
		self.rich_label.append_text(text)
		self.rich_label.append_text('\n')
		print_rich(text)

func on_text_entered(text: String) -> void:
	# fix annoying focused-but-not-selected behavior
	var event = InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)

	if !text:
		return

	self.scroll_to_bottom()
	self.reset_autocomplete()
	self.line_edit.clear()
	self.add_input_history(text)
	self.print_line('[color=#999999]$[/color] ' + text)

	var parts := text.split(' ', true)
	if parts.size() > 0:
		var command_name := parts[0].to_lower()
		if command_name in console_commands:
			var command: ConsoleCommand = console_commands[command_name]

			match min(parts.size() - 1, command.param_count):
				0:
					command.function.call()
				1:
					command.function.call(parts[1])
				2:
					command.function.call(parts[1], parts[2])
				3:
					command.function.call(parts[1], parts[2], parts[3])
				_:
					self.print_line('Commands with more than 3 parameters not supported.')
		else:
			var result = evaluate(text, self, exec_locals)
			if result is String and text == result:
				self.print_line('Command `' + command_name + '` not found.')
			else:
				self.print_line(str(result))

static func evaluate(input: String, global: Object=null, locals: Dictionary={}, _show_error: bool=true):
	var _evaluated_value = null
	var _expression = Expression.new()

	var _err = _expression.parse(input, PackedStringArray(locals.keys()))

	if _err != OK:
		push_warning(_expression.get_error_text())
	else:
		_evaluated_value = _expression.execute(locals.values(), global, _show_error)

		if _expression.has_execute_failed():
			return input

	return _evaluated_value

func add_command(command_name: String, function: Callable, param_count: int=0) -> ConsoleCommand:
	var command = ConsoleCommand.new(command_name, function, param_count)
	console_commands[command_name] = command
	return command

func remove_command(command_name: String) -> void:
	console_commands.erase(command_name)

func add_input_history(text: String) -> void:
	if !console_history.size() || text != console_history.back():  # Don't add consecutive duplicates
		console_history.append(text)
	console_history_index = console_history.size()

# ******************************************************************************
# builtin commands

func quit() -> void:
	get_tree().quit()

func clear() -> void:
	rich_label.clear()

func delete_history() -> void:
	console_history.clear()
	console_history_index = 0
	DirAccess.remove_absolute('user://console_history.txt')

func help(command_name=null) -> void:
	if command_name:
		var command = self.console_commands.get(command_name, null)
		if command:
			command.describe()
		else:
			self.print_line('No help for `' + command_name + '` command were found.')
		return

	self.print_line("Type [color=#ffff66][url=help]help[/url] <command-name>[/color] show information about command.")
	self.print_line("Type [color=#ffff66][url=commands]commands[/url][/color] to get a list of all commands.")
	self.print_line("Type [color=#ffff66][url=quit]quit[/url][/color] to exit the application.")


func commands_list() -> void:
	for command in console_commands:
		self.print_line('[color=#ffff66][url=%s]%s[/url][/color]' % [ command, command ])

# ******************************************************************************

func _enter_tree() -> void:
	var console_history_file := FileAccess.open('user://console_history.txt', FileAccess.READ)
	if console_history_file:
		while !console_history_file.eof_reached():
			var line := console_history_file.get_line()
			if line.length():
				add_input_history(line)

func _exit_tree() -> void:
	var console_history_file := FileAccess.open('user://console_history.txt', FileAccess.WRITE)
	if console_history_file:
		var write_index := 0
		var start_write_index := console_history.size() - 100  # Max lines to write
		for line in console_history:
			if write_index >= start_write_index:
				console_history_file.store_line(line)
			write_index += 1

# ******************************************************************************

func register_autoloads():
	var autoloads = $'/root'.get_children()
	for node in autoloads:
		if node.name == 'Main':
			continue
		self.exec_locals[node.name] = node

func register_exec_symbol(name:String, object):
	self.exec_locals[name] = object
