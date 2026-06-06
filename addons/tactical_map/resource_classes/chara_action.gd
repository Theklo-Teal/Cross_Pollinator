@abstract
extends RefCounted
class_name CharaAction

@warning_ignore("unused_signal")
signal finished

var me : TacCharacter
var icon : Texture2D = preload("res://assets/ui_textures/action_icons_square.tres")
var descript : String

func _init(manager:TacCharacter):
	me = manager

func my(node:NodePath):
	return me.get_node(node)

func store_history() -> bool:
	return true

func enter(_prev:CharaAction):
	pass

func exit(_next:CharaAction):
	pass

func process(_delta:float):
	pass

func input(_event:InputEvent):
	pass
