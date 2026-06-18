extends "res://equipment/action/weapons/long_rifle.gd"

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 448)
	title = "Sheolite"
	description = "An agile low fire-rate bullpup with well rounded characteristics for the next generation soldier. This particular model was developed from experience and battle-tested in war-torn regions of the world."
	slot = SLOT.PRIM
