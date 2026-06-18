extends "res://equipment/action/weapons/long_rifle.gd"

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 448)
	title = "Wildcat"
	description = "Fires heavy bullets capable of penetrating or destroying barriers. Doctrine is to only use semi-auto mode due concerns of collateral damage in tunnel combat. Born from sensibilities of the Cold War, not much changed on it ever since."
	slot = SLOT.PRIM
