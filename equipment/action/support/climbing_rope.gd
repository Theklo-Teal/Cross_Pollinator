extends CharaAction

func _init() -> void:
	noteworthy = true
	icon = preload("res://equipment/action_icons.tres")
	icon.region.position = Vector2(0, 0)
	title = "Hiking Rope"
	description = "Can be dropped from ledges to rapel down, or anyone at the lower level, to climb up."
