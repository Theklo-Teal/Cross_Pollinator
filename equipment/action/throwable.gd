extends CharaAction

func _init() -> void:
	noteworthy = true
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 320)
	description = "You throw it to cause affect an area."
