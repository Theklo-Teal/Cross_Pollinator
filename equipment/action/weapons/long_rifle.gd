extends "res://equipment/action/weapons/projectile.gd"

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	title = "long_rifle"
	description = "Held with two hands."
