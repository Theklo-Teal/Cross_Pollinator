@tool
extends "res://addons/tactical_map/tac_editor_fsm.gd"
class_name TacticalMapEditor

#TODO Handle drawing for the multiple 3D viewports. Infrastructure for it already exists as the `cam_view` dictionary.
#TODO Test map crop, now that offset functions.
#TODO Test zone enter/exit logic in TacMap

#FIXME Map offsetting has some coordinate issue.

#WARNING We must not call for "Tac" (tac_map_global.gd) in this script. It can only enable or disable it.

#region Boilerplate
func _ready() -> void:
	pallet = pallet.instantiate()
	pallet.visible = false
	pallet.zone_clicked.connect(_on_zone_clicked)
	pallet.zones_selected.connect(_on_zones_selected)
	pallet.zone_renamed.connect(_on_zone_renamed)
	pallet.zone_deleted.connect(_on_zone_deleted)
	pallet.ladder_clicked.connect(_on_ladder_clicked)
	pallet.ladders_selected.connect(_on_ladders_selected)
	pallet.ladder_renamed.connect(_on_ladder_renamed)
	pallet.ladder_deleted.connect(_on_ladder_deleted)
	pallet.mode_changed.connect(_on_state_changed)
	pallet.paint_tool_changed.connect(_on_paint_tool_changed)
	pallet.offset_map.connect(_on_offset_map)
	pallet.nav_overlay.connect(func(shown):update_cam_view(last_cam))
	pallet.floor_overlay.connect(func(shown):update_cam_view(last_cam))

func _enter_tree() -> void:
	super()

	modes = {
		"floor": Floor_Mode.new(self),
		"tall": Tall_Wall_Mode.new(self),
		"half": Half_Wall_Mode.new(self),
		"crawl": Crawl_Wall_Mode.new(self),
		"zoning": Zone_Mode.new(self),
		"ladders": Ladder_Mode.new(self),
		"spawner": Spawner_Mode.new(self),
		"coordcapt": Coord_Capture.new(self)
		}
	
	add_custom_type("CharaAction", "RefCounted", preload("res://addons/tactical_map/entity_classes/chara_action.gd"), preload("res://addons/tactical_map/icons/TacCharaAction.svg"))
	add_custom_type("FloorInfo", "Resource", preload("res://addons/tactical_map/resource_classes/floor_info.gd"), preload("res://addons/tactical_map/icons/FloorInfo.svg"))
	add_custom_type("WallInfo", "Resource", preload("res://addons/tactical_map/resource_classes/wall_info.gd"), preload("res://addons/tactical_map/icons/WallInfo.svg"))
	add_custom_type("TacTile", "Resource", preload("res://addons/tactical_map/resource_classes/tac_tile.gd"), preload("res://addons/tactical_map/icons/TacTile.svg"))
	add_custom_type("TacEntitySpawner", "Resource", preload("res://addons/tactical_map/resource_classes/tac_spawner.gd"), preload("res://addons/tactical_map/icons/TacEntitySpawner.svg"))
	add_custom_type("TacEntity", "Area3D", preload("res://addons/tactical_map/entity_classes/tac_entity.gd"), preload("res://addons/tactical_map/icons/TacEntity.svg"))
	add_custom_type("TacCharacter", "TacEntity", preload("res://addons/tactical_map/entity_classes/tac_character.gd"), preload("res://addons/tactical_map/icons/TacChara.svg"))
	add_custom_type("TacNav", "Area3D", preload("res://addons/tactical_map/node_classes/tac_nav_node.gd"), preload("res://addons/tactical_map/icons/TacNav.svg"))
	add_custom_type("TacMap", "Area3D", preload("res://addons/tactical_map/node_classes/tac_map_node.gd"), preload("res://addons/tactical_map/icons/TacMap.svg"))
	add_custom_type("TacInterface", "Node3D", preload("res://addons/tactical_map/node_classes/tac_interface_node.gd"), preload("res://addons/tactical_map/icons/TacInterface.svg"))


