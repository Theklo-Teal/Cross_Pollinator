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
	me.animate("act_idle")

func interact_receive(from:TacCharacter=null):
	cause_busy = true
	me.audio_speak("greeting")
	await me.animate("pose_T", 0.5)
	me.animate("act_idle")
	cause_busy = false


func input(event:InputEvent):
	if event.is_action_pressed(Tac.get_input_action(&"command")):
		me.proceed(&"walk")
