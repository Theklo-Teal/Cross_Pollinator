extends CharaAction

func _init() -> void:
	noteworthy = true
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 320)
	title = "throwing weapon"
	description = "You throw it to affect an area."
