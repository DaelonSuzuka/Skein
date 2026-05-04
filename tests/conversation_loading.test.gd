extends GutTest

# ******************************************************************************
# Tests for parse_conversation_string, load_conversation caching,
# start_with_data, and runtime watcher behavior.
# ******************************************************************************/

const SkeinDialogEngine = preload("res://addons/skein/engine/DialogEngine.gd")

# ******************************************************************************
# parse_conversation_string
# ******************************************************************************/

func test_parse_conversation_name_only():
	var result = Skein.parse_conversation_string("Station")
	assert_eq(result.conversation, "Station", "conversation should be Station")
	assert_eq(result.entry, "", "entry should be empty")
	assert_eq(result.line, 0, "line should be 0")

func test_parse_conversation_name_and_entry():
	var result = Skein.parse_conversation_string("Station:EnterSewer")
	assert_eq(result.conversation, "Station", "conversation should be Station")
	assert_eq(result.entry, "EnterSewer", "entry should be EnterSewer")
	assert_eq(result.line, 0, "line should be 0")

func test_parse_conversation_name_entry_and_line():
	var result = Skein.parse_conversation_string("SubStation:Charged:-1")
	assert_eq(result.conversation, "SubStation", "conversation should be SubStation")
	assert_eq(result.entry, "Charged", "entry should be Charged")
	assert_eq(result.line, -1, "line should be -1")

func test_parse_conversation_strips_res_prefix():
	var result = Skein.parse_conversation_string("res://conversations/Common:NPC")
	assert_eq(result.conversation, "conversations/Common", "should strip res:// prefix")
	assert_eq(result.entry, "NPC", "entry should be NPC")

func test_parse_conversation_user_prefix():
	var result = Skein.parse_conversation_string("user://conversations/Chapter1/Heaven")
	assert_eq(result.conversation, "conversations/Chapter1/Heaven", "should strip user:// prefix")

func test_parse_conversation_empty_string():
	var result = Skein.parse_conversation_string("")
	assert_eq(result.conversation, "", "empty string → empty conversation")
	assert_eq(result.entry, "", "empty string → empty entry")
	assert_eq(result.line, 0, "empty string → line 0")

# ******************************************************************************
# load_conversation caching
# ******************************************************************************/

func test_load_conversation_returns_data():
	var result = Skein.load_conversation("0 Introduction.yarn")
	assert_true(result is Dictionary, "Should return a Dictionary")
	assert_true(result.size() > 0, "Should have at least one node")

func test_load_conversation_caches_result():
	var first = Skein.load_conversation("0 Introduction.yarn")
	var second = Skein.load_conversation("0 Introduction.yarn")
	# Results should be equal in size but independent objects
	# duplicate(true) creates a new top-level Dictionary
	assert_eq(first.size(), second.size(), "Cached result should have same size")
	# Modifying one should not affect the other
	var first_id = first.keys()[0]
	second[first_id]["text"] = "MODIFIED"
	assert_ne(str(first[first_id]["text"]), "MODIFIED",
		"Deep copy should isolate modifications")

func test_load_conversation_with_entry():
	# parse_conversation_string strips :entry, so this should still load
	var result = Skein.load_conversation("0 Introduction.yarn:Developer")
	assert_true(result is Dictionary, "Should return Dictionary even with :entry suffix")
	assert_true(result.size() > 0, "Should have nodes")

func test_load_conversation_with_entry_and_line():
	var result = Skein.load_conversation("0 Introduction.yarn:Developer:2")
	assert_true(result is Dictionary, "Should return Dictionary even with :entry:line suffix")
	assert_true(result.size() > 0, "Should have nodes")

func test_load_conversation_cache_cleared_on_refresh():
	var first = Skein.load_conversation("0 Introduction.yarn")
	Skein.refresh()
	var second = Skein.load_conversation("0 Introduction.yarn")
	# After refresh, cache was cleared and reloaded — should still work
	assert_eq(first.size(), second.size(), "Should return same size after cache refresh")

