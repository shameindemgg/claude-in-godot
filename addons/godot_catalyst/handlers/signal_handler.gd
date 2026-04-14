@tool
class_name CatalystSignalHandler
extends RefCounted
## Handles signal listing, connecting, disconnecting, emitting, and inspection.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- signal.list ---
func list(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var signal_list := node.get_signal_list()
	var signals := []
	for sig in signal_list:
		var args := []
		for arg in sig.get("args", []):
			args.append({
				"name": arg.get("name", ""),
				"type": arg.get("type", 0),
			})
		signals.append({
			"name": sig.get("name", ""),
			"args": args,
		})

	return {"success": true, "node_path": node_path, "signals": signals, "count": signals.size()}


# --- signal.connect_signal ---
func connect_signal(params: Dictionary) -> Dictionary:
	var source_path: String = params.get("source_path", "")
	var signal_name: String = params.get("signal_name", "")
	var target_path: String = params.get("target_path", "")
	var method_name: String = params.get("method_name", "")
	var flags: int = params.get("flags", 0)

	if signal_name.is_empty():
		return _error(-32600, "Missing 'signal_name' parameter")
	if method_name.is_empty():
		return _error(-32600, "Missing 'method_name' parameter")

	var source := _get_node(source_path)
	if source == null:
		return _error(-32001, "Source node not found: '%s'" % source_path)

	var target := _get_node(target_path)
	if target == null:
		return _error(-32001, "Target node not found: '%s'" % target_path)

	if not source.has_signal(signal_name):
		return _error(-32003, "Signal '%s' not found on node '%s'" % [signal_name, source_path])

	if not target.has_method(method_name):
		return _error(-32003, "Method '%s' not found on node '%s'" % [method_name, target_path])

	if source.is_connected(signal_name, Callable(target, method_name)):
		return _error(-32005, "Signal '%s' is already connected to '%s.%s'" % [signal_name, target_path, method_name])

	var err := source.connect(signal_name, Callable(target, method_name), flags)
	if err != OK:
		return _error(-32008, "Failed to connect signal: %s" % error_string(err))

	return {
		"success": true,
		"source": source_path,
		"signal": signal_name,
		"target": target_path,
		"method": method_name,
		"message": "Connected '%s.%s' to '%s.%s'" % [source_path, signal_name, target_path, method_name],
	}


# --- signal.disconnect_signal ---
func disconnect_signal(params: Dictionary) -> Dictionary:
	var source_path: String = params.get("source_path", "")
	var signal_name: String = params.get("signal_name", "")
	var target_path: String = params.get("target_path", "")
	var method_name: String = params.get("method_name", "")

	if signal_name.is_empty():
		return _error(-32600, "Missing 'signal_name' parameter")
	if method_name.is_empty():
		return _error(-32600, "Missing 'method_name' parameter")

	var source := _get_node(source_path)
	if source == null:
		return _error(-32001, "Source node not found: '%s'" % source_path)

	var target := _get_node(target_path)
	if target == null:
		return _error(-32001, "Target node not found: '%s'" % target_path)

	if not source.is_connected(signal_name, Callable(target, method_name)):
		return _error(-32005, "Signal '%s' is not connected to '%s.%s'" % [signal_name, target_path, method_name])

	source.disconnect(signal_name, Callable(target, method_name))

	return {
		"success": true,
		"source": source_path,
		"signal": signal_name,
		"target": target_path,
		"method": method_name,
		"message": "Disconnected '%s.%s' from '%s.%s'" % [source_path, signal_name, target_path, method_name],
	}


# --- signal.get_connections ---
func get_connections(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var connections := []
	for sig in node.get_signal_list():
		var sig_name: String = sig.get("name", "")
		var conn_list := node.get_signal_connection_list(sig_name)
		for conn in conn_list:
			var callable: Callable = conn.get("callable", Callable())
			connections.append({
				"signal": sig_name,
				"target": str(callable.get_object().get_path()) if callable.get_object() else "",
				"method": callable.get_method(),
				"flags": conn.get("flags", 0),
			})

	return {"success": true, "node_path": node_path, "connections": connections, "count": connections.size()}


# --- signal.emit ---
func emit(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var signal_name: String = params.get("signal_name", "")
	var args: Array = params.get("args", [])

	if signal_name.is_empty():
		return _error(-32600, "Missing 'signal_name' parameter")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not node.has_signal(signal_name):
		return _error(-32003, "Signal '%s' not found on node '%s'" % [signal_name, node_path])

	match args.size():
		0: node.emit_signal(signal_name)
		1: node.emit_signal(signal_name, args[0])
		2: node.emit_signal(signal_name, args[0], args[1])
		3: node.emit_signal(signal_name, args[0], args[1], args[2])
		4: node.emit_signal(signal_name, args[0], args[1], args[2], args[3])
		5: node.emit_signal(signal_name, args[0], args[1], args[2], args[3], args[4])
		_: return _error(-32600, "Too many arguments (max 5 supported)")

	return {
		"success": true,
		"node_path": node_path,
		"signal": signal_name,
		"args_count": args.size(),
		"message": "Emitted signal '%s' on '%s' with %d args" % [signal_name, node_path, args.size()],
	}


# --- signal.has_connection ---
func has_connection(params: Dictionary) -> Dictionary:
	var source_path: String = params.get("source_path", "")
	var signal_name: String = params.get("signal_name", "")
	var target_path: String = params.get("target_path", "")
	var method_name: String = params.get("method_name", "")

	if signal_name.is_empty():
		return _error(-32600, "Missing 'signal_name' parameter")
	if method_name.is_empty():
		return _error(-32600, "Missing 'method_name' parameter")

	var source := _get_node(source_path)
	if source == null:
		return _error(-32001, "Source node not found: '%s'" % source_path)

	var target := _get_node(target_path)
	if target == null:
		return _error(-32001, "Target node not found: '%s'" % target_path)

	var connected := source.is_connected(signal_name, Callable(target, method_name))

	return {
		"success": true,
		"source": source_path,
		"signal": signal_name,
		"target": target_path,
		"method": method_name,
		"connected": connected,
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
