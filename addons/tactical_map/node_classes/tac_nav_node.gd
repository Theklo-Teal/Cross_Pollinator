@tool
extends Node3D
class_name TacNav

## A node that handles the navigation of multiple TacMaps and places characters where spawners are marked.

signal zone_entered(entity: TacEntity, zone: StringName)
signal zone_exited(entity: TacEntity, zone: StringName)
signal nav_changed(nav_tile : Array[Vector3i], tile:TacTile)

#NOTE This node only produces navigation graphs when first ready on an executed project. 
# Otherwise it uses «navproxy» which is easily modified. Modifications to children 
# TacMap during execution will modify «navsession» variable, which initally is a copy of the graphs.

@export var tile_size : float = 1.0  ## (meters) The lateral length of square tiles that all children maps abide to.
@export var tile_height : float = 2.0  ## How high walls can get.
@export var tile_margin : float = 0.0  ## (Not Implemented) An extra margin so ceilings have thickness and won't overlap floors above, or characters may sink in to the floor, for water-logged places, for example.

var charas : Array[TacCharacter]  ## Reference to placed characters.
var unique_spawners : Dictionary[StringName, Dictionary]
var zoned : Dictionary[Vector3i, Array]  ## [nav_coordi][i] -> StringName; Association of tile with a zone
var ladders : Dictionary[TacMap, Array]  ## [tacmap][i] -> Ladder; Which ladders each map has.

class Ladder:
	var name : StringName
	var can_enter : bool = true  ## Whether a character can step into this ladder to get to another.
	var can_exit : bool = true  # Whether a character can get to this ladder after entering another.

func _get_configuration_warnings() -> PackedStringArray:
	for each in get_children():
		if each is TacMap:
			return []
	return ["TacNav is intended to be used with TacMap children, otherwise it does nothing."]

#region TacMap handling
var area : Dictionary[int, Rect2i]  ## Total area enclosing all maps of each layer, given their positions and sizes.
var maps : Dictionary[int, Array]  ## [map layer][i] -> TacMap; Reference to placed maps.


## Called by TacMaps when they are added as children of this Node.
func _map_added(map:TacMap):
	var layer = map.get_layer()
	if not layer in maps:
		maps[layer] = []
	elif map in maps[layer]:
		return
	maps[layer].append(map)
	queue_area(layer)

## Called by TacMaps if about to leave this Node.
## The optional parameters are used for «_map_layer_changed()», so usually not meaningful.
func _map_removed(map:TacMap, layer_change:bool=false, layer_before:int=0):
	var layer = map.get_layer()
	if layer_change:
		layer = layer_before
	maps[layer].erase(map)
	if maps[layer].is_empty():
		maps.erase(layer)
	queue_area(layer)

func _map_layer_changed(map:TacMap, before:int):
	_map_removed(map, true, before)
	_map_added(map)

## Given a navigation tile coordinate and layer, which map is there? Return null if nothing is found.
func get_map_at(coord:Vector2i, layer:int) -> TacMap:
	for map : TacMap in maps[layer]:
		if map.nav_area.has_point(coord):
			return map
	return null

## Given a navigation tile coordinate, which maps are there? They will be sorted by layer.
func get_maps_at(coord:Vector2i) -> Array[TacMap]:
	var found : Array[TacMap]
	for layer : int in maps:
		for map : TacMap in maps[layer]:
			if map.nav_area.has_point(coord):
				found.append(map)
	found.sort_custom(func(a,b): return a.get_layer() < b.get_layer())
	return found
#endregion