func _exit_tree() -> void:
	remove_custom_type("Action")
	remove_custom_type("FloorInfo")
	remove_custom_type("WallInfo")
	remove_custom_type("TacTile")
	remove_custom_type("TacEntitySpawner")
	remove_custom_type("TacCharacter")
	remove_custom_type("TacNav")
	remove_custom_type("TacMap")
	remove_custom_type("TacInterface")
	
	if pallet.visible:
		remove_control_from_bottom_panel(pallet)
	pallet.queue_free()

func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/tactical_map/icons/TacEditor.svg")

func _handles(object) -> bool:
	if object is TacMap:
		curr_map = object
		curr_nav = curr_map.get_parent()
		pallet.map_changed(curr_map)
		update_overlays()
		return true
	else:
		if curr_map != null:
			curr_map = null
			pallet.map_changed(null)
			update_overlays()
		return false

var last_bottom_panel : int
func _make_visible(tacmap_selected: bool) -> void:
	#NOTE Called depending on whether `_handles()` returns true
	if tacmap_selected:
		if not pallet.visible:
			add_control_to_bottom_panel(pallet, "Tac Map")
			
			# This is an hacky way to get the control last shown before changing to the «pallet».
			last_bottom_panel = pallet.get_parent().get_parent().current_tab
			
			pallet.show()
			make_bottom_panel_item_visible(pallet)
	elif pallet.visible:
		# Switching back to the panel before «pallet» was shown.
		pallet.get_parent().get_parent().current_tab = last_bottom_panel
		
		pallet.hide()
		remove_control_from_bottom_panel(pallet)


#func _edit(object: Object) -> void:
	#if object is TacMap:
		#pass
	#elif object == null:  # nodes were de-selected
		#pass

## Check if camera moved to redraw overlays.
var past_cam_pos : Transform3D
func _process(_delta: float) -> void:
	if not last_cam == null:
		if not last_cam.transform.is_equal_approx(past_cam_pos):
			past_cam_pos = last_cam.transform
			update_cam_view(last_cam)
			
#endregion

#region Input Events
var last_cam : Camera3D  ## The camera of the last active viewport, where input happened.
var floor := Plane.PLANE_XZ  ## Reference plane for collision with a raycast.
var hover_tile : Vector2i  ## Tile of [code]curr_map[/code] the mouse is hovering in global space.
var start_tile : Vector2i  ## Tile where the a mouse drag operation started in global spatial reference.
var map_hover_tile : Vector2i  ## [code]hover_tile[/code] in [code]curr_map[/code] relative coordinate.
var map_start_tile : Vector2i  ## Tile of [code]curr_map[/code] where a mouse drag operation started.
var within_tile : Vector2  ## Where on the hover tile is the mouse?
var _hover_tile_side : Vector2i  ## An intermediate [code]hover_tile_side[/code] that's calculated ever time the mouse moves, rather than just on mouse clicks.
var _hover_tile_corner : Vector2i  ## An intermediate [code]hover_tile_corner[/code] that's calculated ever time the mouse moves, rather than just on mouse clicks.
var hover_tile_side : Vector2i  ## Which side of the hover tile is the mouse closer to.
var hover_tile_corner : Vector2i  ## Which corner of the hover tile is the mouse closer to.
var hover_tile_side_opposite : Vector2i
var can_drag : bool = false
var is_dragging : bool = false
var within_map : bool = false  ## The [code]hover_tile[/code] is within the area of [code]curr_map[/code].
var camera_moved : bool = false  ## Check if the camera moved since last mouse button press.

