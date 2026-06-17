extends CharaAction

func _init() -> void:
	noteworthy = false
	icon = preload("res://equipment/action_icons.tres")
	icon.region.position = Vector2(0, 0)
	title = "Hunker Down"
	description = "Curl up to become a smaller target and have vital parts less exposed to shrapnel."
