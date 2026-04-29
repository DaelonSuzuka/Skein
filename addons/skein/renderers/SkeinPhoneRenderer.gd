@tool
class_name SkeinPhoneRenderer
extends Control

## Phone-style side-screen renderer. Character portrait appears on one side,
## text types in a pane. The game continues running — the phone is non-modal.
## Inspired by Isotope's DialoguePane — the phone overlay animates in when a
## character starts speaking and can be dismissed while the game runs.

const SkeinDialogEngine = preload("res://addons/skein/engine/DialogEngine.gd")
const SkeinDialogEffect = preload("res://addons/skein/engine/DialogEffect.gd")

@onready var text_box: RichTextLabel = %PhoneText
@onready var name_label: Label = %PhoneName
@onready var next_indicator: Control = %PhoneNext
@onready var options_container: Container = %PhoneOptions
@onready var portrait_container: Control = %PhonePortrait

var engine: SkeinDialogEngine
var _typing_speed: float = 0.03
var _typing_timer: float = 0.0
var _line_text: String = ""


func _process(delta: float) -> void:
	if not engine:
		return
	if not engine.state == SkeinDialogEngine.State.LINE_ACTIVE:
		return

	if _typing_timer > 0.0:
		_typing_timer -= delta
		return

	_consume_next_effect()


## ----------
## Public
## ----------

func start(conversation: String, options: Dictionary = {}) -> void:
	engine = SkeinDialogEngine.new()
	add_child(engine)
	engine.start(conversation, options)
	show()
	_consume_next_effect()


func advance() -> void:
	next_indicator.visible = false
	_clear_options()
	engine.advance()
	if engine.state == SkeinDialogEngine.State.LINE_ACTIVE:
		_consume_next_effect()


func choose(choice_key: String) -> void:
	_clear_options()
	engine.choose(choice_key)
	if engine.state == SkeinDialogEngine.State.LINE_ACTIVE:
		_consume_next_effect()


func dismiss() -> void:
	if engine:
		engine.stop()
	_on_done()


## ----------
## Input (non-blocking — only responds when focused)
## ----------

func _input(event: InputEvent) -> void:
	if not engine:
		return
	if not has_focus():
		return

	if event.is_action_pressed("ui_accept"):
		if engine.state == SkeinDialogEngine.State.WAITING_INPUT:
			advance()
		elif engine.state == SkeinDialogEngine.State.LINE_ACTIVE:
			# Fast-forward
			_line_text = ""
			# Drain remaining effects for this line
			while engine.state == SkeinDialogEngine.State.LINE_ACTIVE:
				var effect = engine.next_effect()
				if not effect:
					break
				if effect.type == SkeinDialogEffect.Type.CHAR:
					_line_text += effect.value
				elif effect.type == SkeinDialogEffect.Type.INSTANT:
					_line_text += effect.value
				elif effect.type == SkeinDialogEffect.Type.LINE_END:
					_on_line_end()
					break
				elif effect.type == SkeinDialogEffect.Type.PAUSE:
					pass
				elif effect.type == SkeinDialogEffect.Type.DONE:
					_on_done()
					return
				elif effect.type == SkeinDialogEffect.Type.DIRECTIVE:
					_apply_directive(effect.value)
				elif effect.type == SkeinDialogEffect.Type.SPEAKER_CHANGED:
					_update_speaker(effect.value)
			text_box.text = _line_text
			text_box.visible_characters = -1


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
			_on_line_end()

		SkeinDialogEffect.Type.CHOICES:
			_show_choices(effect.value)

		SkeinDialogEffect.Type.DIRECTIVE:
			_apply_directive(effect.value)
			_consume_next_effect()

		SkeinDialogEffect.Type.SPEAKER_CHANGED:
			_update_speaker(effect.value)
			_consume_next_effect()

		SkeinDialogEffect.Type.NODE_STARTED, \
		SkeinDialogEffect.Type.LINE_STARTED, \
		SkeinDialogEffect.Type.ACTOR_JOINED:
			if effect.type == SkeinDialogEffect.Type.LINE_STARTED:
				_line_text = ""
				text_box.text = ""
				text_box.visible_characters = 0
			elif effect.type == SkeinDialogEffect.Type.ACTOR_JOINED:
				_on_actor_joined(effect.value)
			_consume_next_effect()

		SkeinDialogEffect.Type.DONE:
			_on_done()


## ----------
## Display
## ----------

func _update_display() -> void:
	text_box.text = _line_text
	text_box.visible_characters = _line_text.length()


func _start_typing_timer() -> void:
	_typing_timer = _typing_speed / engine.speed


func _on_line_end() -> void:
	text_box.visible_characters = -1
	next_indicator.visible = true


func _on_done() -> void:
	hide()
	if engine:
		engine.queue_free()
		engine = null


## ----------
## Speaker & portrait
## ----------

func _update_speaker(data: Dictionary) -> void:
	var new_name = data.get("new_name", "")
	name_label.text = new_name
	name_label.visible = new_name != ""

	var speaker = engine.speaker_character
	if speaker and speaker.get("color"):
		name_label.add_theme_color_override("font_color", speaker.color)


func _on_actor_joined(actor: Node) -> void:
	if not portrait_container or not actor:
		return
	if not portrait_container.is_ancestor_of(actor):
		if actor.get_parent():
			actor.get_parent().remove_child(actor)
		portrait_container.add_child(actor)
	for child in portrait_container.get_children():
		if child != actor:
			child.hide()
	actor.show()


## ----------
## Choices
## ----------

func _show_choices(choices: Dictionary) -> void:
	_clear_options()
	for key in choices:
		var choice = choices[key]
		var button = Button.new()
		button.text = choice.get("choice", "")
		button.pressed.connect(choose.bind(key))
		options_container.add_child(button)


func _clear_options() -> void:
	for child in options_container.get_children():
		child.queue_free()


## ----------
## Directives
## ----------

func _apply_directive(dir: Dictionary) -> void:
	if "show_name" in dir:
		name_label.visible = dir.show_name and name_label.text != ""
	if "set_name" in dir:
		name_label.text = dir.set_name
		name_label.visible = dir.set_name != ""