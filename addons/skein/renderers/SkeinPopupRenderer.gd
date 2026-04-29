@tool
class_name SkeinPopupRenderer
extends Control

## Floating label renderer for short NPC barks and popups.
## No choices, no portrait, no name label — just text that auto-advances
## after a timeout. Useful for one-line NPC comments, sign text, etc.

const SkeinDialogEngine = preload("res://addons/skein/engine/DialogEngine.gd")
const SkeinDialogEffect = preload("res://addons/skein/engine/DialogEffect.gd")

@onready var label: RichTextLabel = %PopupLabel

var engine: SkeinDialogEngine
var _typing_speed: float = 0.03
var _typing_timer: float = 0.0
var _line_text: String = ""
var _auto_advance_timer: float = 0.0
var _auto_advance_duration: float = 3.0  # seconds to show after line ends


func _process(delta: float) -> void:
	if not engine:
		return

	# Auto-advance after line ends
	if engine.state == SkeinDialogEngine.State.WAITING_INPUT:
		_auto_advance_timer -= delta
		if _auto_advance_timer <= 0.0:
			advance()
		return

	if not engine.state == SkeinDialogEngine.State.LINE_ACTIVE:
		return

	if _typing_timer > 0.0:
		_typing_timer -= delta
		return

	_consume_next_effect()


func start(conversation: String, options: Dictionary = {}) -> void:
	engine = SkeinDialogEngine.new()
	add_child(engine)
	# Popups should be short — enforce length limit if not set
	if not "length" in options and not "len" in options:
		options["length"] = 3
	engine.start(conversation, options)
	show()
	_consume_next_effect()


func advance() -> void:
	_auto_advance_timer = 0.0
	engine.advance()
	if engine.state == SkeinDialogEngine.State.LINE_ACTIVE:
		_consume_next_effect()


## ----------
## Effect stream consumer
## ----------

func _consume_next_effect() -> void:
	var effect = engine.next_effect()
	if not effect:
		return

	match effect.type:
		SkeinDialogEffect.Type.CHAR:
			_line_text += effect.value
			_update_display()
			_start_typing_timer()

		SkeinDialogEffect.Type.INSTANT:
			_line_text += effect.value
			_update_display()
			_consume_next_effect()

		SkeinDialogEffect.Type.PAUSE:
			_typing_timer = effect.value / engine.speed

		SkeinDialogEffect.Type.LINE_END:
			label.visible_characters = -1
			_auto_advance_timer = _auto_advance_duration

		SkeinDialogEffect.Type.CHOICES:
			# Popups don't show choices — just end
			_on_done()

		SkeinDialogEffect.Type.DIRECTIVE:
			_consume_next_effect()

		SkeinDialogEffect.Type.SPEAKER_CHANGED, \
		SkeinDialogEffect.Type.NODE_STARTED, \
		SkeinDialogEffect.Type.LINE_STARTED, \
		SkeinDialogEffect.Type.ACTOR_JOINED:
			if effect.type == SkeinDialogEffect.Type.LINE_STARTED:
				_line_text = ""
				label.text = ""
				label.visible_characters = 0
			_consume_next_effect()

		SkeinDialogEffect.Type.DONE:
			_on_done()


func _update_display() -> void:
	label.text = _line_text
	label.visible_characters = _line_text.length()


func _start_typing_timer() -> void:
	_typing_timer = _typing_speed / engine.speed


func _on_done() -> void:
	hide()
	if engine:
		engine.queue_free()
		engine = null