#region Entity Handling
## Returns an array of tiles in the path between the entity and destination.
## the tile coordinates include Y axis for map layer.[br]
## It will return an empty array in the following situations:[br]
## If the entity's map can't be found.[br]
## The entity already is at the destination.[br]
## The entity tried to move between layers, but its maps and destin_map don't
## have ladders connecting them, or exiting ladders can't be used.[br]
func get_traject(entity:TacEntity, destin_tile:Vector2i, destin_map:TacMap) -> PackedVector3Array:
	var loc = locate_entity(entity)
	
	if loc.tacmap == null or destin_map == null:  # Couldn't find the map the entity is on or where it's going.
		return []
	if loc.nav_coord == destin_tile and loc.tacmap == destin_map:  # Position didn't change.
		return []
	
	unblock_navigation(loc.nav_coord, loc.layer)  # AStar2D Can't work if the character is sitting on a blocked tile.
	var start = Saliko.vec2i_id(loc.nav_coord)
	var stop = Saliko.vec2i_id(destin_tile)
	var full_path : PackedVector3Array
	var closest_path : Array[Vector2i]
	var inflection : int = 0
	var destin_layer = destin_map.get_layer()
	
	if destin_layer == loc.layer:
		# Search for a direct path without using ladders first
		var graph : AStar2D = navgraph[loc.layer][entity.attitude]
		closest_path.assign(graph.get_point_path(start, stop, true))
	
	# Discover ladders
	#NOTE This is setup such that characters can cross ladders of the same layer.
	for l_from in ladders.get(loc.tacmap, []):
		for l_to in ladders.get(destin_map, []):
			if l_from.name == l_to.name:
				if l_from.can_enter and l_to.can_exit:
					# Ladder is in common between entity's map and destin_map, and can be used.
					var from_cell = map2nav(loc.tacmap.ladders[l_from.name], loc.tacmap)
					var to_cell = map2nav(destin_map.ladders[l_to.name], destin_map)
					var from_id = Saliko.vec2i_id(from_cell)
					var to_id = Saliko.vec2i_id(to_cell)
					var path_from = navgraph[loc.layer][entity.attitude].get_point_path(start, from_id, false) 
					var path_to = navgraph[destin_layer][entity.attitude].get_point_path(to_id, stop, true)
					
					# Add a position where the character climbs before advancing onto the next layer.
					if destin_layer > loc.layer:
						path_from.append(path_from[-1])
					elif destin_layer < loc.layer:
						path_from.append(path_to[0])
					
					var path = path_from + path_to
					if closest_path.size() > path.size() or closest_path.is_empty():
						inflection = path_from.size()
						if destin_layer > loc.layer:
							inflection -= 1
						closest_path.assign(path)
	
	if closest_path.is_empty():
		# No direct path, nor usable ladders in common between the entity's map and the destination map.
		return []
	else:
		# AStar2D returns Vector2 coordinates, but we need Vector3.
		var layer = loc.layer
		var i : int = -1
		for tile in closest_path:
			i += 1
			if inflection > 0 and i == inflection:
				layer = destin_layer
			full_path.append(Vector3i(tile.x, layer, tile.y))

	block_navigation(loc.nav_coord, loc.layer)  # AStar2D Can't work if the character is sitting on a blocked tile.
	return full_path

## Find the map and coordinate of a TacEntity.
## It will give the map closest to the entity with a lower Y position.[br]
## Returns [code]tacmap[/code], [code]layer[/code], [code]map_coord[/code] and [code]nav_coord[/code].
func locate_entity(entity:TacEntity) -> Dictionary:
	var coord : Vector2i = spatial2nav_tile(entity.position) # TacNav tile of the entity position
	var relevant_maps = get_maps_at(coord)
	for idx in range(relevant_maps.size() - 1, -1, -1):
		var map : TacMap = relevant_maps[idx]
		if map.get_height() <= entity.position.y:
			return {
				"tacmap": map,  # Map where the entity belongs
				"layer": map.get_layer(),
				"map_coord": nav2map(coord, map),  # Coordinate relative to the map
				"nav_coord": coord  # Coordinate relative to this TacNav
				}
	return {
		"tacmap": null,
		"layer": 0,
		"nav_coord": coord,
		}

## Allows to tell which zones a character entered or exited while moving between two tiles.
func check_zone(actor:TacEntity, ini:Vector3i, end:Vector3i) -> Dictionary:
	var ans : Dictionary = {"entered":[], "exited":[]}
	var checked : Dictionary[StringName, bool]  # bool indicates the zone is unique to ini.
	for zone in zoned.get(ini, []):
		checked[zone] = true  # Assume any zone in ini to have been exited (not in common with end)
	for zone in zoned.get(end, []):
		if checked.get(zone, false):  # Is a zone in end already checked?
			checked.erase(zone)  # Remove from checked, leaving only uniques to ini
		else:
			zone_entered.emit(actor, zone)
			ans.entered.append(zone)  # Not found in ini, so is unique to end
	ans.exited = checked.keys()  # Only the uniques to ini are left.
	for each in ans.exited:
		zone_exited.emit(actor, each)
	return ans

