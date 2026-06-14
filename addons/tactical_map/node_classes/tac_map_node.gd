@tool
extends Area3D
class_name TacMap

## A node edited by the TacMap Plugin that stores location of obstacles and
## places walls and floors for levels of a grid-based turn-based tactical combat game
## like XCom, Phantom Doctrine or Phoenix Point.[br]
## It includes a collision shape meant to detect mouse clicks so the player can interact
## with the map, like telling a character where to go.[br]
## NOTE: Maps can overlay if they are at different TacNav layers (height), 
## but please don't overlap them on the same layer.

#TODO Auto-tile upon rebuild

@export var size := Vector2i(12, 12) : 
	set(val):
		size = val.maxi(1)
		if is_node_ready():
			notification(NOTIFICATION_TRANSFORM_CHANGED)
			#TODO: update placements if size changes.

# Info used to build the map.
#NOTE: The spawners being in a dictionary ensures they are in unique coordinates. Also makes it fast to search if a coordinate is occupied.
@export var spawners : Dictionary[Vector2i, TacEntitySpawner]  ## Where NPCs are added
func add_spawner(where:Vector2i, which:TacEntitySpawner):
	spawners[where] = which
	var tacnav : TacNav = get_parent()
	# Ensure whether uniques exist already.
	if which.unique_to_tacnav() in tacnav.unique_spawners:
		var rival : Dictionary = tacnav.unique_spawners[which.unique_to_tacnav()]
		rival.map.rem_spawner(rival.coordi)
	# Register as being unique.
	if not which.unique_to_tacnav().is_empty():
		tacnav.unique_spawners[which.unique_to_tacnav()] = {
			"map" : self,
			"coordi" : where 
			}
	
	var id = str(Saliko.vec2i_id(where))
	if spawns.has_node(id):
		# Ensure there isn't a sprite at that place already.
		spawns.get_node(id).queue_free()
	# Create new sprite.
	var sprite := Sprite3D.new()
	sprite.texture = which.icon
	sprite.pixel_size = get_tile_size() / sprite.texture.get_width() * 0.65
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.position = Saliko.Vec2AddAxis(where, 1, get_tile_height() * 0.2) + Vector3(0.5, 0, 0.5) * get_tile_size()
	sprite.name = id
	spawns.add_child.call_deferred(sprite, true, Node.INTERNAL_MODE_FRONT)
func rem_spawner(where:Vector2i):
	spawners.erase(where)
	var id = str(Saliko.vec2i_id(where))
	if spawns.has_node(id):
		spawns.get_node(id).queue_free()

@export_storage var ladders : Dictionary[String, Vector2i]  ## Tiles that will teleport characters to other tiles of any TacMap under the same TacNav with the same ladder title.
@export_storage var zones : Dictionary[String, Rect2i]  ## Areas that emit a signal when a characters enters or leaves.
@export_storage var tiles : Dictionary[Vector2i, TacTile]  ## Contents of grid cells.

# Actual useful map contents, built upon «_ready()».
var placed : Dictionary[Vector2i, Array]  # Array of Node3D at given coordinate.

#region Inspector Buttons
@export_tool_button("Crop Map") var crop_map_func = crop_map  ## Clear tiles that are outside map area. Usually they are preserved to have persistance when offseting the tiles.

func crop_map():
	var area = Rect2i(Vector2i.ZERO, size)
	for coord in tiles:
		var tacnav : TacNav = get_parent()
		tacnav.nav_outdated.append(tacnav.map3nav(coord, self))
		if not area.has_point(coord):
			tiles.erase(coord)
			rem_spawner(coord)
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
	ladders.clear()
	for each in spawners:
		rem_spawner(each)
	var tacnav : TacNav = get_parent()
	for coord in tacnav.navproxy:
		tacnav.navproxy.erase(coord)  # Delete every data without checks like whether it's within map
		tacnav.queue_nav(coord)  # Inform the overlay to update
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

var _layer : int  ## The last layer this map was found to be on.
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
	if _layer != get_layer():
		tacnav._map_layer_changed(self, _layer)
		_layer = get_layer()
	tacnav.queue_area(get_layer())


