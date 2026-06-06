@tool
extends Resource
class_name TacEntitySpawner

@export var icon = preload("res://addons/tactical_map/assets/chad_wojak.png")
@export_storage var unique_to_tacnav : StringName = &""  ## Set the a name in this variable to make it only appear once in all TacMaps under a Nav.

## Create character instances and the returns them associated to their tile coordinate.
func generate(origin:Vector2i) -> Dictionary[TacEntity, Vector2i]:
	return {}
