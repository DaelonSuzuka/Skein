@tool
extends Button

# ******************************************************************************

enum Fonts {
	AntDesign,
	Entypo,
	EvilIcons,
	Feather,
	FontAwesome,
	FontAwesome5,
	Fontisto,
	Foundation,
	Ionicons,
	MaterialCommunityIcons,
	MaterialIcons,
	Octicons,
	SimpleLineIcons,
	Zocial
}

const FONT_DIR := 'res://addons/skein/resources/vector_icons/fonts/'

@export var icon_set := Fonts.FontAwesome:
	set(name):
		icon_set = name
		var font = load(str(FONT_DIR, Fonts.find_key(name), ".gd"))
		if font != null:
			font_map = font.Cheatsheet

			if icon_name not in font_map:
				for key in font_map:
					icon_name = key
					break

			add_theme_font_override('font', font.FontData)
			update_content()
			notify_property_list_changed()

@export var icon_size := 16:
	set(p_size):
		icon_size = p_size
		add_theme_font_size_override('font_size', p_size)

var icon_name := "ios-analytics":
	set(p_icon):
		icon_name = p_icon
		var iconcode = ""
		if p_icon in font_map:
			iconcode = font_map[p_icon]
		set_text(iconcode)

func _get_property_list():
	var properties = [
		# {
		# 	"name": "icon_set",
		# 	"type": TYPE_INT,
		# 	"hint": PROPERTY_HINT_ENUM,
		# 	"hint_string": ','.join(Fonts.keys()),
		# },
		# {
		# 	"name": "icon_size",
		# 	"type": TYPE_INT,
		# },
		{
			"name": "icon_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ','.join(font_map.keys()),
		}
	]

	return properties

# @export var filter := false:
# 	set(f):
# 		filter = f
# 		if is_inside_tree():
# 			_font.set_use_filter(f)

var font_map = {}
var _font := FontFile.new()

# ******************************************************************************

func _ready():
	self.icon_set = icon_set
	update_content()
	
func update_content():
	self.icon_size = icon_size
	self.icon_name = icon_name
	# self.filter = filter
