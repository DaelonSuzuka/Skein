extends GutTest

# ******************************************************************************
# Editor smoke tests — catch structural regressions that break the editor
# entirely (missing nodes, broken scene tree, failed serialization). These run
# in --headless mode since Godot 4.6 instantiates the full scene tree even
# without a display.
# ******************************************************************************/

var editor

func before_each():
	editor = load("res://addons/skein/editor/SkeinEditor.tscn").instantiate()
	add_child(editor)

func after_each():
	if is_instance_valid(editor):
		editor.queue_free()

# ******************************************************************************
# Boot — does the scene tree even exist?
# ******************************************************************************/

func test_editor_instantiates():
	assert_ne(editor, null, "SkeinEditor should instantiate")

func test_editor_has_graph_edit():
	assert_ne(editor.get_node_or_null("%GraphEdit"), null, "GraphEdit node missing")

func test_editor_has_conversation_tree():
	assert_ne(editor.get_node_or_null("%Tree"), null, "ConversationTree node missing")

func test_editor_has_dialog_box_preview():
	assert_ne(editor.get_node_or_null("%DialogBox"), null, "DialogBox preview node missing")

# ******************************************************************************
# Load — does it populate the graph from a yarn file?
# ******************************************************************************/

func test_load_conversation_sets_current():
	# Editor expects paths relative to conversation_prefix (res://conversations/)
	editor.load_conversation("0 Introduction.yarn")
	assert_ne(editor.current_conversation, "", "Should set current_conversation")

func test_load_conversation_creates_graph_nodes():
	editor.load_conversation("0 Introduction.yarn")
	var ge = editor.get_node("%GraphEdit")
	assert_gt(ge.nodes.size(), 0, "Graph should contain nodes after loading")

func test_load_conversation_serializes_graph_data():
	editor.load_conversation("0 Introduction.yarn")
	var ge = editor.get_node("%GraphEdit")
	var data = ge.get_nodes()
	assert_gt(data.size(), 0, "Serialized graph should have entries")
	for key in data:
		assert_true("type" in data[key], "Node %s should have a type field" % key)
		assert_true("name" in data[key], "Node %s should have a name field" % key)

# ******************************************************************************
# GraphEdit — create/serialize round-trip
# ******************************************************************************/

func test_graph_edit_create_and_serialize_node():
	var ge = editor.get_node("%GraphEdit")
	var node_data = {
		id = "9001",
		type = "dialog",
		name = "SmokeTestNode",
		text = "Hello from test",
		position_offset = Vector2(50, 50),
	}
	ge.create_node(node_data)
	assert_eq(ge.nodes.size(), 1, "Graph should have 1 node")
	var serialized = ge.get_nodes()
	assert_true("9001" in serialized, "Node 9001 should survive round-trip")
	assert_eq(serialized["9001"].name, "SmokeTestNode", "Name should round-trip")

func test_graph_edit_clear_empties_nodes():
	var ge = editor.get_node("%GraphEdit")
	var node_data = {
		id = "9002",
		type = "dialog",
		name = "Transient",
		text = "bye",
		position_offset = Vector2(0, 0),
	}
	ge.create_node(node_data)
	assert_gt(ge.nodes.size(), 0, "Should have nodes before clear")
	ge.clear()
	assert_eq(ge.nodes.size(), 0, "Graph should be empty after clear")