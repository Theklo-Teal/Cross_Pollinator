@tool
extends Resource
class_name TacTile

@export_storage var has_ceiling : bool = true  ## Things can't climb up from the map with this tile.
@export_storage var has_floor : bool = false  ## Regardless of a floor asset, can characters walk over this tile?
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
	return [Tac.Trans.NONE,Tac.Trans.NONE,Tac.Trans.NONE,Tac.Trans.NONE]

## Whether we should delete this tile from the map.
func is_empty() -> bool:
	for dir in range(4):
		if not get_wall(dir).is_empty():
			return false
	if has_floor or has_ceiling: return false
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


func get_wall_info(direction:Tac.Dir) -> WallInfo:
	var wall = get_wall(direction)
	return Tac.pallet_info.get(wall)

## Could a character be able to see through the obstacle in the given direction?[br]
## Also accounts type of obstacle, where anything not TALL or CRAWL is considered visible.
## The [code]medthod[/code] allows specifying what senses the character has.
## If that info is not available in the tile, it's assumed to be false.
func can_see_thru(direction:Tac.Dir, method:=WallInfo.VISION.RGB) -> bool:
	var wall := get_wall_info(direction)
	if not wall.transition in [Tac.Trans.TALL, Tac.Trans.CRAWL]:
		return true
	return wall.see_thru.get(method)

func get_walls_asset() -> Array[Node3D]:
	var walls : Array[Node3D]
	for i in range(4):
		var dir = [Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN][i]
		var wall_info_uid = [wall_east, wall_north, wall_west, wall_south][i]
		if not wall_info_uid.is_empty():
			var wall_info = Tac.pallet_info[wall_info_uid]
			var uid = wall_info.asset_single  #NOTE when auto-tilling this should could be different.
			var new_wall = load(uid).instantiate()
			new_wall.rotation_degrees.y = Tac.DIR_ANG[dir]
			walls.append(new_wall)
	return walls
