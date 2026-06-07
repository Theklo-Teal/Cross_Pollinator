extends Area3D
class_name TacEntity

signal interacted  ## The player tried to click on this object.

@export var interact_distance : float = 2.4  ## How far, in meters, can an active character be from this entity and still allow it to interact.

var interact_action : StringName
var command_action : StringName
var mouse_hover : bool  # Is the mouse over this area?

func _ready():
	input_ray_pickable = true


func _get_configuration_warnings() -> PackedStringArray:
	var msg = []
	if owner != null:
		msg.append("TacEntity are intended to be automatically placed by TacNav.")
	if not get_parent() is TacNav:
		msg.append("TacEntity should be the child of a TacNav.")
	return msg


func _mouse_enter() -> void:
	mouse_hover = true
func _mouse_exit() -> void:
	mouse_hover = false
func _input(event: InputEvent) -> void:  #TODO make work with _unhandled_input()?
	## A player's attemt to interact with this object.
	if event.is_action_released(Tac.get_action(&"interact")) and mouse_hover:
		interaction()
		interacted.emit()
		#var chara_coord = Ses.curr_unit().get_global_coord()
		#var self_coord = get_global_coord()
		#if chara_coord.distance_to(self_coord) <= interact_distance:
			#interacted.emit(self, Ses.curr_unit())

func interaction():
	_interaction()

func _interaction():
	pass

#region Entity movement on the map
var last_step : Vector2i  ## When walking a path, this is the last tile the character was in.
var next_step : Vector3  ## The spatial position the character must reach to achieve the current step in their trajectory.
var trajectory : Array[Vector2i]  ## The path the character will try to walk along.
## Writes to the [code]trajectory[/code] variable in preparation to initiate movement on the map.[br]
## Returns [code]ERR_ALREADY_EXISTS[/code] if destination and current position are the same.[br]
## Returns [code]ERR_QUERY_FAILED[/code] if a path to the destination wasn't found, so trajectory is
## partial.
func traversal_start(destination:Vector2i, teleport:=false) -> Error:
	if destination == get_nav_coord():
		return ERR_ALREADY_EXISTS
	var result : Error = OK
	
	last_step = get_nav_coord()
	if teleport:
		trajectory = [destination]
	else:
		trajectory.assign( get_tacnav().get_traject(self, destination) )
		trajectory.reverse()
		trajectory.pop_back()  # Remove the starting point.
		if not trajectory[0] == destination: # Trajectory is a partial path.
			result = ERR_QUERY_FAILED
	next_step = get_tacnav().tile2spatial(trajectory.back(), 0, true) * get_tacnav().tile_size + Vector3(0,position.y,0)
	result = _traversal_start(result, destination, teleport)
	return result

func _traversal_start(curr_error:Error, destination:Vector2i, teleport:=false) -> Error:
	return curr_error

## Take a step along the trajectory, popping one of its coordinates along the way
## and performing any checks necessary. If it returns [code]ERR_CANT_CONNECT[/code]
## the movement of the character must be aborted.[br]
## Returning [code]ERR_ALREADY_EXISTS[/code] means the end of the traject (even if partial)
## has been reached.
func take_a_step() -> Error:
	var result : Error = OK
	if trajectory.is_empty():  #FIXME character is taking a step with empty trajectory.
		return ERR_ALREADY_EXISTS
	else:
		var step = trajectory.pop_back()
		next_step = get_tacnav().tile2spatial(step, 0, true) * get_tacnav().tile_size + Vector3(0,position.y,0)
		var zones = get_tacnav().check_zone(self, last_step, step)
		result = _take_a_step(step, zones.exited, zones.entered)
		last_step = step
	return result

## Override this function to define what happens when the character moves from one tile to the other.[br]
## Return whether the movement to the «step» tile was successful. Errors won't halt the movement
## Return [code]ERR_CANT_CONNECT[/code] if travel must be aborted.
func _take_a_step(step:Vector2i, _zones_exited, _zones_entered) -> Error:
	#FIXME Node origin and target are the same position, look_at() failed
	look_at(next_step, Vector3.UP, true)
	return OK

## Override to define what the entity does after movement is finished.[br]
## [code]condition[/code] allows knowing the context of the end of travel.[br]
## Return an error code to inform the caller function of the character situation.
func _traversal_finish(condition:Error=OK) -> Error:
	return OK

#endregion

### It returns if interaction was successful.
#func npc_interaction(chara:Character) -> bool:
	#var npc_coord = chara.get_global_coord()
	#var prop_coord = get_global_coord()
		#
	#if prop_coord.distance_to(npc_coord) > interact_distance:
		#return false
	#
	#interacted.emit(self, chara)
	#return true


	
## Get the TacNav this object is part of.
func get_tacnav() -> TacNav:
	if not get_parent() is TacNav:
		push_error("TacEntity: Parent is not a TacNav!")
		return null
	return get_parent()
## In which Tactical Grid is this object on top?[br]
func get_tacmap() -> TacMap:
	return get_tacnav().locate_chara(self).tacmap

func get_nav_coord() -> Vector2i:
	return get_tacnav().locate_entity(self).nav_coord

func get_map_coord() -> Vector2i:
	return get_tacnav().locate_entity(self).map_coord
