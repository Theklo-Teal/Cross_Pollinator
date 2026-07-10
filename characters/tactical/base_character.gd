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


## The longest amount of tiles a character can move without obstructions.
func walk_range() -> int:
	return stamina * speed

func _traversal_finish(condition:Error=OK) -> Error:
	if condition == OK:
		var dir = strongest_cover(get_nav_coord())
		if dir != Vector2i.ZERO:
			rotation_degrees.y = Tac.DIR_ANG[dir]
	return condition

func cannot_act() -> bool:
	for act in actions.values():
		if not act is CharaAction: continue
		if act.stamina_cost <= stamina: return false
		if act.can_use(): return false
	return true

#region Character's senses
var enemy_spotted : Dictionary[TacCharacter, Vector2i]  ## Remember which enemies were detected and where.

## What direction of the tile at [code]from[/code] is cover better?[br]
## Returns [code]Vector2i.ZERO[/code] if there's no valid cover.
func strongest_cover(from:Vector2i) -> Vector2i:
	var code = get_tacnav().navproxy[Vector3i(from.x, get_nav_layer(), from.y)]
	var best := Tac.Dir.EAST
	for dir in range(4):
		if code[dir] > code[best]:
			best = dir as Tac.Dir
	if code[best] == Tac.Trans.PASS:
		return Vector2i.ZERO
	return Tac.DIR_VEC.values()[best]

## Returns the direction on a tile to look for cover against a target or enemy.
func target_effective_cover(from:Vector2i, target:Vector2i) -> Vector2i:
	var alignment = Saliko.alignment(from - target)
	var max_axis = alignment.abs().max_axis_index()
	var direction = Vector2.ZERO
	direction[max_axis] = roundi(alignment[max_axis])
	return direction

## Is the [code]chara[/code] in range and line of sight of this character?
func can_see(chara:TacCharacter) -> bool:
	var layer = get_nav_layer()
	if chara.get_nav_layer() != layer:
		return false
	if "Blinded_Ailment" in info.ailment:
		return false
	if "Conceal_Bonus" in info.perks:
		return false
	if "Camouflage_Perk" in info.perks:
		return false
	var my_coord := get_nav_coord()
	var chara_coord := chara.get_nav_coord()
	var direction = target_effective_cover(my_coord, chara_coord)
	direction = Tac.DIR_VEC.values().find(direction)
	for cell in Geometry2D.bresenham_line(my_coord, chara_coord):
		if not get_tacmap().is_see_thru(get_map_coord(), direction):
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

#endregion
