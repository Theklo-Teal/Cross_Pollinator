extends CharaAction

func store_history() -> bool:
	return false
	
var stride := 1.6

func enter(_prev:CharaAction):
	var tacnav : TacNav = me.get_tacnav()
	me.is_busy = true
	var err = me.traversal_start(Ses.hover_tile)
	if err == ERR_ALREADY_EXISTS: # Character already at destination from start
		me.switch_state(&"idle")
		return

func exit(_next:CharaAction):
	me._traversal_finish(OK)

func process(delta:float):
	if me.position.is_equal_approx(me.next_step):
		var error := me.take_a_step()
		if error == ERR_ALREADY_EXISTS:
			me.switch_state(&"idle")
			return
	else:
		me.position = me.position.move_toward(me.next_step, stride * delta)
