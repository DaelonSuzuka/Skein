@tool
extends Resource
class_name SkeinConversation

@export var file := ''
@export var node := ''
@export var line := ''

func make_path() -> String:
	var str = file.trim_suffix('.yarn')

	if node:
		str += ':' + node
	if line:
		str += ':' + line

	return str
