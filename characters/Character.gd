tool
extends Node2D

# ******************************************************************************

export var color := Color()

onready var Portrait = $Portrait
onready var BlipPlayer = get_node_or_null('BlipPlayer')
var talk_count = 0

# ******************************************************************************

func _ready():
	if Portrait.frames.has_animation('talk'):
		talk_count = Portrait.frames.get_frame_count('talk')

func talk(c):
	if BlipPlayer:
		BlipPlayer.play()

	if talk_count:
		if Portrait.animation != 'talk':
			Portrait.animation = 'talk'

		Portrait.frame = (Portrait.frame + 1) % talk_count

func idle():
	if Portrait.frames.has_animation('idle'):
		Portrait.play('idle')