func _forward_3d_gui_input(camera:Camera3D, event:InputEvent):
	last_cam = camera  # A kludge to keep track of which camera is being used, drawing appropriately to its view.
	if curr_map == null or curr_mode().is_empty():
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	
	if event is InputEventMouseMotion:
		floor.d = curr_map.get_spatial_height()
		var ray_orig = camera.project_ray_origin(event.position)
		var ray_norm = camera.project_ray_normal(event.position)
		var collision = floor.intersects_ray(ray_orig, ray_norm)
		if collision != null:
			hover_tile = curr_nav.spatial2tile(Saliko.Vec3RemAxis(collision))
			map_hover_tile = curr_nav.spatial2map(collision, curr_map)
			within_tile.x = fposmod(collision.x, curr_nav.tile_size) - 0.5
			within_tile.y = fposmod(collision.z, curr_nav.tile_size) - 0.5
			within_map = curr_map.nav_area.has_point(hover_tile)
			
			_hover_tile_corner = Vector2i(sign(within_tile.x), sign(within_tile.y))
			_hover_tile_side = _hover_tile_corner
			_hover_tile_side[within_tile.abs().min_axis_index()] = 0
			
			if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)\
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))\
			and can_drag:
				is_dragging = true
		
		if within_map:
			update_alt_view(camera)
	
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if within_map:
				can_drag = true
			if event.is_pressed():
				start_tile = hover_tile
				map_start_tile = map_hover_tile
				hover_tile_corner = _hover_tile_corner
				hover_tile_side = _hover_tile_side
				hover_tile_side_opposite = -hover_tile_side.sign()
	var response = modes[curr_mode()].input(event)
	
	# This is placed here, so modes have a way to tell where dragging has been happening.
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if event.is_released():
				can_drag = false
				is_dragging = false
		if event.button_index == MOUSE_BUTTON_RIGHT and event.is_released():
			camera_moved = false
	
	if response == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	else:
		return response

func _forward_3d_draw_over_viewport(view: Control) -> void:
	
	# An hack to distinguish the different 3D view cameras and their associated overlay canvas.
	if cam_view.get(last_cam) == null:
		cam_view[last_cam] = view
	if view_cam.get(view) == null:
		view_cam[view] = last_cam
		view.draw.connect(on_cam_view_draw.bind(view, last_cam))
	
	if alt_view.get(last_cam) == null:
		alt_view[last_cam] = Control.new()
		alt_view[last_cam].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		alt_view[last_cam].size_flags_vertical = Control.SIZE_EXPAND_FILL
		view.get_parent().add_child(alt_view[last_cam])
	if view_cam.get(alt_view[last_cam]) == null:
		view_cam[alt_view[last_cam]] = last_cam
		alt_view[last_cam].draw.connect(on_alt_view_draw.bind(alt_view[last_cam], last_cam))


## A kludge to add a second drawing canvas to the 3D overlay.
var cam_view : Dictionary[Camera3D, Control]  # Tell which default overlay is of which camera.
var alt_view : Dictionary[Camera3D, Control]  # Tell which custom added overlay is of which camera.
var view_cam : Dictionary[Control, Camera3D]  # Backreference to find camera of a view. Includes also alt-overlays.
func update_cam_view(camera:Camera3D):
	if camera in cam_view and curr_map != null and not curr_mode().is_empty():
		cam_view[camera].queue_redraw()
func update_alt_view(camera:Camera3D):
	if camera in alt_view and curr_map != null and not curr_mode().is_empty():
		alt_view[camera].queue_redraw()


