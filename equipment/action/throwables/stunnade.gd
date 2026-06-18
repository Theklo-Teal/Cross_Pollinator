extends "res://equipment/action/throwables/throwable.gd"

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	title = "Flashbang"
	description = "A grenade containing a brightly burning metal, causing both temporary blindness and deafness. Particularly effective to users of optical devices."
