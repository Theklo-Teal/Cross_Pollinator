extends CharaAction

func _init() -> void:
	noteworthy = true
	icon = preload("res://equipment/action_icons.tres")
	icon.region.position = Vector2(0, 0)
	title = "Echolocation"
	description = "Very low fidelity in open air, but it's a reliable way to navigate the dark and identify movement through walls."
