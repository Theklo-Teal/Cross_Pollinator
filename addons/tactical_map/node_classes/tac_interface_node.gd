extends Node3D
class_name TacInterface

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: 
		var camera = get_viewport().get_camera_3d()
		if not camera == null:
			var ray_norm = camera.project_ray_normal(event.position)
			var ray_orig = camera.project_ray_origin(event.position)
			var ray_dest = ray_norm * camera.far
			
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
				Tac.hover_layer = Tac.hover_map.get_layer()
				Tac.hover_tile_map = Tac.hover_nav.spatial2map_tile(ray_sect.position, Tac.hover_map)
				Tac.hover_tile = Tac.hover_nav.spatial2nav_tile(ray_sect.position)
				
				# Change in parameters to try searching again.
				var tile : TacTile = Tac.hover_map.tiles.get(Tac.hover_tile_map)
				is_hole = tile == null or tile.is_empty()
				if is_hole:
					except.append(ray_sect.rid)
