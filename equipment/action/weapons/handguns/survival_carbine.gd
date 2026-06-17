extends "res://equipment/action/weapons/handgun.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 320)
	title = "Space Gun"
	description = "Weapons like this are part of aircraft pilot's survival pack, in case they eject and have to fend off nature. This one was designed for astronaut capsules. It has a barrel for shotgun shells and a barrel with for a full power cartridge, but it's a single shot for each barrel."
	slot = SLOT.SECO
