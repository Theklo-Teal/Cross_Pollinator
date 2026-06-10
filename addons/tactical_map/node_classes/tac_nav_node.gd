@tool
extends Node3D
class_name TacNav

## A node that handles the navigation of multiple TacMaps and places characters where spawners are marked.

signal navproxy_changed(tile_coord : Array[Vector3i])
signal zone_entered(zone:StringName, chara:TacCharacter)  ## The character entered a zone. Multiple zones are possible for each tile, so you may get multiple signals from this.
signal zone_exited(zone:StringName, chara:TacCharacter)  ## The character exited a zone. Multiple zones are possible for each tile, so you may get multiple signals from this.

#NOTE This node only produces navigation graphs when first ready on an executed project. 
# Otherwise it uses «navproxy» which is easily modified. Modifications to children 
# TacMap during execution will modify «navsession» variable, which initally is a copy of the graphs.


@export var tile_size : float = 1.0  ## (meters) The lateral length of square tiles that all children maps abide to.
@export var tile_height : float = 2.0  ## How high walls can get.

var charas : Array[TacCharacter]  ## Reference to placed characters.
var unique_spawners : Dictionary[StringName, Dictionary]
var zoned : Dictionary[Vector3i, Array]  ## [nav_coordi][i] -> StringName; Association of tile with a zone
var ladders : Dictionary[TacMap, Array]  ## [tacmap][i] -> Ladder; Which ladders each map has.

class Ladder:
	var name : StringName
	var can_enter : bool  ## Whether a character can step into this ladder to get to another.
	var can_exit : bool  # Whether a character can get to this ladder after entering another.

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
	if loc.tacmap == null:  # Couldn't find the map the entity is on.
		return []
	if loc.nav_coord == destin_tile and loc.tacmap == destin_map:  # Position didn't change.
		return []
	
	var start = Saliko.vec2i_id(loc.nav_coord)
	var stop = Saliko.vec2i_id(destin_tile)
	var full_path : PackedVector3Array
	
	if destin_map == loc.tacmap:
		#NOTE Ladders are intended for traversing between layers, so we'd check 
		# if initial and final layers are the same, but it might be interesting
		# to connect different maps on the same layer. There won't be conflict
		# because maps have their own coordinate on their ladders.
		for tile : Vector2i in navgraph[loc.layer][entity.attitude].get_point_path(start, stop, true):
			full_path.append(Vector3(tile.x, loc.layer, tile.y))
	else:
		var ladders_from : Array[Ladder] = ladders.get(loc.map)
		var ladders_to : Array[Ladder] = ladders.get(destin_map)
		
		var closest_ladder : StringName
		var closest_path : Array[Vector2i]
		for l_from : Ladder in ladders_from:
			for l_to : Ladder in ladders_to:
				if l_from.name == l_to.name and l_from.can_enter and l_to.can_exit:
					# Ladder is in common between entity's map and destin_map, and can be used.
					var enter_ladder = Saliko.vec2i_id(loc.tacmap.ladders[l_from.name])
					var path_from = navgraph[loc.layer][entity.attitude].get_point_path(start, enter_ladder) 
					if closest_path.size() > path_from.size():
						closest_path = path_from
						closest_ladder = l_from.name
		
		if closest_path.is_empty():
			# No usable ladders in common between the entity's map and the destination map.
			return []
		
		## AStar2D returns Vector2 coordinates, but we need Vector3.
		for tile in closest_path:
			full_path.append(Vector3i(tile.x, loc.layer, tile.y))
		var exit_ladder = Saliko.vec2i_id(destin_map.ladders[closest_ladder]) 
		for tile in navgraph[loc.layer][entity.attitude].get_point_path(exit_ladder, stop):
			full_path.append(Vector3i(tile.x, destin_map.get_layer(), tile.y))
		
	return full_path

## Find the map and coordinate of a TacEntity.
## It will give the map closest to the entity with a lower Y position.[br]
## Returns `tacmap`, `layer`, `map_coord` and `nav_coord`.
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

