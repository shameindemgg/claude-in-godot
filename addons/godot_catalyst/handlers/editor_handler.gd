@tool
class_name CatalystEditorHandler
extends RefCounted

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


func get_state(_params: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	var selection := EditorInterface.get_selection()
	var selected := selection.get_selected_nodes()

	return {
		"success": true,
		"current_scene": root.scene_file_path if root else "",
		"scene_root": root.name if root else "",
		"selected_count": selected.size(),
		"selected_nodes": _serialize_paths(selected),
	}


func get_selected(_params: Dictionary) -> Dictionary:
	var selection := EditorInterface.get_selection()
	var selected := selection.get_selected_nodes()
	var nodes := []
	for node in selected:
		nodes.append(CatalystNodeSerializer.serialize_node(node))
	return {"success": true, "nodes": nodes, "count": nodes.size()}


func select(params: Dictionary) -> Dictionary:
	var node_paths: Array = params.get("node_paths", [])
	var selection := EditorInterface.get_selection()
	selection.clear()

	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _error(-32002, "No scene open")

	var selected := []
	for path in node_paths:
		var node := root.get_node_or_null(str(path))
		if node:
			selection.add_node(node)
			selected.append(str(node.get_path()))

	return {"success": true, "selected": selected, "count": selected.size()}


func undo(_params: Dictionary) -> Dictionary:
	var ur := EditorInterface.get_editor_undo_redo()
	if ur.has_undo():
		ur.undo()
		return {"success": true, "message": "Undo performed"}
	return {"success": false, "message": "Nothing to undo"}


func redo(_params: Dictionary) -> Dictionary:
	var ur := EditorInterface.get_editor_undo_redo()
	if ur.has_redo():
		ur.redo()
		return {"success": true, "message": "Redo performed"}
	return {"success": false, "message": "Nothing to redo"}


func get_settings(params: Dictionary) -> Dictionary:
	var keys: Array = params.get("keys", [])
	var settings := {}

	if keys.size() > 0:
		for key in keys:
			var val := EditorInterface.get_editor_settings().get_setting(str(key))
			settings[str(key)] = CatalystTypeConverter.variant_to_json(val)
	else:
		# Return a curated set of common settings
		var common := [
			"text_editor/theme/color_theme",
			"interface/theme/preset",
			"text_editor/behavior/indent/type",
			"text_editor/behavior/indent/size",
			"filesystem/file_dialog/show_hidden_files",
		]
		for key in common:
			if EditorInterface.get_editor_settings().has_setting(key):
				settings[key] = CatalystTypeConverter.variant_to_json(
					EditorInterface.get_editor_settings().get_setting(key))

	return {"success": true, "settings": settings}


func set_settings(params: Dictionary) -> Dictionary:
	var settings: Dictionary = params.get("settings", {})
	var set_keys := []

	for key in settings:
		var val := CatalystTypeConverter.json_to_variant(settings[key])
		EditorInterface.get_editor_settings().set_setting(str(key), val)
		set_keys.append(str(key))

	return {"success": true, "settings_set": set_keys, "message": "Set %d editor settings" % set_keys.size()}


func screenshot(_params: Dictionary) -> Dictionary:
	# Capture the editor viewport
	var viewport := EditorInterface.get_editor_viewport_2d()
	if viewport == null:
		viewport = EditorInterface.get_editor_viewport_3d()
	if viewport == null:
		return _error(-32005, "No editor viewport available")

	var tex := viewport.get_texture()
	if tex == null:
		return _error(-32005, "Viewport has no texture")

	var img := tex.get_image()
	if img == null:
		return _error(-32005, "Failed to capture viewport image")

	var save_path := "res://.tmp_catalyst_screenshot.png"
	var err := img.save_png(save_path)
	if err != OK:
		return _error(-32008, "Failed to save screenshot: %s" % error_string(err))

	return {"success": true, "path": save_path, "size": [img.get_width(), img.get_height()], "message": "Screenshot saved to '%s'" % save_path}


func screenshot_game(_params: Dictionary) -> Dictionary:
	return _error(-32005, "Game screenshots require the game to be running. Use build.play_scene first.")


func set_main_screen(params: Dictionary) -> Dictionary:
	var screen: String = params.get("screen", "")
	if screen.is_empty():
		return _error(-32600, "Missing 'screen' parameter. Use '2D', '3D', 'Script', or 'AssetLib'")

	EditorInterface.set_main_screen_editor(screen)
	return {"success": true, "screen": screen, "message": "Switched to '%s' editor" % screen}


func get_errors(_params: Dictionary) -> Dictionary:
	# No direct API for editor errors in Godot 4
	return {"success": true, "errors": [], "message": "Editor error list not directly accessible via API. Check the Output panel in Godot."}


func clear_output(_params: Dictionary) -> Dictionary:
	return {"success": true, "message": "Output clearing not directly accessible via API"}


# --- Helpers ---

func _serialize_paths(nodes: Array[Node]) -> Array:
	var paths := []
	for node in nodes:
		paths.append(str(node.get_path()))
	return paths


func _error(code: int, message: String, data: Variant = null) -> Dictionary:
	var err := {"error": {"code": code, "message": message}}
	if data != null:
		err["error"]["data"] = data
	return err
