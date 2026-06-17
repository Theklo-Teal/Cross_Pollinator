extends TacInterface
class_name ScenarioDirector

## A state machine defining the rules of a game mode.
## Extend this script to define new states, therefore different game rules.

#region Finite State Machine
var stt : ScenarioState
var states : Dictionary[String, ScenarioState]

func switch_state(next:StringName):
	if next.is_empty():
		return
	if not next in states:
		printerr("switch_state(): Not a valid state.")
		return
	
	var next_stt = states[next]
	stt.exit(next_stt)
	next_stt.enter(stt)
	stt = next_stt

func setup_fsm():
	states = {
		"roaming" = Roaming.new(self),
		"pause" = PauseMenu.new(self),
		}
	var ini_state = _setup_fsm()
	states[ini_state].enter(null)
	stt = states[ini_state]
## Override this function to define which states to use and return the name of the initial state. Can also be used to initialize their parameters.
func _setup_fsm() -> StringName:
	return "roaming"

#region States of the FSM; Ie. Game rules.
## ScenarioState derived classes can be overriden to change their rules. Or new ones created, which then need to be acknowledged with [code]setup_fsm()[/code].
@abstract class ScenarioState:
	var me : ScenarioDirector
	func _init(director:ScenarioDirector):
		me = director
	func my(node:NodePath) -> Node:
		return me.get_node(node)
	
	var keep_ui : Array[StringName]  ## Control node names in the «Scenario_UI» group we want to always keep visible, regardless of mention in [code]set_ui()[/code].
	var refuse_ui : Array[StringName]  ## Control node names in the «Scenario_UI» group we want to always stay hidden, regardless of mention in [code]set_ui()[/code].
	## Given node names as String, it sets which UI to show, while hiding all others. It only affects Control nodes in the group «Scenario_UI».
	func set_ui(visible:bool, ...ui):
		var all = me.get_tree().get_nodes_in_group("Scenario_UI")
		for each in all:
			if each is Control:
				if each in keep_ui:
					each.show()
				elif each in refuse_ui:
					each.hide()
				each.visible = (each.name in ui) == visible
	
	## The selected character has switched state.
	func sel_chara_switched(curr_action:CharaAction, chara:TacCharacter):
		return
	## The selected character has queued a state.
	func sel_chara_queued(curr_action:CharaAction, chara:TacCharacter):
		return
	
	func enter(_prev:ScenarioState):
		pass
	func exit(_next:ScenarioState):
		pass
	func process(_delta:float):
		pass
	func input(_event:InputEvent):
		pass
	
## Exploration RPG-like mode, outside combat.
class Roaming extends ScenarioState:
	func input(event:InputEvent):
		if event is InputEventMouseMotion:
			var chara : Character = Tac.sel_chara
			if chara != null:
				var preview = Tac.hover_nav.get_traject(chara, Tac.hover_tile_nav, Tac.hover_map)
				#var preview = Geometry2D.bresenham_line(chara.get_nav_coord(), Tac.hover_tile_nav)
				me.get_tree().call_group("_scenario_director_sight_indicators", "queue_free")
				for i in range(preview.size()):
					var coord = preview[i]
					#var coord := Vector3i(preview[i].x, Tac.hover_layer, preview[i].y)
					var sprt = Tac.hover_nav.place_tile_sprite(Tac.ui_tile_walk, coord)
					sprt.add_to_group("_scenario_director_sight_indicators")
					sprt.modulate = Color(0.0, 0.0, 1.0, 1.0)
					sprt.position.y += 0.1
		if event.is_action_released(Tac.command_input()):
			if Tac.sel_chara != null:
				Tac.sel_chara.command(&"walk")

class PauseMenu extends ScenarioState:
	pass
#endregion
#endregion


func _ready() -> void:
	Ses.scenario = self
	setup_fsm()
	assert(states.size() > 0, "There are no states set up for the FSM.")

func _process(delta: float) -> void:
	stt.process(delta)
func _unhandled_input(event: InputEvent) -> void:
	stt.input(event)


func _select_active_character(chara:TacCharacter):
	var last = Tac.sel_chara
	if last != null:
		if last.switched_action.is_connected(sel_chara_switched):
			last.switched_action.disconnect(sel_chara_switched)
			last.queued_action.disconnect(sel_chara_queued)
	if not chara.switched_action.is_connected(sel_chara_switched):
		chara.switched_action.connect(sel_chara_switched.bind(chara))
		chara.queued_action.connect(sel_chara_queued.bind(chara))
	super(chara)

## Called when the active player character has changed state.
func sel_chara_switched(curr_action:CharaAction, chara:TacCharacter):
	stt.sel_chara_switched(curr_action, chara)
## Called when the active player character has queued a state.
func sel_chara_queued(curr_action:CharaAction, chara:TacCharacter):
	stt.sel_chara_queued(curr_action, chara)
