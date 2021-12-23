tool
extends "res://addons/graphtastic/dialog_player/normal_mode/choices/gt_vbox_choices.gd"
export(NodePath) var singleton

func set_GTD():
	GTD=get_node(singleton)
