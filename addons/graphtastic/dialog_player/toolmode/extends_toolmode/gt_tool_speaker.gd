tool
extends "res://addons/graphtastic/dialog_player/normal_mode/speaker/gt_speaker_textbox.gd"
export(NodePath) var singleton

func set_GTD():
	GTD=get_node(singleton)
