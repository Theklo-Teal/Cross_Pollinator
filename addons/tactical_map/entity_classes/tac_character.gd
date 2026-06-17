extends TacEntity
class_name TacCharacter

signal switched_action(curr_action:CharaAction)  ## The character has executed the [code]enter()[/code] method of an action. This allows a state to message a TacInterface.
signal queued_action(pushed_to_queue:CharaAction)  ## The character has queued up another action to execute once there's opportunity.

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

enum Team{
	NONE,  ## A catch for teams being improperly set.
	PLAYER, ## Player controlled character
	ALLY,  ## Characters with same objective as player, but not controllable.
	HOSTILE,  ## NPCs that actively target Player characters.
	NEUTRAL,  ## NPCs that avoid combat. Will flee if attacked.
	AGGRO,  ## NPCs that avoid combat, but will retaliate if hurt.
}

const MAX_STACK = 64

@export var team : Team  ## Default alliance of character.
var curr_team : Team  ## If a character defects or is mind-controlled, this keeps track of which side they are on.

@export_group("Actions")
@export var equipment : Array[StringName]

var actions : Dictionary[StringName, CharaAction]

func _ready():
	super()
	curr_team = team
	
	Tac.acquire_action(self, &"idle")
	Tac.acquire_action(self, &"activated")
	Tac.acquire_action(self, &"walk")
	for each in equipment:
		Tac.acquire_action(self, each)
	
	actions[&"idle"].enter(null)
	acting = actions[&"idle"]
	switched_action.emit(actions[&"idle"], OK)

## Is the character busy with some action?
func is_busy():
	return acting.cause_busy
## May the character try to interrupt the current action? (Other conditions might apply)
func can_abort(next:CharaAction=null):
	return acting.can_abort()
## Are conditions met to allow the character action?
func can_act(state:StringName):
	return actions[state].switch_acceptance()
## Does the character have the given ability?
func has_action(state:StringName):
	return actions.has(state)

var acting : CharaAction  ## Current state being performed.
var queue : Array[CharaAction]  ## Actions waiting until one that yields to queue is active before being performed.
var next : CharaAction = null  ## If not null, the character will attempt to switch to the given state at the next process frame.
var resume := false  ## If [code][/code] is not null, should it resume upon switching?

func _process(delta: float) -> void:
	var prev : CharaAction
	
	if next != null:
		prev = acting
		acting = next
	
	if not queue.is_empty():
		if acting.can_yield:
			if prev == null:
				prev == acting
			resume = false
			acting = queue.pop_back()
	
	if prev != null:
		# we did a switch!
		prev.exit(acting)
		if resume:
			resume = false
			acting.resume(prev)
		else:
			acting.enter(prev)
		next = null
		switched_action.emit(acting)
		if Tac.sel_chara == self or Tac.sel_npc == self:
			activated_duration += 1
		if Tac.sel_target == self:
			targetted_duration += 1
	else:
		acting.process(delta)


## Initiate the next action, called by another action.[br]
## Errors that could be returned:[br]
## OK: The action was accepted.[br]
## ERR_DUPLICATE_SYMBOL: Tried switching to current state.[br]
## ERR_DOES_NOT_EXIST: There's no such action, or state name is empty[br]
## ERR_BUG: Hopefully this one never comes up. It would mean conditions weren't checked.
func proceed(next_state:StringName = &"", resuming:=false) -> Error:
	if next_state in actions:
		var act = actions[next_state]
		if act == acting:
			return ERR_DUPLICATE_SYMBOL
		next = actions[next_state]
		resume = resuming
		return OK
	else:
		printerr("TacCharacter/proceed(): Not a valid state. " + next_state)
		return ERR_DOES_NOT_EXIST

## Initiate the next action from an external interface.[br]
## Errors that could be returned:[br]
## OK: The action was accepted an is now in effect.[br]
## ERR_SKIP: The action yielded to an action awaiting in the queue.[br]
## ERR_ALREADY_IN_USE: The action was accepted, but is awaiting in queue.[br]
## ERR_BUSY: Action failed to be accepted because character is busy or couldn't abort.[br]
## ERR_LOCKED: Action wasn't accepted because it failed a requirement defined by the action.[br]
## ERR_QUERY_FAILED: Action wasn't accepted because the current state failed to abort.[br]
## ERR_DUPLICATE_SYMBOL: Action wasn't accepted because it tried switching to current state and can't enter the queue.[br]
## ERR_DOES_NOT_EXIST: There's no such action, or state name is empty[br]
## ERR_BUG: Hopefully this one never comes up. It would mean conditions weren't checked.
func command(next_state:StringName = &"") -> Error:
	if next_state in actions:
		var act = actions[next_state]
		if not act.allow_switch():
			return ERR_LOCKED
		
		if act == acting:
			if act.can_queue:
				queue.push_back(act)
				queued_action.emit(act)
				if queue.size() >= MAX_STACK:
					printerr("TacCharacter: " + name + " Stack Overflow! Too many actions waiting to be performed.")
				return ERR_ALREADY_IN_USE
			else:
				return ERR_DUPLICATE_SYMBOL
		
		if acting.cause_busy:
			if acting.on_abort.call(act):
				# Successful abort
				next = act
				return OK
			elif act.can_queue:
				queue.push_back(act)
				queued_action.emit(act)
				if queue.size() >= MAX_STACK:
					printerr("TacCharacter: " + name + " Stack Overflow! Too many actions waiting to be performed.")
				return ERR_ALREADY_IN_USE
			else:
				return ERR_BUSY
		else:
			next = act
			return OK
	else:
		printerr("TacCharacter/command(): Not a valid state. " + next_state)
		return ERR_DOES_NOT_EXIST

func _unhandled_input(event: InputEvent) -> void:
	acting.input(event)

var activated_duration : int = 0  ## How many states switched since character was activated?
var targetted_duration : int = 0 ## How many states switched since character was targetted?
## The character is selected for performing actions.[br]
## Return an error as a message to be interpreted by extending TacInterface.
func on_being_activated() -> Error:
	activated_duration = 0
	_on_being_activated()
	return OK
## The character is being target of an action.[br]
## Return an error as a message to be interpreted by extending TacInterface.
func on_being_targetted() -> Error:
	targetted_duration = 0
	_on_being_targetted()
	return OK

func _on_being_activated() -> Error:
	return command(&"activated")
func _on_being_targetted() -> Error:
	return OK

func interact_receive(source:TacEntity) -> Error:
	if source == null:
		return command(&"activated")
	return OK
