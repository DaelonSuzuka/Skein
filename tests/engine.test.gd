extends GutTest

# ******************************************************************************
# DialogEngine test suite
# ******************************************************************************/

const DialogEngineScript = preload("res://addons/skein/engine/DialogEngine.gd")
const DialogEffectScript = preload("res://addons/skein/engine/DialogEffect.gd")

var engine

func before_each():
	engine = DialogEngineScript.new()
	add_child(engine)

func after_each():
	if engine:
		engine.queue_free()

# ******************************************************************************
# Helpers
# ******************************************************************************/

func drain_line() -> Array:
	var effects = []
	var safety = 0
	while safety < 200:
		var effect = engine.next_effect()
		effects.append(effect)
		if effect.type == DialogEffectScript.Type.LINE_END:
			break
		safety += 1
	return effects

func collect_text(effects) -> String:
	var text = ""
	for e in effects:
		if e.type == DialogEffectScript.Type.CHAR:
			text += e.value
		elif e.type == DialogEffectScript.Type.INSTANT:
			text += e.value
	return text

func T(type) -> int:
	return DialogEffectScript.Type.get(type) if DialogEffectScript.Type.get(type) != null else -1

# ******************************************************************************
# Basic loading and initialization
# ******************************************************************************/

func test_start_loads_conversation():
	engine.start("res://tests/conversations/engine_basic.yarn")
	assert_ne(engine.state, DialogEngineScript.State.DONE, "Engine should not be DONE after loading")
	assert_true(engine.nodes.size() > 0, "Engine should have loaded nodes")

func test_start_sets_state_to_line_active():
	engine.start("res://tests/conversations/engine_basic.yarn")
	assert_eq(engine.state, DialogEngineScript.State.LINE_ACTIVE, "Engine should be LINE_ACTIVE after start")

func test_start_with_invalid_conversation():
	engine.start("res://tests/conversations/nonexistent.yarn")
	assert_eq(engine.state, DialogEngineScript.State.DONE, "Engine should be DONE for missing conversation")

func test_start_parses_entry_point():
	engine.start("res://tests/conversations/engine_basic.yarn:Start")
	assert_eq(engine.state, DialogEngineScript.State.LINE_ACTIVE, "Should start with entry point 'Start'")

# ******************************************************************************
# Plain text effect stream
# ******************************************************************************/

func test_plain_text_produces_char_effects():
	engine.start("res://tests/conversations/engine_basic.yarn")
	var effects = drain_line()
	var char_effects = effects.filter(func(e): return e.type == DialogEffectScript.Type.CHAR)
	assert_eq(char_effects.size(), 15, "Should have 15 CHAR effects for 'Plain text line'")
	var text = collect_text(effects)
	assert_eq(text, "Plain text line")

func test_line_ends_with_line_end():
	engine.start("res://tests/conversations/engine_basic.yarn")
	var effects = drain_line()
	assert_eq(effects[-1].type, DialogEffectScript.Type.LINE_END, "Last effect should be LINE_END")

# ******************************************************************************
# Speaker detection
# ******************************************************************************/

func test_speaker_detected_from_prefix():
	engine.start("res://tests/conversations/engine_speaker.yarn:SpeakerTest")
	assert_eq(engine.speaker_name, "Alka", "Speaker should be 'Alka'")
	assert_eq(engine._line, "I am Alka", "Line should have speaker stripped")

func test_unknown_speaker_falls_back():
	engine.start("res://tests/conversations/engine_speaker.yarn:SpeakerTest")
	drain_line()
	engine.advance()
	drain_line()
	assert_eq(engine.speaker_name, "", "Unknown speaker should not be set as speaker_name")

func test_no_speaker_prefix():
	engine.start("res://tests/conversations/engine_speaker.yarn:SpeakerTest")
	drain_line()
	engine.advance()
	drain_line()
	engine.advance()
	var effects = drain_line()
	assert_eq(engine.speaker_name, "", "Line without speaker prefix should have empty speaker")
	assert_eq(engine._line, "No speaker here")

# ******************************************************************************
# Silent { } blocks
# ******************************************************************************/

func test_silent_brace_block_erased_from_line():
	engine.start("res://tests/conversations/engine_code.yarn:InlineCode")
	var effects = drain_line()
	var text = collect_text(effects)
	assert_eq(text, "Silent block: ", "Silent block should be erased, leaving 'Silent block: '")

