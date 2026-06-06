extends Node
class_name ScenarioQuest

## This is a sort of template for scene-specific singleton scripts to extend from.
## It is to be extended on each «MapScenario» scene with the functions and definitions specific to the logic of quests in the given scene.

var quest : Array[String]  # Names of quests. Index of each String is the same for associated content on another arrays.
var state : Array  # Array of arrays of bools for Quest switches/checks.
var group : Array  # Array of arrays of nodes that should trigger the quest logic.
var trigg : Dictionary  # An index of nodes -> Array(quest index) for backwards search of quests.


func register(nodes:Array[Node], quests:Array[String]) -> Dictionary:
	## Add new interaction sequences for Quests.
	## Each trigger node can partake in multiple quests.
	## Each quest groups multiple trigger nodes which are related.
	## It returns the index number of each quest.
	var indexes : Dictionary
	for qst_name in quests:
		var idx : int
		if not qst_name in quest:
			idx = quest.size()
			quest.append(qst_name)
			state.append([])
			group.append([])
		else:
			idx = quest.find(qst_name)
		indexes[qst_name] = idx
		for trg in nodes:
			group[idx].append(trg)
			if not trg in trigg:
				trigg[trg] = []
			trigg[trg].append(idx)
	return indexes

func register_interacted(nodes:Array[Node], quests:Array[String]) -> Dictionary:
	var indexes = register(nodes, quests)
	for trg in nodes:
		trg.interacted.connect(query_interacted)
	return indexes

func register_entered(nodes:Array[Node], quests:Array[String]) -> Dictionary:
	var indexes = register(nodes, quests)
	for trg in nodes:
		trg.character_entered.connect(query_interacted)
	return indexes

func register_exited(nodes:Array[Node], quests:Array[String]) -> Dictionary:
	var indexes = register(nodes, quests)
	for trg in nodes:
		trg.character_exited.connect(query_interacted)
	return indexes


func unregister(quests:Array[String]):
	## Remove Quests or interaction sequences.
	#TODO: disconnect signals
	for qst in quests:
		var idx = quest.find(qst)
		var trg_list = group[idx]
		for trg in trg_list:
			trigg[trg].erase(idx)
		state.remove_at(idx)
		group.remove_at(idx)
		quest.remove_at(idx)


func query_interacted(node:Node, chara:Character):
	## A character has interacted with something. This checks if that node has a quest attached.
	## The character is whoever triggered the node, it might not be the player controlled character.
	var success = get_parent().character_interaction(chara)
	if success:
		var quest_list = trigg.get(node, [])
		for qst_index in quest_list:
			var qst_name = quest[qst_index]
			# Arguments are: 
			# Which character caused the interaction. Usually the selected one when the player activated this interaction.
			# Which node triggered the interaction. What did the player activate.
			# The index of the associated quest.
			call(qst_name+"_interacted", chara, node, qst_index)

func query_entered(_node:Node, chara:Character):
	## The character started colliding with the trigger object. (is stepping on it)
	var success = get_parent().character_interaction(chara)
	if success:
		pass

func query_exited(_node:Node, chara:Character):
	## The character left from colliding with the trigger object. (not stepping on it)
	var success = get_parent().character_interaction(chara)
	if success:
		pass

#region Handle UIs
#endregion

#region Handle Dialogues

func talk(chara:Character, msg:String):
	$"../UI/Subtitles".say(chara, msg)
	
#endregion
