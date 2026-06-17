extends "res://equipment/action/hunker_down/hunker_down.gd"

func _init() -> void:
	noteworthy = false
	icon = preload("res://equipment/action_icons.tres")
	icon.region.position = Vector2(0, 0)
	title = "Trip Wire"
	description = "This anti-personnel mine is activated by cable ignition. The user will activate it as an enemy passes too close."