# ******************************************************************************
# {{ }} double brace blocks
# ******************************************************************************/

func test_double_brace_block_inserts_result():
	engine.start("res://tests/conversations/engine_code.yarn:InlineCode")
	drain_line()
	engine.advance()
	var effects = drain_line()
	var text = collect_text(effects)
	assert_eq(text, "Print block: 4", "Double brace should insert result '4'")

func test_double_brace_between_text():
	engine.start("res://tests/conversations/engine_code.yarn:InlineCode")
	drain_line()
	engine.advance()
	drain_line()
	engine.advance()
	var effects = drain_line()
	var text = collect_text(effects)
	assert_eq(text, "Before9After", "{{3*3}} should insert 9 between Before and After")

# ******************************************************************************
# Pauses and special characters
# ******************************************************************************/

func test_pause_produces_pause_effect():
	engine.start("res://tests/conversations/engine_special.yarn:SpecialChars")
	var effects = drain_line()
	var pauses = effects.filter(func(e): return e.type == DialogEffectScript.Type.PAUSE)
	assert_eq(pauses.size(), 1, "Should have one pause effect")
	assert_eq(pauses[0].value, 0.25, "Pause duration should be 0.25")

func test_pipe_chunk_produces_instant():
	engine.start("res://tests/conversations/engine_special.yarn:SpecialChars")
	drain_line()
	engine.advance()
	var effects = drain_line()
	var instants = effects.filter(func(e): return e.type == DialogEffectScript.Type.INSTANT)
	assert_eq(instants.size(), 1, "Should have one INSTANT effect for pipe chunk")
	assert_eq(instants[0].value, "instant", "Pipe chunk should be 'instant'")

func test_bbcode_produces_instant():
	engine.start("res://tests/conversations/engine_special.yarn:SpecialChars")
	drain_line()
	engine.advance()
	drain_line()
	engine.advance()
	drain_line()
	engine.advance()
	var effects = drain_line()
	var bb_open = effects.filter(func(e): return e.type == DialogEffectScript.Type.INSTANT and "[b]" in str(e.value))
	var bb_close = effects.filter(func(e): return e.type == DialogEffectScript.Type.INSTANT and "[/b]" in str(e.value))
	assert_eq(bb_open.size(), 1, "Should have INSTANT for [b]")
	assert_eq(bb_close.size(), 1, "Should have INSTANT for [/b]")

func test_escape_character():
	engine.start("res://tests/conversations/engine_special.yarn:SpecialChars")
	drain_line()
	engine.advance()
	drain_line()
	engine.advance()
	var effects = drain_line()
	var pauses = effects.filter(func(e): return e.type == DialogEffectScript.Type.PAUSE)
	assert_eq(pauses.size(), 0, "Escaped underscore should not produce a PAUSE")

# ******************************************************************************
# Directives
# ******************************************************************************/

func test_speed_directive_updates_engine_speed():
	engine.start("res://tests/conversations/engine_directives.yarn:Directives")
	# Drain the first line to process the <<speed 2.0>> directive
	drain_line()
	assert_eq(engine.speed, 2.0, "<<speed 2.0>> should set engine speed to 2.0 after processing")

func test_show_name_directive():
	engine.start("res://tests/conversations/engine_directives.yarn:Directives")
	drain_line()
	engine.advance()
	drain_line()
	assert_eq(engine.show_name, false, "<<show_name false>> should set show_name = false")

# ******************************************************************************
# Multi-line navigation
# ******************************************************************************/

func test_advance_moves_to_next_line():
	engine.start("res://tests/conversations/engine_multiline.yarn:MultiLine")
	var effects1 = drain_line()
	var text1 = collect_text(effects1)
	assert_eq(text1, "First line")
	engine.advance()
	var effects2 = drain_line()
	var text2 = collect_text(effects2)
	assert_eq(text2, "Second line")

func test_conversation_ends_with_done():
	engine.start("res://tests/conversations/engine_basic.yarn:Start")
	drain_line()
	engine.advance()
	assert_eq(engine.state, DialogEngineScript.State.DONE, "Engine should be DONE after last line")

