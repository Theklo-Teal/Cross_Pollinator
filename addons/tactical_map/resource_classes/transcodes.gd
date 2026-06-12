@tool
extends Resource
class_name TransCodes

@export var EAST : int = 0 : 
	set(val):
		dir[Vector2i.RIGHT] = val
@export var SOUTH : int = 0 : 
	set(val):
		dir[Vector2i.DOWN] = val
@export var WEST : int = 0 : 
	set(val):
		dir[Vector2i.LEFT] = val
@export var NORTH : int = 0 : 
	set(val):
		dir[Vector2i.UP] = val
@export var dir : Dictionary[Vector2i, int] = {
	Vector2i.RIGHT: 0,
	Vector2i.DOWN: 0,
	Vector2i.LEFT: 0,
	Vector2i.UP: 0,
	} : 
	set(val):
		for dir_name in Tac.Dir_Vect:
			var vec = Tac.Dir_Vect[dir_name]
			dir[vec] = val[vec] % Tac.Trans.size()
			set(dir_name, dir[vec])

## Set the transition at the index of a direction
func set_code(i:int, val:Tac.Trans) -> void:
	[EAST, SOUTH, WEST, NORTH][i] = val
## Get the transition by index of a direction
func get_code(i:int) -> Tac.Trans:
	return [EAST, SOUTH, WEST, NORTH][i]

## Get a single int where a bit of 1 means there's some obstacle. Digits are ordered as NWSE.
func simple() -> int:
	var ans := 0
	var i : int = -1
	for code in dir.values():
		i += 1
		ans |= int(code > 0) << i
	return ans

## Get a single int where
func full() -> int:
	var ans := 0
	var i : int = -3
	for code in dir.values():
		i += 3
		ans |= code << i
	return ans
