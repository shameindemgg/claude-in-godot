@tool
class_name CatalystSpatialHandler
extends RefCounted
## Handles spatial analysis: layout analysis, placement suggestions, overlap detection, distance measurement.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- spatial.analyze_layout ---
func analyze_layout(params: Dictionary) -> Dictionary:
	var root_path: String = params.get("node_path", "")
	var include_2d: bool = params.get("include_2d", true)
	var include_3d: bool = params.get("include_3d", true)

	var root := _get_node(root_path)
	if root == null:
		return _error(-32001, "Node not found: '%s'" % root_path)

	var nodes_2d := []
	var nodes_3d := []
	var bounds_2d := Rect2()
	var bounds_3d := AABB()
	var first_2d := true
	var first_3d := true

	_collect_spatial_nodes(root, nodes_2d, nodes_3d, include_2d, include_3d)

	# Compute 2D bounds
	for info in nodes_2d:
		var pos: Vector2 = info["position"]
		var rect := Rect2(pos, Vector2.ZERO)
		if first_2d:
			bounds_2d = rect
			first_2d = false
		else:
			bounds_2d = bounds_2d.merge(rect)

	# Compute 3D bounds
	for info in nodes_3d:
		var pos: Vector3 = info["position"]
		var aabb := AABB(pos, Vector3.ZERO)
		if first_3d:
			bounds_3d = aabb
			first_3d = false
		else:
			bounds_3d = bounds_3d.merge(aabb)

	return {
		"success": true,
		"nodes_2d": nodes_2d.size(),
		"nodes_3d": nodes_3d.size(),
		"bounds_2d": {"position": {"x": bounds_2d.position.x, "y": bounds_2d.position.y}, "size": {"x": bounds_2d.size.x, "y": bounds_2d.size.y}} if not first_2d else null,
		"bounds_3d": {"position": {"x": bounds_3d.position.x, "y": bounds_3d.position.y, "z": bounds_3d.position.z}, "size": {"x": bounds_3d.size.x, "y": bounds_3d.size.y, "z": bounds_3d.size.z}} if not first_3d else null,
		"layout_2d": nodes_2d.slice(0, 50),
		"layout_3d": nodes_3d.slice(0, 50),
	}


# --- spatial.suggest_placement ---
func suggest_placement(params: Dictionary) -> Dictionary:
	var node_type: String = params.get("node_type", "")
	var context: String = params.get("context", "")
	var parent_path: String = params.get("parent_path", "")

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	# Analyze existing children to suggest placement
	var child_positions_2d := []
	var child_positions_3d := []

	for child in parent.get_children():
		if child is Node2D:
			child_positions_2d.append(child.position)
		elif child is Node3D:
			child_positions_3d.append(child.position)

	var suggested := {}
	if child_positions_3d.size() > 0:
		# Suggest placing offset from the average position
		var avg := Vector3.ZERO
		for pos in child_positions_3d:
			avg += pos
		avg /= child_positions_3d.size()
		suggested = {"x": avg.x + 2.0, "y": avg.y, "z": avg.z + 2.0}
	elif child_positions_2d.size() > 0:
		var avg := Vector2.ZERO
		for pos in child_positions_2d:
			avg += pos
		avg /= child_positions_2d.size()
		suggested = {"x": avg.x + 64.0, "y": avg.y}
	else:
		suggested = {"x": 0, "y": 0, "z": 0}

	return {
		"success": true,
		"node_type": node_type,
		"parent": str(parent.get_path()),
		"suggested_position": suggested,
		"existing_children": parent.get_child_count(),
		"context": context,
	}


