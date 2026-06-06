extends CharaAction

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 320)
	descript = "You throw it to cause affect an area."
