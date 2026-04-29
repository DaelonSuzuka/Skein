class_name DialogEngine
extends Node

const DialogEffect = preload("res://addons/skein/engine/DialogEffect.gd")

# ******************************************************************************
# State machine
# ******************************************************************************/

enum State { IDLE, LINE_ACTIVE, WAITING_INPUT, CHOOSING, YIELDING, DONE }

var state: State = State.IDLE

# ******************************************************************************
# Conversation data
# ******************************************************************************/

var nodes := {}
var current_node: String = ""
var current_line := 0
var current_data := {}

# Line scanning state
var _line := ""
var _cursor := 0
var _line_count := 0

# Metadata effect queue — effects emitted before display effects for a line.
# Renderers consume these via next_effect() just like CHAR/PAUSE/etc.
# They are non-blocking: the renderer loop continues past them.
var _pending_effects: Array[DialogEffect] = []

# ******************************************************************************
# Configuration (set via start() options)
# ******************************************************************************/

var caller: Node = null
var length := -1

# Runtime directives
var exec := true
var show_name := true
var name_override = null
var show_portrait := true
var speed := 1.0
var popup := false
var popup_timeout := 1.0

# ******************************************************************************
# Speaker tracking
# ******************************************************************************/

var speaker_name := ""
var speaker_character = null
var previous_speaker = null
var current_speaker = null

# ******************************************************************************
# Line continuation
# ******************************************************************************/

var continue_line := false

# Actors that have already emitted ACTOR_JOINED this conversation
var _seen_actors: Array = []

# ******************************************************************************
# Public API
# ******************************************************************************/

## Start a conversation. conversation_string format: "Name[:Entry[:Line]]"
func start(conversation_string: String, options := {}) -> void:
	_reset_state()

	# Parse conversation string
	conversation_string = conversation_string.trim_prefix(Skein.Files.prefix)
	var entry := ""
	var line_number := 0

	var parts = conversation_string.split(":")
	if parts.size() >= 2:
		entry = parts[1]
	if parts.size() >= 3:
		line_number = int(parts[2])

	# Load conversation data
	nodes = Skein.load_conversation(conversation_string, {}).duplicate(true)
	if nodes.size() == 0:
		push_error('DialogEngine: loading conversation "%s" failed' % conversation_string)
		state = State.DONE
		return

	# Identify starting node
	var start_node := ""
	if entry:
		for node in nodes.values():
			if node.name == entry:
				start_node = str(node.id)
		if start_node == "":
			start_node = entry
	else:
		start_node = nodes.keys()[0]
		for node in nodes.values():
			if node.get("default", false):
				start_node = str(node.id)

	# Apply options
	if "caller" in options:
		caller = options.caller
	if "popup" in options:
		popup = true
		popup_timeout = options.popup
	if "length" in options:
		length = options.length
	if "len" in options:
		length = options.len

	_apply_directive(options)

	# Enter starting node
	_enter_node(start_node)
	if line_number == -1 or line_number > current_data.lines.size():
		current_line = current_data.lines.size() - 1

	_advance_to_next_effect_line()


## Called by the renderer when the user presses accept.
## If currently WAITING_INPUT, advances to the next line.
## If currently LINE_ACTIVE, does nothing (renderer should drain effects instead).
func advance() -> void:
	match state:
		State.WAITING_INPUT:
			_line_count += 1
			current_line += 1
			_advance_to_next_effect_line()
		State.DONE, State.CHOOSING, State.LINE_ACTIVE:
			return


## Select a choice by key ("1", "2", etc.).
func choose(choice_key: String) -> void:
	if state != State.CHOOSING:
		push_warning("DialogEngine: choose() called but not in CHOOSING state")
		return

	var choice = current_data.choices.get(choice_key, {})
	var next_node = choice.get("next", "")
	if next_node == "":
		stop()
		return

	_enter_node(next_node)
	_advance_to_next_effect_line()


## Jump to a node by name or ID.
func jump_to(node_id: String) -> void:
	_enter_node(node_id)
	_advance_to_next_effect_line()


## End the conversation.
func stop() -> void:
	state = State.DONE


