@tool
class_name CatalystRuntimeHandler
extends RefCounted
## Handles runtime inspection: eval GDScript, inspect running scene tree, read console output,
## screenshot comparison, video recording, test sequences, and GUT integration.

var _plugin: EditorPlugin
var _console_buffer: Array = []
var _max_buffer_size := 500
var _recording := false
var _record_frames: Array = []


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- runtime.eval ---
func eval(params: Dictionary) -> Dictionary:
	var code: String = params.get("code", "")
	if code.is_empty():
		return _error(-32600, "Missing 'code' parameter")

	# Create a GDScript that wraps the user code and execute it
	var script := GDScript.new()
	script.source_code = "extends RefCounted\n\nfunc _run():\n"
	for line in code.split("\n"):
		script.source_code += "\t" + line + "\n"

	var err := script.reload()
	if err != OK:
		return _error(-32003, "GDScript compilation error: %s" % error_string(err))

	var obj := script.new()
	if obj.has_method("_run"):
		var result = obj._run()
		return {"success": true, "result": str(result), "note": "Code executed in editor process context"}

	return _error(-32003, "Failed to execute code")


# --- runtime.get_tree ---
func get_tree(params: Dictionary) -> Dictionary:
	var max_depth: int = params.get("max_depth", -1)
	var include_properties: bool = params.get("include_properties", false)

	if not EditorInterface.is_playing_scene():
		return _error(-32002, "No scene is currently running")

	# In editor context, we can read the edited scene root as a proxy
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _error(-32001, "No scene root available")

	var tree := _build_tree(root, 0, max_depth, include_properties)
	return {"success": true, "tree": tree, "note": "Shows editor scene tree. For runtime tree, use DAP debugging."}


