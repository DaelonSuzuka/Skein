extends Node2D

# ******************************************************************************

export var color := Color()

onready var portrait = $Portrait

# ******************************************************************************

func _ready():
	pass

func blip(c):
	prints(name, c)