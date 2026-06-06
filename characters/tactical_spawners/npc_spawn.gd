@tool
extends TacEntitySpawner
class_name NPCSpawn

@export var minimum : int = 1
@export var maximum : int = 1
@export var characters : Array[StringName]

func _nit():
	icon = preload("res://addons/tactical_map/assets/trollface.png")

func generate(origin:Vector2i) -> Dictionary[TacEntity, Vector2i]:
	var dict : Dictionary[TacEntity, Vector2i]
	var i : int = -1
	for each in characters:
		i += 1
		var chara : Character = load("res://characters/tactical/pmc_breacher.tscn").instantiate()
		dict[chara] = origin + Vector2i(i,0)
	return dict
