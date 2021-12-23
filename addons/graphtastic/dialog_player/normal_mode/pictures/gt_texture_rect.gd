extends TextureRect


export(bool) var is_persistent = false
export(int, "Left", "Center", "Right") var identifier=1
var error_label=null


# Called when the node enters the scene tree for the first time.
var GTD
func set_GTD():
	GTD=get_node("/root/GTD")


func _ready():
	set_GTD()
	self.texture=null
	var _err= GTD.connect("GT_set_pictures", self, "_on_GT_set_pictures")
	_err= GTD.connect("GT_dialog_finished", self, "_on_GT_dialog_finished")


func _on_GT_dialog_finished():
	self.texture=null

func _on_GT_set_pictures(pictures):
	#print(pictures)
	if error_label != null:
		error_label.queue_free()
		error_label=null
	var is_valid_picture=false
	var pic = parse_json(pictures)
	pic = pic[identifier]
	if ResourceLoader.exists(pic): 
		var try = load(pic)
		if try is Texture:
			texture=load(pic)
			is_valid_picture=true
	else:
		if pic in GTD.pictures:
			pic=String(GTD.pictures[pic])
			if ResourceLoader.exists(pic): 
				var try = load(pic)
				if try is Texture:
					texture=load(pic)
					is_valid_picture=true
	
	if !is_valid_picture: 
		if texture!=null and is_persistent:
			self.visible=true
		else: 
			texture=null
			if pic == "" or pic == " " or pic == "#":
				self.texture=null
			else:
				create_error_message(pic)

func create_error_message(pic):
	error_label = Label.new()
	self.add_child(error_label)
	error_label.text="no picture in: "+pic
