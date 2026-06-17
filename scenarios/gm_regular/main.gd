extends ScenarioDirector

class PlayerTurn extends ScenarioState:
	func enter(_prev:ScenarioState):
		if Tac.sel_chara == null:
			set_ui(false, "TacticalUI")
		else:
			set_ui(true, "TacticalUI")
	func sel_chara_switched(curr_action:CharaAction, chara:TacCharacter):
		set_ui(true, "TacticalUI")
		Tac.sel_action = chara.actions["walk"]

func _select_active_character(chara:TacCharacter):
	super(chara)
	if not &"submachinegun" in chara.actions:
		Tac.acquire_action(chara, &"submachinegun")
	if not &"diverflexo" in chara.actions:
		Tac.acquire_action(chara, &"diverflexo")
	%TacticalUI.set_character(chara)

func _setup_fsm():
	states["player_turn"] = PlayerTurn.new(self)
	return "player_turn"

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
