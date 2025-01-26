@tool
extends EditorPlugin

# ******************************************************************************

const MethodPickerInspector := preload('./MethodPickerInspectorPlugin.gd')
var inspector_instance

func _enable_plugin():
	print('_enable')

func _disable_plugin():
	print('_disable')

func _enter_tree():
	print('_enter')
	inspector_instance = MethodPickerInspector.new()
	inspector_instance.plugin = self
	add_inspector_plugin(inspector_instance)

func _exit_tree():
	print('_exit')
	if inspector_instance:
		remove_inspector_plugin(inspector_instance)
