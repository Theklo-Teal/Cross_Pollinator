extends "res://addons/tactical_map/assets/actions/idle.gd"

## By default, this action is set up to make the character respond in various
## ways to being clicked on.

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	cause_busy = true
	title = "Being Selected"

func store_history() -> bool:
	return false

func switch_acceptance() -> bool:
	return Tac.hover_entity == me

func enter(prev:CharaAction):
	if Tac.sel_chara == me:
		me.audio_speak(&"ready")
		await me.animate(&"pose_T", 0.5)
	elif prev.name == &"walk":
		me.audio_speak(&"later")
	else:
		me.audio_speak(&"greeting")
		await me.get_tree().create_timer(0.2).timeout
	me.proceed(&"")
