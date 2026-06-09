extends CharaAction

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 320)
	description = "Something that shots projectiles."
