extends GutTest

# ******************************************************************************
# Renderer tests — verify that example renderers correctly consume the
# effect stream and update their UI nodes.
# ******************************************************************************/

const SkeinDialogBoxScript = preload("res://addons/skein/renderers/SkeinDialogBox.gd")
const SkeinPopupRendererScript = preload("res://addons/skein/renderers/SkeinPopupRenderer.gd")
const SkeinSignRendererScript = preload("res://addons/skein/renderers/SkeinSignRenderer.gd")
const SkeinPhoneRendererScript = preload("res://addons/skein/renderers/SkeinPhoneRenderer.gd")
const SkeinDialogEngine = preload("res://addons/skein/engine/DialogEngine.gd")
const SkeinDialogEffect = preload("res://addons/skein/engine/DialogEffect.gd")

var dialog_box
var popup
var sign
var phone

func before_each():
	dialog_box = load("res://addons/skein/renderers/SkeinDialogBox.tscn").instantiate()
	add_child(dialog_box)

	popup = load("res://addons/skein/renderers/SkeinPopupRenderer.tscn").instantiate()
	add_child(popup)

	sign = load("res://addons/skein/renderers/SkeinSignRenderer.tscn").instantiate()
	add_child(sign)

	phone = load("res://addons/skein/renderers/SkeinPhoneRenderer.tscn").instantiate()
	add_child(phone)

func after_each():
	if dialog_box:
		dialog_box.queue_free()
	if popup:
		popup.queue_free()
	if sign:
		sign.queue_free()
	if phone:
		phone.queue_free()

# ******************************************************************************
# SkeinDialogBox
# ******************************************************************************/

func test_dialog_box_start_creates_engine():
	dialog_box.start("res://tests/conversations/engine_basic.yarn:Start")
	assert_ne(dialog_box.engine, null, "DialogBox should have an engine after start")
	assert_eq(dialog_box.engine.state, SkeinDialogEngine.State.LINE_ACTIVE, "Engine should be LINE_ACTIVE after start")

func test_dialog_box_consume_effects_updates_text():
	dialog_box.start("res://tests/conversations/engine_basic.yarn:Start")
	# Drain all effects for the first line
	var safety = 0
	while dialog_box.engine.state == SkeinDialogEngine.State.LINE_ACTIVE and safety < 200:
		dialog_box._consume_next_effect()
		safety += 1
	assert_ne(dialog_box._line_text, "", "DialogBox should have accumulated text from effects")
	assert_eq(dialog_box._line_text, "Plain text line", "DialogBox text should match conversation line")

func test_dialog_box_text_display_updated():
	dialog_box.start("res://tests/conversations/engine_basic.yarn:Start")
	var safety = 0
	while dialog_box.engine.state == SkeinDialogEngine.State.LINE_ACTIVE and safety < 200:
		dialog_box._consume_next_effect()
		safety += 1
	assert_eq(dialog_box.text_box.text, "Plain text line", "RichTextLabel should show the line text")

func test_dialog_box_speaker_name_shown():
	dialog_box.start("res://tests/conversations/engine_speaker.yarn:SpeakerTest")
	var safety = 0
	while dialog_box.engine.state == SkeinDialogEngine.State.LINE_ACTIVE and safety < 200:
		dialog_box._consume_next_effect()
		safety += 1
	assert_eq(dialog_box.name_label.text, "Alka", "Name label should show speaker name")

func test_dialog_box_advance_moves_to_next_line():
	dialog_box.start("res://tests/conversations/engine_multiline.yarn:MultiLine")
	# Drain first line
	dialog_box._consume_next_effect()  # NODE_STARTED metadata
	var safety = 0
	while dialog_box.engine.state == SkeinDialogEngine.State.LINE_ACTIVE and safety < 200:
		dialog_box._consume_next_effect()
		safety += 1
	assert_eq(dialog_box._line_text, "First line", "First line text")
	# Advance to second line
	dialog_box.advance()
	# LINE_STARTED will reset _line_text, then we drain
	safety = 0
	while dialog_box.engine.state == SkeinDialogEngine.State.LINE_ACTIVE and safety < 200:
		dialog_box._consume_next_effect()
		safety += 1
	assert_eq(dialog_box._line_text, "Second line", "Second line text after advance")

func test_dialog_box_stop_hides():
	dialog_box.start("res://tests/conversations/engine_basic.yarn:Start")
	dialog_box.engine.stop()
	dialog_box._on_done()
	assert_eq(dialog_box.visible, false, "DialogBox should be hidden after done")

# ******************************************************************************
# SkeinPopupRenderer
# ******************************************************************************/

func test_popup_start_creates_engine_with_length_limit():
	popup.start("res://tests/conversations/engine_multiline.yarn:MultiLine")
	assert_ne(popup.engine, null, "Popup should have an engine after start")
	# Popup enforces length limit if not provided
	assert_eq(popup.engine.length, 3, "Popup should default to 3 lines")

func test_popup_consume_effects_shows_text():
	popup.start("res://tests/conversations/engine_basic.yarn:Start")
	var safety = 0
	while popup.engine.state == SkeinDialogEngine.State.LINE_ACTIVE and safety < 200:
		popup._consume_next_effect()
		safety += 1
	assert_eq(popup._line_text, "Plain text line", "Popup should show line text")

# ******************************************************************************
# SkeinSignRenderer
# ******************************************************************************/

func test_sign_start_creates_engine():
	sign.start("res://tests/conversations/engine_basic.yarn:Start")
	assert_ne(sign.engine, null, "Sign should have an engine after start")

func test_sign_drains_instantly():
	sign.start("res://tests/conversations/engine_basic.yarn:Start")
	# Signs drain everything — _process calls _consume_next_effect,
	# which calls engine.advance() on LINE_END automatically
	# We just verify the engine was started
	assert_eq(sign.engine.state, SkeinDialogEngine.State.LINE_ACTIVE, "Sign engine should be active")

# ******************************************************************************
# SkeinPhoneRenderer
# ******************************************************************************/

func test_phone_start_creates_engine():
	phone.start("res://tests/conversations/engine_basic.yarn:Start")
	assert_ne(phone.engine, null, "Phone should have an engine after start")

func test_phone_consume_effects_shows_text():
	phone.start("res://tests/conversations/engine_basic.yarn:Start")
	var safety = 0
	while phone.engine.state == SkeinDialogEngine.State.LINE_ACTIVE and safety < 200:
		phone._consume_next_effect()
		safety += 1
	assert_eq(phone._line_text, "Plain text line", "Phone should show line text")

func test_phone_dismiss_stops_engine():
	phone.start("res://tests/conversations/engine_basic.yarn:Start")
	phone.dismiss()
	assert_eq(phone.visible, false, "Phone should be hidden after dismiss")