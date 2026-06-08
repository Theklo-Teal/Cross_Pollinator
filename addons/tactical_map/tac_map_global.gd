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

# Context Things
const DEFAULT_ACTIONS_PATH = "res://addons/tactical_map/assets/actions"
const DEFAULT_TERRAIN_PATH = "res://addons/tactical_map/assets/terrains"
const DEFAULT_ACTION_ICON = "res://addons/tactical_map/icons/action_icons.tres"
var action_icon_atlas : AtlasTexture
var setts : ConfigFile

# Gameplay Things
var hover_nav : TacNav  ## Navigation of TacMap under the mouse
var hover_map : TacMap  ## TacMap under the mouse
var hover_layer : int
var hover_tile : Vector2i  ## TacNav relative coordinate
var hover_tile_map : Vector2i  ## Like «hover_tile», but respective to the «hover_map»
var hover_entity : TacEntity  # What is under the mouse
var select_chara : TacCharacter :
	set(val):
		if val.curr_team == TacCharacter.Team.PLAYER:
			select_chara = val
			get_tree().call_group("observer_character_select", "_on_character_selected", val)
var actions : Dictionary[StringName, CharaAction]

# Level Editor Things
var pallet_fam : Dictionary[StringName, PackedStringArray]  # Associate UID of asset info to a terrain family.
var pallet_info : Dictionary[StringName, Resource]  # Associate UID of asset info to defining Resource
var tag_info : Dictionary[StringName, Array]  #  [tag][idx] -> info_uid

#FIXME These should probably be part of settings.ini
var ui_tile_charac : Texture = load("res://assets/spatial_textures/grid_tile.png")
var ui_tile_walk : Texture = load("res://assets/spatial_textures/grid_tile.png")
var ui_tile_sprint : Texture = load("res://assets/spatial_textures/grid_tile.png")
var ui_tile_weapon : Texture = load("res://assets/spatial_textures/grid_tile.png")


func _ready() -> void:
	setts = ConfigFile.new()
	setts.load("res://addons/tactical_map/settings.ini")
	
	action_icon_atlas = load(setts.get_value("Asset Paths", "action_icon_atlas", DEFAULT_ACTION_ICON))
	
	for file in DirAccess.get_files_at(DEFAULT_ACTIONS_PATH):
		if file.get_extension() == "gd":
			actions[file.get_basename()] = load(DEFAULT_ACTIONS_PATH.path_join(file)).new()
	var act_path = setts.get_value("Asset Paths", "Actions", DEFAULT_ACTIONS_PATH)
	for file in DirAccess.get_files_at(act_path):
		if file.get_extension() == "gd":
			actions[file.get_basename()] = load(DEFAULT_ACTIONS_PATH.path_join(file)).new()
	
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


func get_input_action(action:StringName):
	return setts.get_value("Events", action+"_action", action)
