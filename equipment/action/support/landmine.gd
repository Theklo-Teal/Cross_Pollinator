extends "res://equipment/action/support/trap.gd"

func _init() -> void:
	noteworthy = true
	icon = preload("res://equipment/action_icons.tres")
	icon.region.position = Vector2(0, 0)
	title = "Claymore"
	description = "An anti-personnel mine which will disperses shrapnel towards an area where it is triggered."
