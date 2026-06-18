extends "res://equipment/action/throwables/throwable.gd"

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	title = "Stimulant"
	description = "Secreted by Agarthian simbiotes, this substance makes you feel like you could take an extra hit for team. It counteracts mental ailments by increasing focus and stamina of those affected."
