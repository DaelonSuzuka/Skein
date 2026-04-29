class_name SkeinDialogEffect
extends RefCounted

enum Type {
	# Display effects — may block the renderer loop
	CHAR,           # Single printable character
	PAUSE,          # Delay (duration in value)
	INSTANT,        # Instant text chunk (BBCode, pipe, random inline)
	LINE_END,       # End of line, renderer waits for input

	# Choice effects — block the renderer loop
	CHOICES,        # Dict of choices, renderer waits for selection

	# Directive effects — may carry UI-visible changes
	DIRECTIVE,      # Directive dict (show, hide, speed, set_name, etc.)

	# Metadata effects — informational, renderer loop continues
	# These replace the old signal system
	SPEAKER_CHANGED,  # value = { "new_name": String, "prev_name": String }
	NODE_STARTED,     # value = node_id (String or int)
	LINE_STARTED,     # value = { "node_id": String, "line_number": int }
	ACTOR_JOINED,     # value = actor Node

	# Terminal
	DONE,            # Conversation complete
}

var type: Type
var value: Variant

func _init(t: Type, v: Variant = null):
	type = t
	value = v

func is_blocking() -> bool:
	return type in [Type.CHAR, Type.PAUSE, Type.LINE_END, Type.CHOICES, Type.DONE]