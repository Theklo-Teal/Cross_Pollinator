@tool
extends Sprite3D

@export_storage var unique_to_tacnav : StringName = &""  ## Set the a name in this variable to make it only appear once in all TacMaps under a Nav.

func _ready() -> void:
	add_to_group("tacEntitySpawner")
	texture = preload("res://addons/tactical_map/assets/chad_wojak.png")
	pixel_size = texture.get_width() / get_parent().get_tile_size()
	billboard = BaseMaterial3D.BILLBOARD_ENABLED

## Create character instances and the returns them associated to their tile coordinate.
func generate(origin:Vector2i) -> Dictionary[TacEntity, Vector2i]:
	return {}
