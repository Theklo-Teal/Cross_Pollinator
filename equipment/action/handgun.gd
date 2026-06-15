extends "res://equipment/action/projectile.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 320)
	description = "A modern handgun, but otherwise unremarkable."
