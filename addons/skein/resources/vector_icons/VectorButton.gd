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

var icon_set := Fonts.FontAwesome:
	set(value):
		icon_set = value
		var font = load(str(FONT_DIR, Fonts.find_key(value), ".gd"))
		if font != null:
			font_map = font.Cheatsheet

			if icon_name not in font_map:
				for key in font_map:
					icon_name = key
					break
			var _font := FontVariation.new()
			_font.base_font = font.FontData
			set('theme_override_fonts/font',_font)
			update_content()
			notify_property_list_changed()

var filter := true:
	set(value):
		filter = value
		set('texture_filter', 0 if value else 1)

var icon_size := 16:
	set(value):
		icon_size = value
		set('theme_override_font_sizes/font_size',value)

var icon_color := Color.WHITE:
	set(value):
		icon_color = value
		set('theme_override_colors/font_color',value)

var outline_size := 0:
	set(value):
		outline_size = value
		set('theme_override_constants/outline_size',value)
		notify_property_list_changed()

var outline_color := Color.WHITE:
	set(value):
		outline_color = value
		set('theme_override_colors/font_outline_color',value)

var iconcode := ''
var icon_name := '':
	set(value):
		icon_name = value
		iconcode = font_map.get(value, '')
		if !pressed:
			set_text(iconcode)

var pressed_iconcode := ''
var pressed_icon_name := '':
	set(value):
		pressed_icon_name = value
		pressed_iconcode = font_map.get(value, '')
		if pressed:
			set_text(pressed_iconcode)

func _get_property_list():
	var properties = [
		{
			"name": "icon_set",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ','.join(Fonts.keys()),
		},
		{
			"name": "filter",
			"type": TYPE_BOOL,
		},
		{
			"name": "toggle_mode",
			"type": TYPE_BOOL,
		},
		{
			"name": "icon_size",
			"type": TYPE_INT,
		},
		{
			"name": "icon_color",
			"type": TYPE_COLOR,
		},
		{
			"name": "outline_size",
			"type": TYPE_INT,
		},
	]
	if outline_size > 0:
		properties.append({
			"name": "outline_color",
			"type": TYPE_COLOR,
		})

	properties.append({
		"name": "icon_name",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ','.join(font_map.keys()),
	})
	if toggle_mode:
		properties.append({
			"name": "pressed_icon_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ','.join(font_map.keys()),
		})

	return properties

func _set(property: StringName, value: Variant) -> bool:
	if property == "toggle_mode":
		notify_property_list_changed()

	return false

var font_map = {}
var _font := FontVariation.new()

# ******************************************************************************

func _ready():
	self.icon_set = icon_set
	update_content()
	toggled.connect(_on_toggled)

func _on_toggled(on: bool):
	print('toggled')
	if on:
		set_text(pressed_iconcode)
	else:
		set_text(iconcode)

func update_content():
	self.icon_size = icon_size
	self.icon_name = icon_name
	# self.filter = filter
