extends Resource
class_name FloorInfo

@export var name : StringName = "Floor"
@export var tags : PackedStringArray
@export var is_solid : bool = true  ## Can characters walk over this floor?
@export var atlas : AtlasTexture
@export var tiles : Dictionary[String, Vector2i]  ## Tile Name: Atlas Coordinates;