func test_load_conversation_missing_returns_default():
	var result = Skein.load_conversation("nonexistent_file.yarn", {})
	assert_eq(result, {}, "Should return default for missing file")

# ******************************************************************************
# start_with_data
# ******************************************************************************/

func test_start_with_data_basic():
	var engine = SkeinDialogEngine.new()
	var nodes = {
		"1": {
			"id": "1",
			"type": "dialog",
			"name": "Start",
			"text": "Hello from data",
			"next": "none",
			"default": true,
		}
	}
	engine.start_with_data(nodes)
	assert_eq(engine.state, SkeinDialogEngine.State.LINE_ACTIVE, "Engine should be LINE_ACTIVE after start_with_data")
	# Drain to get the text
	var text = ""
	var safety = 0
	while engine.state == SkeinDialogEngine.State.LINE_ACTIVE and safety < 50:
		var effect = engine.next_effect()
		if effect.type == SkeinDialogEngine.DialogEffect.Type.CHAR:
			text += effect.value
		safety += 1
	assert_eq(text, "Hello from data", "Should produce text from pre-loaded data")
	engine.queue_free()

func test_start_with_data_with_entry():
	var engine = SkeinDialogEngine.new()
	var nodes = {
		"1": {
			"id": "1",
			"type": "dialog",
			"name": "Start",
			"text": "First node",
			"next": "none",
		},
		"2": {
			"id": "2",
			"type": "dialog",
			"name": "Second",
			"text": "Second node",
			"next": "none",
		}
	}
	engine.start_with_data(nodes, {"entry": "Second"})
	assert_eq(engine.state, SkeinDialogEngine.State.LINE_ACTIVE, "Engine should start at named entry")
	var text = ""
	var safety = 0
	while engine.state == SkeinDialogEngine.State.LINE_ACTIVE and safety < 50:
		var effect = engine.next_effect()
		if effect.type == SkeinDialogEngine.DialogEffect.Type.CHAR:
			text += effect.value
		safety += 1
	assert_eq(text, "Second node", "Should start at the Second node")
	engine.queue_free()

func test_start_with_data_default_node():
	var engine = SkeinDialogEngine.new()
	var nodes = {
		"1": {
			"id": "1",
			"type": "dialog",
			"name": "Default",
			"text": "I am default",
			"next": "none",
			"default": true,
		},
		"2": {
			"id": "2",
			"type": "dialog",
			"name": "Other",
			"text": "I am other",
			"next": "none",
		}
	}
	engine.start_with_data(nodes)
	var text = ""
	var safety = 0
	while engine.state == SkeinDialogEngine.State.LINE_ACTIVE and safety < 50:
		var effect = engine.next_effect()
		if effect.type == SkeinDialogEngine.DialogEffect.Type.CHAR:
			text += effect.value
		safety += 1
	assert_eq(text, "I am default", "Should start at default node when no entry given")
	engine.queue_free()

func test_start_with_data_empty_fails_gracefully():
	var engine = SkeinDialogEngine.new()
	engine.start_with_data({})
	assert_eq(engine.state, SkeinDialogEngine.State.DONE, "Empty data should set state to DONE")
	engine.queue_free()

func test_start_with_data_does_not_hit_disk():
	# Verify that start_with_data never calls Skein.load_conversation
	# by using nodes that don't exist on disk at all
	var engine = SkeinDialogEngine.new()
	var nodes = {
		"42": {
			"id": "42",
			"type": "dialog",
			"name": "InMemory",
			"text": "No disk needed",
			"next": "none",
		}
	}
	engine.start_with_data(nodes)
	assert_eq(engine.state, SkeinDialogEngine.State.LINE_ACTIVE, "Should work without any disk access")
	engine.queue_free()

# ******************************************************************************
# Watcher is editor-only
# ******************************************************************************/

func test_watcher_not_child_at_runtime():
	# In headless test mode (not editor), Watcher should not be a child of Skein
	var has_watcher = false
	for child in Skein.get_children():
		if child.name == "Watcher":
			has_watcher = true
	assert_false(has_watcher, "Watcher should not be a child of Skein in non-editor mode")