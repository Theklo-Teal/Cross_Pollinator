extends "res://addons/tactical_map/assets/actions/idle.gd"

## By default, this action is set up to make the character respond in various
## ways to being clicked on.

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	title = "Being Selected"

func allow_switch() -> bool:
	return Tac.hover_entity == me

func enter(prev:CharaState):
	if prev.name == &"walk":
		me.audio_speak(&"later")
	else:
		if me.activated_duration > 1:
			me.audio_speak(&"ready")
			await me.animate(&"pose_T", 0.5)
		else:
			me.audio_speak(&"greeting")
			await me.get_tree().create_timer(0.2).timeout
	if prev == null:
		me.proceed.call_deferred(&"idle")
	else:
		me.proceed.call_deferred(prev.name, {"resume":true})
