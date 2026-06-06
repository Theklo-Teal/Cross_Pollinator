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

func move_on_map(destination:Vector2i, teleport:=false):
	var tacnav = get_tacnav()
	if destination == get_nav_coord():
		return
	
	var last_step = get_nav_coord()
	var traject : Array[Vector2i]
	if teleport:
		traject = [destination]
	else:
		traject = tacnav.get_traject(self, destination)
		traject.reverse()
		traject.pop_back()  # Remove the starting point.
	while not traject.is_empty():
		var step = traject.pop_back()
		var zones = tacnav.check_zone(self, last_step, step)
		_step_on_map(step, zones.exited, zones.entered)
		last_step = step

## Override this function to define what happens when the character moves from one tile to the other.
func _step_on_map(_step:Vector2i, zones_exited, zones_entered):
	pass

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
	assert(get_parent() is TacNav)
	return get_parent()
## In which Tactical Grid is this object on top?[br]
func get_tacmap() -> TacMap:
	return get_tacnav().locate_chara(self).tacmap

func get_nav_coord() -> Vector2i:
	return get_tacnav().locate_entity(self).nav_coord

func get_map_coord() -> Vector2i:
	return get_tacnav().locate_entity(self).map_coord
