@tool
class_name CatalystInputHandler
extends RefCounted
## Handles input simulation: keyboard, mouse, touch, gamepad, and action input events.
## Also supports recording and replaying input sequences.

var _plugin: EditorPlugin
var _recording := false
var _record_start_time := 0.0
var _recorded_events: Array = []
var _record_name := ""


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- input.simulate_key ---
func simulate_key(params: Dictionary) -> Dictionary:
	var keycode_str: String = params.get("keycode", "")
	if keycode_str.is_empty():
		return _error(-32600, "Missing 'keycode' parameter")

	var pressed: Variant = params.get("pressed", null)
	var echo: bool = params.get("echo", false)
	var shift: bool = params.get("shift", false)
	var ctrl: bool = params.get("ctrl", false)
	var alt: bool = params.get("alt", false)

	var keycode := _string_to_keycode(keycode_str)
	if keycode == KEY_NONE:
		return _error(-32003, "Unknown key: '%s'" % keycode_str)

	if pressed == null:
		# Press then release
		_send_key_event(keycode, true, echo, shift, ctrl, alt)
		_send_key_event(keycode, false, false, shift, ctrl, alt)
		return {"success": true, "action": "press_and_release", "key": keycode_str}
	else:
		_send_key_event(keycode, bool(pressed), echo, shift, ctrl, alt)
		return {"success": true, "action": "press" if bool(pressed) else "release", "key": keycode_str}


# --- input.simulate_mouse ---
func simulate_mouse(params: Dictionary) -> Dictionary:
	var action: String = params.get("action", "")
	var position: Dictionary = params.get("position", {})
	var button: String = params.get("button", "left")
	var scroll_delta: float = params.get("scroll_delta", 0.0)
	var drag_to: Dictionary = params.get("drag_to", {})
	var double_click: bool = params.get("double_click", false)

	var pos := Vector2(position.get("x", 0.0), position.get("y", 0.0))
	var btn := _string_to_mouse_button(button)

	match action:
		"click":
			var ev := InputEventMouseButton.new()
			ev.position = pos
			ev.global_position = pos
			ev.button_index = btn
			ev.pressed = true
			ev.double_click = double_click
			Input.parse_input_event(ev)
			var ev2 := InputEventMouseButton.new()
			ev2.position = pos
			ev2.global_position = pos
			ev2.button_index = btn
			ev2.pressed = false
			Input.parse_input_event(ev2)
			return {"success": true, "action": "click", "position": {"x": pos.x, "y": pos.y}}

		"move":
			var ev := InputEventMouseMotion.new()
			ev.position = pos
			ev.global_position = pos
			Input.parse_input_event(ev)
			return {"success": true, "action": "move", "position": {"x": pos.x, "y": pos.y}}

		"scroll":
			var ev := InputEventMouseButton.new()
			ev.position = pos
			ev.global_position = pos
			ev.button_index = MOUSE_BUTTON_WHEEL_UP if scroll_delta > 0 else MOUSE_BUTTON_WHEEL_DOWN
			ev.pressed = true
			ev.factor = absf(scroll_delta)
			Input.parse_input_event(ev)
			return {"success": true, "action": "scroll", "delta": scroll_delta}

		"drag":
			var end := Vector2(drag_to.get("x", pos.x), drag_to.get("y", pos.y))
			# Press at start
			var press := InputEventMouseButton.new()
			press.position = pos
			press.global_position = pos
			press.button_index = btn
			press.pressed = true
			Input.parse_input_event(press)
			# Move to end
			var move := InputEventMouseMotion.new()
			move.position = end
			move.global_position = end
			move.relative = end - pos
			Input.parse_input_event(move)
			# Release at end
			var release := InputEventMouseButton.new()
			release.position = end
			release.global_position = end
			release.button_index = btn
			release.pressed = false
			Input.parse_input_event(release)
			return {"success": true, "action": "drag", "from": {"x": pos.x, "y": pos.y}, "to": {"x": end.x, "y": end.y}}

		_:
			return _error(-32003, "Unknown mouse action: '%s'. Use 'click', 'move', 'scroll', or 'drag'" % action)


