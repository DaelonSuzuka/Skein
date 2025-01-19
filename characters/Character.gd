@tool
extends Node2D

# ******************************************************************************

@export var color := Color()

@onready var Portrait: AnimatedSprite2D = get_node_or_null('Portrait')
@onready var BlipPlayer = get_node_or_null('BlipPlayer')

var talk_base = ''
var talk_count = 0
var _mood = ''

# ******************************************************************************

func _ready():
	if Portrait:
		if Portrait.sprite_frames.has_animation('talk'):
			talk_base = 'talk'
		elif Portrait.sprite_frames.has_animation('idle'):
			talk_base = 'idle'

		if talk_base:
			talk_count = Portrait.sprite_frames.get_frame_count(talk_base)

func talk(c):
	if c in [' ', ',', '.']:
		return

	if BlipPlayer:
		BlipPlayer.play()

	if talk_count:
		var talk_anim = talk_base + _mood
		if Portrait.animation != talk_anim:
			Portrait.animation = talk_anim

		Portrait.frame = (Portrait.frame + 1) % talk_count

func idle():
	var idle_anim = 'idle' + _mood
	if Portrait and Portrait.sprite_frames.has_animation(idle_anim):
		Portrait.play(idle_anim)

# ******************************************************************************

func mood(mood_name=''):
	_mood = mood_name
	if _mood:
		_mood = '_' + mood_name

	var talk_anim = talk_base + _mood
	if Portrait and Portrait.sprite_frames.has_animation(talk_anim):
		talk_count = Portrait.sprite_frames.get_frame_count(talk_anim)
	return self
