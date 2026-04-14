@tool
class_name CatalystProjectHandler
extends RefCounted

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


func get_info(_params: Dictionary) -> Dictionary:
	return {
		"success": true,
		"name": ProjectSettings.get_setting("application/config/name", ""),
		"description": ProjectSettings.get_setting("application/config/description", ""),
		"version": ProjectSettings.get_setting("application/config/version", ""),
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
		"godot_version": Engine.get_version_info(),
	}


func get_settings(params: Dictionary) -> Dictionary:
	var keys: Array = params.get("keys", [])
	var settings := {}

	if keys.size() > 0:
		for key in keys:
			if ProjectSettings.has_setting(str(key)):
				settings[str(key)] = CatalystTypeConverter.variant_to_json(
					ProjectSettings.get_setting(str(key)))
			else:
				settings[str(key)] = null
	else:
		var common := [
			"application/config/name",
			"application/run/main_scene",
			"display/window/size/viewport_width",
			"display/window/size/viewport_height",
			"rendering/renderer/rendering_method",
			"physics/2d/default_gravity",
			"physics/3d/default_gravity",
		]
		for key in common:
			if ProjectSettings.has_setting(key):
				settings[key] = CatalystTypeConverter.variant_to_json(
					ProjectSettings.get_setting(key))

	return {"success": true, "settings": settings}


func set_settings(params: Dictionary) -> Dictionary:
	var settings: Dictionary = params.get("settings", {})
	var set_keys := []

	for key in settings:
		var val := CatalystTypeConverter.json_to_variant(settings[key])
		ProjectSettings.set_setting(str(key), val)
		set_keys.append(str(key))

	ProjectSettings.save()
	return {"success": true, "settings_set": set_keys, "message": "Set %d project settings" % set_keys.size()}


func get_filesystem(params: Dictionary) -> Dictionary:
	var dir_path: String = params.get("path", "res://")
	var depth: int = params.get("depth", 3)

	var tree := _build_file_tree(dir_path, depth, 0)
	return {"success": true, "tree": tree}


func search_files(params: Dictionary) -> Dictionary:
	var pattern: String = params.get("pattern", "")
	var search_path: String = params.get("path", "res://")

	if pattern.is_empty():
		return _error(-32600, "Missing 'pattern' parameter")

	var results := []
	_search_files_recursive(search_path, pattern, results)
	return {"success": true, "pattern": pattern, "files": results, "count": results.size()}


func get_input_actions(_params: Dictionary) -> Dictionary:
	var actions := {}
	for prop in ProjectSettings.get_property_list():
		var name_str: String = prop["name"]
		if name_str.begins_with("input/"):
			var action_name := name_str.substr(6)
			var val: Variant = ProjectSettings.get_setting(name_str)
			if val is Dictionary:
				var events := []
				var dict_val: Dictionary = val
				if dict_val.has("events"):
					for event in dict_val["events"]:
						events.append(str(event))
				actions[action_name] = {"deadzone": dict_val.get("deadzone", 0.5), "events": events}
	return {"success": true, "actions": actions, "count": actions.size()}


func set_input_action(params: Dictionary) -> Dictionary:
	var action_name: String = params.get("action_name", "")
	var events: Array = params.get("events", [])

	if action_name.is_empty():
		return _error(-32600, "Missing 'action_name' parameter")

	var setting_key := "input/" + action_name
	var action_data := {"deadzone": 0.5, "events": events}
	ProjectSettings.set_setting(setting_key, action_data)
	ProjectSettings.save()

	return {"success": true, "action": action_name, "message": "Input action '%s' updated" % action_name}


func delete_input_action(params: Dictionary) -> Dictionary:
	var action_name: String = params.get("action_name", "")
	if action_name.is_empty():
		return _error(-32600, "Missing 'action_name' parameter")

	var setting_key := "input/" + action_name
	if not ProjectSettings.has_setting(setting_key):
		return _error(-32004, "Input action '%s' not found" % action_name)

	ProjectSettings.set_setting(setting_key, null)
	ProjectSettings.save()

	return {"success": true, "message": "Deleted input action '%s'" % action_name}


func get_statistics(_params: Dictionary) -> Dictionary:
	var stats := {"scripts": 0, "scenes": 0, "resources": 0, "images": 0, "audio": 0, "other": 0}
	_count_files("res://", stats)
	return {"success": true, "statistics": stats}


func uid_to_path(params: Dictionary) -> Dictionary:
	var uid: String = params.get("uid", "")
	if uid.is_empty():
		return _error(-32600, "Missing 'uid' parameter")

	var path := ResourceUID.get_id_path(ResourceUID.text_to_id(uid))
	if path.is_empty():
		return _error(-32004, "UID '%s' not found" % uid)

	return {"success": true, "uid": uid, "path": path}


# --- Helpers ---

func _build_file_tree(dir_path: String, max_depth: int, current_depth: int) -> Dictionary:
	var result := {"name": dir_path.get_file(), "path": dir_path, "type": "directory", "children": []}

	if max_depth >= 0 and current_depth >= max_depth:
		return result

	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var full_path := dir_path.path_join(file_name)
			if dir.current_is_dir():
				(result["children"] as Array).append(
					_build_file_tree(full_path, max_depth, current_depth + 1))
			else:
				(result["children"] as Array).append({
					"name": file_name,
					"path": full_path,
					"type": "file",
					"extension": file_name.get_extension(),
				})
		file_name = dir.get_next()
	dir.list_dir_end()

	return result


func _search_files_recursive(dir_path: String, pattern: String, results: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var full_path := dir_path.path_join(file_name)
			if dir.current_is_dir():
				_search_files_recursive(full_path, pattern, results)
			elif file_name.matchn(pattern):
				results.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _count_files(dir_path: String, stats: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var full_path := dir_path.path_join(file_name)
			if dir.current_is_dir():
				_count_files(full_path, stats)
			else:
				var ext := file_name.get_extension().to_lower()
				if ext == "gd":
					stats["scripts"] += 1
				elif ext == "tscn":
					stats["scenes"] += 1
				elif ext in ["tres", "res"]:
					stats["resources"] += 1
				elif ext in ["png", "jpg", "jpeg", "svg", "webp"]:
					stats["images"] += 1
				elif ext in ["wav", "ogg", "mp3"]:
					stats["audio"] += 1
				else:
					stats["other"] += 1
		file_name = dir.get_next()
	dir.list_dir_end()


func _error(code: int, message: String, data: Variant = null) -> Dictionary:
	var err := {"error": {"code": code, "message": message}}
	if data != null:
		err["error"]["data"] = data
	return err