# --- spatial.detect_overlaps ---
func detect_overlaps(params: Dictionary) -> Dictionary:
	var root_path: String = params.get("node_path", "")
	var threshold: float = params.get("threshold", 0.01)

	var root := _get_node(root_path)
	if root == null:
		return _error(-32001, "Node not found: '%s'" % root_path)

	var overlaps := []
	var nodes_3d: Array[Node3D] = []
	_collect_node3d(root, nodes_3d)

	# Check all pairs for overlap
	for i in range(nodes_3d.size()):
		for j in range(i + 1, nodes_3d.size()):
			var a := nodes_3d[i]
			var b := nodes_3d[j]
			var dist := a.global_position.distance_to(b.global_position)
			if dist < threshold:
				overlaps.append({
					"node_a": str(a.get_path()),
					"node_b": str(b.get_path()),
					"distance": dist,
					"type": "position_overlap",
				})

	return {
		"success": true,
		"checked_nodes": nodes_3d.size(),
		"overlap_count": overlaps.size(),
		"overlaps": overlaps,
	}


# --- spatial.measure_distance ---
func measure_distance(params: Dictionary) -> Dictionary:
	var from_path: String = params.get("from_path", "")
	var to_path: String = params.get("to_path", "")

	var from_node := _get_node(from_path)
	var to_node := _get_node(to_path)

	if from_node == null:
		return _error(-32001, "From node not found: '%s'" % from_path)
	if to_node == null:
		return _error(-32001, "To node not found: '%s'" % to_path)

	var result := {"success": true, "from": from_path, "to": to_path}

	if from_node is Node3D and to_node is Node3D:
		var a: Node3D = from_node
		var b: Node3D = to_node
		var dist := a.global_position.distance_to(b.global_position)
		result["distance"] = dist
		result["from_position"] = {"x": a.global_position.x, "y": a.global_position.y, "z": a.global_position.z}
		result["to_position"] = {"x": b.global_position.x, "y": b.global_position.y, "z": b.global_position.z}
		result["dimension"] = "3d"
	elif from_node is Node2D and to_node is Node2D:
		var a: Node2D = from_node
		var b: Node2D = to_node
		var dist := a.global_position.distance_to(b.global_position)
		result["distance"] = dist
		result["from_position"] = {"x": a.global_position.x, "y": a.global_position.y}
		result["to_position"] = {"x": b.global_position.x, "y": b.global_position.y}
		result["dimension"] = "2d"
	else:
		return _error(-32003, "Both nodes must be either Node2D or Node3D")

	return result


# ---------- Helpers ----------

func _collect_spatial_nodes(node: Node, list_2d: Array, list_3d: Array, inc_2d: bool, inc_3d: bool) -> void:
	if inc_2d and node is Node2D:
		var n2d: Node2D = node
		list_2d.append({"name": n2d.name, "class": n2d.get_class(), "path": str(n2d.get_path()), "position": n2d.global_position, "rotation": n2d.rotation})
	if inc_3d and node is Node3D:
		var n3d: Node3D = node
		list_3d.append({"name": n3d.name, "class": n3d.get_class(), "path": str(n3d.get_path()), "position": n3d.global_position, "rotation": {"x": n3d.rotation.x, "y": n3d.rotation.y, "z": n3d.rotation.z}})
	for child in node.get_children():
		_collect_spatial_nodes(child, list_2d, list_3d, inc_2d, inc_3d)


func _collect_node3d(node: Node, list: Array[Node3D]) -> void:
	if node is Node3D:
		list.append(node as Node3D)
	for child in node.get_children():
		_collect_node3d(child, list)


func _get_scene_root() -> Node:
	return EditorInterface.get_edited_scene_root()


func _get_node(path: String) -> Node:
	if path.is_empty():
		return _get_scene_root()
	var scene_root := _get_scene_root()
	if scene_root == null:
		return null
	if path.begins_with("/root/"):
		var rel := path.substr(6)
		return scene_root.get_tree().root.get_node_or_null(rel)
	elif path == "/root":
		return scene_root
	else:
		return scene_root.get_node_or_null(path)


func _error(code: int, message: String, data: Variant = null) -> Dictionary:
	var err := {"error": {"code": code, "message": message}}
	if data != null:
		err["error"]["data"] = data
	return err
