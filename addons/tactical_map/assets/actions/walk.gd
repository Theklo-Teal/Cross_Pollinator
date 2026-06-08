extends CharaAction

func _init() -> void:
	cause_busy = true
	yield_queue = false
	can_queue = true
	
	title = "Walk"
	description = "If you walk without rhythm, you won't attract the worm."

func store_history() -> bool:
	return false

var stride := 1.6

func enter(_prev:CharaAction):
	var err = me.traversal_start(Tac.hover_tile, Tac.hover_layer)
	if err == ERR_ALREADY_EXISTS: # Character already at destination from start
		me.proceed(&"idle")

func exit(_next:CharaAction):
	me.traversal_finish(OK)

func process(delta:float):
	if me.position.is_equal_approx(me.next_step):
		var error := me.take_a_step()
		if error == ERR_ALREADY_EXISTS:
			me.proceed(&"idle")
			return
	else:
		me.position = me.position.move_toward(me.next_step, stride * delta)

func interact_receive(from:TacCharacter=null):
	me.audio_speak("later")

func input(event:InputEvent):
	if event.is_action_pressed(Tac.get_input_action(&"command")):
		me.audio_speak("refusal")
