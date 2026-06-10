extends CharaAction

func _init(character:TacCharacter) -> void:
	super(character)
	cause_busy = true
	yield_queue = false
	can_queue = true
	
	title = "Walk"
	description = "If you walk without rhythm, you won't attract the worm."

func store_history() -> bool:
	return false

var stride := 1.6
var nav_error : Error

func enter(_prev:CharaAction):
	nav_error = me.traversal_start(Tac.hover_tile, Tac.hover_map)
	if nav_error == ERR_ALREADY_EXISTS or nav_error == ERR_CANT_CONNECT:
		me.proceed(&"idle")

func exit(_next:CharaAction):
	if nav_error == OK:
		me.audio_speak("ready")
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
