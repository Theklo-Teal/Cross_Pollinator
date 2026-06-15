@tool
extends Resource
class_name TacEntitySpawner

@export var icon = preload("res://addons/tactical_map/assets/chad_wojak.png")
@export_enum("EAST", "SOUTH", "WEST", "NORTH") var orientation : int

## What name the level editor pallet will display for this spawner. Also how it is referred in indexes.
static func display_name() -> StringName:
	return &"EntitySpawner"

## Set the a name in this variable to make it only appear once in all TacMaps under a Nav.
static func unique_to_tacnav() -> StringName:
	return &""

## Help hints or information about the parameters of the current spawner instance to display in the Tactical Editor pallet panel.
func editor_info() -> String:
	return display_name()

## Helper function to make characters face a direction. Assumes the character's front is towards positive Z. From 0 to 3, directions are EAST, SOUTH, WEST, NORTH.
func orient(entity:TacEntity, dir:int):
	dir = (dir - 1) % 3
	entity.rotation_degrees.y = Tac.DIR_ANG.values()[dir]

## Create character instances and the returns them associated to their tile coordinate.
func generate(origin:Vector2i) -> Dictionary[TacEntity, Vector2i]:
	return {}
