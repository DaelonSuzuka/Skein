tool
extends "res://addons/graphtastic/dialog_player/normal_mode/pictures/gt_texture_rect.gd"
export(NodePath) var singleton

func set_GTD():
	GTD=get_node(singleton)
