extends Node2D

@export var conversation: SkeinConversation
@export var another_conversation: SkeinConversation
@export var a_third_conversation: SkeinConversation

@export var target : MethodPickerTarget


func _ready():
	print(conversation)