@tool
extends Resource
class_name TacTile

@export_storage var is_ceiling : bool  ## The floor is actually a ceiling.
@export_storage var has_floor : bool = false  ## Regardless of a floor asset, can characters walk over this tile?
@export_storage var floor : StringName  ## UID FloorInfo that defines the assets.
@export_storage var floor_name : StringName  ## Which of the sprites referred in the FloorInfo.
@export_storage var floor_dir := Vector2i.LEFT :  ## The orientation of the floor.
	set(val):
		if val in DIR_ANGLE:
			floor_dir = val
@export_storage var wall_east: StringName  ## UID of the WallInfo that defines the assets.
@export_storage var wall_south : StringName  ## UID of the WallInfo that defines the assets.
@export_storage var wall_west : StringName  ## UID of the WallInfo that defines the assets.
@export_storage var wall_north : StringName  ## UID of the WallInfo that defines the assets.

const DIR_ANGLE = {
	Vector2i.RIGHT: 0,
	Vector2i.DOWN: 270,
	Vector2i.LEFT: 180,
	Vector2i.UP: 90,
	}

## Whether we should delete this tile from the map.
func has_content() -> bool:
	for dir in range(4):
		if not get_wall(dir).is_empty():
			return true
	if floor.is_empty() and not has_floor:
		return false
	return true

## If the tile doesn't define floor or ceiling.
func is_empty() -> bool:
	return not has_floor

## Get the wall by index.
func get_wall(direction:Tac.Dir):
	return [wall_east, wall_south, wall_west, wall_north][direction]

## Return the transition of this tile in the provided direction.
func get_transition(direction:Tac.Dir, adjacent:TacTile) -> Tac.Trans:
	var wall = get_wall(direction)
	var leads_to_hole = adjacent == null or not adjacent.has_floor
	if leads_to_hole:
		return Tac.Trans.TALL  #TODO Could a hole in the map return a code that isn't "Tac.Trans.TALL"?
	elif wall.is_empty():  # There's no wall.
		return Tac.Trans.PASS
	else:
		return Tac.pallet_info[wall].transition

## Return the transition between this tile and those adjacent.
## It returns a full obstacle code («code» key), a simplified one («simple» key) which only tells whether
## a side has an obstacle, and the «sides» key is an array with the transition code of each side.
func get_trans_codes(adjacent:Array[TacTile]) -> Dictionary:
	var ans : Dictionary = get_empty_codes()
	var side : int = -1
	for dir in Tac.Dir:
		var dir_i = Tac.Dir.keys().find(dir)
		side += 1
		ans.sides[side] = get_transition(dir_i, adjacent[dir_i])
		ans.code |= ans.sides[side] << (side * 2)
		ans.simple |= int(ans.sides[side] > 0) << side
	return ans

## What would the «get_trans_codes()» output be if there was a TacTile where there is no content.
static func get_empty_codes() -> Dictionary:
	return {
		"code":0,
		"simple":0,
		"sides":[0,0,0,0]
	}

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
