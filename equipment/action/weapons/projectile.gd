extends CharaAction

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	noteworthy = true
	icon = preload("res://equipment/action_icons.tres")
	icon.region.position = Vector2(0, 0)
	title = "projectile weapon"
	description = "Something that shots projectiles."
