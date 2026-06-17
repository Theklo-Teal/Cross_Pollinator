extends CharaAction

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	cause_busy = true
	can_yield = false
	can_queue = true
	on_abort = abortion
	
	title = "Walk"
	description = "If you walk without rhythm, you won't attract the worm."

func can_abort(next:CharaAction=null) -> bool:
	return next == null or not (next.noteworthy or next == self)

func abortion(next:CharaAction) -> bool:
	return can_abort(next)

func allow_switch() -> bool:
	return Tac.hover_entity == null

var stride := 3.5
var nav_error : Error

func enter(prev:CharaAction):
	nav_error = me.traversal_start(Tac.hover_tile, Tac.hover_map)
	if nav_error == ERR_ALREADY_EXISTS or nav_error == ERR_CANT_CONNECT:
		me.proceed(&"idle")
	else:
		me.animate(&"sprint", INF)

func exit(next:CharaAction):
	if next.name == &"idle":
		if nav_error == OK and randf() > 0.6:
			me.audio_speak(&"complete")
		me.traversal_finish(OK)

func process(delta:float):
	if me.position.is_equal_approx(me.next_step):
		var error := me.take_a_step()
		if error == ERR_ALREADY_EXISTS:
			me.proceed(&"idle")
			return
	else:
		me.position = me.position.move_toward(me.next_step, stride * delta)
