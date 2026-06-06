@tool
extends Node

enum Dir{
	EAST,
	SOUTH,
	WEST,
	NORTH
}

const Dir_Vect = {
	"EAST" : Vector2i.RIGHT,
	"SOUTH" : Vector2i.DOWN,
	"WEST" : Vector2i.LEFT,
	"NORTH" : Vector2i.UP,
}

const Dir_Mask = {
	"EAST" : 0b11,
	"SOUTH" : 0b1100,
	"WEST" : 0b110000,
	"NORTH" : 0b11000000,
}


enum Trans{  ## Tile transisition types
	PASS,  ## Anyone can traverse. Wary characters only traverse this kind of transition.
	CRAWL,  ## Crawl Space: Only small characters can pass
	HALF,  ## Only hasty or swift characters can pass
	TALL,  ## Nobody can pass, unless they are intangible.
}
enum Hazard{
	NONE,
	DARK,
	SMOKE,
	RADIO,  # Radioactivity
	FLOOD,  # Water logged
	FIRE,
	# Warehouse traps
	POISON,  # Nerve Gas
	MINE,  # Anti-Personnel Mine
	PUNJI,  # Trapdoor dropping onto spikes
	# Agartian traps
	SPRIT,  # Rogue Spritilo/Radiotrophes
	BRILE,  # Brilerato
}

var setts : ConfigFile
var actions : Dictionary[StringName, Resource]

var pallet_fam : Dictionary[StringName, PackedStringArray]  # Associate UID of asset info to a terrain family.
var pallet_info : Dictionary[StringName, Resource]  # Associate UID of asset info to defining Resource
var tag_info : Dictionary[StringName, Array]  #  [tag][idx] -> info_uid

#FIXME These should probably be part of settings.ini
var ui_tile_charac : Texture = load("res://assets/spatial_textures/grid_tile.png")
var ui_tile_walk : Texture = load("res://assets/spatial_textures/grid_tile.png")
var ui_tile_sprint : Texture = load("res://assets/spatial_textures/grid_tile.png")
var ui_tile_weapon : Texture = load("res://assets/spatial_textures/grid_tile.png")

const DEFAULT_ACTIONS_PATH = "res://addons/tactical_map/assets/actions"
const DEFAULT_TERRAIN_PATH = "res://addons/tactical_map/assets/terrains"

func _ready() -> void:
	setts = ConfigFile.new()
	setts.load("res://addons/tactical_map/settings.ini")

	for file in DirAccess.get_files_at(DEFAULT_ACTIONS_PATH):
		if file.get_extension() == "gd":
			actions[file.get_basename()] = load(DEFAULT_ACTIONS_PATH.path_join(file))
	var act_path = setts.get_value("Asset Paths", "Actions", DEFAULT_ACTIONS_PATH)
	for file in DirAccess.get_files_at(DEFAULT_ACTIONS_PATH):
		if file.get_extension() == "gd":
			actions[file.get_basename()] = load(DEFAULT_ACTIONS_PATH.path_join(file))
	
	var terr_path : String = setts.get_value("Asset Paths", "Terrains", DEFAULT_TERRAIN_PATH)
	for family in DirAccess.get_directories_at(terr_path):
		pallet_fam[family] = []
		for terrset in DirAccess.get_directories_at(terr_path.path_join(family)):
			if terrset != "assets":
				for asset_file in DirAccess.get_files_at(terr_path.path_join(family).path_join(terrset)):
					if asset_file.get_extension() == "tres":
						var asset_info = load("/".join([terr_path, family, terrset, asset_file]))
						var uid = ResourceUID.path_to_uid("/".join([terr_path, family, terrset, asset_file]))
						pallet_fam[family].append(uid)
						pallet_info[uid] = asset_info
						asset_info.set_meta("terrain_family", family)
						
						for tag in asset_info.tags:
							if not tag in asset_info:
								tag_info[tag] = []
							tag_info[tag].append(asset_info)

func _exit_tree() -> void:
	setts.save("res://addons/tactical_map/settings.ini")


func get_action(act:StringName):
	return setts.get_value("Context", act+"_action", act)

#region Math Problems

## Return a list of the grid coordinates surrounding the given cell.
## Optionally, rotates the list to have the cell at a certain direction as the first element.
static func adjacent_cells(center : Vector2i, first_cardinal:int=0, include_diagonal:=true) -> Array[Vector2i]:
	const cardinals = [
		Vector2i(0,-1),  # North
		Vector2i(-1,-1),  # NW
		Vector2i(-1,0),  # West
		Vector2i(-1,1),  # SW
		Vector2i(0,1),  # South
		Vector2i(1,1),  # SE
		Vector2i(1,0),  # East
		Vector2i(1,-1),  # NE
	]
	
	var rotated_list : Array[Vector2i]
	for n in range(cardinals.size()):
		if include_diagonal or n % 2 == 0:
			rotated_list.append( cardinals[(n + first_cardinal) % 8] + center )
	
	return rotated_list

## Find grid coordinates which are adjacent to a given tile.
## It can take several tiles, as if contouring the shape produced.
## Optionally, include a list of tiles allowed to be returned, as a boundary.
static func contour_shape(shape : Array[Vector2i], boundary : Array[Vector2i] = []) -> Array[Vector2i]:
	var contour : Array[Vector2i]
	for coord in shape:
		for adjacent in adjacent_cells(coord):
			var rules = [
				adjacent in shape,
				adjacent in contour,
				not ( adjacent in boundary or boundary.is_empty() ),  # If the boundary is empty, we ignore that feature.
				]
			if true in rules:  # The rules exclude coordinates from the solution.
				continue
			else:
				contour.append(adjacent)
	return contour

#endregion