## Produce a sprite that fits a tile. Optionally provide a map if the [code]coord[/code] is relative to it.
func place_tile_sprite(texture:Texture2D, coord:Vector2i, map:TacMap=null) -> Sprite3D:
	var sprite = Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = tile_size / sprite.texture.get_width()
	sprite.rotation_degrees.x = -90
	sprite.double_sided = false
	if map == null:
		sprite.position = tile2spatial(coord, 0, true)
		map.add_child(sprite, false, Node.INTERNAL_MODE_BACK)
	else:
		sprite.position = map3spatial(coord, map, true)
		add_child(sprite, false, Node.INTERNAL_MODE_BACK)
	return sprite
#endregion

## Makes a tile in [code]navsession[/code] disabled such it can't be entered.
## Usually because there are characters occupying it.
func block_navigation(tile:Vector2i, layer:int):
	var cell_id : int = Saliko.vec2i_id(tile)
	for trans in navsession[layer]:
		var nav : AStar2D = navsession[layer][trans]
		if not nav.has_point(cell_id):
			var in_area = area[layer].has_point(tile)
			printerr("TacNav.block_navigation(): navigation point doesn't exist!; Coordinate within area: ", in_area)
			break
		nav.set_point_disabled(cell_id, true)

## Re-enable a tile in [code]navsession[/code].
## Usually because a character moved out of it
func unblock_navigation(tile:Vector2i, layer:int):
	var cell_id : int = Saliko.vec2i_id(tile)
	for trans in navsession[layer]:
		var nav : AStar2D = navsession[layer][trans]
		if not nav.has_point(cell_id):
			var in_area = area[layer].has_point(tile)
			printerr("TacNav.unblock_navigation(): navigation point doesn't exist!; Coordinate within area: ", in_area)
			break
		nav.set_point_disabled(cell_id, false)

# Any modification to a map's terrain should update the «nav_queue», so many modifications can be performed in
# a process frame and only committed once at the end of the frame.
# Changes in map size or position should call «queue_area».
var area_outdated : PackedInt32Array  ## The layer where a map changed size or position.
var nav_outdated : Array[Vector3i]  ## In TacNav relative space. Add coordinates of TacNav cells that had terrain altered.
var navsession : Dictionary[int, Dictionary]  ## [Map Layer][Tac.Trans] -> AStart2D; A copy of «navgraph» that can be modified during a game session without losing the original for reference of what's default.
var navproxy : Dictionary[Vector3i, Array]  ## [cell coord] -> obstacle_codes;  Used to produce the navigation overlay. Faster than recreating AStar2D all the time. The coordinate is that of a tile with layer included. The value Dictionary is the return of «TacTile.get_trans_codes()».

func queue_area(layer:int):
	if not layer in area:
		area[layer] = Rect2i()
	if not layer in area_outdated:
		area_outdated.append(layer)

## Finds a Rect2i that fully encloses the children maps on each given layer.
func compute_area(layers:PackedInt32Array):
	for layer in layers:
		var first := true
		for map : TacMap in maps[layer]:
			if first:
				first = false
				area[layer] = map.nav_area
			else:
				area[layer] = area[layer].merge(map.nav_area)
		if not area[layer].has_area():
			area.erase(layer)

func queue_nav(coordi:Vector3i):
	#NOTE Can't check if «coordi» is in the area here, because during «_ready()» 
	# there will be «queue_nav()» calls that will be filtered out as the «area_queue»
	# hasn't been processed yet, the associated Rect2i will have no size, so there
	# won't be areas that contain the «coordi».
	var in_area = area[coordi.y].has_point(Saliko.Vec3RemAxis(coordi))
	if not coordi in nav_outdated and in_area:
		nav_outdated.append(coordi)

func _process(_delta: float) -> void:
	# This where frequent changes in terrain or area are handled, during level editing.
	
	if not area_outdated.is_empty():
		compute_area(area_outdated)
		area_outdated.clear()
	
	if not nav_outdated.is_empty():
		# Set navigation connections according to changes in map terrain.
		# Use block_navigation for placement of entities.
		nav_outdated.clear.call_deferred()
		for coord3i in nav_outdated:
			var layer = coord3i.y
			var nav_cell = Vector2i(coord3i.x, coord3i.z)
			
			var map = get_map_at(nav_cell, layer)
			nav_changed.emit(coord3i, map.tiles.get(nav2map(nav_cell, map)))
			
			# Change the NavProxy
			update_codes(nav_cell, layer, map)
			
			if not OS.has_feature("editor_hint"):
				# Change the NavSession
				pass


