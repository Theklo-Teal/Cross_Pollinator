extends ScenarioDirector

class PauseMenu extends ScenarioState:
	var interrupted : ScenarioState
	func _init(director:ScenarioDirector):
		super(director)
		keep_ui = ["PauseMenu"]
		refuse_ui = ["TacticalUId"]
	
	func enter(prev:ScenarioState):
		interrupted = prev
		set_ui()
		me.get_tree().paused = true
	func input(event:InputEvent):
		if event is InputEventKey and event.is_released():
			if event.keycode == KEY_ESCAPE:
				Ses.pausing(false)
	func exit(next:ScenarioState):
		me.get_tree().paused = false

## A state that can do decisions between switching turns.
class BetweenTurn extends ScenarioState:
	func enter(prev:ScenarioState):
		if prev == me.states[&"player"]:
			me.switch_state_of.call_deferred(&"robots")
			for each in Ses.robots:
				each.stamina = each.max_stamina
		elif prev == me.states[&"robots"] or prev == null:
			me.switch_state_of.call_deferred(&"player")
			for each in Ses.player:
				each.stamina = each.max_stamina

class PlayerTurn extends ScenarioState:
	var max_range : int = 8
	var tired_chara : int = 0 : 
		set(val):
			tired_chara = val
			if tired_chara >= Ses.player.size():
				me.switch_state_of(&"between")
	
	var comm_accept = {  ## Flags of whether a command would be acceptable to issue.
		&"walk" : false,
	}
	
	func _init(director:ScenarioDirector):
		super(director)
		keep_ui = ["TacticalUI", "TacticalSessionPanel"]
		refuse_ui = ["PauseMenu", "RobotSign"]
	func enter(prev:ScenarioState):
		tired_chara = 0
		player_chara_selected(Tac.sel_chara)
	func exit(next:ScenarioState):
		for tacnav : TacNav in me.tacnavs:
			var cells : Dictionary[int, PackedVector2Array]
			for each in Ses.player:
				var cell : Vector3i = each.get_nav_coord3()
				cells.get_or_add(cell.y, []).append(Vector2(cell.x, cell.z))
			for layer in cells:
				Ses.player_centroid[layer] = tacnav.spatial2tile(Math.centroid.callv(cells[layer]))
	func player_chara_selected(chara:TacCharacter):
		if chara == null:
			set_ui(false, "TacticalPlayerPanel")
		else:
			set_ui(true, "TacticalPlayerPanel")
			me.select_active_action( chara.default_action )
	
	var targets : Array[Character]
	var tgt_idx : int = 0
	func selected_action(action:CharaState):
		targets = action.targets()
		tgt_idx = 0
		my("%TacticalSessionPanel").set_chara_targets(targets)
	
	func sel_chara_switched(curr_action:CharaState, chara:TacCharacter):
		if Tac.sel_chara.cannot_act(): tired_chara += 1
		my("%TacticalPlayerPanel").update_character(Tac.sel_chara)
	
	func input(event:InputEvent):
		if Tac.sel_chara == null:
			return
		
		if event.is_action_pressed("next_target"):
			tgt_idx = (tgt_idx + 1) % targets.size()
			if Tac.sel_action.name == &"walk":
				me.select_active_character(targets[tgt_idx])
			else:
				me.select_target_character(targets[tgt_idx])
			
		if event is InputEventMouseMotion:
			if Tac.sel_action.name == &"walk":
				var traject = Tac.sel_chara.get_tacnav().get_traject(Tac.sel_chara, Tac.hover_tile, Tac.hover_map)
				comm_accept[&"walk"] = traject.size() <= max_range
			
		if event.is_action_pressed("command"):
			if comm_accept.get(Tac.sel_action.name, true):
				Tac.sel_chara.command(Tac.sel_action.name)
		
		#if event.is_action_pressed("interact"):
			#print("Interacted")
	
class RobotTurn extends ScenarioState:
	var acting_chara : Array[Character]
	var chara_i : int = 0
	func _init(director:ScenarioDirector):
		super(director)
		keep_ui = ["TacticalUI", "TacticalSessionPanel"]
		refuse_ui = ["PauseMenu", "TacticalPlayerPanel"]
		for each in me.get_node("TacNav").get_children():
			if each is Character:
				acting_chara.append(each)
	func enter(prev:ScenarioState):
		set_ui(true, "RobotSign")
		chara_i = 0
		on_npc_finished()
	func on_npc_finished():
		var assessment = acting_chara[chara_i].assess_options()
		#acting_chara[chara_i].perform_action()


func _setup_fsm():
	states = {
		&"pause" : PauseMenu.new(self),
		&"between" : BetweenTurn.new(self),
		&"player" : PlayerTurn.new(self),
		&"robots" : RobotTurn.new(self),
		}
	return &"between"

func _select_active_character(chara:TacCharacter):
	super(chara)
	%TacticalPlayerPanel.set_character(chara)


func _on_tactical_session_panel_skip_turn() -> void:
	if stt == states[&"player"]:
		stt.tired_chara = Ses.player.size()


func _on_tactical_player_panel_action_picked(action: StringName) -> void:
	if stt == states[&"player"]:
		if Tac.sel_chara.actions.has(action):
			select_active_action(Tac.sel_chara.actions[action])
