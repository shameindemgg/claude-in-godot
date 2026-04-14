@tool
class_name CatalystNodeSerializer
extends RefCounted
## Serializes Godot node trees to JSON-compatible dictionaries.


static func serialize_tree(root: Node, depth: int = -1) -> Dictionary:
	return _serialize_node_recursive(root, depth, 0)


static func serialize_node(node: Node) -> Dictionary:
	var data := {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}

	# Script info
	var script := node.get_script() as Script
	if script and script.resource_path:
		data["script"] = script.resource_path

	# Groups
	var groups := node.get_groups()
	if groups.size() > 0:
		data["groups"] = []
		for g in groups:
			if not str(g).begins_with("_"):  # Skip internal groups
				(data["groups"] as Array).append(str(g))

	# Key properties based on node type
	data["properties"] = _get_key_properties(node)

	return data


static func _serialize_node_recursive(node: Node, max_depth: int, current_depth: int) -> Dictionary:
	var data := serialize_node(node)

	if max_depth < 0 or current_depth < max_depth:
		var children := []
		for child in node.get_children():
			children.append(_serialize_node_recursive(child, max_depth, current_depth + 1))
		if children.size() > 0:
			data["children"] = children

	return data


static func _get_key_properties(node: Node) -> Dictionary:
	var props := {}

	# Common spatial properties
	if node is Node2D:
		var n2d := node as Node2D
		props["position"] = CatalystTypeConverter.variant_to_json(n2d.position)
		props["rotation"] = n2d.rotation
		props["scale"] = CatalystTypeConverter.variant_to_json(n2d.scale)
		props["visible"] = n2d.visible
		props["z_index"] = n2d.z_index
	elif node is Node3D:
		var n3d := node as Node3D
		props["position"] = CatalystTypeConverter.variant_to_json(n3d.position)
		props["rotation"] = CatalystTypeConverter.variant_to_json(n3d.rotation)
		props["scale"] = CatalystTypeConverter.variant_to_json(n3d.scale)
		props["visible"] = n3d.visible
	elif node is Control:
		var ctrl := node as Control
		props["position"] = CatalystTypeConverter.variant_to_json(ctrl.position)
		props["size"] = CatalystTypeConverter.variant_to_json(ctrl.size)
		props["visible"] = ctrl.visible

	return props
