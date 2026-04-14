@tool
extends Node
## WebSocket server for Godot Catalyst communication.
## Uses TCPServer + WebSocketPeer (Godot 4 pattern).

signal request_received(peer_id: int, id: String, method: String, params: Dictionary)
signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)

var _tcp_server: TCPServer = TCPServer.new()
var _peers: Dictionary = {}  # peer_id -> { "ws": WebSocketPeer, "tcp": StreamPeerTCP }
var _next_peer_id: int = 1
var _listening: bool = false


func start_server(port: int = 6505) -> Error:
	if _listening:
		stop_server()

	var err := _tcp_server.listen(port, "127.0.0.1")
	if err != OK:
		push_error("[Godot Catalyst] Failed to listen on port %d: %s" % [port, error_string(err)])
		return err

	_listening = true
	return OK


func stop_server() -> void:
	for peer_id in _peers.keys():
		_disconnect_peer(peer_id)
	_peers.clear()

	_tcp_server.stop()
	_listening = false


func send_response(peer_id: int, id: String, result: Dictionary) -> void:
	var msg := {
		"jsonrpc": "2.0",
		"id": id,
		"result": result,
	}
	_send_to_peer(peer_id, JSON.stringify(msg))


func send_error(peer_id: int, id: String, code: int, message: String, data: Variant = null) -> void:
	var error_obj := {"code": code, "message": message}
	if data != null:
		error_obj["data"] = data

	var msg := {
		"jsonrpc": "2.0",
		"id": id,
		"error": error_obj,
	}
	_send_to_peer(peer_id, JSON.stringify(msg))


func send_notification(method: String, params: Dictionary = {}) -> void:
	var msg := {
		"jsonrpc": "2.0",
		"method": method,
		"params": params,
	}
	var text := JSON.stringify(msg)
	for peer_id in _peers.keys():
		_send_to_peer(peer_id, text)


func _process(_delta: float) -> void:
	if not _listening:
		return

	# Accept new TCP connections
	while _tcp_server.is_connection_available():
		var tcp := _tcp_server.take_connection()
		if tcp:
			var ws := WebSocketPeer.new()
			var err := ws.accept_stream(tcp)
			if err == OK:
				var peer_id := _next_peer_id
				_next_peer_id += 1
				_peers[peer_id] = {"ws": ws, "tcp": tcp}
				client_connected.emit(peer_id)
			else:
				push_warning("[Godot Catalyst] Failed to accept WebSocket stream: %s" % error_string(err))

	# Poll all connected peers
	var disconnected: Array[int] = []
	for peer_id in _peers.keys():
		var peer_data: Dictionary = _peers[peer_id]
		var ws: WebSocketPeer = peer_data["ws"]

		ws.poll()

		var state := ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var packet := ws.get_packet()
				var text := packet.get_string_from_utf8()
				_handle_message(peer_id, text)
		elif state == WebSocketPeer.STATE_CLOSING:
			pass  # Wait for it to close
		elif state == WebSocketPeer.STATE_CLOSED:
			disconnected.append(peer_id)

	# Clean up disconnected peers
	for peer_id in disconnected:
		_disconnect_peer(peer_id)


func _handle_message(peer_id: int, text: String) -> void:
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("[Godot Catalyst] Invalid JSON from peer %d: %s" % [peer_id, json.get_error_message()])
		send_error(peer_id, "", -32700, "Parse error: " + json.get_error_message())
		return

	var msg: Variant = json.data
	if not msg is Dictionary:
		send_error(peer_id, "", -32600, "Invalid Request: expected JSON object")
		return

	var dict: Dictionary = msg

	# Validate JSON-RPC 2.0
	if dict.get("jsonrpc") != "2.0":
		send_error(peer_id, dict.get("id", ""), -32600, "Invalid Request: missing jsonrpc 2.0")
		return

	var id: String = str(dict.get("id", ""))
	var method: String = str(dict.get("method", ""))
	var params: Dictionary = dict.get("params", {}) if dict.get("params") is Dictionary else {}

	if method.is_empty():
		send_error(peer_id, id, -32600, "Invalid Request: missing method")
		return

	request_received.emit(peer_id, id, method, params)


func _send_to_peer(peer_id: int, text: String) -> void:
	if not _peers.has(peer_id):
		return
	var ws: WebSocketPeer = _peers[peer_id]["ws"]
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(text)


func _disconnect_peer(peer_id: int) -> void:
	if _peers.has(peer_id):
		var ws: WebSocketPeer = _peers[peer_id]["ws"]
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.close()
		_peers.erase(peer_id)
		client_disconnected.emit(peer_id)
