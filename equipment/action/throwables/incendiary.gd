extends "res://equipment/action/throwables/throwable.gd"

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	title = "Incendiary Grenade"
	description = "Historically used to sabotage artillery, this grenade spreads thermite around an area that burns hot enough that even some metals catch fire and destroy cover."
