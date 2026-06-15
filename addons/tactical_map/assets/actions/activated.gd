extends "res://addons/tactical_map/assets/actions/idle.gd"

func _init(character:TacCharacter) -> void:
	super(character)
	cause_busy = true
	title = "Being Selected"

func enter(prev:CharaAction):
	me.audio_speak(&"greeting")
	me.proceed(&"idle")
