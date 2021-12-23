tool
extends EditorPlugin

const MainPanel = preload("res://addons/graphtastic/dialog_editor/starter_panel.tscn")
var main_panel_instance


func _enter_tree():
	#The Singleton:	
	add_autoload_singleton ("GTD", "res://addons/graphtastic/helper_classes/gt_variablesdata_singleton.gd")
	
	#add node-types:
	add_custom_type("GTDialog_Textbox", "RichTextLabel", preload("dialog_player/normal_mode/textbox/gt_dialog_textbox.gd"), preload("graphtastic_icon.png"))
	add_custom_type("GTDialog_Choices", "VBoxContainer", preload("dialog_player/normal_mode/choices/gt_vbox_choices.gd"), preload("graphtastic_icon.png"))
	add_custom_type("GTDialog_Picture", "TextureRect", preload("dialog_player/normal_mode/pictures/gt_texture_rect.gd"), preload("graphtastic_icon.png"))
	add_custom_type("GTDialog_SpeakerLabel", "RichTextLabel", preload("dialog_player/normal_mode/speaker/gt_speaker_textbox.gd"), preload("graphtastic_icon.png"))
	
	#Editor in MainPanel:
	main_panel_instance = MainPanel.instance()
	get_editor_interface().get_editor_viewport().add_child(main_panel_instance)
	make_visible(false)


func _exit_tree():
	#remove_custom_type("GraphtasticPlayer")
	remove_autoload_singleton ("GTP")
	if main_panel_instance:
		main_panel_instance.queue_free()


func has_main_screen():
	return true


func make_visible(visible):
	if visible:
		main_panel_instance.show()
	else:
		main_panel_instance.hide()


func get_plugin_name():
	return "GraphTasticDialog"


func get_plugin_icon():
	# Must return some kind of Texture for the icon.
	return preload("graphtastic_icon.png")			#get_editor_interface().get_base_control().get_icon("Node", "EditorIcons")
