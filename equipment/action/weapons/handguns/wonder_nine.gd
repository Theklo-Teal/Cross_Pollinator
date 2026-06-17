extends "res://equipment/action/weapons/handgun.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 320)
	title = "Wonder Nine"
	description = "A pistol with all the modern features you might expect. Its unusual fixed barrel action allows suppressors to be effective."
	slot = SLOT.SECO
