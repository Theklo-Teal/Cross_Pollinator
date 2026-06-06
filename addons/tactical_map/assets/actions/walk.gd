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
	path.assign( tacnav.get_traject(me, Ses.hover_tile) )
	path.reverse()
	if path.is_empty():
		me.switch_state(&"idle")
	path.pop_back()  # Remove the starting coord.
	step = path.pop_back()
	next_pos = tacnav.tile2spatial(step, 0, true)
	me.look_at(next_pos, Vector3.UP, true)
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
		me.look_at(next_pos, Vector3.UP, true)
	else:
		me.position = me.position.move_toward(next_pos, stride * delta)
