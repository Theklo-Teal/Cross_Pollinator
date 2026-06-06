@tool
extends Area3D
class_name TacMap

## A node edited by the TacMap Plugin that stores location of obstacles and
## places walls and floors for levels of a grid-based turn-based tactical combat game
## like XCom, Phantom Doctrine or Phoenix Point.[br]
## It includes a collision shape meant to detect mouse clicks so the player can interact
## with the map, like telling a character where to go.[br]
## NOTE: Maps can overlay if they are different TacNav layers (height), 
## but please don't overlap them on the same layer.

#TODO Auto-tile upon rebuild

@export var size := Vector2i(12, 12) : 
	set(val):
		size = val.maxi(1)
		notification(NOTIFICATION_LOCAL_TRANSFORM_CHANGED)
		#TODO: update placements if size changes.

# Info used to build the map.
#NOTE: The spawners being in a dictionary ensures they are in unique coordinates. Also makes it fast to search if a coordinate is occupied.
@export var spawns : Dictionary[Vector2i, TacEntitySpawner]  ## Where NPCs are added
@export_storage var ladders : Dictionary[Vector2i, String]  ## Tiles that will teleport characters to other tiles of any TacMap under the same TacNav with the same ladder title.
@export_storage var zones : Dictionary[String, Rect2i]  ## Areas that emit a signal when a characters enters or leaves.
@export_storage var tiles : Dictionary[Vector2i, TacTile]  ## Contents of grid cells.

# Actual useful map contents, built upon «_ready()».
var placed : Dictionary[Vector2i, Array]  # Array of Node3D at given coordinate.

#region Inspector Buttons
@export_tool_button("Crop Map") var crop_map_func = crop_map  ## Clear tiles that are outside map area. Usually they are preserved to have persistance when offseting the tiles.

func crop_map():
	var area = Rect2i(Vector2i.ZERO, size)
	for coord in tiles:
		if not area.has_point(coord):
			tiles.erase(coord)
			if coord in placed:
				for node in placed[coord]:
					node.queue_free()
				placed.erase(coord)

@export_tool_button("Clear Map") var clear_map_func = clear_map  ## Remove assets from the map and clear tiles.

## Note that this is meant to use in the editor only. It will not rebuild the Navigation graphs.
func clear_map():
	for coord in placed:
		for node in placed[coord]:
			node.queue_free()
	placed.clear()
	tiles.clear()
	zones.clear()
	spawns.clear()
	var tacnav : TacNav = get_parent()
	for coord in tacnav.navproxy:
		tacnav.navproxy[coord] = {}
#endregion


func _get_configuration_warnings() -> PackedStringArray:
	if not get_parent() is TacNav:
		return ["TacMap requires a TacNav parent to provide navigation for characters."]
	else:
		return []

func _enter_tree() -> void:
	assert(get_parent() is TacNav)
	var tacnav : TacNav = get_parent()
	position.y = snapped(position.y, get_tile_height())
	position.x = snapped(position.x, get_tile_size())
	position.z = snapped(position.z, get_tile_size())
	update_area()
	tacnav._map_added(self)

func _exit_tree() -> void:
	assert(get_parent() is TacNav)
	var tacnav : TacNav = get_parent()
	tacnav._map_removed(self)

var nav_area : Rect2i  ## The area, in tile units, in the parent TacNav.
var global_area : Rect2i  ## Area of the map in global 3D space, but in tile size units.
var area_outdated : bool = true
func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		area_outdated = true

func update_area():
	var tacnav : TacNav = get_parent()
	var map_nav_pos : Vector2i = tacnav.spatial2tile(Saliko.Vec3RemAxis(position))
	var map_glob_pos : Vector2i = tacnav.nav2spatial_tile(map_nav_pos)
	nav_area = Rect2i(map_nav_pos, size)
	global_area = Rect2i(map_glob_pos, size)
	print("TacMap: Computed area ", nav_area)