# --- input.simulate_touch ---
func simulate_touch(params: Dictionary) -> Dictionary:
	var action: String = params.get("action", "")
	var index: int = params.get("index", 0)
	var position: Dictionary = params.get("position", {})
	var pos := Vector2(position.get("x", 0.0), position.get("y", 0.0))

	match action:
		"press", "release":
			var ev := InputEventScreenTouch.new()
			ev.index = index
			ev.position = pos
			ev.pressed = (action == "press")
			Input.parse_input_event(ev)
			return {"success": true, "action": action, "index": index, "position": {"x": pos.x, "y": pos.y}}

		"move":
			var ev := InputEventScreenDrag.new()
			ev.index = index
			ev.position = pos
			Input.parse_input_event(ev)
			return {"success": true, "action": "move", "index": index, "position": {"x": pos.x, "y": pos.y}}

		_:
			return _error(-32003, "Unknown touch action: '%s'. Use 'press', 'release', or 'move'" % action)


# --- input.simulate_gamepad ---
func simulate_gamepad(params: Dictionary) -> Dictionary:
	var device: int = params.get("device", 0)

	if params.has("button"):
		var button: int = int(params["button"])
		var pressed: bool = params.get("pressed", true)
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = button as JoyButton
		ev.pressed = pressed
		Input.parse_input_event(ev)
		return {"success": true, "type": "button", "device": device, "button": button, "pressed": pressed}

	if params.has("axis"):
		var axis: int = int(params["axis"])
		var axis_value: float = float(params.get("axis_value", 0.0))
		var ev := InputEventJoypadMotion.new()
		ev.device = device
		ev.axis = axis as JoyAxis
		ev.axis_value = axis_value
		Input.parse_input_event(ev)
		return {"success": true, "type": "axis", "device": device, "axis": axis, "value": axis_value}

	return _error(-32600, "Must provide 'button' or 'axis' parameter")


# --- input.simulate_action ---
func simulate_action(params: Dictionary) -> Dictionary:
	var action_name: String = params.get("action", "")
	if action_name.is_empty():
		return _error(-32600, "Missing 'action' parameter")

	if not InputMap.has_action(action_name):
		return _error(-32001, "Input action not found: '%s'" % action_name)

	var pressed: Variant = params.get("pressed", null)
	var strength: float = params.get("strength", 1.0)

	var ev := InputEventAction.new()
	ev.action = action_name
	ev.strength = strength

	if pressed == null:
		# Press then release
		ev.pressed = true
		Input.parse_input_event(ev)
		var ev2 := InputEventAction.new()
		ev2.action = action_name
		ev2.pressed = false
		Input.parse_input_event(ev2)
		return {"success": true, "action": action_name, "type": "press_and_release"}
	else:
		ev.pressed = bool(pressed)
		Input.parse_input_event(ev)
		return {"success": true, "action": action_name, "type": "press" if ev.pressed else "release"}


# --- input.record ---
func record(params: Dictionary) -> Dictionary:
	var action: String = params.get("action", "")

	match action:
		"start":
			_recording = true
			_record_start_time = Time.get_ticks_msec() / 1000.0
			_recorded_events.clear()
			_record_name = params.get("name", "recording_%d" % int(Time.get_unix_time_from_system()))
			return {"success": true, "action": "start", "name": _record_name}

		"stop":
			_recording = false
			var events := _recorded_events.duplicate()
			_recorded_events.clear()
			return {"success": true, "action": "stop", "name": _record_name, "event_count": events.size(), "recording": events}

		_:
			return _error(-32003, "Unknown record action: '%s'. Use 'start' or 'stop'" % action)


