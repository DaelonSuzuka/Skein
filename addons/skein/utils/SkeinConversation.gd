extends Resource
class_name SkeinConversation

@export var conversation := ''
@export var entry := ''
@export var line := ''

@export var path := ''

func _to_string() -> String:
	var str = conversation

	if entry:
		str += ':' + entry
	if line:
		str += ':' + line

	return str
