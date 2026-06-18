extends "res://equipment/action/throwables/throwable.gd"

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	title = "Anesthetic Grenade"
	description = "Releases cloud of odorless gas based on synthetic opioids that stealthily knocks out multiple people in the same room."
