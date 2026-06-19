extends Node
class_name ScenarioQuests

## A Signal Bus where nodes can be grouped into common "quest" objects. Quests
## should be defined in child QuestEntry.[br]
## Whenever an interaction happens in a ScenarioDirector, associated quest events
## are queried and functions called according to QuestEntry definition.

#TODO Do we need a mechanism to allow ScenarioDirector veto an interaction for a quest?

@export var scenario : ScenarioDirector  ## The ScenarioDirector instance that should query the quests.
@export var enabled : bool = true  ## Whether to make use of this set of quests.
var triggers : Dictionary[TacEntity, Array]  ## [trigger_node][i] -> QuestEntry

func _ready() -> void:
	assert(scenario != null, "ScenarioDirector not set!")
	scenario.entities_changed.connect(_on_entities_changed)

func _on_entities_changed(added:Array[TacEntity], removed:Array[TacEntity]):
	for entry : QuestEntry in get_children():
		for entity in added:
			if entity.name in entry.requires and not entity.name in entry._triggers:
				entry.add_triggers(entity)
		for entity in removed:
			entry.rem_triggers(entity)
		entry.on_entities_changed(added, removed)

## Places a reference of triggs associated to a quest in [code]scenario.quests[/code].[br]
## To add entities to [code]QuestEntry[/code], use [code]QuestEntry.add_triggers()[/code] instead.[br]
func register(quest:QuestEntry, ...triggs):
	if scenario == null:
		return
	for entity in triggs:
		if not entity in scenario.quests:
			scenario.quests[entity] = []
		if not self in scenario.quests[entity]:
			scenario.quests[entity].append(self)
		if not entity in triggers:
			triggers[entity] = []
		if not quest in triggers[entity]:
			triggers[entity].append(quest)

## Remove [code]quest[/code] from association with [code]triggers[/code] in the
## [code]scenario.quests[/code]. If [code]quest[/code] is [code]null[/code], then
## remove from all quests.[br]
## To remove entities from [code]QuestEntry[/code], use [code]QuestEntry.rem_triggers()[/code] instead.[br]
## If a given trigger has no associations, remover it from the reference.
func unregister(quest:QuestEntry, ...triggs):
	if scenario == null:
		return
	var entries = [quest]
	if quest == null:
		entries = get_children()
	for entity in triggs:
		if not entity in triggers:
			continue
		scenario.quests[entity].erase(self)
		if scenario.quests[entity].is_empty():
			scenario.quests.erase(entity)
		for entry in entries:
			triggers[entity].erase(entry)
			if triggers[entity].is_empty():
				triggers.erase(entity)


func selected_chara(entity:TacEntity):
	for entry : QuestEntry in triggers.get(entity, []):
		entry.selected_chara(entity)

func entity_zone_entered(entity:TacEntity, zone:StringName):
	for entry : QuestEntry in triggers.get(entity, []):
		entry.zone_entered(entity, zone)

func entity_zone_exited(entity:TacEntity, zone:StringName):
	for entry : QuestEntry in triggers.get(entity, []):
		entry.zone_exited(entity, zone)

func emitted_interaction(entity:TacEntity, distance:int):
	for entry : QuestEntry in triggers.get(entity, []):
		entry.emitted_interaction(entity, distance)

func received_interaction(entity:TacEntity, distance:int):
	for entry : QuestEntry in triggers.get(entity, []):
		entry.received_interaction(entity, distance)

func player_interaction(entity:TacEntity):
	for entry : QuestEntry in triggers.get(entity, []):
		entry.player_interaction(entity)