## Allows to tell which zones a character entered or exited while moving between two tiles
## And triggers signals and functions about that.
func check_zone(actor:TacEntity, ini:Vector3i, end:Vector3i) -> Dictionary:
	var ini_zones : Array[StringName]
	var end_zones : Array[StringName]
	ini_zones.assign(zoned.get(ini, []))
	end_zones.assign(zoned.get(end, []))
	var exit_zones : Array[StringName]
	var enter_zones : Array[StringName]
	
	for zone in ini_zones:
		if not zone in end_zones:
			exit_zones.append(zone)
			zone_exited.emit(zone, actor)
	for zone in end_zones:
		if not zone in ini_zones:
			enter_zones.append(zone)
			zone_entered.emit(zone, actor)
	
	return {"entered": enter_zones, "exited":exit_zones}

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


## Change connections of a cell in the one of the provided navigation graph dictionaries, according to the given transcodes.
func set_navigation(graph:Dictionary, layer:int, cell_id:int, adjacent:Array[int], transcodes:Array[Tac.Trans]):
	var dir : int = -1
	for adja in adjacent:
		if not area[layer].has_point(Saliko.id_vec2i(adja)):  # Trying to disconnect or connect to non established cell.
			continue
		dir += 1
		if transcodes[dir] == Tac.Trans.PASS:
			for trans_type in graph[layer]:
				var nav : AStar2D = graph[layer][trans_type]
				nav.connect_points(cell_id, adja, false)
			continue
		else:
			for trans_type in graph[layer]:
				var nav : AStar2D = graph[layer][trans_type]
				nav.disconnect_points(cell_id, adja, false)
			if transcodes[dir] == null:
				continue
			var nav : AStar2D = graph[layer][transcodes[dir]]
			nav.connect_points(cell_id, adja, false)

## Makes a tile in [code]navsession[/code] disabled such it can't be entered.
## Usually because there are characters occupying it.
func block_navigation(tile:Vector2i, layer:int):
	var cell_id : int = Saliko.vec2i_id(tile)
	for trans in navsession[layer]:
		var nav : AStar2D = navsession[layer][trans]
		nav.set_point_disabled(cell_id, true)
## Re-enable a tile in [code]navsession[/code].
## Usually because a character moved out of it
func unblock_navigation(tile:Vector2i, layer:int):
	var cell_id : int = Saliko.vec2i_id(tile)
	for trans in navsession[layer]:
		var nav : AStar2D = navsession[layer][trans]
		nav.set_point_disabled(cell_id, false)

# Any modification to a map's terrain should update the «nav_queue», so many modifications can be performed in
# a process frame and only committed once at the end of the frame.
# Changes in map size or position should call «queue_area».
var area_outdated : PackedInt32Array  ## The layer where a map changed size or position.
var nav_outdated : Array[Vector3i]  ## In TacNav relative space. Add coordinates of TacNav cells that had terrain altered.
var navsession : Dictionary[int, Dictionary]  ## [Map Layer][Tac.Trans] -> AStart2D; A copy of «navgraph» that can be modified during a game session without losing the original for reference of what's default.
var navproxy : Dictionary[Vector3i, Dictionary]  ## [cell coord][TacTile.generate()] -> obstacle_codes;  Used to produce the navigation overlay. Faster than recreating AStar2D all the time. The coordinate is that of a tile with layer included. The value Dictionary is the return of «TacTile.get_trans_codes()».

func queue_nav(coordi:Vector3i):
	#NOTE Can't check if «coordi» is in the area here, because during «_ready()» 
	# there will be «queue_nav()» calls that will be filtered out as the «area_queue»
	# hasn't been processed yet, the associated Rect2i will have no size, so there
	# won't be areas that contain the «coordi».
	var in_area = area[coordi.y].has_point(Saliko.Vec3RemAxis(coordi))
	if not coordi in nav_outdated and in_area:
		nav_outdated.append(coordi)

func queue_area(layer:int):
	if not layer in area:
		area[layer] = Rect2i()
	if not layer in area_outdated:
		area_outdated.append(layer)

# Finds a Rect2i that fully encloses the children maps on each given layer.
func compute_area(layers:PackedInt32Array):
	for layer in layers:
		area[layer] = Rect2i()
		for map : TacMap in maps[layer]:
			area[layer] = area[layer].merge(map.nav_area)
		if not area[layer].has_area():
			area.erase(layer)