var navgraph : Dictionary[int, Dictionary]  ## [Map Layer][Tac.Trans] -> AStart2D; Main navigation data.
func _ready() -> void:
	if not area_outdated.is_empty():
		compute_area(area_outdated)
		area_outdated.clear()
	
	# Establish the existence of things.
	var chara_tiles : Array[Vector3i]  # Where entities are being placed, so we can block those tiles.
	for layer in maps:
		var layer_cells : Dictionary[int, Dictionary] # [tile_id][transcodes / adjacent_ids] -> Array[int] / Array[int]
		
		# Instantiate navigation graphs to the layer of the map
		if not layer in navgraph:
			navgraph[layer] = {}
			for trans in range(Tac.Trans.size()-1):
				navgraph[layer][trans] = AStar2D.new()
		
		for map : TacMap in maps[layer]:
			if not OS.has_feature("editor_hint"):
				# Place Entities/Characters
				for map_coord in map.spawners:
					var spawn_nav_tile = map2nav(map_coord, map)
					var characters = map.spawners[map_coord].generate(map_coord)
					for chara : TacEntity in characters:
						var chara_tile = map2nav(characters[chara], map)
						chara_tiles.append(Vector3i(chara_tile.x, layer, chara_tile.y))
						chara.position = tile2spatial(chara_tile, layer, true)
						add_child(chara, false, Node.INTERNAL_MODE_DISABLED)
				
				# Register zones to tiles
				for z in map.zones:
					var zone_area = map.zones[z]
					for y in range(zone_area.position.y, zone_area.end.y):
						for x in range(zone_area.position.x, zone_area.end.x):
							var tile_at_zone = zoned.get_or_add(map3nav(Vector2i(x,y), map), [])
							tile_at_zone.append(z)
			
				# Register ladders
				if not map in ladders and not map.ladders.is_empty():
					ladders[map] = []
					for l in map.ladders:
						var ladder = Ladder.new()
						ladder.name = l
						ladder.can_enter = true
						ladder.can_exit = true
						ladders[map].append(ladder)
		
		#NOTE We always compute the navproxy. `navgraph` relies on it. If the game is started without the editor, we will still need the proxy.
		build_navproxy(layer)
		
	if not OS.has_feature("editor_hint"):
		build_navgraph()
		# `Navsession` is just a copy of `navgraph` at the start, but what's used in-game for pathfinding
		# and will be edited if the terrain changes in-game.
		navsession = navgraph.duplicate_deep()
		for tile in chara_tiles:
			block_navigation(Vector2i(tile.x, tile.z), tile.y)

func at_map_edge(map_cell:Vector2i, map:TacMap):
		return map_cell.x == 0 or map_cell.y == 0 or map_cell.x == map.size.x - 1 or map_cell.y == map.size.y - 1

## Applies the rules for obstacle codes on [code]navproxy[/code].
func update_codes(nav_cell:Vector2i, layer:int, map:TacMap):
	if not area[layer].has_point(nav_cell):
		return
	
	var map_cell = nav2map(nav_cell, map)
	var nav_coord = Vector3i(nav_cell.x, layer, nav_cell.y)
	var adjacent : Dictionary[Vector2i, TacTile]
	for dir in Tac.Dir_Vect.values():
		adjacent[nav_cell + dir] = map.tiles.get(map_cell + dir)
	var map_tile : TacTile = map.tiles.get(map_cell)
	var codes : PackedInt32Array = [0,0,0,0]
	if map_tile != null:
		codes = map_tile.find_codes()
		
	var i : int = -1
	# Block paths towards undefined cells.
	for cell in adjacent:
		i += 1
		var adja = adjacent[cell]
		if adja == null:
			codes[i] == Tac.Trans.NONE
	
	# Set path into and out of holes as "AERIAL".
	for j in range(4):
		var adja : TacTile = adjacent.values()[j]
		var adja_cell : Vector2i = adjacent.keys()[j]
		if Rect2i(Vector2i.ZERO, map.size).has_point(adja_cell):  # We want to keep map edges possible to cross, so characters can cross between maps of the same layer
			if map_tile != null and map_tile.has_floor:
				# If the adjacent is a hole
				if (adja == null or not adja.has_floor) and codes[j] == Tac.Trans.PASS:
					codes[j] = Tac.Trans.AERIAL
			else:
				# If this cell is a hole
				if adja != null and adja.has_floor:
					codes[j] == Tac.Trans.AERIAL

	if nav_cell.x == area[layer].position.x:
		codes[Tac.WEST] = Tac.Trans.NONE
	if nav_cell.y == area[layer].position.y:
		codes[Tac.NORTH] = Tac.Trans.NONE
	if nav_cell.x == area[layer].end.x - 1:
		codes[Tac.EAST] = Tac.Trans.NONE
	if nav_cell.y == area[layer].end.y - 1:
		codes[Tac.SOUTH] = Tac.Trans.NONE
	navproxy[nav_coord] = codes