## Use this to draw things that only need to update on camera motion.
func on_cam_view_draw(canvas:Control, cam:Camera3D) -> void:
	#NOTE That all 3D coordinates used for drawing are in global space.
	if not (cam in cam_view and curr_map != null and not curr_mode().is_empty()):
		return
	
	# Draw boundary of the TacMap
	var fence = [
		Vector3(curr_map.global_area.position.x,curr_map.get_spatial_height(),curr_map.global_area.position.y),
		Vector3(curr_map.global_area.position.x,curr_map.get_spatial_height(),curr_map.global_area.end.y),
		Vector3(curr_map.global_area.end.x, curr_map.get_spatial_height(), curr_map.global_area.end.y),
		Vector3(curr_map.global_area.end.x, curr_map.get_spatial_height(), curr_map.global_area.position.y),
		]
	draw_area_outline(canvas, fence, Color.WEB_PURPLE, 8)
	
	# Floor Overlay
	#if pallet.is_floor_overlay_visible():
		#pass
	
	# Navigation Graph Overlay
	#if pallet.is_nav_overlay_visible():
		#for coordi : Vector3i in curr_nav.navproxy:
			#var coord = curr_nav.nav3spatial(coordi, true)
			#if cam.is_position_in_frustum(coord):
				#var transcodes : int = curr_nav.navproxy[coordi].simple
				#if transcodes > 0 and transcodes < 0b1111:
					#var distance = cam.position.distance_to(coord)
					#var rad = Saliko.apparent_size(cam, curr_nav.tile_size, distance)
					#var unproj = cam.unproject_position(coord)
					#view.draw_circle(unproj, rad, Color.RED)
	
	modes[curr_mode()].draw(canvas, cam)

## Use this to draw things updated with mouse motion.
func on_alt_view_draw(canvas:Control, cam:Camera3D) -> void:
	#NOTE That all 3D coordinates used for drawing are in global space.
	if not (cam in alt_view and curr_map != null and not curr_mode().is_empty()):
		return
	
	# Hover Tile Indicator
	var tile_rect = Saliko.get_area(Vector2(hover_tile), Vector2(hover_tile) + Vector2.ONE * curr_nav.tile_size)
	var hei = curr_map.get_spatial_height()
	var tile_corners = [
		Vector3(tile_rect.end.x,hei,tile_rect.position.y),
		Vector3(tile_rect.end.x,hei,tile_rect.end.y),
		Vector3(tile_rect.position.x,hei,tile_rect.end.y),
		Vector3(tile_rect.position.x, hei, tile_rect.position.y),
		Vector3(tile_rect.end.x, hei, tile_rect.position.y),
		]
	var color = [Color.RED, Color.PURPLE][int(within_map)]
	color.a = 0.25
	draw_area_polygon(canvas, tile_corners, color)
	if within_map:
		var lateral = {
		Vector2i.RIGHT : [0,1],
		Vector2i.DOWN : [1,2],
		Vector2i.LEFT : [2,3],
		Vector2i.UP : [3,4],
		}
		var side = lateral[_hover_tile_side]
		if cam.is_position_in_frustum(tile_corners[side[0]]) or cam.is_position_in_frustum(tile_corners[side[1]]):
			canvas.draw_line(
				cam.unproject_position(tile_corners[side[0]]),
				cam.unproject_position(tile_corners[side[1]]),
				Color.PURPLE, 6)

#endregion

#region Drawing Help Functions
## Produces a 2D polygon from a polygon in 3D space for purposes of
## [code]Control._draw()[/code].[br]
## Coordinates of [code]verts[/code] should be in Global 3D space.
func unproject_area(canvas:Control, verts:PackedVector3Array) -> PackedVector2Array:
	#FIXME Who's calling this before cameras are discovered?
	var cam = view_cam[canvas]
	var polyline : PackedVector2Array
	verts = Geometry3D.clip_polygon(verts, cam.get_frustum()[0])
	for p in verts:
		polyline.append(cam.unproject_position(p))
	return polyline

## Draw the outline overlay of an area in 3D perspective. Processes [code]corners[/code]
## using [code]unproject_area[/code].
func draw_area_outline(canvas:Control, corners: PackedVector3Array, color:Color, thickness:int=-1):
	corners.append(corners[0])
	var points = unproject_area(canvas, corners)
	if points.size() >= 3:
		canvas.draw_polyline(points, color, thickness)

## Draw a filled polyong overlay of an area in 3D perspective. Processes [code]corners[/code]
## using [code]unproject_area[/code].
func draw_area_polygon(canvas:Control, corners: PackedVector3Array, color:Color):
	var points = unproject_area(canvas, corners)
	if points.size() >= 3:
		canvas.draw_colored_polygon(points, color)

