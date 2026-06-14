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

func on_being_selected():
	cause_busy = true
	me.audio_speak(&"ready")
	await me.animate(&"pose_T", 0.5)
	me.animate(&"act_idle")
	cause_busy = false

func interact_receive(from:TacCharacter=null):
	me.audio_speak(&"greeting")
