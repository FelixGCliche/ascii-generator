@tool
extends "res://addons/gd-plug/plug.gd"


func _plugging() -> void:
	plug("bitwes/Gut", {"tag": "v9.7.1", "include": ["addons/gut"]})
