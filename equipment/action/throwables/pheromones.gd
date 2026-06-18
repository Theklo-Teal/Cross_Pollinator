extends "res://equipment/action/throwables/throwable.gd"

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	title = "Pheromones"
	description = "A spray of a mix of complex terpenes engineered to affect human state of mind through inhalation."
