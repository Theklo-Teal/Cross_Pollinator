extends "res://equipment/action/weapons/long_rifle.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 512)
	title = "Lancer"
	description = "A special weapon meant for high volume of sustained rate of fire. This is achieved by feeding from a belt and an advanced constant-recoil system, so shooting feels like a constant push on the shoulder, rather than jerky impulses. Tunnel combat made it be rechambered for the lighter and underpenetrating pistol cartridges."
	
