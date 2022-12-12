@tool
extends MenuButton

# ******************************************************************************

@export(String, 
	"AntDesign", 
	"Entypo", 
	"EvilIcons", 
	"Feather", 
	"FontAwesome",
	"FontAwesome5", 
	"Fontisto", 
	"Foundation", 
	"Ionicons", 
	"MaterialCommunityIcons",
	"MaterialIcons", 
	"Octicons", 
	"SimpleLineIcons", 
	"Zocial")\
	var icon_set = "Ionicons" : set = _set_icon_set

@export var size = 16 setget _set_size # (int, 0, 1000, 1)
@export var icon_name = "ios-analytics" : set = _set_icon
@export var filter = false : set = _set_filter

var Cheatsheet = {}
var _font = FontFile.new()

func _set_size(p_size):
	size = p_size
	_font.set_size(p_size)

func _set_icon(p_icon):
	icon_name = p_icon
	var iconcode = ""
	if p_icon in Cheatsheet:
		iconcode = Cheatsheet[p_icon]
	set_text(iconcode)

func _set_filter(f):
	filter = f
	if is_inside_tree():
		_font.set_use_filter(f)

func _set_icon_set(name):
	icon_set = name
	var font = load(str('res://addons/diagraph/resources/vector_icons/fonts/', name, ".gd"))
	if font != null:
		self.Cheatsheet = font.Cheatsheet
		_font = FontFile.new()
		_font.set_font_data(font.FontData)
		set("custom_fonts/font", _font)
		update_content()

# ******************************************************************************

func _ready():
	self.icon_set = icon_set
	update_content()
	
func update_content():
	self.size = size
	self.icon_name = icon_name
	self.filter = filter