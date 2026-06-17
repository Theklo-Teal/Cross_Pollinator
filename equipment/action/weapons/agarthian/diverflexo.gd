extends "res://equipment/action/weapons/projectile.gd"

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 576)
	title = "Diverflexo"
	description = "An unusual weapon without a trigger and and integral to an organic gimbal. An Agarthian could use it in auto-targetting mode. They just think about their target and the gun aims and fires by itself. It uses contained gas sabot, making it silent by not expelling hot gasses."
	slot = SLOT.SECO
