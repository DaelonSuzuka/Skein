@tool
extends Node

# ******************************************************************************

func reparent_node(node: Node, new_parent: Node, legible_unique_name:=false) -> void:
	if !is_instance_valid(node) or !is_instance_valid(new_parent):
		return

	var old_parent = node.get_parent()
	if old_parent:
		old_parent.remove_child(node)

	new_parent.add_child(node, legible_unique_name)

# ******************************************************************************

func try_connect(src, sig, dest, method, args=[], flags=0):
	if dest.has_method(method):
		if !src.is_connected(sig, Callable(dest, method)):
			src.connect(sig, Callable(dest, method).bind(args), flags)

func connect_all(src: Node, dest: Node, prefix:=''):
	for sig in src.get_signal_list():
		if dest.has_method(prefix + sig.name):
			src.connect(sig.name, dest.get(prefix + sig.name))

# ******************************************************************************

func get_all_children(node: Node, _children={}) -> Dictionary:
	_children[node.get_path()] = node

	for child in node.get_children():
		_children[child.get_path()] = child
		if child.get_child_count():
			get_all_children(child, _children)

	return _children