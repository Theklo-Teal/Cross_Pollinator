@tool
extends TacEntitySpawner
class_name PlayerSpawn

func _init() -> void:
	icon = preload("res://addons/tactical_map/assets/wojak_feels.png")

static func display_name() -> StringName:
	return &"Player Starting Point"

static func unique_to_tacnav() -> StringName:
	return &"PlayerSpawn"

func generate(origin:Vector2i) -> Dictionary[TacEntity, Vector2i]:
	var dict : Dictionary[TacEntity, Vector2i]
	var charas : Array = Ses.save.get_value("Team", "characters", [])
	var chara_pack = Saliko.get_square_pack(charas.size())
	for y in range(chara_pack.y):
		for x in range(chara_pack.x):
			if charas.is_empty():
				break
			var chara_name = charas.pop_back()
			var chara = load("res://characters/tactical/"+chara_name+".tscn").instantiate()
			dict[chara] = origin + Vector2i(x, y)
	return dict