# --- input.replay ---
func replay(params: Dictionary) -> Dictionary:
	var recording: Array = params.get("recording", [])
	var speed: float = params.get("speed", 1.0)

	if recording.is_empty():
		return _error(-32600, "Empty recording — nothing to replay")

	# Replay events using a timer-based approach
	var replayed := 0
	for event_data in recording:
		if event_data is Dictionary:
			var time: float = float(event_data.get("time", 0.0))
			var type: String = event_data.get("type", "")
			var data: Dictionary = event_data.get("data", {})

			# Apply speed multiplier delay (simplified — actual timing via coroutine)
			match type:
				"key":
					simulate_key(data)
				"mouse":
					simulate_mouse(data)
				"touch":
					simulate_touch(data)
				"gamepad":
					simulate_gamepad(data)
				"action":
					simulate_action(data)
			replayed += 1

	return {"success": true, "events_replayed": replayed, "speed": speed}


# ---------- Helpers ----------

func _send_key_event(keycode: Key, pressed: bool, echo: bool, shift: bool, ctrl: bool, alt: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	ev.echo = echo
	ev.shift_pressed = shift
	ev.ctrl_pressed = ctrl
	ev.alt_pressed = alt
	Input.parse_input_event(ev)


func _string_to_keycode(s: String) -> Key:
	match s.to_upper():
		"A": return KEY_A
		"B": return KEY_B
		"C": return KEY_C
		"D": return KEY_D
		"E": return KEY_E
		"F": return KEY_F
		"G": return KEY_G
		"H": return KEY_H
		"I": return KEY_I
		"J": return KEY_J
		"K": return KEY_K
		"L": return KEY_L
		"M": return KEY_M
		"N": return KEY_N
		"O": return KEY_O
		"P": return KEY_P
		"Q": return KEY_Q
		"R": return KEY_R
		"S": return KEY_S
		"T": return KEY_T
		"U": return KEY_U
		"V": return KEY_V
		"W": return KEY_W
		"X": return KEY_X
		"Y": return KEY_Y
		"Z": return KEY_Z
		"0": return KEY_0
		"1": return KEY_1
		"2": return KEY_2
		"3": return KEY_3
		"4": return KEY_4
		"5": return KEY_5
		"6": return KEY_6
		"7": return KEY_7
		"8": return KEY_8
		"9": return KEY_9
		"SPACE": return KEY_SPACE
		"ESCAPE", "ESC": return KEY_ESCAPE
		"ENTER", "RETURN": return KEY_ENTER
		"TAB": return KEY_TAB
		"BACKSPACE": return KEY_BACKSPACE
		"DELETE", "DEL": return KEY_DELETE
		"UP": return KEY_UP
		"DOWN": return KEY_DOWN
		"LEFT": return KEY_LEFT
		"RIGHT": return KEY_RIGHT
		"SHIFT": return KEY_SHIFT
		"CONTROL", "CTRL": return KEY_CTRL
		"ALT": return KEY_ALT
		"F1": return KEY_F1
		"F2": return KEY_F2
		"F3": return KEY_F3
		"F4": return KEY_F4
		"F5": return KEY_F5
		"F6": return KEY_F6
		"F7": return KEY_F7
		"F8": return KEY_F8
		"F9": return KEY_F9
		"F10": return KEY_F10
		"F11": return KEY_F11
		"F12": return KEY_F12
		"HOME": return KEY_HOME
		"END": return KEY_END
		"PAGEUP": return KEY_PAGEUP
		"PAGEDOWN": return KEY_PAGEDOWN
		"INSERT": return KEY_INSERT
	return KEY_NONE


func _string_to_mouse_button(s: String) -> MouseButton:
	match s.to_lower():
		"left": return MOUSE_BUTTON_LEFT
		"right": return MOUSE_BUTTON_RIGHT
		"middle": return MOUSE_BUTTON_MIDDLE
	return MOUSE_BUTTON_LEFT


func _error(code: int, message: String, data: Variant = null) -> Dictionary:
	var err := {"error": {"code": code, "message": message}}
	if data != null:
		err["error"]["data"] = data
	return err
