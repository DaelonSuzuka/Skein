@tool
class_name SkeinSignRenderer
extends Control

## Sign/terminal renderer. Text auto-scrolls with no typewriter effect.
## No choices, no portrait, no speaker name. Meant for signs, terminals,
## computer screens, graffiti — any read-only text. For world-space placement,
## put this Control inside a SubViewport or parent it to a game-world node.

const SkeinDialogEngine = preload("res://addons/skein/engine/DialogEngine.gd")
const SkeinDialogEffect = preload("res://addons/skein/engine/DialogEffect.gd")

@onready var text_display: RichTextLabel = %SignText

var engine: SkeinDialogEngine
var _line_text: String = ""
var _advance_delay: float = 0.02  # Delay between effects when draining


func _process(delta: float) -> void:
	if not engine:
		return

	if not engine.state == SkeinDialogEngine.State.LINE_ACTIVE:
		return

	# Signs drain the effect stream as fast as possible — no typewriter
	_consume_next_effect()


func start(conversation: String, options: Dictionary = {}) -> void:
	engine = SkeinDialogEngine.new()
	add_child(engine)
	engine.start(conversation, options)
	show()
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

		SkeinDialogEffect.Type.INSTANT:
			_line_text += effect.value
			_update_display()

		SkeinDialogEffect.Type.PAUSE:
			pass  # Signs ignore pauses

		SkeinDialogEffect.Type.LINE_END:
			_line_text += "\n"
			_update_display()
			engine.advance()

		SkeinDialogEffect.Type.CHOICES:
			# Signs don't do choices
			_on_done()

		SkeinDialogEffect.Type.DIRECTIVE:
			pass  # Signs ignore most directives

		SkeinDialogEffect.Type.SPEAKER_CHANGED, \
		SkeinDialogEffect.Type.NODE_STARTED, \
		SkeinDialogEffect.Type.LINE_STARTED, \
		SkeinDialogEffect.Type.ACTOR_JOINED:
			if effect.type == SkeinDialogEffect.Type.LINE_STARTED:
				# First line starts fresh, subsequent lines append
				if _line_text == "":
					_line_text = ""
			# Continue draining — metadata never blocks
			if engine.state == SkeinDialogEngine.State.LINE_ACTIVE:
				_consume_next_effect()

		SkeinDialogEffect.Type.DONE:
			_on_done()


func _update_display() -> void:
	if text_display:
		text_display.text = _line_text


func _on_done() -> void:
	# Signs stay visible until the game hides them
	pass