extends "res://equipment/action/projectile.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 576)
	description = "An unusual weapon without a trigger and and integral to an organic gimbal. An Agarthian could use it in auto-targetting mode. They just think about their target and the gun aims and fires by itself. It uses contained gas sabot, making it silent by not expelling hot gasses."
