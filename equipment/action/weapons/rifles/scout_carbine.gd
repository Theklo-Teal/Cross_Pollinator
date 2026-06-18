extends "res://equipment/action/weapons/long_rifle.gd"

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 448)
	title = "Scout Carbine"
	description = "As they say in the movies, it's a modern re-imagination of the utilitarian frontier rifle. Being a cheap bolt action shooting intermediary cartridges, it isn't particularly good at anything and maybe that's the point."
	slot = SLOT.PRIM