var area_collider := CollisionShape3D.new()
var floors := Node3D.new()
var walls := Node3D.new()
var spawns := Node3D.new()
func _ready() -> void:
	area_collider.shape = BoxShape3D.new()
	area_collider.shape.size = Vector3(size.x * get_tile_size(), 0.2, size.y * get_tile_size())
	area_collider.position = area_collider.shape.size / 2
	
	add_child(area_collider, true, INTERNAL_MODE_BACK)
	add_child(floors, true, INTERNAL_MODE_BACK)
	add_child(walls, true, INTERNAL_MODE_FRONT)
	area_collider.name = "TacMapArea"
	floors.name = "TacMapFloors"
	walls.name = "TacMapWalls"
	
	# Place objects with stored references.
	for coord in tiles:
		queue_place(coord)
	
	_layer = get_layer()
	
	if OS.has_feature("editor_hint"):
		add_child(spawns, true, INTERNAL_MODE_FRONT)
		spawns.name = "TacMapSpawns"
	
		var former = spawners.duplicate_deep()
		spawners.clear()
		for each in former:
			add_spawner(each, former[each])
	else:
		# Give parameters for the collision shape for mouse detection.
		collision_layer = Con.phys_layer["tacmap"]
		input_ray_pickable = true
	
	print("TacMap loaded: «", name,"»; Tiles defined: ", tiles.size())

func _process(_delta: float) -> void:
	if not tile_queue.is_empty():
		tile_queue.clear.call_deferred()
		for cell in tile_queue:
			if tiles.get(cell) == null or tiles.get(cell).is_empty():
				tiles.erase(cell)
			place_assets(cell)
		var nav : TacNav = get_parent()
	
	if area_outdated:
		area_outdated = false
		update_area()

var tile_queue : Array[Vector2i]  # Dirty Pattern: We append all the coordinates that need contents updated here, then only on the next frame are they updated, once the decision of what to update is final.
func queue_place(cell:Vector2i):
	if not cell in tile_queue and Rect2i(Vector2i.ZERO, size).has_point(cell):
		tile_queue.append(cell)

## Update the visual assets from a TacTile UID.
func place_assets(cell:Vector2i):
	var tacnav : TacNav = get_parent()
	var self_area = Rect2i(Vector2i.ZERO, size)
	
	for each in placed.get(cell, []):
		each.queue_free()
	placed.erase(cell)
	
	if not self_area.has_point(cell) or not tiles.has(cell):
		return
		
	var tile : TacTile = tiles.get(cell)
	var floor = tile.get_floor_asset(get_tile_size())
	if not floor == null:
		floor.position = tacnav.tile2spatial(cell, 0, true)
		if tile.is_ceiling:
			floor.position.y += get_tile_height()
		floors.add_child(floor, false, Node.INTERNAL_MODE_BACK)
		if not placed.has(cell):
			placed[cell] = []
		placed[cell].append(floor)
		
	for wall in tile.get_walls_asset():
		wall.position = tacnav.tile2spatial(cell, 0, true,)
		walls.add_child(wall, false, Node.INTERNAL_MODE_FRONT)
		if not placed.has(cell):
			placed[cell] = []
		placed[cell].append(wall)

## Create or update tile, Ie. Put a new [code]TacTile[/code] in [code]tiles[/code].
func set_tile_asset(cell:Vector2i, side:Vector2i, info_uid:String):
	queue_place(cell)
	var asset_info : Resource = Tac.pallet_info[info_uid]
	var tile = tiles.get_or_add(cell, TacTile.new())
	if asset_info is FloorInfo:
		tiles[cell].floor = info_uid
		tiles[cell].floor_dir = side
		tiles[cell].has_floor = asset_info.is_solid
	elif asset_info is WallInfo:
		const wall_side = {
			Vector2i.RIGHT : "wall_east",
			Vector2i.LEFT : "wall_west",
			Vector2i.UP : "wall_north",
			Vector2i.DOWN : "wall_south",
		}
		tiles[cell].set(wall_side[side], info_uid)


func get_tile_size() -> float:
	assert(get_parent() is TacNav)
	return get_parent().tile_size
func get_tile_height() -> float:
	assert(get_parent() is TacNav)
	return get_parent().tile_height

## Get the height of the map according to increments of the parent TacNav grid in the Y direction.
func get_layer() -> int:
	return floori(inverse_lerp(0, get_tile_height(), position.y))
## Get the spatial height of the map, but snapped to the grid of the parent TacNav tile_height.
func get_height() -> float:
	return snappedf(position.y, get_tile_height())
## Get the height of the map according to increments of the parent TacNav tile_height in the global 3D grid.
func get_spatial_layer() -> int:
	assert(get_parent() is TacNav)
	var tacnav : TacNav = get_parent()
	return floori(inverse_lerp(0, get_tile_height(), position.y + tacnav.position.y))
## Get the spatial height of the map in the global coordinates, but snapped to the parent TacNav tile_height.
func get_spatial_height() -> float:
	assert(get_parent() is TacNav)
	var tacnav : TacNav = get_parent()
	return snappedf(position.y, get_tile_height()) + tacnav.position.y