## Iterate over [code]area[/code] and [code]TacMap.tiles[/code] to find obstacle/transition codes.
func build_navproxy(layer:int):
	for map : TacMap in maps[layer]:
		for map_cell in Saliko.cells_of(Vector2i(0, map.size.x), Vector2i(0, map.size.y)):
			var nav_cell = map2nav(map_cell, map)
			update_codes(nav_cell, layer, map)

## Convert data in [code]navproxy[/code] to connections in [code]AStar2D[/code] graphs.
## This function trusts that [code]navproxy[/code] has precompute all conditions for transitions
## properly, so here we don't do any checks with adjacent tiles or whatever.
func build_navgraph():
	for layer : int in area:
		for nav_cell in Saliko.cells_of(Vector2i(area[layer].position.x, area[layer].end.x), Vector2i(area[layer].position.y, area[layer].end.y)):
			var coord = Vector3i(nav_cell.x, layer, nav_cell.y)
			var cell_code = navproxy.get(coord, [])
			if cell_code.is_empty():  # Tile is undefined.
				continue
			var cell_id = Saliko.vec2i_id(nav_cell)
			for i : Tac.Trans in range(navgraph[layer].size()):
				var graph : AStar2D = navgraph[layer][i]
				graph.add_point(cell_id, nav_cell)
				
				for oppo in [0, 1]:  # We are scanning from towards positive x and y, so we check tiles in the north, west direction, and adjacent in the east, south, which are opposite.
					var side = [2,3][oppo]
					var trans : Tac.Trans = navproxy[coord][side]
					var adja_cell = [Vector2i.LEFT, Vector2i.UP][oppo] + nav_cell
					var adja_coord = Vector3i(adja_cell.x, layer, adja_cell.y)
					if not adja_coord in navproxy or trans == Tac.Trans.NONE:
						continue
					var adja_id = Saliko.vec2i_id(adja_cell)
					var adja_trans : Tac.Trans = navproxy[adja_coord][oppo]
					if trans == Tac.Trans.PASS or trans == i:  #NOTE Considerations about undefined tiles and tiles without floor is responsability of navproxy.
						graph.connect_points(cell_id, adja_id, false)
					if adja_trans == Tac.Trans.PASS or adja_trans == i:
						graph.connect_points(adja_id, cell_id, false)


#region Coordinate System Conversions

#region Generic
## From a Vector2 coord, find a grid-bound coordinate according to tile size.
func spatial2tile(coord:Vector2) -> Vector2i:
	coord.x = inverse_lerp(0, tile_size, coord.x)
	coord.y = inverse_lerp(0, tile_size, coord.y)
	coord = coord.floor()
	return Vector2i(coord.x, coord.y)

## From a Vector3 coord, find a grid-bound coordinate according to tile size and
## height. Y coordinate will be tile height units.
func spatial3tile(coord:Vector3) -> Vector3i:
	coord.x = inverse_lerp(0, tile_size, coord.x)
	coord.y = inverse_lerp(0, tile_height, coord.y)
	coord.z = inverse_lerp(0, tile_size, coord.z)
	return Vector3i(coord.floor())

## Generically get a space coordinate for the given tile coord.
## If [code]centered[/code] is [code]true[/code], an offset is added 
## to find the center of the tile. It assumes tiles as 2D. If height
## is important, it can be provided as [code]layer[/code].
func tile2spatial(coordi:Vector2i, layer:int=0, centered:=false) -> Vector3:
	var coord := Vector3.ZERO
	coord.x = lerpf(0, tile_size, coordi.x)
	coord.y = lerpf(0, tile_height, layer)
	coord.z = lerpf(0, tile_size, coordi.y)
	if centered:
		coord.x += tile_size * 0.5
		coord.z += tile_size * 0.5
	return coord

## Generically get a space coordinate for the given tile coord. Coordinate Y is
## properly addressed as tile height.
## If [code]centered[/code] is [code]true[/code], an offset is added 
## to find the center of the tile in the XZ axis.
func tile3spatial(coordi:Vector3i, centered:=false) -> Vector3:
	var coord := Vector3.ZERO
	coord.x = lerpf(0, tile_size, coordi.x)
	coord.y = lerpf(0, tile_height, coordi.y)
	coord.z = lerpf(0, tile_size, coordi.z)
	if centered:
		coord.x += tile_size * 0.5
		coord.z += tile_size * 0.5
	return coord
