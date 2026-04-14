@tool
class_name CatalystResourceHandler
extends RefCounted

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


func create(params: Dictionary) -> Dictionary:
	var type: String = params.get("type", "")
	var path: String = params.get("path", "")
	var properties: Dictionary = params.get("properties", {})

	if type.is_empty() or path.is_empty():
		return _error(-32600, "Missing 'type' or 'path' parameter")

	if not ClassDB.class_exists(type):
		return _error(-32003, "Invalid resource type: '%s'" % type)

	var res: Resource = ClassDB.instantiate(type)
	if res == null:
		return _error(-32003, "Cannot instantiate resource type: '%s'" % type)

	for key in properties:
		var val := CatalystTypeConverter.json_to_variant(properties[key])
		res.set(StringName(key), val)

	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var err := ResourceSaver.save(res, path)
	if err != OK:
		return _error(-32008, "Failed to save resource: %s" % error_string(err))

	return {"success": true, "path": path, "type": type, "message": "Created %s at '%s'" % [type, path]}


func read(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	var res := load(path)
	if res == null:
		return _error(-32004, "Resource not found: '%s'" % path)

	var props := {}
	for prop in res.get_property_list():
		var usage: int = prop.get("usage", 0)
		if usage & PROPERTY_USAGE_STORAGE:
			var name_str: String = prop["name"]
			props[name_str] = CatalystTypeConverter.variant_to_json(res.get(StringName(name_str)))

	return {"success": true, "path": path, "type": res.get_class(), "properties": props}


func update(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var properties: Dictionary = params.get("properties", {})

	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	var res := load(path)
	if res == null:
		return _error(-32004, "Resource not found: '%s'" % path)

	for key in properties:
		var val := CatalystTypeConverter.json_to_variant(properties[key])
		res.set(StringName(key), val)

	var err := ResourceSaver.save(res, path)
	if err != OK:
		return _error(-32008, "Failed to save resource: %s" % error_string(err))

	return {"success": true, "path": path, "message": "Updated resource '%s'" % path}


func save(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var resource_path: String = params.get("resource_path", path)

	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	var res := load(resource_path)
	if res == null:
		return _error(-32004, "Resource not found: '%s'" % resource_path)

	var err := ResourceSaver.save(res, path)
	if err != OK:
		return _error(-32008, "Failed to save resource: %s" % error_string(err))

	return {"success": true, "path": path, "message": "Saved resource to '%s'" % path}


func list(params: Dictionary) -> Dictionary:
	var dir_path: String = params.get("path", "res://")
	var type_filter: String = params.get("type_filter", "")

	var results := []
	_list_resources_recursive(dir_path, type_filter, results)

	return {"success": true, "resources": results, "count": results.size()}


func get_dependencies(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	var deps := ResourceLoader.get_dependencies(path)
	var dep_list := []
	for dep in deps:
		dep_list.append(str(dep))

	return {"success": true, "path": path, "dependencies": dep_list, "count": dep_list.size()}


func import_asset(params: Dictionary) -> Dictionary:
	var source_path: String = params.get("source_path", "")
	var dest_path: String = params.get("dest_path", "")

	if source_path.is_empty() or dest_path.is_empty():
		return _error(-32600, "Missing 'source_path' or 'dest_path'")

	var dir_path := dest_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var err := DirAccess.copy_absolute(source_path, dest_path)
	if err != OK:
		return _error(-32008, "Failed to copy asset: %s" % error_string(err))

	EditorInterface.get_resource_filesystem().scan()
	return {"success": true, "source": source_path, "destination": dest_path, "message": "Asset imported, reimport scan triggered"}


func manage_autoloads(params: Dictionary) -> Dictionary:
	var action: String = params.get("action", "list")
	var autoload_name: String = params.get("name", "")
	var autoload_path: String = params.get("path", "")

	match action:
		"list":
			var autoloads := {}
			for prop in ProjectSettings.get_property_list():
				var name_str: String = prop["name"]
				if name_str.begins_with("autoload/"):
					var al_name := name_str.substr(9)
					autoloads[al_name] = ProjectSettings.get_setting(name_str)
			return {"success": true, "autoloads": autoloads}
		"add":
			if autoload_name.is_empty() or autoload_path.is_empty():
				return _error(-32600, "Missing 'name' or 'path' for autoload add")
			ProjectSettings.set_setting("autoload/" + autoload_name, "*" + autoload_path)
			ProjectSettings.save()
			return {"success": true, "message": "Added autoload '%s' -> '%s'" % [autoload_name, autoload_path]}
		"remove":
			if autoload_name.is_empty():
				return _error(-32600, "Missing 'name' for autoload remove")
			ProjectSettings.set_setting("autoload/" + autoload_name, null)
			ProjectSettings.save()
			return {"success": true, "message": "Removed autoload '%s'" % autoload_name}
		_:
			return _error(-32600, "Unknown action '%s'. Use 'list', 'add', or 'remove'" % action)


# --- Helpers ---

# --- resource.reimport ---
func reimport(params: Dictionary) -> Dictionary:
	var resource_path: String = params.get("resource_path", "")
	if resource_path.is_empty():
		return _error(-32600, "Missing 'resource_path' parameter")

	var fs := EditorInterface.get_resource_filesystem()
	fs.reimport_files(PackedStringArray([resource_path]))
	return {
		"success": true,
		"resource_path": resource_path,
		"message": "Reimport triggered for '%s'" % resource_path,
	}


func _list_resources_recursive(dir_path: String, type_filter: String, results: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_list_resources_recursive(full_path, type_filter, results)
		else:
			var ext := file_name.get_extension().to_lower()
			if ext in ["tres", "res", "tscn", "material", "mesh"]:
				if type_filter.is_empty():
					results.append({"path": full_path, "extension": ext})
				else:
					var res := load(full_path)
					if res and res.is_class(type_filter):
						results.append({"path": full_path, "type": res.get_class()})
		file_name = dir.get_next()
	dir.list_dir_end()


func _error(code: int, message: String, data: Variant = null) -> Dictionary:
	var err := {"error": {"code": code, "message": message}}
	if data != null:
		err["error"]["data"] = data
	return err
