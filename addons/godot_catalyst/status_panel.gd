@tool
extends MarginContainer

var _status_label: Label
var _connected: bool = false


func _ready() -> void:
	_status_label = $HBoxContainer/StatusLabel


func set_connected(connected: bool) -> void:
	_connected = connected
	if _status_label:
		if connected:
			_status_label.text = "Godot Catalyst: Connected"
			_status_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			_status_label.text = "Godot Catalyst: Disconnected"
			_status_label.add_theme_color_override("font_color", Color.RED)
