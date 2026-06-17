extends "res://equipment/action/hunker_down/hunker_down.gd"

func _init() -> void:
	noteworthy = false
	icon = preload("res://equipment/action_icons.tres")
	icon.region.position = Vector2(0, 0)
	title = "Snare"
	description = "A hoop of rope that's pulled by the user when an enemy passes by, arresting them from further movement."
