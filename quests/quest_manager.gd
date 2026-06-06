extends Node
class_name QuestManager

## A Signal Bus pattern is used to carry out quests and interactions.

@export var dialoguer : Control  ## The node that deals with subtitles and character speech.
var quests : Dictionary  ## Experimental
var events : Dictionary  ## Events and the objects that observe them.

func register(event:String, who:Node = null):
	## Register an observing object or event, if no object is provided.
	if not events.has(event):
		events[event] = []
	if not who in events[event] and who != null:
		events[event].append(who)

func register_many(who:Node, event_array:Array[String]):
	## Register object to multiple events
	for each in event_array:
		register(each, who)

func unregister(who:Node):
	who.unregistered = true
	for each in who.events:
		events[each].erase(who)

func trigger_action(event:String, caller=null):
	for each in events[event]:
		each.trigger_action(event, caller)

func character_action(event:String, chara:Character):
	for each in events[event]:
		each.character_action(chara)

func character_crossing(event:String, chara:Character):
	for each in events[event]:
		each.character_crossing(event, chara)


func define_speech(msgs:Array[String]):
	var comm = speech.new()
	comm.msgs = msgs
	comm.mentioned.resize(msgs.size())
	return comm

class speech:
	pass
	### Handle character's speech.
	#var msgs : Array[String]
	#var mentioned : Array[bool]
	#var index : int
	#func talk_next(who:Character):
		### Say the next message line in the sequence.
		#QueBus.dialoguer.get_node("%Portrait").texture = who.portrait
		#QueBus.dialoguer.get_node("%Chara").text = who.human_name()
		#QueBus.dialoguer.say(msgs[index], mentioned[index])
		#mentioned[index] = true
		#index = clamp(index + 1, 0, msgs.size() - 1)
	#
	#func talk_at(who:Character, at:int, mark_mention:bool=true):
		### Force a line from the messages.
		#QueBus.dialoguer.get_node("%Portrait").texture = who.portrait
		#QueBus.dialoguer.get_node("%Chara").text = who.human_name()
		#QueBus.dialoguer.say(msgs[at], mentioned[at])
		#mentioned[at] = mentioned[at] or mark_mention
