tool
extends Control
signal Dialog_Finished
var resource=null
var variables = {}
var pictures = {}
export(int, 1, 9999) var chapterID = 1
export(int, 1, 9999) var startID = 1

onready var singleton =get_node("Singleton")
onready var pic_center = get_node("Singleton/VBoxContainer/HBoxContainer/VBoxContainer2/TextureRectLEFT")
onready var pic_left =get_node("Singleton/VBoxContainer/HBoxContainer/VBoxContainer2/TextureRectLEFT")
onready var pic_right =get_node("Singleton/VBoxContainer/HBoxContainer/Control/TextureRectRIGHT")
onready var speaker = get_node("Singleton/VBoxContainer/HBoxContainer/VBoxContainer2/TextureRectLEFT/RichTextLabel")
onready var choices = get_node("Singleton/VBoxContainer/HBoxContainer/VBoxContainer/ScrollContainer/VBoxContainer")
onready var textbox =get_node("Singleton/VBoxContainer/RichTextLabel")


func _ready():
	singleton.variables=variables
	singleton.pictures=pictures
	textbox.resource_path=resource #resource_path
	textbox.chapterID=chapterID
	textbox.startID=startID
	textbox._ready()


func _on_Singleton_GT_dialog_finished():
	emit_signal("Dialog_Finished", singleton.variables)
