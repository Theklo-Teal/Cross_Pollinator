extends TacEntity
class_name TacCharacter

## A state machine manager for characters placed by a TacNav node. Each state is
## a character's action. The actions are [code]CharaAction[/code] instances.[br]
## Implementing a scene using or extending this script makes it into a character
## that can perform actions, unlike just [code]TacEntity[/code].[br]
## Use [code]proceed()[/code] to change action. A collection of available actions
## is stored in the tac_map_global script ("Tac"), so they can be referred by 
## StringName and reused by multiple characters.[br]
## Use [code]proceed()/code] to change state. Typically you would use an external
## player interface script to call for a character to perform an action. If the
## character is in a state that's defined as "busy", that action waits until it 
## gets to a state defined as not "busy" (unless [code]CharaAction.can_queue[/code]
## is [code]false[/code] as an exception). When it is actions calling to be 
## changed to another action, the character won't care if its "busy".

enum ATT{
	WARY,  ## Character is careful and avoids vaulting over small obstacles.
	TINY,  ## The Character is small enough to enter cramped spaces.
	HASTY,  ## The Character will be aggressive, trying to swiftly find the shortest distance physically possible.
	UNTOUCH,  ## The Character doesn't care about obstacles or might even be intangible.
	FLYING,  ## (Don't Use: Tentative feature) The character can travel through holes in the floor, changing level.
	}

enum Team{
	PLAYER, ## Player controlled character
	ALLY,  ## Characters with same objective as player, but not controllable.
	HOSTILE,  ## NPCs that actively target Player characters.
	NEUTRAL,  ## NPCs that avoid combat. Will flee if attacked.
	AGGRO,  ## NPCs that avoid combat, but will retaliate if hurt.
}

const MAX_STACK = 64

@export var team : Team  ## Default alliance of character.
var curr_team : Team  ## If a character defects or is mind-controlled, this keeps track of which side they are on.
@export var attitude : ATT  ## How the character navigates the environment.

@export_group("Actions")
@export var equipment : Array[StringName]

var actions : Dictionary[StringName, CharaAction]

func _ready():
	actions[&"idle"] = Tac.actions[&"idle"].new(self)
	actions[&"walk"] = Tac.actions[&"walk"].new(self)
	for each in equipment:
		actions[each] = Tac.actions[each].new(self)
	stt.append(actions[&"idle"])
	actions[&"idle"].enter(null)

var queue : Array[CharaAction]  ## When an action was attempted while the character was busy, they go here and wait for character to not be busy.
var stt : Array[CharaAction]  ## State history stack. Current state is at the back.
var prev : CharaAction  ## The last character action, even if not stored in the stack.

## Is the character busy with some action?
func is_busy():
	return stt.back().cause_busy
## Can the character interrupt the current action?
func can_abort():
	return stt.back().can_abort()

func _switch_state(external:bool, next:CharaAction=null) -> Error:
	var result : Error = ERR_BUG
	
	var is_restoring_past_state :=false
	if next == null:
		#NOTE in restoring a state from history, we don't save the current one to it, so it's possible to keep back-tracking actions if needed.
		prev = stt.pop_back()
		next = stt.back()
		is_restoring_past_state = true
	else:
		prev = stt.back()
		if not prev.store_history():
			# if the current state doesn't want to be recorded, remove it from history.
			stt.pop_back()
	
	if prev.cause_busy and external:
		# Character is currently busy, see if we may abort the current action. if not, 
		# action goes into the queue.
		# State switches called by CharaActions (ie. internal) bypass "cause_busy",
		# because they would be the actions in "prev" and be blocked by their own "cause_busy".		
		if prev.can_abort():
			prev.on_abort.call()
		elif next.can_queue:
			queue.push_front(next)
			result = ERR_ALREADY_IN_USE
		else:
			# Action doesn't want to wait in queue.
			result = ERR_BUSY
	
	if result == ERR_BUG:
		# None of the "cause_busy" situations were resolved yet.
		
		if not next.cause_busy and next.yield_queue and not queue.is_empty():
			# The action about to be changed into doesn't make the character busy, so
			# it will allow a queued action to take priority if available.
			#NOTE We don't care to store skipped states in history, so they are effectively bypassed.
			next = queue.pop_back()
			result = ERR_SKIP
		else:
			result = OK
		
		prev.exit(next)
		if not is_restoring_past_state:
			# We don't want to put a retrieved past state back into the history. That will just duplicate it.
			stt.push_back(next)
		next.enter(prev)
		
	# Limit the history size.
	if stt.size() >= MAX_STACK:
		stt = stt.slice(-MAX_STACK)
	
	if queue.size() >= MAX_STACK:
		printerr("TacCharacter: " + name + " Too many actions waiting to be performed.")
	
	return result

## Initiate the next action, called by another action. Pass an empty string to retrieve a previous action.
## Errors that could be returned:[br]
## OK: The action was accepted an is now in effect.
## ERR_SKIP: The action yielded to an action awaiting in the queue.
## ERR_ALREADY_IN_USE: The action was accepted, but is awaiting in queue.[br]
## ERR_BUSY: Action failed to be accepted because character is busy.[br]
## ERR_DOES_NOT_EXIST: There's no such action.[br]
## ERR_BUG: Hopefully this one never comes up. It would mean conditions weren't checked.
func proceed(next_state:StringName = &"") -> Error:
	if next_state.is_empty():
		return _switch_state(false, null)
	elif next_state in actions:
		return _switch_state(false, actions[next_state])
	else:
		printerr("TacCharacter/proceed(): Not a valid state. " + next_state)
		return ERR_DOES_NOT_EXIST

## Initiate the next action from an external interface. Pass an empty string to retrieve a previous action.
## state in the history.[br]
## Errors that could be returned:[br]
## OK: The action was accepted an is now in effect.
## ERR_SKIP: The action yielded to an action awaiting in the queue.
## ERR_ALREADY_IN_USE: The action was accepted, but is awaiting in queue.[br]
## ERR_BUSY: Action failed to be accepted because character is busy.[br]
## ERR_DOES_NOT_EXIST: There's no such action.[br]
## ERR_BUG: Hopefully this one never comes up. It would mean conditions weren't checked.
func command(next_state:StringName = &"") -> Error:
	if next_state.is_empty():
		return _switch_state(true, null)
	elif next_state in actions:
		return _switch_state(true, actions[next_state])
	else:
		printerr("TacCharacter/command(): Not a valid state. " + next_state)
		return ERR_DOES_NOT_EXIST

func _process(delta: float) -> void:
	stt.back().process(delta)
func _unhandled_input(event: InputEvent) -> void:
	stt.back().input(event)

# TODO Distinguish whether interactions represent this character acting on another or other on this one.
func _interaction() -> Error:
	stt.back().interact_receive(null)
	return OK
