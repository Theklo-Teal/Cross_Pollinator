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

enum Trans{  ## Tile transisition types
	PASS,  ## Anyone can traverse. Wary characters only traverse this kind of transition.
	CRAWL,  ## Crawl Space: Only small characters can pass
	HALF,  ## Only hasty or swift characters can pass
	TALL,  ## Nobody can pass, unless they are intangible.
	AERIAL,  ## Flying things can cross.
	NONE,  ## There's nothing that can cross, transition won't connect in any navgraph.
}
const TColor = {  ## Colors of Trans for the navigation overlay.
	Tac.Trans.PASS : Color.TRANSPARENT, #Color(0.87058824, 0.72156864, 0.5294118, 0.3),
	Tac.Trans.CRAWL : Color(0.85490197, 0.64705884, 0.1254902, 0.3),
	Tac.Trans.HALF : Color(1, 0.49803922, 0.3137255, 0.3),
	Tac.Trans.TALL : Color(1, 0, 0, 0.3),
	Tac.Trans.AERIAL : Color(0.25490198, 0.4117647, 0.88235295, 0.3),
	Tac.Trans.NONE : Color(0, 0, 0, 0.3)
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
var hover_layer : int  ## TacNav Layer of [code]hover_map[/code] in Global space coordinates.
var hover_layer_nav : int  ## Layer of [code]hover_map[/code] within its TacNav
var hover_tile : Vector2i  ## Global space relative coordinate
var hover_tile_nav : Vector2i  ## Like [code]hover_tile[/code], but in [code]hover_nav[/code] space.
var hover_tile_map : Vector2i  ## Like [code]hover_tile[/code], but in [code]hover_map[/code] space.
var hover_entity : TacEntity  ## What is under the mouse
var select_target : TacCharacter
var select_chara : TacCharacter :
	set(val):
		if val.curr_team == TacCharacter.Team.PLAYER:
			select_chara = val
			get_tree().call_group("observer_character_select", "_on_character_selected", val)
var actions : Dictionary[StringName, Resource]

# Level Editor Things
var spawners : Dictionary[StringName, Resource]  # List of available spawners.
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
	
	# Get all the default action classes.
	for file in DirAccess.get_files_at(DEFAULT_ACTIONS_PATH):
		if file.get_extension() == "gd":
			actions[file.get_basename()] = load(DEFAULT_ACTIONS_PATH.path_join(file))
	# Get external action classes as well.
	var act_path = setts.get_value("Asset Paths", "actions", DEFAULT_ACTIONS_PATH)
	for file in DirAccess.get_files_at(act_path):
		if file.get_extension() == "gd":
			actions[file.get_basename()] = load(act_path.path_join(file))
	
	var spawn_path : String = setts.get_value("Asset Paths", "entity_spawn", "")
	if not spawn_path.is_empty():
		for file in DirAccess.get_files_at(spawn_path):
			if file.get_extension() == "gd":
				var spawn_rsrc = load(spawn_path.path_join(file))
				spawners[spawn_rsrc.display_name()] = spawn_rsrc
	
	var terr_path : String = setts.get_value("Asset Paths", "terrains", DEFAULT_TERRAIN_PATH)
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


func interact_input():
	return setts.get_value("Events", "interact_action", "interact")
func command_input():
	return setts.get_value("Events", "command_action", "command")
