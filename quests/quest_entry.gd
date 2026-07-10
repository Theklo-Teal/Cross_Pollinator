extends Node
class_name QuestEntry

signal has_completed  ## Emitted if this quest is to be considered completed.
signal has_progressed(stage:int, max_stage:int)  ## Emitted if a stage towards completion of the quest was finished.

## A child of ScenarioQuests. This script should be extended to define a new
## quest. Each quest is group of interactable entities and functions for when
## they are prompted. Here you can establish event connections and track the
## chain of interactions towards a quest being completed.

func _get_configuration_warnings() -> PackedStringArray:
	if not get_parent() is ScenarioQuests:
		return ["Quest Entries are meant to be children of ScenarioQuest"]
	return []

@export var triggers : Array[TacEntity]  ## Entities which are relevant in quests, except those added dynamically.
@export var requires : Array[StringName]  ## For entities added dynamically, we'll be on the lookout for any with the Node name mentioned here to register it.
var _triggers : Dictionary[StringName, TacEntity]  ## Helper variable to get triggers by node name.
var completed : bool = false : 
	set(val):
		completed = val
		if completed:
			has_completed.emit()
var progress : int = 0 :
	set(val):
		if max_progress > 0:
			has_progressed.emit(val, max_progress)
		progress = val
var max_progress : int = -1  ## Negative value means the quest doesn't count progress.

func _ready() -> void:
	add_triggers.callv(triggers)

func add_triggers(...entities):
	var quest_handler : ScenarioQuests = get_parent()
	quest_handler.register.callv([self] + entities)
	for entity in entities:
		_triggers[entity.name] = entity
		trigger_added(entity)

func rem_triggers(...entities):
	var quest_handler : ScenarioQuests = get_parent()
	quest_handler.unregister.callv([self] + entities)
	for entity in entities:
		triggers.erase(entity)
		_triggers.erase(entity.name)

## Override this function to connect signals of a trigger to some function.[br]
## [code]TacCharacter[/code] has a custom [code]quest_communicate[/code] signal
## to be emitted be extending it and is useful here.
func trigger_added(entity:TacEntity):
	pass

#region Trigger Events
## Define events for situation that entities are spawned or despawned.
func on_entities_changed(added:Array[TacEntity], removed:Array[TacEntity]):
	pass
## The event of the selected active character changing.
func selected_chara(entity:TacEntity):
	pass
## The event of the active character's selected action changing.
func selected_action(action:CharaState):
	pass
## The event of an entity stepping on a trigger zone.
func zone_entered(entity:TacEntity, zone:StringName):
	pass
## The event of an entity leaving a trigger zone.
func zone_exited(entity:TacEntity, zone:StringName):
	pass
## The event of an entity producing an interation.
func emitted_interaction(entity:TacEntity, distance:int):
	pass
## The event of an entity being affected by an interation.
func received_interaction(entity:TacEntity, distance:int):
	pass
##  The event of the player directly interacting with an entity.
func player_interaction(entity:TacEntity):
	pass
#endregion
