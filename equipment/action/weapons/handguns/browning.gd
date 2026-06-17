extends "res://equipment/action/weapons/handgun.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 320)
	title = "Browning Patented"
	description = "The classical tilting barrel short recoil pistol. Unfit for use with suppressor, but reliable."
	slot = SLOT.SECO
