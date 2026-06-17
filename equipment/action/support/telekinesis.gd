extends CharaAction

func _init() -> void:
	noteworthy = true
	icon = preload("res://equipment/action_icons.tres")
	icon.region.position = Vector2(0, 0)
	title = "Repair Work"
	description = "Restores function to damaged robots."
