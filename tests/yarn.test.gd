extends GutTest

# ******************************************************************************
# Yarn parser tests — multi-node parsing, round-trip fidelity, edge cases
# from real Isotope production usage patterns.
# ******************************************************************************/

var Yarn = Skein.Yarn

const multi_node_path = "res://tests/conversations/yarn_multi_node.yarn"

# ******************************************************************************
# Multi-node parsing
# ******************************************************************************/

func test_parse_multi_node_yarn():
	var nodes = Yarn.load_yarn(multi_node_path)
	assert_eq(nodes.size(), 6, "Should parse 6 nodes")

func test_multi_node_ids_are_keys():
	var nodes = Yarn.load_yarn(multi_node_path)
	assert_true("3161026589" in nodes, "First node ID should be a key")
	assert_true("3388302846" in nodes, "Last node ID should be a key")

func test_multi_node_names():
	var nodes = Yarn.load_yarn(multi_node_path)
	assert_eq(nodes["3161026589"].name, "Developer", "First node name")
	assert_eq(nodes["3485632630"].name, "EnterSewer", "Last node name")

func test_multi_node_default_flag():
	var nodes = Yarn.load_yarn(multi_node_path)
	var default_nodes = []
	for id in nodes:
		if nodes[id].get("default") == "True":
			default_nodes.append(id)
	assert_eq(default_nodes.size(), 1, "Should have exactly one default node")
	assert_eq(default_nodes[0], "3161026589", "Developer is the default node")

func test_multi_node_body_text():
	var nodes = Yarn.load_yarn(multi_node_path)
	var body = nodes["4134715227"].text
	assert_eq(body, "This box is absorbing energy from the fuel tank\nIt seems to be sending the energy somewhere else",
		"Multi-line body should preserve newlines")

func test_multi_node_next_field():
	var nodes = Yarn.load_yarn(multi_node_path)
	assert_eq(nodes["3161026589"].next, "none", "Simple node has next=none")
	assert_eq(nodes["3006975953"].next, "choice", "Choice node has next=choice")

func test_multi_node_connections_parsed():
	var nodes = Yarn.load_yarn(multi_node_path)
	var connections = nodes["3006975953"].connections
	assert_true(connections is Dictionary, "Connections should be a Dictionary")
	assert_true("4248563603" in connections, "Should have connection to Quest node")
	assert_true("3388302846" in connections, "Should have connection to Later node")

func test_multi_node_choices_parsed():
	var nodes = Yarn.load_yarn(multi_node_path)
	var choices = nodes["3006975953"].choices
	assert_true(choices is Dictionary, "Choices should be a Dictionary")
	assert_true("1" in choices, "Should have choice 1")
	assert_eq(choices["1"].choice, "Of course!", "Choice 1 text")
	assert_eq(choices["1"].next, "4248563603", "Choice 1 next target")
	assert_eq(choices["2"].choice, "Maybe later", "Choice 2 text")

func test_multi_node_choice_body_text():
	var nodes = Yarn.load_yarn(multi_node_path)
	var body = nodes["3485632630"].text
	assert_true("-> Yes" in body, "Choice arrow syntax should be in body")
	assert_true("-> Ew No" in body, "Second choice should be in body")

# ******************************************************************************
# Round-trip: parse → save → parse again
# ******************************************************************************/

func test_round_trip_preserves_node_count():
	var original = Yarn.load_yarn(multi_node_path)
	var yarn_text = Yarn.convert_nodes_to_yarn(original.duplicate(true))
	var reparsed = Yarn.parse_yarn(yarn_text)
	assert_eq(reparsed.size(), original.size(), "Round-trip should preserve node count")

func test_round_trip_preserves_names():
	var original = Yarn.load_yarn(multi_node_path)
	var yarn_text = Yarn.convert_nodes_to_yarn(original.duplicate(true))
	var reparsed = Yarn.parse_yarn(yarn_text)
	for id in original:
		assert_true(id in reparsed, "Node %s should exist after round-trip" % id)
		assert_eq(reparsed[id].name, original[id].name,
			"Node %s name should survive round-trip" % id)

func test_round_trip_preserves_body_text():
	var original = Yarn.load_yarn(multi_node_path)
	var yarn_text = Yarn.convert_nodes_to_yarn(original.duplicate(true))
	var reparsed = Yarn.parse_yarn(yarn_text)
	for id in original:
		assert_eq(reparsed[id].text, original[id].text,
			"Node %s body should survive round-trip" % id)

# ******************************************************************************
# Speech → Dialog legacy rename
# ******************************************************************************/

func test_speech_type_becomes_dialog():
	var yarn_text = "id: 99\ntype: speech\ntitle: Speech\n---\nHello!\n===\n"
	var nodes = Yarn.parse_yarn(yarn_text)
	assert_eq(nodes["99"].type, "dialog", "speech type should be renamed to dialog")
	assert_eq(nodes["99"].name, "Dialog", "\"Speech\" title should be renamed to \"Dialog\"")

func test_speech_type_preserves_custom_title():
	var yarn_text = "id: 99\ntype: speech\ntitle: Greeting\n---\nHello!\n===\n"
	var nodes = Yarn.parse_yarn(yarn_text)
	assert_eq(nodes["99"].type, "dialog", "speech type should still be renamed to dialog")
	assert_eq(nodes["99"].name, "Greeting", "Custom title should be preserved")

# ******************************************************************************
# Edge cases
# ******************************************************************************/

func test_empty_node_body():
	var yarn_text = "id: 55\ntype: dialog\ntitle: Empty\n---\n===\n"
	var nodes = Yarn.parse_yarn(yarn_text)
	var text: String = nodes["55"].text
	assert_eq(text.length(), 0, "Empty body should produce empty string")

func test_missing_type_defaults_to_dialog():
	var yarn_text = "id: 77\ntitle: NoType\n---\nSome text\n===\n"
	var nodes = Yarn.parse_yarn(yarn_text)
	assert_eq(nodes["77"].type, "dialog", "Missing type should default to dialog")

func test_header_field_with_colon_in_value():
	var yarn_text = "id: 88\ntype: dialog\ntitle: Test\nposition: Rect2( 10, 20, 300, 400 )\n---\nHello\n===\n"
	var nodes = Yarn.parse_yarn(yarn_text)
	assert_eq(nodes["88"].position, "Rect2( 10, 20, 300, 400 )",
		"Header value with colons should be preserved (split(':', true, 1))")

func test_crlf_in_yarn_file():
	var yarn_text = "id: 42\r\ntype: dialog\r\ntitle: CRLF\r\n---\r\nLine one\r\nLine two\r\n===\r\n"
	var nodes = Yarn.parse_yarn(yarn_text)
	assert_eq(nodes["42"].name, "CRLF", "CRLF should not corrupt header names")
	# parse_yarn strips ALL \r globally before splitting — body text has LF only
	assert_eq(nodes["42"].text, "Line one\nLine two",
		"CRLF in body is converted to LF by global replace")

# ******************************************************************************
# convert_nodes_to_yarn mutates input (known behavior, documented)
# ******************************************************************************/

func test_convert_nodes_to_yarn_renames_name_to_title():
	var data = {"42": {id = "42", type = "dialog", name = "Start", text = "Hi", next = "none"}}
	Yarn.convert_nodes_to_yarn(data)
	# convert_nodes_to_yarn mutates: name → title, text/size/offset erased
	assert_false("name" in data["42"], "name should be erased (renamed to title in output)")
	assert_true("title" in data["42"], "title should be added")
	assert_false("text" in data["42"], "text should be erased (moved to body)")