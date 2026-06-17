extends "res://equipment/action/weapons/handgun.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 320)
	title = "Taser"
	description = "This is a non-lethal weapon that can disable a target temporarily by causing muscular convulsion. At least until they are arrested or stop resisting."
	slot = SLOT.SECO