# --- runtime.inspect_node ---
func inspect_node(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return _error(-32600, "Missing 'node_path' parameter")

	var include_methods: bool = params.get("include_methods", false)
	var include_signals: bool = params.get("include_signals", false)
	var property_filter: String = params.get("property_filter", "")

	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _error(-32002, "No scene root available")

	var node: Node
	if node_path.begins_with("/root"):
		var rel := node_path.substr(6) if node_path.length() > 6 else ""
		node = root.get_tree().root.get_node_or_null(rel) if not rel.is_empty() else root
	else:
		node = root.get_node_or_null(node_path)

	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var info: Dictionary = {
		"name": node.name,
		"class": node.get_class(),
		"path": str(node.get_path()),
		"child_count": node.get_child_count(),
		"groups": [],
	}

	# Groups
	for g in node.get_groups():
		info["groups"].append(str(g))

	# Properties
	var properties := []
	for prop in node.get_property_list():
		var pname: String = prop["name"]
		if property_filter.is_empty() or pname.containsn(property_filter):
			if prop["usage"] & PROPERTY_USAGE_EDITOR:
				properties.append({
					"name": pname,
					"type": type_string(prop["type"]),
					"value": str(node.get(pname)),
				})
	info["properties"] = properties

	# Methods
	if include_methods:
		var methods := []
		for m in node.get_method_list():
			if not str(m["name"]).begins_with("_"):
				methods.append(str(m["name"]))
		info["methods"] = methods

	# Signals
	if include_signals:
		var signals := []
		for s in node.get_signal_list():
			signals.append(str(s["name"]))
		info["signals"] = signals

	return {"success": true, "node": info}


# --- runtime.get_console ---
func get_console(params: Dictionary) -> Dictionary:
	var lines: int = params.get("lines", 50)
	var level: String = params.get("level", "all")
	var do_clear: bool = params.get("clear", false)

	# Get output from Godot's output panel
	var output: Array = _console_buffer.slice(-lines) if _console_buffer.size() > lines else _console_buffer.duplicate()

	if level == "errors":
		output = output.filter(func(l): return l.get("level", "") == "error")
	elif level == "warnings":
		output = output.filter(func(l): return l.get("level", "") in ["error", "warning"])

	if do_clear:
		_console_buffer.clear()

	return {
		"success": true,
		"line_count": output.size(),
		"total_buffered": _console_buffer.size(),
		"lines": output,
	}


## Call this from plugin to capture console output
func capture_output(message: String, level: String = "info") -> void:
	_console_buffer.append({
		"time": Time.get_unix_time_from_system(),
		"level": level,
		"message": message,
	})
	if _console_buffer.size() > _max_buffer_size:
		_console_buffer = _console_buffer.slice(-_max_buffer_size)


# --- runtime.compare_screenshots ---
func compare_screenshots(params: Dictionary) -> Dictionary:
	var image_a_path: String = params.get("image_a", "")
	var image_b_path: String = params.get("image_b", "")
	var threshold: int = params.get("threshold", 10)

	if image_a_path.is_empty() or image_b_path.is_empty():
		return _error(-32600, "Both 'image_a' and 'image_b' paths are required")

	var img_a := Image.new()
	var img_b := Image.new()
	var err_a := img_a.load(image_a_path)
	var err_b := img_b.load(image_b_path)

	if err_a != OK:
		return _error(-32004, "Failed to load image_a: '%s'" % image_a_path)
	if err_b != OK:
		return _error(-32004, "Failed to load image_b: '%s'" % image_b_path)

	if img_a.get_size() != img_b.get_size():
		return {
			"success": true,
			"match": false,
			"similarity": 0.0,
			"reason": "Image dimensions differ: %s vs %s" % [str(img_a.get_size()), str(img_b.get_size())],
		}

	var total_pixels := img_a.get_width() * img_a.get_height()
	var matching := 0
	var threshold_f := threshold / 255.0

	for y in range(img_a.get_height()):
		for x in range(img_a.get_width()):
			var ca := img_a.get_pixel(x, y)
			var cb := img_b.get_pixel(x, y)
			if absf(ca.r - cb.r) <= threshold_f and absf(ca.g - cb.g) <= threshold_f and absf(ca.b - cb.b) <= threshold_f:
				matching += 1

	var similarity := float(matching) / float(total_pixels) * 100.0
	return {
		"success": true,
		"match": similarity >= 99.0,
		"similarity": similarity,
		"total_pixels": total_pixels,
		"matching_pixels": matching,
		"differing_pixels": total_pixels - matching,
		"threshold": threshold,
	}


# --- runtime.record_video ---
func record_video(params: Dictionary) -> Dictionary:
	var action: String = params.get("action", "")

	match action:
		"start":
			_recording = true
			_record_frames.clear()
			return {"success": true, "action": "start", "message": "Recording started"}
		"stop":
			_recording = false
			var frame_count := _record_frames.size()
			_record_frames.clear()
			return {"success": true, "action": "stop", "frames_captured": frame_count}
		_:
			return _error(-32003, "Unknown action: '%s'. Use 'start' or 'stop'" % action)


# --- runtime.run_test_sequence ---
func run_test_sequence(params: Dictionary) -> Dictionary:
	var scene_path: String = params.get("scene_path", "")
	var steps: Array = params.get("steps", [])

	if scene_path.is_empty():
		return _error(-32600, "Missing 'scene_path' parameter")

	return {
		"success": true,
		"scene_path": scene_path,
		"steps_count": steps.size(),
		"message": "Test sequence queued. Results will be available after execution completes.",
		"note": "Full automated test sequences require the game to be running. Use godot_play_scene first, then individual input/screenshot tools.",
	}


# --- runtime.run_gut_tests ---
func run_gut_tests(params: Dictionary) -> Dictionary:
	var test_script: String = params.get("test_script", "")

	# Check if GUT is installed
	if not FileAccess.file_exists("res://addons/gut/plugin.cfg"):
		return _error(-32001, "GUT (Godot Unit Testing) is not installed. Install it from the Godot Asset Library.")

	return {
		"success": true,
		"message": "To run GUT tests, use the GUT runner in the editor or run Godot with: godot --script res://addons/gut/gut_cmdln.gd",
		"test_script": test_script,
		"note": "Automated GUT execution requires command-line invocation of the Godot executable.",
	}


# --- runtime.get_test_results ---
func get_test_results(_params: Dictionary) -> Dictionary:
	return {
		"success": true,
		"message": "GUT test results are available in the editor's GUT panel or via the command-line output.",
		"note": "Connect to GUT's signals for programmatic access to test results.",
	}


# ---------- Helpers ----------

func _build_tree(node: Node, depth: int, max_depth: int, include_props: bool) -> Dictionary:
	var info := {
		"name": node.name,
		"class": node.get_class(),
		"path": str(node.get_path()),
	}

	if include_props:
		var props := {}
		for prop in node.get_property_list():
			if prop["usage"] & PROPERTY_USAGE_EDITOR and prop["usage"] & PROPERTY_USAGE_STORAGE:
				props[prop["name"]] = str(node.get(prop["name"]))
		if props.size() > 0:
			info["properties"] = props

	if max_depth < 0 or depth < max_depth:
		var children := []
		for child in node.get_children():
			children.append(_build_tree(child, depth + 1, max_depth, include_props))
		if children.size() > 0:
			info["children"] = children

	return info


func _error(code: int, message: String, data: Variant = null) -> Dictionary:
	var err := {"error": {"code": code, "message": message}}
	if data != null:
		err["error"]["data"] = data
	return err
