@tool
extends Resource
class_name TacTile

const DIR_ANGLE = {
	Vector2i.RIGHT: 0,
	Vector2i.DOWN: 270,
	Vector2i.LEFT: 180,
	Vector2i.UP: 90,
	}

@export_storage var is_ceiling : bool  ## The floor is actually a ceiling.
@export_storage var force_floor : bool = false  ## Whether the current [code]has_floor[/code] was enforced manually, or is set by the definition of [code]floor[/code].
@export_storage var has_floor : bool = false  ## Regardless of a floor asset, can characters walk over this tile?
@export_storage var floor : StringName :   ## UID FloorInfo that defines the assets. Setting it empty will set [code]has_floor[/code], [code]force_floor[/code] and [code]is_ceiling[/code] to [code]false[/code].
	set(val):
		var new = _asset_checker(floor, val)
		if new != floor and new.is_empty():
			has_floor = false
			force_floor = false
			is_ceiling = false
		floor = new
@export_storage var floor_name : StringName  ## Which of the sprites referred in the FloorInfo.
@export_storage var floor_dir := Vector2i.LEFT :  ## The orientation of the floor.
	set(val):
		if val in DIR_ANGLE:
			floor_dir = val
@export_storage var wall_east: StringName :  ## UID of the WallInfo that defines the assets.
	set(val):
		wall_east = _asset_checker(wall_east, val)
@export_storage var wall_south : StringName :  ## UID of the WallInfo that defines the assets.
	set(val):
		wall_south = _asset_checker(wall_south, val)
@export_storage var wall_west : StringName :  ## UID of the WallInfo that defines the assets.
	set(val):
		wall_west = _asset_checker(wall_west, val)
@export_storage var wall_north : StringName :  ## UID of the WallInfo that defines the assets.
	set(val):
		wall_north = _asset_checker(wall_north, val)

func _asset_checker(old:StringName, new:StringName) -> StringName:
	var ans : StringName
	if ResourceUID.ensure_path(new).is_empty():
		ans = &""
	else:
		ans = new
	return ans

## What would the «find_codes()» output be if there was a TacTile where there is no content.
static func get_empty_codes() -> PackedInt32Array:
	return []

## Whether we should delete this tile from the map.
func is_empty() -> bool:
	for dir in range(4):
		if not get_wall(dir).is_empty():
			return false
	if not floor.is_empty() or has_floor:
		return false
	return true

func find_codes() -> PackedInt32Array:
	var codes : PackedInt32Array
	for i in range(4):
		var uid = get_wall(i)
		var info : WallInfo = Tac.pallet_info.get(uid)
		if uid.is_empty():
			codes.append(Tac.Trans.PASS)
		elif info == null:
			codes.append(Tac.Trans.NONE)
		else:
			codes.append(info.transition)
	return codes

## Get wall by index
func get_wall(direction:Tac.Dir):
	return [wall_east, wall_south, wall_west, wall_north][direction]
## Get the wall by compass direction.
func get_wall_dir(direction:StringName):
	return {
		&"EAST": wall_east,
		&"SOUTH": wall_south,
		&"WEST": wall_west,
		&"NORTH": wall_north,
	}[direction]

func get_floor_asset(tile_size:int = 32) -> Sprite3D:
	if floor.is_empty():
		return null
	var info = Tac.pallet_info[floor]
	var new_floor := Sprite3D.new()
	new_floor.texture = info.atlas.duplicate()
	new_floor.texture.region.position = Vector2(info.tiles.values()[0])  #NOTE when auto-tilling this should could be different.
	new_floor.double_sided = false
	new_floor.pixel_size = tile_size / new_floor.texture.region.size.x
	new_floor.rotation_degrees.x = -90
	new_floor.rotation_degrees.y = DIR_ANGLE[floor_dir]
	return new_floor

func get_walls_asset() -> Array[Node3D]:
	var walls : Array[Node3D]
	for i in range(4):
		var dir = [Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN][i]
		var wall_info_uid = [wall_east, wall_north, wall_west, wall_south][i]
		if not wall_info_uid.is_empty():
			var wall_info = Tac.pallet_info[wall_info_uid]
			var uid = wall_info.asset_single  #NOTE when auto-tilling this should could be different.
			var new_wall = load(uid).instantiate()
			new_wall.rotation_degrees.y = DIR_ANGLE[dir]
			walls.append(new_wall)
	return walls