var area_collider := CollisionShape3D.new()
var floors := Node3D.new()
var walls := Node3D.new()
var spawners := Node3D.new()
func _ready() -> void:
	area_collider.shape = BoxShape3D.new()
	area_collider.shape.size = Vector3(size.x * get_tile_size(), 0.2, size.y * get_tile_size())
	area_collider.position = area_collider.shape.size / 2
	
	add_child(area_collider, true, INTERNAL_MODE_BACK)
	add_child(floors, true, INTERNAL_MODE_BACK)
	add_child(walls, true, INTERNAL_MODE_FRONT)
	add_child(spawners, true, INTERNAL_MODE_FRONT)
	area_collider.name = "TacMapArea"
	floors.name = "TacMapFloors"
	walls.name = "TacMapWalls"
	
	# Place objects with stored references.
	for y in range(size.y):
		for x in range(size.x):
			var coord = Vector2i(x,y)
			if coord in tiles:
				if not tiles[coord].has_content():
					tiles.erase(coord)
				else:
					queue_place.append(coord)
	
	if not OS.has_feature("editor_hint"):
		# Give parameters for the collision shape for mouse detection.
		#TODO How may I click through empty tiles and detect maps beyond this shape?
		collision_layer = Con.phys_layer["tacmap"]
		input_ray_pickable = true
	
	print("TacMap loaded: «", name,"»; Tiles defined: ", tiles.size())

func _process(_delta: float) -> void:
	if not queue_place.is_empty():
		place_assets(queue_place)
	queue_place.clear()
	
	if area_outdated:
		area_outdated = false
		update_area()

var queue_place : Array[Vector2i]  # Observer Pattern: We append all the coordinates that need contents updated here, then only on the next frame are they updated, once the decision of what to update is final.
## Update the visual assets from the TacTile UIDs
func place_assets(coords:Array[Vector2i]):
	var tacnav : TacNav = get_parent()
	var self_area = Rect2i(Vector2i.ZERO, size)
	
	for coord in coords:
		if not self_area.has_point(coord):
			printerr("Not in map area: ", coord)
			continue
		var tile : TacTile = tiles.get(coord)
		for each in placed.get(coord, []):
			each.queue_free()
		placed.erase(coord)
		if tile == null:
			continue
		
		var floor = tile.get_floor_asset(get_tile_size())
		if not floor == null:
			floor.position = tacnav.tile2spatial(coord, 0, true)
			if tile.is_ceiling:
				floor.position.y += get_tile_height()
			floors.add_child(floor, false, Node.INTERNAL_MODE_BACK)
			if not placed.has(coord):
				placed[coord] = []
			placed[coord].append(floor)
		
		for wall in tile.get_walls_asset():
			wall.position = tacnav.tile2spatial(coord, 0, true,)
			walls.add_child(wall, false, Node.INTERNAL_MODE_FRONT)
			if not placed.has(coord):
				placed[coord] = []
			placed[coord].append(wall)

func set_tile_asset(coord:Vector2i, side:Vector2i, info_uid:String):
	queue_place.append(coord)
	var asset_info : Resource = Tac.pallet_info[info_uid]
	var tile = tiles.get_or_add(coord, TacTile.new())
	if asset_info is FloorInfo:
		tiles[coord].floor = info_uid
		tiles[coord].floor_dir = side
		tiles[coord].has_floor = asset_info.is_solid
	elif asset_info is WallInfo:
		const wall_side = {
			Vector2i.RIGHT : "wall_east",
			Vector2i.LEFT : "wall_west",
			Vector2i.UP : "wall_north",
			Vector2i.DOWN : "wall_south",
		}
		tiles[coord].set(wall_side[side], info_uid)


func get_tile_size() -> float:
	assert(get_parent() is TacNav)
	return get_parent().tile_size
func get_tile_height() -> float:
	assert(get_parent() is TacNav)
	return get_parent().tile_height

## Get the height of the map according to increments of the parent TacNav grid in the Y direction.
func get_layer() -> int:
	return floori(inverse_lerp(0, get_tile_height(), position.y))
## Get the spatial height of the map, but snapped to the grid of the parent TacNav tile_height. Also corrects self position.y if it is offset.
func get_height() -> float:
	return snappedf(position.y, get_tile_height())
## Get the height of the map according to increments of the parent TacNav tile_height in the global 3D grid.
func get_spatial_layer() -> int:
	assert(get_parent() is TacNav)
	var tacnav : TacNav = get_parent()
	return floori(inverse_lerp(0, get_tile_height(), position.y + tacnav.position.y))
## Get the spatial height of the map in the global coordinates, but snapped to the parent TacNav tile_height. Also corrects self position.y if it is offset.
func get_spatial_height() -> float:
	assert(get_parent() is TacNav)
	var tacnav : TacNav = get_parent()
	return snappedf(position.y, get_tile_height()) + tacnav.position.y
