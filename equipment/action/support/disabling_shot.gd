extends CharaAction

func _init() -> void:
	noteworthy = true
	icon = preload("res://equipment/action_icons.tres")
	icon.region.position = Vector2(0, 0)
	title = "Disabling Shot"
	description = "Aiming with precision at the enemy's ands prevents them from using their main weapon."
