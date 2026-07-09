extends CharaAction

## Overriding default "Walk" behavior for Tactical Combat.

func _init(character:TacCharacter, act_name:StringName) -> void:
	super(character, act_name)
	cause_busy = true
	can_yield = false
	can_queue = false
	
	title = "Walk"
	description = "If you walk without rhythm, you won't attract the worm."

func allow_switch() -> bool:
	return Tac.hover_entity == null

var stride := 3.5
var nav_error : Error

func enter(prev:CharaState):
	print("WALKEN HERE")
	var to_cell = entry_info.args.get("cell_coord", Tac.hover_tile)
	var to_map = entry_info.args.get("tacmap", Tac.hover_map)
	nav_error = me.traversal_start(to_cell, to_map)
	if nav_error == ERR_ALREADY_EXISTS or nav_error == ERR_CANT_CONNECT:
		me.proceed(&"idle")
	else:
		me.animate(&"sprint", INF)

func exit(next:CharaState):
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

func utility_score() -> float:
	var actor = me as Character
	var player_dist = Geometry2D.bresenham_line(Ses.player_centroid[me.get_nav_layer()], actor.get_nav_coord()).size()
	match actor.approach:
		Character.APPR.RETREAT:
			return clamp(-inverse_lerp(0, me.walk_range(), player_dist), -1, 1)
		Character.APPR.DEFENSE:
			return 0
		Character.APPR.OFFENSE:
			return clamp(inverse_lerp(0, me.walk_range(), player_dist), -1, 1)
		Character.APPR.PANIC:
			return 0
	return 0
