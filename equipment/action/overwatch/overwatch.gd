extends CharaAction

func _init() -> void:
	noteworthy = false
	icon = preload("res://equipment/action_icons.tres")
	icon.region.position = Vector2(0, 0)
	title = "Overwatch"
	description = "Be watch for any enemy movement and shoot at them if that happens."
