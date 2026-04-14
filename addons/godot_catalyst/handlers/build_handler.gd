@tool
class_name CatalystBuildHandler
extends RefCounted
## Handles scene running, stopping, and export operations.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- build.play_scene ---
func play_scene(params: Dictionary) -> Dictionary:
	var scene_path: String = params.get("scene_path", "")

	if scene_path.is_empty():
		EditorInterface.play_current_scene()
		return {
			"success": true,
			"message": "Playing current scene",
		}

	if not FileAccess.file_exists(scene_path):
		return _error(-32004, "Scene file not found: '%s'" % scene_path)

	EditorInterface.play_custom_scene(scene_path)
	return {
		"success": true,
		"scene_path": scene_path,
		"message": "Playing scene '%s'" % scene_path,
	}


# --- build.play_main ---
func play_main(_params: Dictionary) -> Dictionary:
	EditorInterface.play_main_scene()
	return {
		"success": true,
		"message": "Playing main scene",
	}


# --- build.stop ---
func stop(_params: Dictionary) -> Dictionary:
	if not EditorInterface.is_playing_scene():
		return {"success": false, "message": "No scene is currently running"}

	EditorInterface.stop_playing_scene()
	return {
		"success": true,
		"message": "Stopped running scene",
	}


# --- build.is_playing ---
func is_playing(_params: Dictionary) -> Dictionary:
	var playing := EditorInterface.is_playing_scene()
	var playing_scene := EditorInterface.get_playing_scene()
	return {
		"success": true,
		"is_playing": playing,
		"playing_scene": playing_scene,
	}


# --- build.list_exports ---
func list_exports(_params: Dictionary) -> Dictionary:
	var config_path := "res://export_presets.cfg"
	if not FileAccess.file_exists(config_path):
		return {
			"success": true,
			"presets": [],
			"count": 0,
			"message": "No export_presets.cfg found. Configure exports via Project > Export in the editor.",
		}

	var config := ConfigFile.new()
	var err := config.load(config_path)
	if err != OK:
		return _error(-32008, "Failed to read export_presets.cfg: %s" % error_string(err))

	var presets := []
	var idx := 0
	while config.has_section("preset.%d" % idx):
		var section := "preset.%d" % idx
		presets.append({
			"index": idx,
			"name": config.get_value(section, "name", ""),
			"platform": config.get_value(section, "platform", ""),
			"export_path": config.get_value(section, "export_path", ""),
			"runnable": config.get_value(section, "runnable", false),
		})
		idx += 1

	return {"success": true, "presets": presets, "count": presets.size()}


# --- build.export_project ---
func export_project(_params: Dictionary) -> Dictionary:
	return {
		"success": false,
		"message": "Programmatic export is not directly supported via the editor plugin API. "
			+ "Use the Godot CLI for export: "
			+ "'godot --headless --export-release <preset_name> <output_path>'. "
			+ "Use build.list_exports to see available preset names.",
	}


# ---------- Helpers ----------

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
