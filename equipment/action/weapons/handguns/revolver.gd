extends "res://equipment/action/weapons/handgun.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 320)
	title = "Magnum Revolver"
	description = "Fancy old time guns like this can only be personal purchase from individual agents, not standard issue. This one is chambered for a hunting pistol cartridge."
	slot = SLOT.SECO