#endregion

#region To Global Space
func nav3spatial(coordi:Vector3i, centered:=false) -> Vector3:
	return tile3spatial(coordi, centered) + position

func nav2spatial_tile(coordi:Vector2i) -> Vector2i:
	return coordi + spatial2tile(Saliko.Vec3RemAxis(position))

func map2spatial(coordi:Vector2i, map:TacMap) -> Vector2:
	var coord = Vector2(coordi) + Saliko.Vec3RemAxis(position + map.position)
	return coord

## Returns tiles in 3D Global coordinate from tiles in a TacMaps.
func map2spatial_tile(coordi:Vector2i, map:TacMap) -> Vector2i:
	return coordi + spatial2tile(Saliko.Vec3RemAxis(position + map.position))

## Returns the Global 3D coordinate of a tile in the TacMap. Optionally point to the center of the tile on the XZ plane.
func map3spatial(coordi:Vector2i, map:TacMap, centered:=false) -> Vector3:
	var coord : Vector3 = tile3spatial(Saliko.Vec2AddAxis(coordi, 1, map.position.y), centered)
	return coord + position
#endregion

#region To TacNav
## Global space coordinate to TacNav space coordinate.
func spatial2nav(coord:Vector3) -> Vector2:
	return Saliko.Vec3RemAxis(coord - position)

## Global 3D coordinate goes in, TacNav relative tile goes out. Height value is neglected.
## If desired, use [code]spatial3nav[/code] instead.
func spatial2nav_tile(coord:Vector3) -> Vector2i:
	coord -= position
	return spatial2tile(Saliko.Vec3RemAxis(coord))

## Global 3D coordinate goes in, TacNav relative coordinate goes out.
func spatial3nav(coord:Vector3) -> Vector3:
	return coord - position

## Global 3D coordinate goes in, TacNav relative tile goes out. Y coordinate will be a TacMap layer.
func spatial3nav_tile(coord:Vector3) -> Vector3i:
	return spatial3tile(spatial3nav(coord))

## TacMap tile coord goes in and TacNav coordinate where that is comes out.
func map2nav(coordi:Vector2i, map:TacMap) -> Vector2i:
	coordi += spatial2tile(Saliko.Vec3RemAxis(map.position))
	return coordi

## TacMap tile coord goes in and TacNav coordinate where that is comes out.
func map3nav(coordi:Vector2i, map:TacMap) -> Vector3i:
	coordi = map2nav(coordi, map)
	return Vector3i(coordi.x, map.get_layer(), coordi.y)
#endregion

#region To TacMap
## Tile in Global space coordinate to a tile in TacMap space.
func spatial_tile2map_tile(coordi:Vector2i, map:TacMap) -> Vector2i:
	var coord = Saliko.Vec3RemAxis(position + map.position)
	return  coordi - spatial2tile(coord)

## Global space coordinate to TacMap space.
func spatial2map(coord:Vector3, map:TacMap) -> Vector2:
	coord -= position + map.position
	return Saliko.Vec3RemAxis(coord)

## Global 3D coordinate goes in, TacMap relative tile goes out.
## The height is neglected. If desired us [code]spatial3map[/code] instead.
func spatial2map_tile(coord:Vector3, map:TacMap) -> Vector2i:
	return spatial2tile(spatial2map(coord, map))

## Global 3D coordinate goes in, TacMap relative tile goes out.
## By default the Y coordinate is the layer of the given TacMap,
## but you can specify to find the layer from the given coordinate.
func spatial3map_tile(coord:Vector3, map:TacMap, layer_from_spatial:=false) -> Vector3i:
	coord -= position + map.position
	var coordi = spatial3tile(coord)
	if not layer_from_spatial:
		coordi.y = map.get_layer()
	return coordi

func spatial3map(coord:Vector3, map:TacMap, height_from_spatial:=false) -> Vector3:
	coord -= position + map.position
	if not height_from_spatial:
		coord.y = map.get_spatial_height()
	return coord

## TacNav tile coord goes in and coordinate at the given TacMap goes out.
func nav2map(coordi:Vector2i, map:TacMap) -> Vector2i:
	coordi -= spatial2tile(Saliko.Vec3RemAxis(map.position))
	return coordi
#endregion
#endregion