func _reset_state() -> void:
	nodes.clear()
	current_node = ""
	current_line = 0
	current_data = {}
	_line = ""
	_cursor = 0
	_line_count = 0
	caller = null
	length = -1
	popup = false
	popup_timeout = 1.0
	exec = true
	show_name = true
	name_override = null
	show_portrait = true
	speed = 1.0
	speaker_name = ""
	speaker_character = null
	previous_speaker = null
	current_speaker = null
	continue_line = false
	_seen_actors.clear()
	_pending_effects.clear()
	state = State.IDLE

# ******************************************************************************
# Effect stream — the renderer calls next_effect() to consume effects one by one.
# ******************************************************************************/

## Return the next DialogEffect for the renderer to process.
##
## Metadata effects (SPEAKER_CHANGED, NODE_STARTED, LINE_STARTED, ACTOR_JOINED)
## are queued first and yielded before line-scanning effects.
## The renderer loop should continue past metadata effects without blocking.
func next_effect() -> DialogEffect:
	# Drain pending metadata effects first
	if _pending_effects.size() > 0:
		return _pending_effects.pop_front()

	if state == State.DONE:
		return DialogEffect.new(DialogEffect.Type.DONE)
	if state == State.CHOOSING:
		return DialogEffect.new(DialogEffect.Type.CHOICES, current_data.choices)
	if state == State.WAITING_INPUT:
		return DialogEffect.new(DialogEffect.Type.LINE_END)
	if state != State.LINE_ACTIVE:
		return DialogEffect.new(DialogEffect.Type.DONE)

	# Scan _line at _cursor
	while _cursor < _line.length():
		var ch = _line[_cursor]

		# {{ }} — evaluate and insert result
		if ch == "{" and _char_at(_cursor + 1) == "{":
			var result = _scan_double_brace()
			if result != null:
				return result
			continue

		# { } — evaluate silently, continue
		if ch == "{":
			var result = _scan_single_brace()
			if result != null:
				continue
			_cursor += 1
			continue

		# << >> — directive
		if ch == "<" and _char_at(_cursor + 1) == "<":
			var result = _scan_directive()
			if result != null:
				return result
			_cursor += 1
			continue

		# [[ ]] — inline random
		if ch == "[" and _char_at(_cursor + 1) == "[":
			var result = _scan_inline_random()
			if result != null:
				return result
			_cursor += 1
			continue

		# [ ] — BBCode passthrough
		if ch == "[":
			var end_pos = _line.findn("]", _cursor + 1)
			if end_pos != -1:
				var block = _line.substr(_cursor, end_pos - _cursor + 1)
				_cursor = end_pos + 1
				return DialogEffect.new(DialogEffect.Type.INSTANT, block)
			_cursor += 1
			continue

		# |...| — pipe instant chunk
		if ch == "|":
			var end = _line.findn("|", _cursor + 1)
			if end != -1:
				var chunk = _line.substr(_cursor + 1, end - _cursor - 1)
				_cursor = end + 1
				return DialogEffect.new(DialogEffect.Type.INSTANT, chunk)
			_cursor += 1
			continue

		# _ — pause
		if ch == "_":
			_cursor += 1
			return DialogEffect.new(DialogEffect.Type.PAUSE, 0.25)

		# \ — escape / continuation
		if ch == "\\":
			_cursor += 1
			if _cursor < _line.length():
				var escaped = _line[_cursor]
				_cursor += 1
				return DialogEffect.new(DialogEffect.Type.CHAR, escaped)
			else:
				# Backslash at end of line — continuation
				continue_line = true
				return DialogEffect.new(DialogEffect.Type.INSTANT, "")

		# Regular character
		_cursor += 1
		return DialogEffect.new(DialogEffect.Type.CHAR, ch)

	# End of line
	state = State.WAITING_INPUT
	return DialogEffect.new(DialogEffect.Type.LINE_END)

# ******************************************************************************
# Effect scanning helpers
# ******************************************************************************/

func _char_at(pos: int) -> String:
	if pos >= 0 and pos < _line.length():
		return _line[pos]
	return ""