func test_done_effect_returned():
	engine.start("res://tests/conversations/engine_basic.yarn:Start")
	drain_line()
	engine.advance()
	var effect = engine.next_effect()
	assert_eq(effect.type, DialogEffectScript.Type.DONE, "Should return DONE effect when conversation is over")

# ******************************************************************************
# Random lines preprocessing
# ******************************************************************************/

func test_random_lines_select_one():
	engine.start("res://tests/conversations/engine_random.yarn:RandomLines")
	# The %lines randomly resolve to one of the options
	var effects = drain_line()
	var text = collect_text(effects)
	assert_true(text in ["Maybe this", "Or this", "Definitely this"], "Random lines should resolve to one of the % options")

# ******************************************************************************
# Choices
# ******************************************************************************/

func test_inline_choices_enter_choosing_state():
	var nodes = {
		"1": {
			"id": 1,
			"name": "ChoiceTest",
			"type": "dialog",
			"text": "-> Yes => 2\n-> No",
			"next": "choice",
			"choices": {},
		},
		"2": {
			"id": 2,
			"name": "YesNode",
			"type": "dialog",
			"text": "You said yes",
			"next": "none",
		}
	}
	engine.nodes = nodes.duplicate(true)
	engine._enter_node("1")
	engine._advance_to_next_effect_line()
	assert_eq(engine.state, DialogEngineScript.State.CHOOSING, "Should enter CHOOSING state for inline choices")

func test_choose_transitions_to_new_node():
	var nodes = {
		"1": {
			"id": 1,
			"name": "ChoiceTest",
			"type": "dialog",
			"text": "Pick one\n-> Yes => 2\n-> No",
			"next": "choice",
			"choices": {
				"1": {"choice": "Yes", "condition": "", "next": "2"},
				"2": {"choice": "No", "condition": "", "next": "3"},
			},
		},
		"2": {
			"id": 2,
			"name": "YesNode",
			"type": "dialog",
			"text": "You said yes",
			"next": "none",
		},
		"3": {
			"id": 3,
			"name": "NoNode",
			"type": "dialog",
			"text": "You said no",
			"next": "none",
		}
	}
	engine.nodes = nodes.duplicate(true)
	engine._enter_node("1")
	engine._advance_to_next_effect_line()
	drain_line()
	engine.advance()
	assert_eq(engine.state, DialogEngineScript.State.CHOOSING, "Should be CHOOSING")
	engine.choose("1")
	assert_eq(engine.current_node, "2", "Should have jumped to node 2")

func test_choosing_state_returns_choices_effect():
	var nodes = {
		"1": {
			"id": 1,
			"name": "Test",
			"type": "dialog",
			"text": "Choose!",
			"next": "choice",
			"choices": {
				"1": {"choice": "Yes", "condition": "", "next": ""},
			},
		}
	}
	engine.nodes = nodes.duplicate(true)
	engine._enter_node("1")
	engine._advance_to_next_effect_line()
	drain_line()
	engine.advance()
	var effect = engine.next_effect()
	assert_eq(effect.type, DialogEffectScript.Type.CHOICES, "Should return CHOICES effect")

# ******************************************************************************
# Line count limit
# ******************************************************************************/

func test_length_option_limits_lines():
	engine.start("res://tests/conversations/engine_multiline.yarn:MultiLine", {"length": 1})
	var effects = drain_line()
	var text = collect_text(effects)
	assert_eq(text, "First line", "First line should display with length=1")
	engine.advance()
	assert_eq(engine.state, DialogEngineScript.State.DONE, "Should be DONE after length limit reached")

# ******************************************************************************
# Stop and jump
# ******************************************************************************/

func test_stop_ends_conversation():
	engine.start("res://tests/conversations/engine_basic.yarn:Start")
	engine.stop()
	assert_eq(engine.state, DialogEngineScript.State.DONE, "stop() should set state to DONE")

func test_jump_to_moves_to_specified_node():
	engine.start("res://tests/conversations/engine_multiline.yarn:MultiLine")
	# Jump to a named node
	engine.jump_to("MultiLine")
	assert_eq(engine.current_data.name, "MultiLine", "Should have jumped to node named 'MultiLine'")

# ******************************************************************************
# Reset
# ******************************************************************************/

