extends Node3D
class_name TacInterface

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: 
		var camera = get_viewport().get_camera_3d()
		if not camera == null:
			var ray_norm = camera.project_ray_normal(event.position)
			var ray_orig = camera.project_ray_origin(event.position)
			var ray_dest = ray_norm * camera.far
			
			# Find TacMap, TacNav and tile coords under the mouse and through holes in maps.
			var except : Array[RID]
			var is_hole : bool = true  # There's a hole in the floor where the mouse is.
			while is_hole:
				var ray_query = PhysicsRayQueryParameters3D.create(ray_orig, ray_dest, Con.phys_layer["tacmap"])
				ray_query.hit_back_faces = false
				ray_query.hit_from_inside = false
				ray_query.collide_with_areas = true
				ray_query.exclude = except
				
				var ray_sect : Dictionary = get_world_3d().direct_space_state.intersect_ray(ray_query)
				if ray_sect.is_empty():
					#Nothing could be ever be found by the raycast
					Tac.hover_map = null
					break
				
				Tac.hover_map = ray_sect.collider
				Tac.hover_nav = Tac.hover_map.get_parent()
				Tac.hover_layer = Tac.hover_map.get_spatial_layer() 
				Tac.hover_layer_nav = Tac.hover_map.get_layer()
				Tac.hover_tile = Tac.hover_nav.spatial2tile(Saliko.Vec3RemAxis(ray_sect.position))
				Tac.hover_tile_nav = Tac.hover_nav.spatial2nav_tile(ray_sect.position)
				Tac.hover_tile_map = Tac.hover_nav.spatial2map_tile(ray_sect.position, Tac.hover_map)
				
				# Change in parameters to try searching again.
				var tile : TacTile = Tac.hover_map.tiles.get(Tac.hover_tile_map)
				is_hole = tile == null or tile.is_empty()
				if is_hole:
					except.append(ray_sect.rid)
			
			
			# Find TacEntity under the mouse and past already known map holes.
			var ray_query = PhysicsRayQueryParameters3D.create(ray_orig, ray_dest, Con.phys_layer["tac_entity"])
			ray_query.collide_with_areas = true
			ray_query.exclude = except
			
			var ray_sect : Dictionary = get_world_3d().direct_space_state.intersect_ray(ray_query)
			if ray_sect.is_empty():
				Tac.hover_entity = null
			else:
				Tac.hover_entity = ray_sect.collider
			#print(Tac.hover_entity)
	
	if event.is_action_released(Tac.command_input()):
		if Tac.hover_entity != null:
			entity_chara_interaction(Tac.hover_entity)
	if event.is_action_released(Tac.interact_input()):
		if Tac.hover_entity != null:
			entity_player_interaction(Tac.hover_entity)


## Override this function to decide what chara will be blamed for interacting with other entities.
func get_interaction_emitter() -> TacCharacter:
	return Tac.sel_chara

## This is meant to represent an action of a character on another entity, usually commanded by the player.
func entity_chara_interaction(receiver:TacEntity):
	var emitter = get_interaction_emitter()
	if emitter == null:
		return
	if emitter == receiver:
		receiver.interact_self()
	elif emitter.get_nav_layer() == receiver.get_nav_layer():
		if receiver is TacCharacter and receiver != Tac.sel_target:
			select_target_character(receiver)
		else:
			var distance = Geometry2D.bresenham_line(Tac.sel_chara.get_nav_coord(), receiver.get_nav_coord())
			_entity_chara_interaction(emitter, receiver, distance.size())

func _entity_chara_interaction(emitter:TacEntity, receiver:TacEntity, distance:int):
	if distance <= max(emitter.interact_distance, receiver.interact_distance):
		emitter.interact_emit(receiver)
		receiver.interact_receive(emitter)

## This is meant to represent a direct action of the player on a character, usually a selection.
func entity_player_interaction(receiver:TacEntity):
	if receiver == Tac.sel_chara:
		receiver.command_self()
	if receiver is TacCharacter and receiver.team == TacCharacter.Team.PLAYER and receiver != Tac.sel_chara:
		select_active_character(receiver)
	else:
		_entity_player_interaction(receiver)

func _entity_player_interaction(receiver:TacEntity):
	receiver.interact_receive(null)


## Set the character receiving commands.[br]
## NOTE: the override callback is called before setting character, so they can tell whether
## to behave differently before and after being selected.
func select_active_character(chara:TacCharacter):
	_select_active_character(chara)
	Tac.sel_chara = chara
	get_tree().call_group("observer_character_active", "_on_character_activated", chara)

## Override to define what happens if a character is selected for control. [code]Tac.sel_chara[/code] still contains the last selected character during this function call, if necessary to know.
func _select_active_character(chara:TacCharacter):
	chara.on_being_activated()

## Set the character targetted by an action.[br]
## NOTE: the override callback is called before setting character, so they can tell whether
## to behave differently before and after being selected.
func select_target_character(chara:TacCharacter):
	_select_target_character(chara)
	Tac.sel_target = chara
	get_tree().call_group("observer_target_select", "_on_target_selected", chara)

func _select_target_character(chara:TacCharacter):
	chara.on_being_targetted()
