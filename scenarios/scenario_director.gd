extends TacInterface
class_name ScenarioDirector

## A state machine defining the rules of a game mode.
## Extend this script to define new states, therefore different game rules.

#region Finite State Machine
var stt : ScenarioState  ## The current state in effect.
var states : Dictionary[StringName, ScenarioState]

## Switch state by StringName
func switch_state_of(next:StringName):
	if next.is_empty():
		return
	if not next in states:
		printerr("switch_state(): Not a valid state.")
		return
	switch_state(states[next])
## Switch state by ScenarioState instance.
func switch_state(next:ScenarioState):
	if next == null:
		return
	stt.exit(next)
	next.enter(stt)
	stt = next

func setup_fsm():
	var ini_state = _setup_fsm()
	assert(ini_state in states)
	states[ini_state].enter(null)
	stt = states[ini_state]
## Override this function to define which states to use and return the name of
## the initial state. Can also be used to initialize their parameters.[br]
## NOTE: If you override the implementation of a inner class, you have to set it
## in states again, in here.
func _setup_fsm() -> StringName:
	states = {
		"bogus" = BogusState.new(self),
		}
	return "bogus"

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
	## Given node names as String, it sets which UI to show, while hiding all others.
	## It only affects Control nodes in the group «Scenario_UI».[br]
	## Call this function without any arguments if you only want to change UI to
	## defaults according to [code]keep_ui[/code] and [code]refuse_ui[/code].
	func set_ui(visible:bool=false, ...ui):
		var all = me.get_tree().get_nodes_in_group("Scenario_UI")
		for each in all:
			if not each is Control:
				continue
			if each.name in keep_ui:
				each.show()
			elif each.name in refuse_ui:
				each.hide()
			else:
				each.visible = (each.name as String in ui) and visible
			ui.erase(each.name as String)  # Flipping ui.has(each.name) returns true when a StringName is given to an Array[String], but ui.erase(each.name) disagrees and it made me waste so much time fixing this.
		assert(ui.is_empty(), "ScenarioDirector/ScenarioState/set_ui(): No Control node found for names: " + str(ui))
	
	func any_chara_selected(chara:TacCharacter):
		return
	## Selected a player character
	func player_chara_selected(chara:TacCharacter):
		return
	## Selected a character as target of an action
	func target_chara_selected(chara:TacCharacter):
		return
	
	## The selected character has switched state.
	func sel_chara_switched(curr_action:CharaState, chara:TacCharacter):
		return
	## The selected character has queued a state.
	func sel_chara_queued(curr_action:CharaState, chara:TacCharacter):
		return
	
	func enter(prev:ScenarioState):
		pass
	func exit(next:ScenarioState):
		pass
	func process(delta:float):
		pass
	func input(event:InputEvent):
		pass

class BogusState extends ScenarioState:
	func enter(prev:ScenarioState):
		print("Placeholder state was entered.")
#endregion
#endregion


func _ready() -> void:
	Ses.scenario = self
	setup_fsm()
	assert(states.size() > 0, "There are no states set up for the FSM.")
	
	# SET UP CHARACTERS
	for chara_name in Ses.save.get_value("Team", "characters", []):
		if $TacNav.has_node(chara_name):
			var chara : Character = $TacNav.get_node(chara_name)
			chara.max_health = Ses.save.get_value(chara_name, "health", 1)
			chara.health = chara.max_health
			chara.max_stamina = Ses.save.get_value(chara_name, "stamina", 1)
			chara.stamina = chara.max_stamina
			chara.max_mental = Ses.save.get_value(chara_name, "mental", 1)
			chara.mental = chara.max_mental
			var chara_actions = Ses.save.get_value(chara_name, "weapons", []) + Ses.save.get_value(chara_name, "added", [])
			for action : StringName in chara_actions:
				Tac.acquire_action(chara, action)

func _process(delta: float) -> void:
	stt.process(delta)
func _unhandled_input(event: InputEvent) -> void:
	stt.input(event)
func _input(event: InputEvent) -> void:
	super(event)
	if event is InputEventKey and event.is_released() and event.keycode == KEY_ESCAPE:
		request_pause()

## Override to define what happens when attempting to pause the game. All events that pause the game should call this.
func request_pause():
	return

func _select_active_character(chara:TacCharacter):
	var last = Tac.sel_chara
	stt.any_chara_selected(chara)
	stt.player_chara_selected(chara)
	if last != null:
		if last.switched_action.is_connected(sel_chara_switched):
			last.switched_action.disconnect(sel_chara_switched)
			last.queued_action.disconnect(sel_chara_queued)
	if not chara.switched_action.is_connected(sel_chara_switched):
		chara.switched_action.connect(sel_chara_switched.bind(chara))
		chara.queued_action.connect(sel_chara_queued.bind(chara))
	for quest_set in quests.get(chara as TacEntity, []):
		quest_set.selected_chara(chara)
	super(chara)

func _select_target_character(chara:TacCharacter):
	stt.any_chara_selected(chara)
	stt.target_chara_selected(chara)
	super(chara)

## Called when the active player character has changed state.
func sel_chara_switched(curr_action:CharaState, chara:TacCharacter):
	stt.sel_chara_switched(curr_action, chara)
## Called when the active player character has queued a state.
func sel_chara_queued(curr_action:CharaState, chara:TacCharacter):
	stt.sel_chara_queued(curr_action, chara)

#region Quest Handling
signal entities_changed(added:Array[TacEntity], removed:Array[TacEntity])
var quests : Dictionary[TacEntity, Array]  ## [trigger_node][i] -> scenario_quests

func _on_entities_changed(added:Array[TacEntity], removed:Array[TacEntity]):
	entities_changed.emit(added, removed)

func _tacnav_entered(tacnav:TacNav):
	super(tacnav)
	tacnav.zone_entered.connect(_entity_zone_entered)
	tacnav.zone_exited.connect(_entity_zone_exited)
	tacnav.entities_changed.connect(_on_entities_changed)
func _tacnav_exited(tacnav:TacNav):
	super(tacnav)
	_on_entities_changed([], tacnav.entities)

func _entity_zone_entered(entity:TacEntity, zone:StringName):
	for quest_set in quests.get(entity, []):
		quest_set.entity_zone_entered(entity, zone)

func _entity_zone_exited(entity:TacEntity, zone:StringName):
	for quest_set in quests.get(entity, []):
		quest_set.entity_zone_exited(entity, zone)

func _entity_chara_interaction(emitter:TacEntity, receiver:TacEntity, distance:int):
	super(emitter, receiver, distance)
	for quest_set in quests.get(emitter,[]):
		quest_set.emitted_interaction(emitter, distance)
	for quest_set in quests.get(receiver, []):
		quest_set.received_interaction(receiver, distance)

func _entity_player_interaction(receiver:TacEntity):
	super(receiver)
	for quest_set in quests.get(receiver, []):
		quest_set.player_interaction(receiver)
#endregion
