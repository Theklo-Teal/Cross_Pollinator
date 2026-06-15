extends "res://equipment/action/long_rifle.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 448)
	title = "Helsing"
	description = "Seems like some armourer's free-time side project. An improvised weapon that fires bolts using compressed air."
