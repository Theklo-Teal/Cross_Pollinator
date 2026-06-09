@tool
extends TacEntitySpawner
class_name NPCSpawn

@export var minimum : int = 1
@export var maximum : int = 1
@export var characters : Array[StringName]

func _init():
	icon = preload("res://addons/tactical_map/assets/trollface.png")

static func display_name() -> StringName:
	return &"NPC Cluster"

func editor_info() -> String:
	var txt : String
	txt = "min: " + str(minimum)
	txt += "\nmax: " + str(maximum)
	txt += "\n--- NPCs: ---"
	for each in characters:
		txt += "\n" + each
	return txt

func generate(origin:Vector2i) -> Dictionary[TacEntity, Vector2i]:
	var dict : Dictionary[TacEntity, Vector2i]
	var i : int = -1
	for each in characters:
		i += 1
		var chara : TacEntity = load("res://characters/tactical/pmc_breacher.tscn").instantiate()
		dict[chara] = origin + Vector2i(i,0)
	return dict
