@tool
extends Node3D
class_name TacNav

## A node that handles the navigation of multiple TacMaps and places characters where spawners are marked.

signal navproxy_changed(tile_coord : Array[Vector3i])
signal zone_entered(zone:StringName, chara:TacCharacter)  ## The character entered a zone. Multiple zones are possible for each tile, so you may get multiple signals from this.
signal zone_exited(zone:StringName, chara:TacCharacter)  ## The character exited a zone. Multiple zones are possible for each tile, so you may get multiple signals from this.

#FIXME navgraphs don't find coords mentioned by navqueue

#NOTE This node only produces navigation graphs when first ready on an executed project. Otherwise it uses «navproxy» which is easily modified.
# Modifications to children TacMap during execution will modify «navsession» variable, which initally is a copy of the graphs.


@export var tile_size : float = 1.0  ## (meters) The lateral length of square tiles that all children maps abide to.
@export var tile_height : float = 2.0  ## How high walls can get.

var unique_spawners : Dictionary[StringName, Dictionary]
var charas : Array[TacCharacter]  ## Reference to placed characters.
var zoned : Dictionary[Vector2i, Array]  ## [nav_coordi][i] -> StringName; Association of tile with a zone
#var ladders : Dictionary[Vector2i, StringName]  ## Coordinate of tiles connecting to a "ladder" of common name with other TacMaps.


func _get_configuration_warnings() -> PackedStringArray:
	for each in get_children():
		if each is TacMap:
			return []
	return ["TacNav is intended to be used with TacMap children, otherwise it does nothing."]

#region TacMap handling
var area : Rect2i  ## Total area enclosing all maps, given their positions and sizes.
var maps : Dictionary[int, Array]  ## [map layer][i] -> TacMap; Reference to placed maps.


## Called by TacMaps when they are added as children of this Node.
func _map_added(map:TacMap):
	var layer = map.get_layer()
	if not layer in maps:
		maps[layer] = []
	elif map in maps[layer]:
		return
	maps[layer].append(map)
	area_outdated = true

## Called by TacMaps if about to leave this Node.
func _map_removed(map:TacMap):
	var layer = map.get_nav_layer()
	maps[layer].erase(map)
	if maps[layer].is_empty():
		maps.erase(layer)
	area_outdated = true

## Given a navigation tile coordinate, which maps are there? They will be sorted by layer.
func get_maps_at(coord:Vector2i) -> Array[TacMap]:
	var found : Array[TacMap]
	for layer : int in maps:
		for map : TacMap in maps[layer]:
			var map_coord = spatial2tile(Saliko.Vec3RemAxis(map.position))
			var area = Rect2i(map_coord, map.size)
			if area.has_point(coord):
				found.append(map)
	found.sort_custom(func(a,b): return a.get_nav_layer() < b.get_nav_layer())
	return found
#endregion

#region Entity Handling
func get_traject(entity:TacCharacter, destination : Vector2i) -> PackedVector2Array:
	var loc = locate_entity(entity)
	if loc.tacmap == null:  # Couldn't find the map the entity is on.
		return []
	if loc.nav_coord == destination:  # Position didn't change.
		return []
	var start = Saliko.vec2i_id(loc.nav_coord)
	var stop = Saliko.vec2i_id(destination)
	return navgraph[loc.tacmap.get_nav_layer()][entity.attitude].get_point_path(start, stop, true)

## Find the map and coordinate of a TacEntity.
## It will give the map closest to the entity with a lower Y position.
func locate_entity(entity:TacEntity) -> Dictionary:
	var coord : Vector2i = spatial2nav_tile(entity.position) # TacNav tile of the entity position
	var relevant_maps = get_maps_at(coord)
	for idx in range(relevant_maps.size() - 1, -1, -1):
		var map : TacMap = relevant_maps[idx]
		if map.get_nav_height() <= entity.position.y:
			return {
				"tacmap": map,  # Map where the entity belongs
				"map_coord": nav2map(coord, map),  # Coordinate relative to the map
				"nav_coord": coord  # Coordinate relative to this TacNav
				}
	return {
		"tacmap": null,
		"nav_coord": coord
		}

## Allows to tell which zones a character entered or exited while moving between two tiles
## And triggers signals and functions about that.
func check_zone(actor:TacEntity, ini:Vector2i, end:Vector2i) -> Dictionary:
	var ini_zones = zoned.get(ini, [])
	var end_zones = zoned.get(end, [])
	var exit_zones : Array[String]
	var enter_zones : Array[String]
	
	for zone in ini_zones:
		if not zone in end_zones:
			exit_zones.append(zone)
	for zone in end_zones:
		if not zone in ini_zones:
			enter_zones.append(zone)
 	
	for zone in exit_zones:
		zone_exited.emit(zone, actor)
	for zone in enter_zones:
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
		dir += 1
		if transcodes[dir] == Tac.Trans.PASS:
			for trans in range(graph[layer].size()):
				var nav : AStar2D = graph[layer][trans]
				nav.connect_points(cell_id, adja, false)
			continue
		else:
			for trans in range(graph[layer].size()):
				var nav : AStar2D = graph[layer][trans]
				nav.disconnect_points(cell_id, adja, false)
			if transcodes[dir] == null:
				continue
			var nav : AStar2D = graph[layer][transcodes[dir]]
			nav.connect_points(cell_id, adja, false)

