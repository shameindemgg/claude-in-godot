@tool
class_name CatalystThemeHandler
extends RefCounted
## Handles theme creation, colors, constants, font sizes, and styleboxes.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- theme.create ---
func create(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var base_theme: String = params.get("base_theme", "")

	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	if not path.ends_with(".tres"):
		path += ".tres"

	var theme := Theme.new()

	if not base_theme.is_empty():
		if not FileAccess.file_exists(base_theme):
			return _error(-32004, "Base theme file not found: '%s'" % base_theme)
		var base := load(base_theme) as Theme
		if base == null:
			return _error(-32008, "Failed to load base theme: '%s'" % base_theme)
		theme.merge_with(base)

	var err := ResourceSaver.save(theme, path)
	if err != OK:
		return _error(-32008, "Failed to save theme to '%s': error %d" % [path, err])

	return {
		"success": true,
		"path": path,
		"message": "Created theme at '%s'" % path,
	}


# --- theme.set_color ---
func set_color(params: Dictionary) -> Dictionary:
	var theme_path: String = params.get("theme_path", "")
	var node_type: String = params.get("node_type", "")
	var color_name: String = params.get("name", "")
	var color = params.get("color", null)

	if theme_path.is_empty():
		return _error(-32600, "Missing 'theme_path' parameter")
	if node_type.is_empty():
		return _error(-32600, "Missing 'node_type' parameter")
	if color_name.is_empty():
		return _error(-32600, "Missing 'name' parameter")
	if color == null:
		return _error(-32600, "Missing 'color' parameter")

	var theme := _load_theme(theme_path)
	if theme == null:
		return _error(-32008, "Failed to load theme: '%s'" % theme_path)

	var color_val: Color = CatalystTypeConverter.json_to_variant(color)
	theme.set_color(color_name, node_type, color_val)

	var err := ResourceSaver.save(theme, theme_path)
	if err != OK:
		return _error(-32008, "Failed to save theme: error %d" % err)

	return {
		"success": true,
		"theme_path": theme_path,
		"node_type": node_type,
		"name": color_name,
		"message": "Set color '%s' on '%s' in theme" % [color_name, node_type],
	}


# --- theme.set_constant ---
func set_constant(params: Dictionary) -> Dictionary:
	var theme_path: String = params.get("theme_path", "")
	var node_type: String = params.get("node_type", "")
	var const_name: String = params.get("name", "")
	var value: int = params.get("value", 0)

	if theme_path.is_empty():
		return _error(-32600, "Missing 'theme_path' parameter")
	if node_type.is_empty():
		return _error(-32600, "Missing 'node_type' parameter")
	if const_name.is_empty():
		return _error(-32600, "Missing 'name' parameter")

	var theme := _load_theme(theme_path)
	if theme == null:
		return _error(-32008, "Failed to load theme: '%s'" % theme_path)

	theme.set_constant(const_name, node_type, int(value))

	var err := ResourceSaver.save(theme, theme_path)
	if err != OK:
		return _error(-32008, "Failed to save theme: error %d" % err)

	return {
		"success": true,
		"theme_path": theme_path,
		"node_type": node_type,
		"name": const_name,
		"value": value,
		"message": "Set constant '%s' = %d on '%s' in theme" % [const_name, value, node_type],
	}


# --- theme.set_font_size ---
func set_font_size(params: Dictionary) -> Dictionary:
	var theme_path: String = params.get("theme_path", "")
	var node_type: String = params.get("node_type", "")
	var font_name: String = params.get("name", "")
	var size: int = params.get("size", 16)

	if theme_path.is_empty():
		return _error(-32600, "Missing 'theme_path' parameter")
	if node_type.is_empty():
		return _error(-32600, "Missing 'node_type' parameter")
	if font_name.is_empty():
		return _error(-32600, "Missing 'name' parameter")

	var theme := _load_theme(theme_path)
	if theme == null:
		return _error(-32008, "Failed to load theme: '%s'" % theme_path)

	theme.set_font_size(font_name, node_type, int(size))

	var err := ResourceSaver.save(theme, theme_path)
	if err != OK:
		return _error(-32008, "Failed to save theme: error %d" % err)

	return {
		"success": true,
		"theme_path": theme_path,
		"node_type": node_type,
		"name": font_name,
		"size": size,
		"message": "Set font size '%s' = %d on '%s' in theme" % [font_name, size, node_type],
	}


# --- theme.set_stylebox ---
func set_stylebox(params: Dictionary) -> Dictionary:
	var theme_path: String = params.get("theme_path", "")
	var node_type: String = params.get("node_type", "")
	var style_name: String = params.get("name", "")
	var stylebox_properties: Dictionary = params.get("stylebox_properties", {})

	if theme_path.is_empty():
		return _error(-32600, "Missing 'theme_path' parameter")
	if node_type.is_empty():
		return _error(-32600, "Missing 'node_type' parameter")
	if style_name.is_empty():
		return _error(-32600, "Missing 'name' parameter")

	var theme := _load_theme(theme_path)
	if theme == null:
		return _error(-32008, "Failed to load theme: '%s'" % theme_path)

	var stylebox := StyleBoxFlat.new()

	for key in stylebox_properties:
		var val: Variant = CatalystTypeConverter.json_to_variant(stylebox_properties[key])
		stylebox.set(StringName(key), val)

	theme.set_stylebox(style_name, node_type, stylebox)

	var err := ResourceSaver.save(theme, theme_path)
	if err != OK:
		return _error(-32008, "Failed to save theme: error %d" % err)

	return {
		"success": true,
		"theme_path": theme_path,
		"node_type": node_type,
		"name": style_name,
		"message": "Set stylebox '%s' on '%s' in theme" % [style_name, node_type],
	}


# --- theme.get_info ---
func get_info(params: Dictionary) -> Dictionary:
	var theme_path: String = params.get("theme_path", "")

	if theme_path.is_empty():
		return _error(-32600, "Missing 'theme_path' parameter")

	var theme := _load_theme(theme_path)
	if theme == null:
		return _error(-32008, "Failed to load theme: '%s'" % theme_path)

	var info := {
		"path": theme_path,
		"type_variations": [],
		"colors": {},
		"constants": {},
		"font_sizes": {},
		"styleboxes": {},
	}

	# Get all type variations
	var type_list := theme.get_type_list()
	for t in type_list:
		var type_info := {}

		var color_list := theme.get_color_list(t)
		if color_list.size() > 0:
			var colors := {}
			for c in color_list:
				colors[c] = CatalystTypeConverter.variant_to_json(theme.get_color(c, t))
			info["colors"][t] = colors

		var const_list := theme.get_constant_list(t)
		if const_list.size() > 0:
			var constants := {}
			for c in const_list:
				constants[c] = theme.get_constant(c, t)
			info["constants"][t] = constants

		var font_size_list := theme.get_font_size_list(t)
		if font_size_list.size() > 0:
			var sizes := {}
			for f in font_size_list:
				sizes[f] = theme.get_font_size(f, t)
			info["font_sizes"][t] = sizes

		var stylebox_list := theme.get_stylebox_list(t)
		if stylebox_list.size() > 0:
			var boxes := {}
			for s in stylebox_list:
				var sb := theme.get_stylebox(s, t)
				boxes[s] = sb.get_class() if sb != null else "null"
			info["styleboxes"][t] = boxes

	return {"success": true, "theme_info": info}


# ---------- Helpers ----------

func _load_theme(path: String) -> Theme:
	if not FileAccess.file_exists(path):
		return null
	return load(path) as Theme


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
