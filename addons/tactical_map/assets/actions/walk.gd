extends CharaAction

func store_history() -> bool:
	return false
	
var stride := 1.6
var path : Array[Vector2i]
var step : Vector2i
var next_pos : Vector3

func enter(_prev:CharaAction):
	var tacnav : TacNav = me.get_tacnav()
	me.is_busy = true
	var err = me.move_on_map(Ses.hover_tile)
	var step_fail = err == ERR_CANT_CONNECT  # Failed to take a step
	var move_fail = err == ERR_ALREADY_IN_USE  # Character already at destination from start
	if move_fail or step_fail:
		me.switch_state(&"idle")
		return
	me.walk_started()

func exit(_next:CharaAction):
	me.walk_finished()

func process(delta:float):
	if me.position.is_equal_approx(next_pos):
		if path.is_empty():
			me.switch_state("idle")
			return
		var tacnav : TacNav = me.get_tacnav()
		step = path.pop_back()
		next_pos = tacnav.tile2spatial(step, 0, true)
	else:
		me.position = me.position.move_toward(next_pos, stride * delta)
