extends "res://equipment/action/weapons/projectile.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 320)
	description = "Held with a single hand"
