extends RefCounted
class_name CharaAction

## Actions are the states of the state machine in TacCharacter.[br]
## By default it represents and empty action slot.

var me : TacCharacter
var icon : Texture2D = Tac.action_icon_atlas
var title : String = "Empty Slot"  # The name shown to the player for selecting this action.
var description : String = "This slot has not equipment."

var cause_busy : bool = true  ## Should the character inhibit changing to another action when this action is active? The function [code]on_abort[/code] can only be executed if this is true.
var yield_queue : bool = true  ## When [code]cause_busy[/code] is [code]false[/code] and the character is asked to enter this action, will it give permission to other action waiting in queue to replace it?.
var can_queue : bool = true  ## Can this action be held to activate later if the character is busy?
var on_abort : Callable  ## If this action can be interrupted to change to other action. What should it do? Unlike just setting [code]cause_busy[/code], aborting executes a function.

func _init(character:TacCharacter) -> void:
	me = character
	me.add_to_group("observer_character_select")

func my(node:NodePath):
	return me.get_node(node)

## If this action can be aborted only in particular circumstances, define them here.[br]
## By default, it assumes it's possible to abort if [code]on_abort[/code] is set to something.
func can_abort() -> bool:
	return not on_abort.is_null()

## Can this action be recalled by another?
func store_history() -> bool:
	return true

func enter(prev:CharaAction):
	pass

func exit(next:CharaAction):
	pass

func process(delta:float):
	pass

func input(event:InputEvent):
	pass

func _on_character_selected(chara:TacCharacter):
	if chara == self:
		on_being_selected()

func on_being_selected():
	pass

## Whether this character was clicked on or prompted. If [code]from[/code] is
## [code]null[/code] it means the interaction is direct from the player.
func interact_receive(from:TacCharacter=null):
	pass

## Whether another character was clicked on or prompted while this one was active.
## If it represents this character acting on the other. If [code]to[/code] is
## [code]null[/code] it means the interaction is direct from the player.
func interact_transmit(to:TacCharacter=null):
	pass

## Return a value from 0 to 1 about the confidence of whether an NPC should use this action.
func utility_score() -> float:
	return 0.5