## Scan {{ }} block: evaluate expression, replace the block in _line
## with the result text. The result text will be scanned character-by-character
## by subsequent next_effect() calls.
## Returns null to continue scanning from the insertion point.
func _scan_double_brace() -> Variant:
	# Find the block boundaries BEFORE advancing cursor
	var start = _cursor
	var end_pos = _line.findn("}}", start + 2)
	if end_pos == -1:
		return null

	var block = _line.substr(start + 2, end_pos - start - 2).strip_edges()
	var result_str = ""

	if exec:
		var result = _evaluate(block)
		result_str = str(result)

	# Replace the entire {{...}} span with the result text
	var end_of_block = end_pos + 2
	_line = _line.substr(0, start) + result_str + _line.substr(end_of_block)
	# _cursor stays at start — result text will be consumed as regular chars
	return null


## Scan { } block: evaluate silently, erase the block from _line,
## then continue scanning from the same position.
func _scan_single_brace() -> Variant:
	var start = _cursor
	var end_pos = _line.findn("}", start + 1)
	if end_pos == -1:
		return null

	var block = _line.substr(start + 1, end_pos - start - 1).strip_edges()

	if exec:
		_evaluate(block)

	# Erase the entire {block} from _line
	_line = _line.substr(0, start) + _line.substr(end_pos + 1)
	# _cursor stays at start; scanning continues from there
	return null


## Scan << >> block: parse directive, apply internally.
## Returns a DIRECTIVE effect for visual directives (show/hide).
## Jump directives are handled by calling jump_to() and returning
## a DIRECTIVE effect so the renderer knows to clear text.
func _scan_directive() -> Variant:
	var start = _cursor
	var end_pos = _line.findn(">>", start + 2)
	if end_pos == -1:
		return null

	var block = _line.substr(start + 2, end_pos - start - 2).strip_edges()
	_cursor = end_pos + 2  # advance past >>

	var directive = _parse_directive(block)

	if "jump" in directive:
		_apply_directive(directive)
		jump_to(directive.jump)
		return DialogEffect.new(DialogEffect.Type.DIRECTIVE, directive)

	_apply_directive(directive)

	# Only emit DIRECTIVE effect for things the renderer needs to see
	if "show" in directive or "hide" in directive:
		return DialogEffect.new(DialogEffect.Type.DIRECTIVE, directive)

	# Non-visual directives consumed silently
	return null


## Scan [[ ]] block: random inline selection.
## Replaces the [[...]] in _line with a random option, then continues scanning
## from the insertion point.
func _scan_inline_random() -> Variant:
	var start = _cursor
	var end_pos = _line.findn("]]", start + 2)
	if end_pos == -1:
		return null

	var content = _line.substr(start + 2, end_pos - start - 2)
	var parts = content.split("|")
	var selection = parts[randi() % parts.size()]

	# Replace entire [[...]] span with the selection
	var end_of_block = end_pos + 2
	_line = _line.substr(0, start) + selection + _line.substr(end_of_block)
	# _cursor stays at start; selection text will be scanned naturally
	return null

# ******************************************************************************
# Node and line navigation
# ******************************************************************************/

func _enter_node(node_id: String) -> void:
	if node_id in nodes:
		current_node = node_id
	else:
		for key in nodes:
			if str(nodes[key].get("name", "")) == node_id or nodes[key].get("name", "") == node_id:
				current_node = str(nodes[key].id)
				break

	current_line = 0
	current_data = nodes[current_node].duplicate(true)
	current_data.lines = _split_text(current_data.get("text", ""))
	_pending_effects.append(DialogEffect.new(DialogEffect.Type.NODE_STARTED, current_data.get("id", current_node)))