func test_reset_state_clears_everything():
	engine.start("res://tests/conversations/engine_basic.yarn:Start")
	assert_true(engine.nodes.size() > 0, "Should have loaded nodes")
	engine._reset_state()
	assert_eq(engine.nodes.size(), 0, "Nodes should be cleared")
	assert_eq(engine.state, DialogEngineScript.State.IDLE, "State should be IDLE")

# ******************************************************************************
# Metadata effects
# ******************************************************************************/

func test_node_started_effect_emitted():
	engine.start("res://tests/conversations/engine_basic.yarn:Start")
	var effect = engine.next_effect()
	assert_eq(effect.type, DialogEffectScript.Type.NODE_STARTED, "First effect should be NODE_STARTED")

func test_speaker_changed_effect_emitted():
	engine.start("res://tests/conversations/engine_speaker.yarn:SpeakerTest")
	# Drain past NODE_STARTED, then look for SPEAKER_CHANGED
	var found_speaker = false
	var safety = 0
	while safety < 20:
		var effect = engine.next_effect()
		if effect.type == DialogEffectScript.Type.SPEAKER_CHANGED:
			found_speaker = true
			assert_eq(effect.value.new_name, "Alka", "SPEAKER_CHANGED should contain new_name")
			break
		if effect.type == DialogEffectScript.Type.LINE_END or effect.type == DialogEffectScript.Type.DONE:
			break
		safety += 1
	assert_true(found_speaker, "Should have found SPEAKER_CHANGED effect")

func test_line_started_effect_emitted():
	engine.start("res://tests/conversations/engine_basic.yarn:Start")
	var found_line = false
	var safety = 0
	while safety < 20:
		var effect = engine.next_effect()
		if effect.type == DialogEffectScript.Type.LINE_STARTED:
			found_line = true
			assert_eq(effect.value.line_number, 0, "LINE_STARTED should have line_number")
			break
		if effect.type == DialogEffectScript.Type.LINE_END or effect.type == DialogEffectScript.Type.DONE:
			break
		safety += 1
	assert_true(found_line, "Should have found LINE_STARTED effect")

func test_metadata_effects_come_before_display():
	engine.start("res://tests/conversations/engine_basic.yarn:Start")
	var first = engine.next_effect()
	assert_eq(first.type, DialogEffectScript.Type.NODE_STARTED, "First effect is metadata")
	var second = engine.next_effect()
	assert_eq(second.type, DialogEffectScript.Type.LINE_STARTED, "Second effect is metadata")
	var third = engine.next_effect()
	assert_eq(third.type, DialogEffectScript.Type.CHAR, "Third effect is display (CHAR)")

# ******************************************************************************
# Engine + Sandbox integration (caller, scene, dialog)
# ******************************************************************************/

class TestCaller extends Node:
	var npc_name := "Guard"
	var health := 100

class TestScene extends Node:
	var scene_label := "TestScene"

func _make_caller_with_owner() -> TestCaller:
	var scene_root = TestScene.new()
	scene_root.name = "TestScene"
	var caller = TestCaller.new()
	caller.name = "Guard"
	scene_root.add_child(caller)
	caller.owner = scene_root
	add_child(scene_root)
	add_child(engine)
	return caller

func _cleanup_caller(caller: TestCaller) -> void:
	if engine.get_parent() == self:
		remove_child(engine)
	if caller.get_parent():
		caller.get_parent().queue_free()

func test_caller_accessible_in_double_brace():
	var caller = _make_caller_with_owner()
	engine.start("res://tests/conversations/engine_context.yarn:ContextTest", {"caller": caller})
	# Drain past NODE_STARTED and LINE_STARTED
	engine.next_effect()  # NODE_STARTED
	engine.next_effect()  # LINE_STARTED
	# Collect all display text for the first line
	var text = ""
	var safety = 0
	while safety < 100:
		var effect = engine.next_effect()
		if effect.type == DialogEffectScript.Type.LINE_END:
			break
		if effect.type == DialogEffectScript.Type.CHAR:
			text += effect.value
		if effect.type == DialogEffectScript.Type.INSTANT:
			text += effect.value
		safety += 1
	assert_eq(text, "Caller name: Guard", "{{caller.npc_name}} should resolve to 'Guard'")
	_cleanup_caller(caller)

