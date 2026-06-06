extends Node3D
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

	func chara_selected(_chara:TacCharacter):
		pass
	
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
		if event.is_action_pressed("interact", false):
			if not Ses.select_chara == null and not Ses.select_chara.is_busy:
				Ses.select_chara.enact("walk")

class PauseMenu extends ScenarioState:
	func store_history() -> bool:
		return false
#endregion
#endregion


func _ready() -> void:
	add_to_group("observer_character_select")
	setup_fsm()
	assert(stt.size() > 0, "There are no states set up for the FSM.")
	stt.back().enter(null)

## Oportunity to update UI, for example.
func _on_character_selected(chara:TacCharacter):
	stt.back().chara_selected(chara)

func _process(delta: float) -> void:
	stt.back().process(delta)
func _unhandled_input(event: InputEvent) -> void:
	stt.back().input(event)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:  #TODO test if we can select maps through the holes on other maps.
		var camera = get_viewport().get_camera_3d()
		if not camera == null:
			var space_state = get_world_3d().direct_space_state
			var ray_norm = get_viewport().get_camera_3d().project_ray_normal(event.position)
			var ray_orig = get_viewport().get_camera_3d().project_ray_origin(event.position)
			var ray_dest = ray_norm * camera.far
			var ray_sect : Dictionary

			var map_coord : Vector2i  # Tile coordinate on the map
			var nav_coord : Vector2i  # Tile coordinate on the map, relative ot the nav.
			var except : Array[RID]
			var is_hole : bool = true  # There's a hole in the floor where the mouse is.
			while is_hole:
				var ray_query = PhysicsRayQueryParameters3D.create(ray_orig, ray_dest, Con.phys_layer["tacmap"], except)
				ray_sect = space_state.intersect_ray(ray_query)
				if ray_sect.is_empty():  #Nothing could be ever be found by the raycast
					break
				Ses.hover_map = ray_sect.collider
				Ses.hover_nav = Ses.hover_map.get_parent()
				map_coord = Ses.hover_nav.spatial2map(ray_sect.position, Ses.hover_map)
				nav_coord = Ses.hover_nav.spatial2nav(ray_sect.position)
				# Change in parameters to try searching again.
				var tile : TacTile = Ses.hover_map.tiles.get(map_coord)
				is_hole = tile == null or tile.is_empty()
				if is_hole:
					except.append(ray_sect.rid)
			
			if ray_sect.is_empty():
				Ses.hover_map = null
			else:
				Ses.hover_map = ray_sect.collider
				Ses.hover_tile = nav_coord
