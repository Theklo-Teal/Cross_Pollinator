extends CharaAction

func _init(character:TacCharacter) -> void:
	super(character)
	cause_busy = false
	yield_queue = true
	can_queue = false
	title = "Idle"  # The name shown to the player for selecting this action.
	description = "Awaiting the opportunity, the tool and the command."

func store_history() -> bool:
	return false

func enter(prev:CharaAction):
	me.animate(&"idle", INF)