## Combines both [code]draw_area_outline()[/code] and [code]draw_area_polygon()[/code].
## Processes [code]corners[/code] using [code]unproject_area[/code].
func draw_area_outlined_polygon(canvas:Control, corners: PackedVector3Array, fill_color:Color, perim_color:Color, thickness:int=-1):
	corners.append(corners[0])
	var points = unproject_area(canvas, corners)
	if points.size() >= 3:
		canvas.draw_colored_polygon(points, fill_color)
		canvas.draw_polyline(points, perim_color, thickness)
#endregion

#region Zoning and Ladders
var sel_zones : PackedStringArray
var sel_ladders: PackedStringArray

func set_active_zone(zone_name:StringName):
	sel_zones.append(zone_name)
	pallet.set_active_zone(zone_name)
func set_active_ladder(ladder_name:StringName):
	sel_ladders.append(ladder_name)
	pallet.set_active_ladder(ladder_name)

func _on_zone_clicked():
	update_cam_view(last_cam)
func _on_zones_selected(zones:PackedStringArray):
	sel_zones = zones
	update_cam_view(last_cam)
func _on_zone_deleted(zone:String):
	curr_map.zones.erase(zone)
	sel_zones.erase(zone)
	update_cam_view(last_cam)
func _on_zone_renamed(old:String, new:String):
	curr_map.zones[new] = curr_map.zones[old]
	curr_map.zones.erase(old)
	sel_zones.erase(old)
	sel_zones.append(new)
	update_cam_view(last_cam)

func _on_ladder_clicked():
	update_cam_view(last_cam)
func _on_ladders_selected(ladders:PackedStringArray):
	sel_ladders = ladders
	update_cam_view(last_cam)
func _on_ladder_deleted(ladder:String):
	curr_map.ladders.erase(ladder)
	sel_ladders.erase(ladder)
	update_cam_view(last_cam)
func _on_ladder_renamed(old:String, new:String):
	curr_map.ladders[new] = curr_map.ladders[old]
	curr_map.ladders.erase(old)
	sel_ladders.erase(old)
	sel_ladders.append(new)
	update_cam_view(last_cam)

#endregion

#region Painting
func _on_offset_map(direction:Vector2i):
	var new_tiles : Dictionary[Vector2i, TacTile]
	for coord in curr_map.tiles:
		var new_coord = coord + direction
		if not curr_map.queue_place.has(coord):
			curr_map.queue_place.append(coord)
		if not curr_map.queue_place.has(new_coord):
			curr_map.queue_place.append(new_coord)
		new_tiles[new_coord] = curr_map.tiles[coord]
	curr_map.tiles = new_tiles


func set_tile_asset(coord:Vector2i, side:Vector2i):
	var asset_info_uid : String = pallet.get_active_asset_info_uid()
	if asset_info_uid.is_empty():
		printerr("TacMap Editor: No valid active asset!")
		return
	curr_map.set_tile_asset(coord, side, asset_info_uid)
	curr_nav.queue_nav(curr_nav.map3nav(coord, curr_map))

func rem_tile_asset(coord:Vector2i, side:=Vector2i.ZERO):
	curr_nav.queue_nav(curr_nav.map3nav(coord, curr_map))
	var tile : TacTile = curr_map.tiles.get(coord)
	if tile == null:
		return
	var fam = pallet.get_mode()
	match fam:
		"floor":
			curr_map.queue_place.append(coord)
			tile.floor = ""
			tile.has_floor = false
			tile.is_ceiling = false
		"tall", "half", "crawl":
			curr_map.queue_place.append(coord)
			const sides = {
			Vector2i.RIGHT : "wall_east",
			Vector2i.DOWN : "wall_south",
			Vector2i.LEFT : "wall_west",
			Vector2i.UP : "wall_north"
			}
			if side == Vector2i.ZERO:
				for s in sides:
					tile.set(sides[s], "")
			else:
				tile.set(sides[side], "")
#endregion
