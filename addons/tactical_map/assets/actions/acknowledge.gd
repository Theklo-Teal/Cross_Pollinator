extends "res://addons/tactical_map/assets/actions/idle.gd"

func _init(character:TacCharacter) -> void:
	super(character)
	cause_busy = true
	title = "Acknowledge"


func enter(prev:CharaAction):
	me.audio_speak(&"ready")
	await me.animate(&"pose_T", 0.5)
	me.animate(&"act_idle")
	me.audio_speak(&"greeting")

	me.proceed(&"idle")
