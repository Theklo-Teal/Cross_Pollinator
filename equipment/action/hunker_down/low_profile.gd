extends CharaAction

func _init() -> void:
	noteworthy = false
	icon = preload("res://equipment/action_icons.tres")
	icon.region.position = Vector2(0, 0)
	title = "Low Profile"
	description = "Standing in pronate position allows short covers to act as high covers and reduces accuracy of enemies by displaying a smaller silluette."
