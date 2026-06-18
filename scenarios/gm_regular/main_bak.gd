extends ScenarioDirector

class PauseMenu extends ScenarioState:
	var interrupted : ScenarioState
	
	func _init(director:ScenarioDirector):
		super(director)
		keep_ui = ["PauseMenu"]
	
	func enter(prev:ScenarioState):
		interrupted = prev
		set_ui()
		me.get_tree().paused = true
	func input(event:InputEvent):
		if event is InputEventKey and event.is_pressed():
			if event.keycode == KEY_ESCAPE:
				print("to continue")
				me.switch_state(interrupted)
	func exit(next:ScenarioState):
		me.get_tree().paused = false


class PlayerTurn extends ScenarioState:
	func _init(director:ScenarioDirector):
		super(director)
		refuse_ui = ["PauseMenu"]
	func enter(_prev:ScenarioState):
		if Tac.sel_chara == null:
			set_ui(false, "TacticalUI")
		else:
			set_ui(true, "TacticalUI")
	func sel_chara_switched(curr_action:CharaAction, chara:TacCharacter):
		set_ui(true, "TacticalUI")
		Tac.sel_action = chara.actions["walk"]

class RobotTurn extends ScenarioState:
	func _init(director:ScenarioDirector):
		super(director)
		refuse_ui = ["PauseMenu", "TacticalUI"]
		set_ui()
	func enter(prev:ScenarioState):
		pass
	func on_npc_finished():
		pass


func _setup_fsm():
	states["pause"] = PauseMenu.new(self)
	states["player_turn"] = PlayerTurn.new(self)
	states["robot_turn"] = RobotTurn.new(self)
	return "player_turn"

func _on_tactical_ui_pause_requested() -> void:
	switch_state_of("pause")


func _select_active_character(chara:TacCharacter):
	super(chara)
	%TacticalUI.set_character(chara)

func sel_chara_switched(curr_action:CharaAction, chara:TacCharacter):
	super(curr_action, chara)
	%curr_act.text = curr_action.name
	%ItemList.clear()
	for i in range( chara.queue.size() - 1, -1, -1 ):
		%ItemList.add_item(chara.queue[i].name)

func sel_chara_queued(curr_action:CharaAction, chara:TacCharacter):
	super(curr_action, chara)
	%ItemList.clear()
	for i in range( chara.queue.size() - 1, -1, -1 ):
		%ItemList.add_item(chara.queue[i].name)