func _process(_delta: float) -> void:
	if not area_outdated.is_empty():
		compute_area(area_outdated)
		area_outdated.clear()
	
	if not nav_outdated.is_empty():
		# Set navigation connections according to changes in map obstacles.
		nav_outdated.clear.call_deferred()
		for coord3i in nav_outdated:
			var layer = coord3i.y
			var coord2i = Vector2i(coord3i.x, coord3i.z)
			if not area[layer].has_point(coord2i):
				printerr("TacNav: Coordinate not within area! ", coord2i)
				continue
			var map : TacMap = null
			for each : TacMap in maps[layer]:
				if each.nav_area.has_point(coord2i):
					map = each
					break
			if map == null:
				printerr("TacNav: Coordinate not in any map! ", coord3i)
				continue
			var map_coord = nav2map(coord2i, map)
			var this_tile : TacTile = map.tiles.get(map_coord)
			if this_tile == null or this_tile.is_empty():
				# Handling deletions.
				if OS.has_feature("editor_hint"):
					navproxy[coord3i] = TacTile.get_empty_codes()
				else: #TODO deal with navsession
					pass
				continue
			
			if OS.has_feature("editor_hint"):
				# Change «navproxy». It can be then rendered in «tactical_map_editor».
				var adjacents : Array[TacTile] = []
				for dir in Tac.Dir_Vect.values():
					var adja_tile = map_coord + dir
					adjacents.append(map.tiles.get(adja_tile))
				navproxy[coord3i] = this_tile.get_trans_codes(adjacents)
				navproxy_changed.emit(nav_outdated)
			else:
				# Change «navsession» with in-game changes to terrain.
				var adjacents : Array[TacTile] = []
				var adja_ids : Array[int] = []
				for dir in Tac.Dir:
					var adja_tile = coord2i + Tac.Dir_Vect[dir]
					adja_ids.append(Saliko.vec2i_id(adja_tile))
					adjacents.append(map.tiles.get(adja_tile))
				var transcodes : Array[Tac.Trans]
				transcodes.assign(this_tile.get_trans_codes(adjacents).sides)
				set_navigation(navsession, layer, Saliko.vec2i_id(coord2i), adja_ids, transcodes)


var navgraph : Dictionary[int, Dictionary]  ## [Map Layer][Tac.Trans] -> AStart2D; May navigation data.
func _ready() -> void:
	# Build «navgraph» at the beginning of a game session.
	
	if not area_outdated.is_empty():
		compute_area(area_outdated)
		area_outdated.clear()
	
	var chara_tiles : Array[Vector3i]  # Where characters are being placed, so we can block those tiles.
	for layer in maps:
		var layer_cells : Dictionary[int, Dictionary] # [tile_id][transcodes / adjacent_ids] -> Array[int] / Array[int]
		
		# Instantiate navigation graphs to the layer of the map
		if not layer in navgraph:
			navgraph[layer] = {}
			for trans in range(Tac.Trans.size()):
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
			
			# Create graph points for the map tiles.
			for map_tile : Vector2i in map.tiles:
				var tile : TacTile = map.tiles[map_tile]
				var nav_tile = map2nav(map_tile, map)
				var tile_id = Saliko.vec2i_id(nav_tile)
				layer_cells[tile_id] = {}
				layer_cells[tile_id]["adjacent_ids"] = []
				var adja_tiles : Array[TacTile] = []
				for dir in Tac.Dir:
					var adja_coord = nav_tile + Tac.Dir_Vect[dir]
					var adja_id = Saliko.vec2i_id(adja_coord)
					layer_cells[tile_id]["adjacent_ids"].append(adja_id)
					adja_tiles.append(map.tiles.get(adja_coord))
				layer_cells[tile_id]["transcodes"] = tile.get_trans_codes(adja_tiles).sides
				
				if not OS.has_feature("editor_hint"):
					for trans in range(Tac.Trans.size()):
						var graph : AStar2D = navgraph[layer][trans]
						graph.add_point(tile_id, nav_tile)
					
		
		if not OS.has_feature("editor_hint"):
			# Connect points in the graph of current layer.
			for tile_id in layer_cells:
				var adjacents : Array[int]
				adjacents.assign(layer_cells[tile_id].adjacent_ids)
				var transcodes : Array[Tac.Trans]
				transcodes.assign(layer_cells[tile_id].transcodes)
				set_navigation(navgraph, layer, tile_id, adjacents, transcodes)
	
	navsession = navgraph.duplicate_deep()
	for tile in chara_tiles:
		block_navigation(Vector2i(tile.x, tile.z), tile.y)

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
func nav3spatial(coordi:Vector3i, centered:=false):
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
