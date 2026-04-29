@tool
class_name SkeinDialogBox
extends Control

## Full-screen modal dialog renderer. Types text character-by-character,
## handles choices, shows speaker name and portrait. Bring-your-own-scene:
## this is a working example, not a base class. Copy and modify it.

const SkeinDialogEngine = preload("res://addons/skein/engine/DialogEngine.gd")
const SkeinDialogEffect = preload("res://addons/skein/engine/DialogEffect.gd")

@onready var text_box: RichTextLabel = %TextBox
@onready var name_label: Label = %Name
@onready var next_indicator: Control = %Next
@onready var options_container: Container = %Options
@onready var portrait_container: Control = %Portrait

var engine: SkeinDialogEngine
var _typing_speed: float = 0.04  # seconds per character
var _typing_timer: float = 0.0
var _fast_forward: bool = false
var _line_text: String = ""


func _process(delta: float) -> void:
	if not engine:
		return
	if not engine.state == SkeinDialogEngine.State.LINE_ACTIVE:
		return

	# Tick the typing timer
	if _typing_timer > 0.0:
		_typing_timer -= delta
		return

	# Timer expired or fast-forward — consume next effect
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
	_fast_forward = false
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


## ----------
## Input
## ----------

func _input(event: InputEvent) -> void:
	if not engine:
		return
	if event.is_action_pressed("ui_accept"):
		if engine.state == SkeinDialogEngine.State.WAITING_INPUT:
			advance()
		elif engine.state == SkeinDialogEngine.State.LINE_ACTIVE:
			_fast_forward = true
	elif event.is_action_pressed("ui_cancel") and engine.state == SkeinDialogEngine.State.LINE_ACTIVE:
		_fast_forward = true


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
			_update_text_display()
			_start_typing_timer()

		SkeinDialogEffect.Type.INSTANT:
			_line_text += effect.value
			_update_text_display()
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
			_handle_metadata(effect)
			_consume_next_effect()

		SkeinDialogEffect.Type.DONE:
			_on_done()


## ----------
## Display
## ----------

func _update_text_display() -> void:
	if _fast_forward:
		text_box.text = _line_text
		text_box.visible_characters = -1
	else:
		text_box.text = _line_text
		text_box.visible_characters = _line_text.length()


func _start_typing_timer() -> void:
	if _fast_forward:
		_typing_timer = 0.0
	else:
		_typing_timer = _typing_speed / engine.speed


func _on_line_end() -> void:
	_fast_forward = false
	text_box.visible_characters = -1
	next_indicator.visible = true


func _on_line_started() -> void:
	_line_text = ""
	text_box.text = ""
	text_box.visible_characters = 0


func _on_done() -> void:
	hide()
	if engine:
		engine.queue_free()
		engine = null


## ----------
## Metadata
## ----------

func _handle_metadata(effect: SkeinDialogEffect) -> void:
	match effect.type:
		SkeinDialogEffect.Type.LINE_STARTED:
			_on_line_started()
		SkeinDialogEffect.Type.ACTOR_JOINED:
			_on_actor_joined(effect.value)


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