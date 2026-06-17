extends CharaAction

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	cause_busy = false
	can_yield = true
	can_queue = false
	title = "Idle"  # The name shown to the player for selecting this action.
	description = "Awaiting the opportunity, the tool and the command."

func enter(prev:CharaAction):
	me.animate(&"idle", INF)

func resume(prev:CharaAction):
	enter(prev)
