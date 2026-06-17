extends RefCounted
class_name CharaState

## Actions are the states of the state machine in TacCharacter.[br]
## By default it represents and empty action slot.

var me : TacCharacter
var name : StringName  ## Name endowed to this action during discovery.
var icon : Texture2D = Tac.action_icon_atlas
var title : String = "Empty Slot"  ## The name shown to the player for selecting this action.
var description : String = "This slot has not equipment."
var noteworthy := false  ## Is the action intended to represent equipment that can be selected in menus?

var cause_busy : bool = true  ## Should the character inhibit changing to another action when this action is active? The function [code]on_abort[/code] can only be executed if this is true.
var can_yield : bool = true  ## Let an action waiting in queue to take over.
var can_queue : bool = true  ## Can this action be held to activate later if the character is busy?
var on_abort : Callable  ## If this action can be interrupted to change to other action. What should it do?[br]It must take a [code]CharaAction[/code] argument which receives the state asking to take over.[br]It must return a [code]bool[/code] of whether to accept aborting. [br]Unlike just setting [code]cause_busy[/code], aborting executes a function.

func _init(character:TacCharacter, act_name:StringName) -> void:
	me = character
	name = act_name

func my(node:NodePath):
	return me.get_node(node)

## This function can be called by an extension of TacInterface when it recieves 
## a me.swiched_action signal.[br]
## return something that might be meaningful to a particular extension of it.
func message_interface(interface:TacInterface) -> Variant:
	return null

## If this action can be aborted only in particular circumstances, define them here.[br]
## Allows checking if aborting is possible without executing the abort function.[br]
## By default, it assumes it's possible to abort if [code]on_abort[/code] is set to something.
func can_abort() -> bool:
	return not on_abort.is_null()

## Return whether conditions are met to switch to this action.[br]
## This is used in particular to define if action is to be used as interaction with other character or
## be blocked if the mouse is over a character, avoiding queueing an interaction state along with
## another unrelated state.
func allow_switch() -> bool:
	return true

## Sometimes a state interrupts the current one to then allow this one to continue
## again. Instead of [code]enter()[/code], this function is called instead.[br]
## If it's desired to change state here use [code]call_deferred()[/code] or
## things will break.
func resume(prev:CharaAction):
	return &""

## Constructor of the state. If it's desired to change state here use
## [code]call_deferred()[/code] or things will break.
func enter(prev:CharaAction):
	return &""

## Deconstructor of the state. Please don't try to change state here.
func exit(next:CharaAction):
	return

func process(delta:float):
	pass

func input(event:InputEvent):
	pass

## Return a value from 0 to 1 about the confidence of whether an NPC should use this action.
func utility_score() -> float:
	return 0.5