## Advance to the next line that produces displayable effects.
## Handles: node boundaries, branching, routing, choices, line skipping.
func _advance_to_next_effect_line() -> void:
	# Check line count limit
	if length > 0 and _line_count >= length:
		state = State.DONE
		return

	# Exhausted all lines in current node?
	if current_line >= current_data.lines.size():
		# Handle branch nodes
		if current_data.get("type", "") == "branch" and current_data.get("branches", {}):
			for key in current_data.branches:
				var branch = current_data.branches[key]
				if branch.get("next", ""):
					if branch.get("condition", ""):
						var result = _evaluate(branch.condition)
						if not (result is String) and result == true:
							current_data["next"] = branch.next
							break
					else:
						current_data["next"] = branch.next
						break

		var next = current_data.get("next", "none")
		if next == "none" or next == "":
			state = State.DONE
			return
		if next == "choice":
			state = State.CHOOSING
			return

		_enter_node(next)
		_advance_to_next_effect_line()
		return

	var raw_line: String = current_data.lines[current_line]

	# Skip blank lines and comments
	if raw_line.length() == 0 or raw_line.begins_with("#") or raw_line.begins_with("//"):
		current_line += 1
		_advance_to_next_effect_line()
		return

	# Check for choice markers
	var marker = _detect_choice_marker(raw_line)
	if marker:
		current_data.choices = _process_inline_choices(marker)
		state = State.CHOOSING
		return

	# Detect speaker and prepare line
	_detect_speaker(raw_line)


func _detect_choice_marker(line: String) -> String:
	if line.begins_with("->"):
		return "->"
	if line.begins_with("-"):
		return "-"
	return ""


## Detect the speaker from a line, update speaker state,
## and prepare the displayable line text for effect scanning.
func _detect_speaker(raw_line: String) -> void:
	var line_text = raw_line

	previous_speaker = current_speaker
	var next_speaker = null
	var name = ""

	var parts = line_text.split(":", true, 1)
	if parts.size() > 1:
		name = parts[0]
		# Handle dot notation (expression evaluation)
		if "." in name:
			_evaluate(name)
			name = name.split(".")[0]

		if name in Skein.characters:
			line_text = _strip_name(line_text)
			next_speaker = Skein.characters[name]
			# Queue ACTOR_JOINED if this character hasn't been seen yet
			if next_speaker and not next_speaker in _seen_actors:
				_seen_actors.append(next_speaker)
				_pending_effects.append(DialogEffect.new(DialogEffect.Type.ACTOR_JOINED, next_speaker))
		else:
			name = ""

	if current_speaker != next_speaker:
		var prev_name = ""
		if previous_speaker and previous_speaker.get("name"):
			prev_name = previous_speaker.name
		_pending_effects.append(DialogEffect.new(DialogEffect.Type.SPEAKER_CHANGED, {"new_name": name, "prev_name": prev_name}))
		current_speaker = next_speaker

	speaker_name = name
	speaker_character = next_speaker

	# Prepare line for effect scanning
	_line = line_text
	_cursor = 0
	state = State.LINE_ACTIVE

	# Queue LINE_STARTED metadata effect
	var line_number = current_line
	if "original_node" in current_data:
		line_number = current_data.get("line_offset", 0) + current_line
	_pending_effects.append(DialogEffect.new(DialogEffect.Type.LINE_STARTED, {"node_id": current_node, "line_number": line_number}))

# ******************************************************************************
# Choice processing
# ******************************************************************************/

func _process_inline_choices(marker: String) -> Dictionary:
	var c_num := 0
	var choices := {}

	for i in range(current_line, current_data.lines.size()):
		var choice_line: String = current_data.lines[i]
		if choice_line.begins_with(marker):
			c_num += 1
			var stripped = choice_line.lstrip(" " + marker)
			var choice_parts = stripped.split("=>", true, 1)
			var choice_text = choice_parts[0].strip_edges()
			var next := ""
			if choice_parts.size() == 2:
				next = choice_parts[1].strip_edges()
			choices[str(c_num)] = {
				"choice": choice_text,
				"condition": "",
				"next": next,
				"body": [],
				"location": i,
			}
		elif choice_line.begins_with("    "):
			choices[str(c_num)].body.append(choice_line.trim_prefix("    "))
		elif choice_line.begins_with("\t"):
			choices[str(c_num)].body.append(choice_line.trim_prefix("\t"))

	# Create dynamic nodes for choice bodies
	for key in choices:
		if choices[key].body.size() > 0:
			var node_id = str(_get_id())
			var node = {
				"name": node_id,
				"text": "",
				"lines": [],
				"next": "none",
				"type": "dialog",
				"id": node_id,
				"original_node": current_node,
				"line_offset": choices[key].location + 1,
			}
			if "original_node" in current_data:
				node["original_node"] = current_data.original_node
				node["line_offset"] += current_data.get("line_offset", 0)
			for body_line in choices[key].body:
				node.text += body_line + "\n"
			choices[key].next = node_id
			nodes[node_id] = node

	return choices