# Any modification to a map's terrain should update the «nav_queue», so many modifications can be performed in
# a process frame and only committed once at the end of the frame.
# Changes in map size or position should set «area_outdated» true.
var area_outdated : bool = true  ## Set true if a TacMap changed place or size.
var nav_queue : Array[Vector3i]  ## In TacNav relative space. Add coordinates of TacNav cells that had terrain altered.
var navsession : Dictionary[int, Dictionary]  ## [Map Layer][Tac.Trans] -> AStart2D; A copy of «navgraph» that can be modified during a game session without losing the original for reference of what's default.
var navproxy : Dictionary[Vector3i, Dictionary]  ## [cell coord][TacTile.generate()] -> obstacle_codes;  Used to produce the navigation overlay. Faster than recreating AStar2D all the time. The coordinate is that of a tile with layer included. The value Dictionary is the return of «TacTile.get_trans_codes()».

func _process(delta: float) -> void:
	if area_outdated:
		# Finds a Rect2i that fully encloses the children maps.
		area_outdated = false
		area = Rect2i()
		for layer in maps:
			for map : TacMap in maps[layer]:
				area = area.merge(map.nav_area)
		print("TacNav: Computed total map area ", area)
	
	if not nav_queue.is_empty():
		nav_queue.clear.call_deferred()
		for coord3i in nav_queue:
			var layer = coord3i.y
			var coord2i = Vector2i(coord3i.x, coord3i.z)
			if not area.has_point(coord2i):
				printerr("TacNav: Coordinate not within area! ", coord2i)
				continue
			var map : TacMap
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
				navproxy_changed.emit(nav_queue)
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
	
	for layer in maps:
		var layer_cells : Dictionary[Vector2i, Dictionary] # [nav_tile][transcodes / adjacent_ids] -> Array[int] / Array[int]
		
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
						chara.position = tile2spatial(chara_tile, layer, true)
						add_child(chara, false, Node.INTERNAL_MODE_DISABLED)
			
			# Create graph points for the map tiles.
			for map_tile : Vector2i in map.tiles:
				var tile : TacTile = map.tiles[map_tile]
				var nav_tile = map2nav(map_tile, map)
				nav_queue.append(Vector3i(nav_tile.x, layer, nav_tile.y))
				var tile_id = Saliko.vec2i_id(nav_tile)
				layer_cells[nav_tile] = {}
				layer_cells[nav_tile]["adjacent_ids"] = []
				var adja_tiles : Array[TacTile] = []
				for dir in Tac.Dir:
					var adja_coord = nav_tile + Tac.Dir_Vect[dir]
					layer_cells[nav_tile]["adjacent_ids"].append(Saliko.vec2i_id(adja_coord))
					adja_tiles.append(map.tiles.get(adja_coord))
				layer_cells[nav_tile]["transcodes"] = tile.get_trans_codes(adja_tiles).sides
				
				if not OS.has_feature("editor_hint"):
					for trans in range(Tac.Trans.size()):
						var graph : AStar2D = navgraph[layer][trans]
						graph.add_point(tile_id, nav_tile)
					
					# Set zones to tiles
					for z in map.zones:
						var zone_area = map.zones[z]
						for y in range(zone_area.position.y, zone_area.end.y):
							for x in range(zone_area.position.x, zone_area.end.x):
								var tile_at_zone = zoned.get_or_add(map2nav(Vector2i(x,y), map), [])
								tile_at_zone.append(z)
		
		if not OS.has_feature("editor_hint"):
			# Connect points in the graph of current layer.
			for nav_tile in layer_cells:
				var tile_id = Saliko.vec2i_id(nav_tile)
				var adjacents : Array[int]
				adjacents.assign(layer_cells[nav_tile].adjacent_ids)
				var transcodes : Array[Tac.Trans]
				transcodes.assign(layer_cells[nav_tile].transcodes)
				set_navigation(navgraph, layer, tile_id, adjacents, transcodes)
	
	navsession = navgraph.duplicate_deep()

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

## Generically get a space coordinate for the given tile coord.
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
func map2spatial_tile(coord:Vector2i, map:TacMap) -> Vector2i:
	return spatial2tile(map2spatial(coord, map))

## Returns the Global 3D coordinate of a tile in the TacMap. Optionally point to the center of the tile on the XZ plane.
func map3spatial(coordi:Vector2i, map:TacMap, centered:=false) -> Vector3:
	var coord : Vector3 = tile3spatial(Saliko.Vec2AddAxis(coordi, 1, map.position.y), centered)
	return coord + position
#endregion

#region To TacNav
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
func spatial_tile2map_tile(coordi:Vector2i, map:TacMap) -> Vector2i:
	var coord = Saliko.Vec3RemAxis(position + map.position)
	return  coordi - spatial2tile(coord)

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
		coordi.y = map.get_nav_layer()
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
