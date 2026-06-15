extends RefCounted
class_name CharaAction

## Actions are the states of the state machine in TacCharacter.[br]
## By default it represents and empty action slot.

var me : TacCharacter
var name : StringName  ## Name endowed to this action during discovery.
var icon : Texture2D = Tac.action_icon_atlas
var title : String = "Empty Slot"  ## The name shown to the player for selecting this action.
var description : String = "This slot has not equipment."

var noteworthy := false  ## Is the action intended to represent equipment that can be selected in menus?

var cause_busy : bool = true  ## Should the character inhibit changing to another action when this action is active? The function [code]on_abort[/code] can only be executed if this is true.
var yield_queue : bool = true  ## When [code]cause_busy[/code] is [code]false[/code] and the character is asked to enter this action, will it perform an action awaiting in queue instead?.
var can_queue : bool = true  ## Can this action be held to activate later if the character is busy?
var on_abort : Callable  ## If this action can be interrupted to change to other action. What should it do? Unlike just setting [code]cause_busy[/code], aborting executes a function.

func _init(character:TacCharacter, act_name:StringName) -> void:
	me = character
	name = act_name

func my(node:NodePath):
	return me.get_node(node)

## Can this action be recalled by another?
func store_history() -> bool:
	return true

## If this action can be aborted only in particular circumstances, define them here.[br]
## By default, it assumes it's possible to abort if [code]on_abort[/code] is set to something.
func can_abort() -> bool:
	return not on_abort.is_null()

## Return whether conditions are met to switch to this action.[br]
## Is use in particular to define is action is to be used as interaction with other character or
## be blocked if the mouse is over a character, avoiding queueing an interaction state along with
## another unrelated state.
func switch_acceptance() -> bool:
	return true

func enter(prev:CharaAction):
	pass

func exit(next:CharaAction):
	pass

func process(delta:float):
	pass

func input(event:InputEvent):
	pass

## Return a value from 0 to 1 about the confidence of whether an NPC should use this action.
func utility_score() -> float:
	return 0.5