func _get_id() -> int:
	var id = randi()
	if str(id) in nodes:
		id = _get_id()
	return id

# ******************************************************************************
# Text preprocessing
# ******************************************************************************/

func _split_text(text: String) -> Array:
	var lines = text.split("\n")
	return _preprocess_random_lines(lines)


func _preprocess_random_lines(lines: Array) -> Array:
	var output := []
	var choices := []

	for line in lines:
		if line.begins_with("%"):
			choices.append(line)
		else:
			if choices.size() > 0:
				output.append(choices[randi() % choices.size()].lstrip("% ").strip_edges())
				choices.clear()
			output.append(line)

	if choices.size() > 0:
		output.append(choices[randi() % choices.size()].lstrip("% ").strip_edges())

	return output


func _strip_name(text: String) -> String:
	var parts = text.split(":", true, 1)
	if parts.size() > 1:
		return parts[1].strip_edges()
	return text

# ******************************************************************************
# Directive parsing and application
# ******************************************************************************/

var _bool_values := {
	"checked": true,
	"unchecked": false,
	"true": true,
	"false": false,
	"1": true,
	"0": false,
}


func _parse_bool(value: String, default: bool) -> bool:
	if value in _bool_values:
		return _bool_values[value]
	return default


func _parse_directive(block: String) -> Dictionary:
	var parts = block.split(" ", true, 1)
	var result := {}
	var cmd = parts[0]
	var arg = parts[1] if parts.size() > 1 else ""

	match cmd:
		"push":
			result["push"] = arg
		"return":
			result["return"] = arg
		"emit":
			result["emit"] = arg
		"jump":
			result["jump"] = arg
		"show":
			result["show"] = true
		"hide":
			result["hide"] = true
		"speed":
			result["speed"] = float(arg)
		"exec":
			result["exec"] = _parse_bool(arg, exec)
		"assignment":
			result["assignment"] = _parse_bool(arg, Skein.Sandbox._assignment_enabled)
		"show_name":
			result["show_name"] = _parse_bool(arg, show_name)
		"set_name":
			result["set_name"] = arg
		"show_portrait":
			result["show_portrait"] = _parse_bool(arg, show_portrait)
	return result


func _apply_directive(dir: Dictionary) -> void:
	if "exec" in dir:
		exec = dir.exec
	if "assignment" in dir:
		Skein.Sandbox._assignment_enabled = dir.assignment
	if "show_name" in dir:
		show_name = dir.show_name
	if "set_name" in dir:
		name_override = dir.set_name if dir.set_name != "null" else null
	if "show_portrait" in dir:
		show_portrait = dir.show_portrait
	if "speed" in dir:
		speed = dir.speed

# ******************************************************************************
# Expression evaluation
# ******************************************************************************/

func _evaluate(expression: String) -> Variant:
	var ctx = Skein.Sandbox.get_context()

	# Inject game-state references as named locals for expression evaluation.
	# 'caller' is the object that triggered the dialog (NPC, prop, etc.)
	# 'dialog' is the engine itself (for jump(), speed() method calls).
	# 'scene' is the level/owner of the caller.
	Skein.Sandbox.add_temp_local("caller", caller)
	Skein.Sandbox.add_temp_local("dialog", self)
	Skein.Sandbox.add_temp_local("scene", caller.owner if caller else null)

	ctx.variable("var dialog  # set via props after tree entry")
	ctx.variable("var _speed = " + str(speed))
	ctx.method(
		"func speed(value=_speed):",
		["dialog.set_speed(value)"]
	)
	ctx.method(
		"func jump(node):",
		["dialog.jump_to_from_eval(node)"]
	)
	ctx.method(
		"func timer(duration):",
		["return get_tree().create_timer(duration)"]
	)

	var result = ctx.eval(expression, self, {"dialog": self})

	# Clean up temp locals after evaluation
	Skein.Sandbox.clear_temp_locals()

	return result


func set_speed(value: float) -> void:
	speed = value


func jump_to_from_eval(node_id: String) -> void:
	jump_to(node_id)