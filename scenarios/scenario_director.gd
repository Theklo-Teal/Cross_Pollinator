extends TacInterface
class_name ScenarioDirector

## A state machine defining the rules of a game mode.
## Extend this script to define new states, therefore different game rules.

#region Finite State Machine
var stt : Array[ScenarioState]  ## Stack representing to history of states.
var states : Dictionary[String, ScenarioState]

func switch_state(next_state:String=""):
	var prev : ScenarioState
	var next : ScenarioState
	if next_state.is_empty():
		prev = stt.pop_back()
		next = stt.back()
	else:
		assert(next_state in states, "switch_state(): Not a valid state.")
		if prev.store_history():
			prev = stt.back()
		else:
			prev = stt.pop_back()
		next = states[next_state]
		stt.push_back(next)
	if stt.size() >= Con.MAX_STT:
		stt = stt.slice(-Con.MAX_STT, )
	prev.exit(next)
	next.enter(prev)

## Override this function to define which states to use and which one to start with. Can also be used to initialize their parameters.
func setup_fsm():
	states = {
		"initial" = Roaming.new(self),
		"pause" = PauseMenu.new(self),
		}
	stt.append(states["initial"])

#region States of the FSM; Ie. Game rules.
## ScenarioState derived classes can be overriden to change their rules. Or new ones created, which then need to be acknowledged with [code]setup_fsm()[/code].
@abstract class ScenarioState:
	## Choose whether to save the state in the stack, so it can be returned to.
	func store_history() -> bool:
		return true
	var me : ScenarioDirector
	func _init(director:ScenarioDirector):
		me = director
	func my(node:NodePath) -> Node:
		return me.get_node(node)
	
	var keep_ui : Array[StringName]  ## Control node names in the «Scenario_UI» group we want to always keep visible, regardless of mention in [code]set_ui()[/code].
	var refuse_ui : Array[StringName]  ## Control node names in the «Scenario_UI» group we want to always stay hidden, regardless of mention in [code]set_ui()[/code].
	## Given node names as String, it sets which UI to show, while hiding all others. It only affects Control nodes in the group «Scenario_UI».
	func set_ui(visible:bool, ...ui):
		var all = SceneTree.current_scene.get_tree().get_nodes_in_group("Scenario_UI")
		for each in all:
			if each is Control:
				if each in keep_ui:
					each.show()
				elif each in refuse_ui:
					each.hide()
				each.visible = (each.name in ui) == visible
	
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
	func store_history() -> bool:
		return false
#endregion
#endregion


func _ready() -> void:
	Ses.scenario = self
	setup_fsm()
	assert(stt.size() > 0, "There are no states set up for the FSM.")
	stt.back().enter(null)

func _process(delta: float) -> void:
	stt.back().process(delta)
func _unhandled_input(event: InputEvent) -> void:
	stt.back().input(event)