func test_scene_accessible_in_double_brace():
	var caller = _make_caller_with_owner()
	engine.start("res://tests/conversations/engine_context.yarn:ContextTest", {"caller": caller})
	# Skip first line
	drain_line()
	engine.advance()
	# Collect second line
	var text = ""
	var safety = 0
	while safety < 100:
		var effect = engine.next_effect()
		if effect.type == DialogEffectScript.Type.LINE_END:
			break
		if effect.type == DialogEffectScript.Type.CHAR:
			text += effect.value
		if effect.type == DialogEffectScript.Type.INSTANT:
			text += effect.value
		safety += 1
	assert_eq(text, "Scene label: TestScene", "{{scene.scene_label}} should resolve to caller.owner.scene_label 'TestScene'")
	_cleanup_caller(caller)

func test_dialog_accessible_in_double_brace():
	var caller = _make_caller_with_owner()
	engine.start("res://tests/conversations/engine_context.yarn:ContextTest", {"caller": caller})
	# Note: start() resets speed to 1.0, so we read whatever the engine has
	# Skip first two lines
	drain_line()
	engine.advance()
	drain_line()
	engine.advance()
	# Collect third line
	var text = ""
	var safety = 0
	while safety < 100:
		var effect = engine.next_effect()
		if effect.type == DialogEffectScript.Type.DONE:
			break
		if effect.type == DialogEffectScript.Type.LINE_END:
			break
		if effect.type == DialogEffectScript.Type.CHAR:
			text += effect.value
		if effect.type == DialogEffectScript.Type.INSTANT:
			text += effect.value
		safety += 1
	# start() resets speed to 1.0
	assert_eq(text, "Dialog speed: 1.0", "{{dialog.speed}} should resolve to engine's speed value (1.0 after start resets)")
	_cleanup_caller(caller)

func test_silent_brace_accesses_caller_property():
	var caller = _make_caller_with_owner()
	engine.start("res://tests/conversations/engine_context_silent.yarn:ContextSilentTest", {"caller": caller})
	var text = ""
	var safety = 0
	while safety < 100:
		var effect = engine.next_effect()
		if effect.type == DialogEffectScript.Type.LINE_END:
			break
		if effect.type == DialogEffectScript.Type.CHAR:
			text += effect.value
		if effect.type == DialogEffectScript.Type.INSTANT:
			text += effect.value
		safety += 1
	# {caller.name} is silent — it evaluates but doesn't print
	assert_eq(text, "Silent caller: ", "Silent {caller.npc_name} should be erased from line output")
	_cleanup_caller(caller)

func test_silent_brace_accesses_scene():
	var caller = _make_caller_with_owner()
	engine.start("res://tests/conversations/engine_context_silent.yarn:ContextSilentTest", {"caller": caller})
	drain_line()
	engine.advance()
	var text = ""
	var safety = 0
	while safety < 100:
		var effect = engine.next_effect()
		if effect.type == DialogEffectScript.Type.LINE_END:
			break
		if effect.type == DialogEffectScript.Type.CHAR:
			text += effect.value
		if effect.type == DialogEffectScript.Type.INSTANT:
			text += effect.value
		safety += 1
	assert_eq(text, "Silent scene: ", "Silent {scene.scene_label} should be erased from line output")
	_cleanup_caller(caller)

func test_no_caller_scene_is_null():
	# Start engine without a caller — scene should be null
	engine.start("res://tests/conversations/engine_basic.yarn:Start")
	assert_eq(engine.caller, null, "caller should be null when not provided")
	# The conversation should still work, just no caller/scene in expressions
	var effects = drain_line()
	assert_ne(effects.size(), 0, "Should still produce effects without caller")

func test_speed_directive_modifies_speed_via_sandbox():
	var caller = _make_caller_with_owner()
	engine.start("res://tests/conversations/engine_directives.yarn:Directives", {"caller": caller})
	drain_line()
	assert_eq(engine.speed, 2.0, "<<speed 2.0>> should set speed via sandbox eval")
	_cleanup_caller(caller)

func test_speed_function_call_in_expression():
	# Tests that {speed(3.0)} calls dialog.set_speed() via the EvalContext method
	var caller = _make_caller_with_owner()
	engine.start("res://tests/conversations/engine_speed_call.yarn:SpeedCallTest", {"caller": caller})
	drain_line()
	assert_eq(engine.speed, 3.0, "{{speed(3.0)}} should call dialog.set_speed and update engine speed")
	_cleanup_caller(caller)