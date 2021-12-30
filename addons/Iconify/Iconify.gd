tool
extends EditorPlugin

const CONTENT = "Control/PanelContainer/Contents/"

const popup_scene = preload("res://addons/Iconify/Iconify.tscn")
var canvas: CanvasLayer
var popup: CenterContainer
var overlay: ColorRect

var icons: Array

var icon_rect: TextureRect
var node_input: LineEdit
var property_input: OptionButton

var apply_button: Button
var cancel_button: Button

var selected: TextureRect
var icon_grid: GridContainer
var new_icon_rect: TextureRect
var new_icon_name: LineEdit

func _enter_tree():
	add_tool_menu_item("Iconify", self, "iconify")
	add_tool_menu_item("Icon Browser", self, "iconify_view_only")
	
	# Custom canvaslayer and popup because window sizing is wack, at least currently (3.3.3.stable)
	canvas = popup_scene.instance()
	overlay = canvas.get_node("ColorRect")
	popup = canvas.get_node("Control")
	popup.theme = get_editor_interface().get_base_control().theme
	icon_rect = canvas.get_node(CONTENT+"TargetNodeInput/InputDivider/TextureRect")
	node_input = canvas.get_node(CONTENT+"TargetNodeInput/InputDivider/LineEdit")
	property_input = canvas.get_node(CONTENT+"TargetPropertyInput/OptionButton")
	icon_grid = canvas.get_node(CONTENT+"IconInput/ScrollContainer/IconGrid")
	new_icon_rect = canvas.get_node(CONTENT+"IconInput/InputDivider/TextureRect")
	new_icon_name = canvas.get_node(CONTENT+"IconInput/InputDivider/LineEdit")
	cancel_button = canvas.get_node(CONTENT+"HBoxContainer/Cancel")
	apply_button = canvas.get_node(CONTENT+"HBoxContainer/Apply")
	icons = Array(get_editor_interface().get_base_control().theme.get_icon_list("EditorIcons"))
	icons.sort()
	
	for ic in icons:
		var icr = TextureRect.new()
		var ici = get_icon(ic)
		if ici.get_size() != Vector2(16, 16):
			var im = ImageTexture.new()
			var dat = ici.get_data()
			dat.resize(16, 16)
			im.create_from_image(dat)
			icr.texture = im
		else:
			icr.texture = ici
		
		icr.hint_tooltip = ic
		icr.connect("gui_input", self, "icon_input", [icr])
		icon_grid.add_child(icr)
	
	node_input.connect("text_changed", self, "iconify_update")
	property_input.connect("item_selected", self, "iconify_update")
	new_icon_name.connect("text_changed", self, "iconify_search_update")
	apply_button.connect("pressed", self, "apply")
	cancel_button.connect("pressed", popup, "hide")
	cancel_button.connect("pressed", overlay, "hide")
	
	iconify_update()
	get_editor_interface().get_editor_viewport().add_child(canvas)
	popup.get_node("PanelContainer").add_stylebox_override("panel", popup.get_stylebox("panel", "WindowDialog"))
	hide_popup()

func icon_input(event, icon):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == BUTTON_LEFT:
			selected = icon
			iconify_update()

func iconify(_d = null):
	var selected_nodes = get_editor_interface().get_selection().get_transformable_selected_nodes()
	if selected_nodes.size() > 0:
		var selected_node = get_editor_interface().get_selection().get_transformable_selected_nodes()[0]
		var selected_node_path = selected_node.get_path()
		var properties = selected_node.get_property_list()
		
		icon_rect.texture = get_icon(selected_node.get_class())
		node_input.text = selected_node_path
		
		property_input.clear()
		for p in properties:
			if p["class_name"] == "Texture":
				property_input.add_item(p.name)
		
		if property_input.items.size() == 0:
			show_error(
				"Error",
				"No texture properties found on selected node. If you just want to search for icons use ctrl+I"
			)
		else:
			show_input(true)
			show_popup()
			iconify_update()
	else:
		show_error(
			"Error",
			"Please select a node before using Iconify. If you just want to search for icons use ctrl+I"
		)

func iconify_view_only(_d = null):
	show_input(false)
	show_popup()

func iconify_search_update(new_text: String):
	if new_text.empty():
		for ic in icon_grid.get_children():
			ic.visible = true
	else:
		for ic in icon_grid.get_children():
			ic.visible = new_text.is_subsequence_ofi(ic.hint_tooltip)

# Null arguments for signals with more arguments
func iconify_update(_d = null, _d2 = null, _d3 = null):
	apply_button.disabled = \
		property_input.items.size() == 0 || \
		node_input.text.length() == 0 || \
		!selected
	
	if !selected:
		new_icon_rect.visible = false
	else:
		new_icon_rect.visible = true
		new_icon_rect.texture = selected.texture
		new_icon_name.text = selected.hint_tooltip

func apply():
	get_node(node_input.text).set(
		property_input.get_item_text(property_input.selected),
		get_icon(selected.hint_tooltip)
	)
	hide_popup()

func show_error(error_title: String, error_content: String):
	var p = AcceptDialog.new()
	p.window_title = error_title
	p.dialog_text = error_content
	p.popup_exclusive = true
	p.connect("popup_hide", p, "queue_free")
	popup.add_child(p)
	p.popup_centered()

func get_icon(icon_name: String) -> Texture:
	return get_editor_interface().get_base_control().theme.get_icon(icon_name, "EditorIcons")

func show_input(target: bool):
	canvas.get_node(CONTENT+"TargetNodeInput").visible = target
	canvas.get_node(CONTENT+"TargetPropertyInput").visible = target
	if target:
		cancel_button.size_flags_horizontal = Control.SIZE_FILL
	else:
		cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.visible = target
	apply_button.disabled = !target

func show_popup():
	new_icon_name.grab_focus()
	popup.show()
	overlay.show()

func hide_popup():
	popup.hide()
	overlay.hide()

func _exit_tree():
	if canvas:
		canvas.queue_free()
	remove_tool_menu_item("Iconify")
	remove_tool_menu_item("Icon Browser")

# Shortcuts
func _unhandled_input(event):
	if canvas:
		if event is InputEventKey:
			if event.control && event.scancode == KEY_I && event.pressed && !event.echo:
				if event.shift:
					iconify(null)
				else:
					iconify_view_only()
			if popup.visible:
				if event.pressed && event.scancode == KEY_ESCAPE:
					hide_popup()
				if event.pressed && event.scancode == KEY_ENTER && !apply_button.disabled && apply_button.visible:
					apply()
