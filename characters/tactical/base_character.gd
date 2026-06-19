extends TacCharacter
class_name BaseTacCharacter

@export var info : CharacterID
# The functions in CharacterID are defaults.
# These functions here can be overridden for different results.
func get_proper_name():
	return info.get_proper_name()
func get_alias():
	return info.get_alias()

@export var rank : int

@export_group("Stats")
@export var max_health : int
@export var max_stamina : int
@export var max_mental : int

@export var appeal : int  ## Charisma
@export var speed : int  ## Movement
@export var will : int  ## Determination

var health : int
var stamina : int
var mental : int
var spritilo : int
var ectoplasm : int


## The longest amount of tiles a character can move without obstructions.
func walk_range() -> int:
	return stamina * speed

#region Character's senses
var enemy_spotted : Dictionary[TacCharacter, Vector2i]  ## Remember which enemies were detected and where.

## Is the "chara" in range and line of sight of this character?[br]
## NOTE: This assumes both this character the "chara" are in the same TacMap.
func can_see(_chara:TacCharacter) -> bool:
	if "Blinded_Ailment" in info.ailment:
		return false
	if "Conceal_Bonus" in info.perks: #and not chara.is_in_group(team):
		return false
	return true

## Returns a list of cells around the character associated with their terrain codes.
func terrain_in_range() -> Dictionary[Vector2i, Dictionary]:
	var terrain : Dictionary
	var loc := get_location_info()
	var from = loc.nav_coord - Vector2.ONE * walk_range()
	var to = loc.nav_coord + Vector2.ONE * walk_range()
	for cell in Saliko.cells_of(Vector2(from.x, to.x), Vector2(from.y, to.y)):
		terrain[cell] = loc.tacnav.navproxy.get(Vector3i(cell.x, loc.layer, cell.y), TacTile.get_empty_codes())
	return terrain

## Returns a list of tiles with obstacles that connect to the character's current cover.
func curr_cover_contour() -> Array[Vector2i]:
	var contour : Array[Vector2i]  ## Tiles next to an obstacle.
	var terrain := terrain_in_range()
	var skip_cell := false
	for cell in terrain:
		skip_cell = false
		for dir_code in terrain[cell]:
			if dir_code in [Tac.Trans.HALF, Tac.Trans.TALL]:
				contour.append(cell)
				skip_cell = true
				break
		if skip_cell: continue
	return contour
#endregion
