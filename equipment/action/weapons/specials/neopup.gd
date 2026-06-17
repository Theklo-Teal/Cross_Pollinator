extends "res://equipment/action/weapons/projectile.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 448)
	title = "Neopup"
	description = "An advanced bespoke weapon for the requirements of underground combat. Altough it looks like a fat shotgun, it fires small rifle grenades. A computer in the rangefinder programs each round to airburst after penetrating cover."
	slot = SLOT.SECO
