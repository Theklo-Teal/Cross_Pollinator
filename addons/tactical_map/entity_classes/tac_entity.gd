extends Area3D
class_name TacEntity

signal interacted  ## The player tried to click on this object.

@export var interact_distance : float = 2.4  ## How far, in meters, can an active character be from this entity and still allow it to interact.

var mouse_hover : bool  # Is the mouse over this area?

func _ready():
	input_ray_pickable = true
	collision_layer = Con.phys_layer["tac_entity"]


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
	if event.is_action_released(Tac.interact_input()) and mouse_hover:
		interaction()
		interacted.emit()
		#var chara_coord = Ses.curr_unit().get_global_coord()
		#var self_coord = get_global_coord()
		#if chara_coord.distance_to(self_coord) <= interact_distance:
			#interacted.emit(self, Ses.curr_unit())

func interaction() -> Error:
	return _interaction()

func _interaction() -> Error:
	return OK

func text_speak(speech:StringName):
	pass

func audio_speak(speech:StringName):
	pass

func animate(sequence:StringName, duration:float=NAN):
	pass

#region Entity movement on the mapw
#TODO Change TacNav.navsession to accound change in position of characters.

var last_step : Vector3i  ## When walking a path, this is the last tile the character was in.
var next_step : Vector3  ## The spatial position the character must reach to achieve the current step in their trajectory.
var trajectory : Array[Vector3i]  ## The path the character will try to walk along. Y coordinate is the layer.

## Writes to the [code]trajectory[/code] variable in preparation to initiate movement on the map.[br]
## The [code]destination[/code] is a TacNav coordinate at the given destination [code]tacmap[/code].[br]
## Returns [code]ERR_ALREADY_EXISTS[/code] if destination and current position are the same.[br]
## Returns [code]ERR_QUERY_FAILED[/code] if a path to the destination wasn't found, so trajectory is
## partial.
## Returns [code]ERR_CANT_CONNECT[/code] If the path couldn't be resolved at all. Eg. requires ladders
## That aren't available, [code]tacmap[/code] is [code]null[/code] or destination is outside the map.
func traversal_start(destination:Vector2i, tacmap:TacMap, teleport:=false) -> Error:
	if destination == get_nav_coord():
		return ERR_ALREADY_EXISTS
	if tacmap == null:
		return ERR_CANT_CONNECT
	if tacmap.tiles.get(destination) == null:
		return ERR_CANT_CONNECT
		
	var result : Error = OK
	
	var destin := Vector3i(destination.x, tacmap.get_layer(), destination.y)
	
	last_step = get_nav_coord3()
	if teleport:
		trajectory = [destin]
	else:
		trajectory.assign( get_tacnav().get_traject(self, destination, tacmap) )
		if trajectory.is_empty():
			result = ERR_ALREADY_EXISTS
		else:
			trajectory.reverse()
			trajectory.pop_back()  # Remove the current entity position.
			if not trajectory[0] == destin: # Trajectory is a partial path.
				result = ERR_QUERY_FAILED
			take_a_step()  # Update information where the character goes first.
	result = _traversal_start(result, destin, teleport)
	return result

## Override this to do something when a character is about to move location.
## It should relay the given [code]curr_error[/code] or return other.[br]
## Possible errors:[br]
## [code]ERR_ALREADY_EXISTS[/code]: The character already is at the destination.[br]
## [code]ERR_QUERY_FAILED[/code]: [code]trajectory[/code] is partial. Probably
## because a path wasn't found.[br]
func _traversal_start(curr_error:Error, destination:Vector3i, teleport:=false) -> Error:
	return curr_error

## Take a step along the trajectory, popping one of its coordinates along the way
## and performing any checks necessary. If it returns [code]ERR_CANT_CONNECT[/code]
## the movement of the character must be aborted.[br]
## Returning [code]ERR_ALREADY_EXISTS[/code] means the end of the traject (even if partial)
## has been reached.
func take_a_step() -> Error:
	var result : Error = OK
	if trajectory.is_empty():  #FIXME character is about to take a step on an empty trajectory.
		return ERR_ALREADY_EXISTS
	else:
		var step : Vector3i = trajectory.pop_back()
		next_step = get_tacnav().tile3spatial(step, true)
		var zones = get_tacnav().check_zone(self, last_step, step)
		get_tacnav().block_navigation(Vector2i(step.x, step.z), step.y)
		get_tacnav().unblock_navigation(Vector2i(last_step.x, last_step.z), last_step.y)
		last_step = step
		result = _take_a_step(step, zones.exited, zones.entered)
	return result

## Override this function to define what happens when the character moves from one tile to the other.[br]
## Return whether the movement to the «step» tile was successful. Errors won't halt the movement
## Return [code]ERR_CANT_CONNECT[/code] if that's desired.
func _take_a_step(step:Vector3i, zones_exited, zones_entered) -> Error:
	if step.y == last_step.y:
		look_at(next_step, Vector3.UP, true)
	return OK

#NOTE This function is not doing much, but it's here in case a use comes up, I don't have to rename things.
func traversal_finish(condition:Error=OK) -> Error:
	return _traversal_finish(condition)

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
	return get_tacnav().locate_entity(self).tacmap

func get_nav_coord() -> Vector2i:
	return get_tacnav().locate_entity(self).nav_coord

func get_nav_coord3() -> Vector3i:
	var loc = get_tacnav().locate_entity(self)
	var tile = loc.nav_coord
	return Vector3i(tile.x, loc.layer, tile.y)

func get_map_coord() -> Vector2i:
	return get_tacnav().locate_entity(self).map_coord

func get_nav_layer() -> int:
	return get_tacnav().locate_entity(self).layer
