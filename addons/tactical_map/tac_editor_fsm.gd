@tool
extends EditorPlugin

#TODO Undo/Redo
#TODO Flood Fill
#TODO Enable Picker Tool
#TODO Tags for searching assets and the filter input
#TODO Test Ladders
#TODO Test Zone triggers
#TODO Offset Map also offstes Zones and Ladders, but not characters.

#FIXME Spawner placement seems unreliable? Not always returning EditorPlugin.AFTER_GUI_INPUT_STOP or something.
#FIXME Alternate mode of adding walls (to produce opposite/external walls) shouldn't try to place on tiles outside the map.
#FIXME Navoverlay not updating as objects are placed.

#NOTE How to use undo_redo
	##undo_redo.create_action("TacMap: set wall tiles")
	##undo_redo.add_do_property()
	##undo_redo.add_undo_property()
	##undo_redo.commit_action()

#region Boilerplate
var curr_map : TacMap
var curr_nav : TacNav  ## TacNav parent of the [code]curr_map[/code].
var pallet = preload("res://addons/tactical_map/tac_map_pallet.tscn")
var undo_redo : EditorUndoRedoManager

func _enable_plugin() -> void:
	add_autoload_singleton("Tac", "res://addons/tactical_map/tac_map_global.gd")
func _disable_plugin() -> void:
	remove_autoload_singleton("Tac")

func _enter_tree() -> void:
	#NOTE Have been having issues with «add_autoload_singleton()» not doing its job in «_enable_plugin()», so here we ensure «Tac» is set.
	if not ProjectSettings.has_setting("autoload/Tac"):
		add_autoload_singleton("Tac", "res://addons/tactical_map/tac_map_global.gd")
	
	undo_redo = get_undo_redo()

#endregion

var modes : Dictionary
func curr_mode() -> StringName:
	return pallet.get_mode()

func _on_state_changed(next:StringName, prev:StringName):
	if not prev.is_empty():
		modes[prev].exit()
	if not next.is_empty():
		modes[next].enter()
		pallet.set_help(modes[next].help())

func _on_paint_tool_changed(tool:StringName):
	if not tool.is_empty():
		pallet.set_help(modes[curr_mode()].help())

## Given tiles, get an Rect2i contained by the TacMap's area in Global space
## coordinates. Set [code]no_zero[/code] true if rect should alway have area.
## By default assumes coordinates are in Global space, provide a TacMap to use 
## that map's space.[br]
func get_map_rect(from:Vector2i, to:Vector2i, no_zero:bool=false, tacmap:TacMap=null) -> Rect2i:
	var rect := Rect2i(from, Vector2i.ONE)
	rect.end = to
	if not tacmap == null:
		rect.position = curr_nav.map2spatial_tile(from, tacmap)
		rect.end = curr_nav.map2spatial_tile(to, tacmap)
	rect = rect.abs()
	if no_zero:
		rect = rect.grow_individual(0,0,1,1)
	if not tacmap == null:
		rect = rect.intersection(tacmap.global_area)
	return rect

## Given tiles, get an area contained by the TacMap's area in Global space
## coordinates. Useful for a 2D overlay drawing.[br]
## By default assumes coordinates are in Global space, provide a TacMap to use 
## that map's space.[br]
## Returns an area in 3D space according to the TacMap's height (if available)
## and [code]offset[/code] height.
func get_map_area(from:Vector2i, to:Vector2i, tacmap:TacMap=null, offset:float=0) -> PackedVector3Array:
	var rect : Rect2 = get_map_rect(from, to, true, tacmap)
	var polygon = Saliko.rect2polygon(rect)
	var area : PackedVector3Array
	for tile in polygon:
		var vert : Vector3
		vert = curr_nav.tile2spatial(tile)
		vert.y = offset
		if not tacmap == null:
			vert.y += tacmap.get_height()
		area.append(vert)
	return area


@abstract class TacEditorState:
	var me : TacticalMapEditor
	var update_queue : Array[Vector3i]  ## In Nav coordinates with layer as Y; Tiles to have navigation updated at the end of an operation.
	
	func queue_update(map_cell:Vector2i):
		var nav_coord = me.curr_nav.map3nav(map_cell, me.curr_map)
		if not nav_coord in update_queue:
			update_queue.append(nav_coord)
	
	func relieve_queue():
		if not (me.curr_nav == null or update_queue.is_empty()):
			me.curr_nav.queue_nav_arr(update_queue)
			update_queue.clear()
			me.update_cam_view(me.last_cam) #FIXME why won't the navigation overlay update with this?
	
	func _init(manager:TacticalMapEditor):
		me = manager
	
	func help() -> String:
		return ""
	
	func enter():
		# Enable all tools
		me.pallet.force_paint_tool(&"Single", &"Area", &"Flood")
	func exit():
		pass
	
	func input(event:InputEvent):
		if me.curr_map == null or me.curr_nav == null:
			return
		
		var alternate = Input.is_key_pressed(KEY_CTRL)
		
		if event is InputEventMouseMotion and me.is_dragging and me.within_map:
			var left_button = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			var right_button = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
			return while_dragging(alternate, left_button, right_button)
		
		if event is InputEventMouseButton and me.within_map:
			if event.is_pressed():
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						return left_press(alternate)
					MOUSE_BUTTON_RIGHT:
						return right_press(alternate)
					MOUSE_BUTTON_MIDDLE:  #NOTE Middle mouse button won't get through the "me.camera_move" check.
						if me.within_map:
							return pick_tool(alternate)
			elif event.is_released() and not me.camera_moved:
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						return left_release(alternate)
					MOUSE_BUTTON_RIGHT:
						return right_release(alternate)
		
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	
	func pick_tool(alternate:bool):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	func while_dragging(alternate:bool, left_button_down:bool, right_button_down:bool):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	func left_release(alternate:bool):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	func left_press(alternate:bool):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	func right_release(alternate:bool):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	func right_press(alternate:bool):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	
	func draw(canvas:Control, cam:Camera3D):
		if me.camera_moved:
			draw_cam_moved(canvas, cam)
		if me.is_dragging:
			draw_dragging(canvas, cam)
	## To redraw, keeping something visible if the camera moves.
	func draw_cam_moved(canvas:Control, cam:Camera3D):
		pass
	## To redraw whil dragging the mouse.
	func draw_dragging(canvas:Control, cam:Camera3D):
		pass

class Paint_Mode extends TacEditorState:
	var area_polygon : PackedVector3Array  # The highlighted area as the mouse drags.
	var last_placed : Vector2i  # Remember last affected tile, avoiding it constantly changing while the mouse button is held.
	var has_placed : bool = false  # Whether to acknowledge «last_placed»
	
	## Performs [code]operation[/code] on tiles in breadth-first search for which
	## [code]seek[/code] returns [code]true[/code] from a given [code]origin[/code]
	## in map coordinates. This function constrains itself to the area of the active TacMap.[br]
	## [code]edging[/code] tells to only operate on tiles at the edge of flooded area.[br]
	## [code]seek[/code] should take a [code]TacTile[/code] as argument.[br]
	## [code]operation[/code] should take a Vector2i of the map coordinate for a cell
	## and a [code]TacTile[/code].[br]
	func flood_fill(origin:Vector2i, seek:Callable, operation:Callable, edging:=false):
		var area := Rect2(Vector2.ZERO, me.curr_map.size)
		var reject : Array
		var queue : Array = [origin]
		var head : int = - 1
		while head <= queue.size() - 1:
			for curr in queue.slice(head, queue.size()):
				head += 1
				var accepted : Array
				for dir in Tac.DIR_VEC.values():
					var next = curr + dir
					if not area.has_point(next): continue
					if next in queue: continue
					if next in reject: continue
					accepted.append(next)
				var at_edge : bool = accepted.size() < 4
				for next in accepted:
					var tile = me.curr_map.tiles.get(next)
					if seek.call(tile):
						queue.append(next)
						if not(edging and not at_edge):
							operation.call(next, tile)
					else: reject.append(next)
	
	## Returns what on a tile is of interest for the picker tool.
	## If not overriden returns the transition code.
	func pick_target(tile:TacTile) -> Variant:
		var dir = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP].find(me.hover_tile_side)
		var adja = me.curr_map.tiles.get(me.map_hover_tile + me.hover_tile_side)
		return tile.get_transition(dir, adja)
	
	func while_dragging(alt:bool, left, right):
		if me.pallet.get_paint_tool() == "Area":
			area_polygon = me.get_map_area(me.map_start_tile, me.map_hover_tile, me.curr_map, 0.1)
			me.update_cam_view(me.last_cam)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func left_press(alternate:bool):
		has_placed = false
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func right_press(alternate:bool):
		has_placed = false
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func left_release(alt:bool):
		if not area_polygon.is_empty():
			area_polygon.clear()
		if me.is_dragging:
			me.update_cam_view(me.last_cam)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	func right_release(alt:bool):
		if not area_polygon.is_empty():
			area_polygon.clear()
		if me.is_dragging:
			me.update_cam_view(me.last_cam)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

class Zone_Mode extends Paint_Mode:
	func help() -> String:
		return "Tiles contained by a zone will trigger events when characters step on them or out of them.\nType a zone title, then drag on map to create a new zone. Clicking zones from the list highlights them on the map.\nSubmitting a title renames the last clicked zone. Submitting an empty title deletes the last clicked zone."
	
	func enter():
		me.pallet.force_paint_tool(&"Area")
		me.update_cam_view(me.last_cam)
	
	func while_dragging(alt:bool, left, right):
		if left:
			super(alt, left, right)
	
	func left_release(alt:bool):
		var zone_name = me.pallet.on_add_zone(me.curr_map.zones.keys())
		if not zone_name.is_empty():
			var rect = me.get_map_rect(me.map_start_tile, me.map_hover_tile, true)
			rect = rect.intersection(Rect2i(Vector2i.ZERO, me.curr_map.size))
			me.curr_map.zones[zone_name] = rect
			me.set_active_zone(zone_name)
		return super(alt)
	
	func pick_tool(alt:bool):
		for each in me.sel_zones:
			var zone_rect : Rect2i = me.curr_map.zones[each]
			if zone_rect.has_point(me.map_hover_tile):
				me.pallet.set_active_zone(each)
				me.update_cam_view(me.last_cam)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func draw_dragging(canvas:Control, cam:Camera3D):
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not area_polygon.is_empty():
				var color = Color.DARK_SLATE_GRAY
				color.a = 0.4
				me.draw_area_outlined_polygon(canvas, area_polygon, color, Color.SEA_GREEN, 3)
	
	func draw(canvas:Control, cam:Camera3D):
		super(canvas, cam)
		var dirty_zones : PackedStringArray
		for zone in me.sel_zones:
			if not zone in me.curr_map.zones:
				dirty_zones.append(zone)
				continue
			var rect = me.curr_map.zones[zone]
			rect = rect.grow_individual(0,0,-1,-1)
			var polygon := me.get_map_area(rect.position, rect.end, me.curr_map, 0.1)
			var fill := Color.DIM_GRAY
			var outline := Color.DARK_SLATE_GRAY
			if zone == me.pallet.last_sel_zone:
				fill = Color.WEB_GREEN
				outline = Color.SEA_GREEN
			fill.a = 0.4
			me.draw_area_outlined_polygon(canvas, polygon, fill, outline, 3)
		for each in dirty_zones:
			me.sel_zones.erase(each)

class Ladder_Mode extends Paint_Mode:
	func help() -> String:
		return "Connects tiles of the same ladder title. Can't have the same ladder title more than once on each TacMap. \nType a ladder title, then click on map to create a warp tile. Clicking ladders from the list highlights them on the map.\nSubmitting a title renames the last clicked ladder. Submitting an empty title deletes the last clicked ladder."
	func enter():
		me.pallet.force_paint_tool(&"Single")
		me.update_cam_view(me.last_cam)
	
	func left_release(alt:bool):
		var ladder_name = me.pallet.on_add_ladder(me.curr_map.ladders.keys())
		if not ladder_name.is_empty():
			me.curr_map.ladders[ladder_name] = me.map_hover_tile
			me.set_active_ladder(ladder_name)
		return super(alt)
	
	func pick_tool(alternate:bool):
		for each in me.sel_ladders:
			if me.map_hover_tile == me.curr_map.ladders[each]:
				me.pallet.set_active_ladder(each)
				me.update_cam_view(me.last_cam)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func draw(canvas:Control, cam:Camera3D):
		super(canvas, cam)
		var dirty_ladders : PackedStringArray
		for ladder in me.sel_ladders:
			if not ladder in me.curr_map.ladders:
				dirty_ladders.append(ladder)
				continue
			var tile := me.curr_map.ladders[ladder]
			var polygon := me.get_map_area(tile, tile, me.curr_map, 0.1)
			if ladder == me.pallet.last_sel_ladder:
				var fill = Color.DARK_KHAKI
				fill.a = 0.4
				me.draw_area_outlined_polygon(canvas, polygon, fill, Color.KHAKI, 3)
			else:
				var fill = Color.DIM_GRAY
				fill.a = 0.4
				me.draw_area_outlined_polygon(canvas, polygon, fill, fill, 3)
		for each in dirty_ladders:
			me.sel_ladders.erase(each)

class Floors_Mode extends Paint_Mode:
	func help() -> String:
		return "Sets which tiles a character can walk on. Hold CTRL for setting ceilings.
		The overlay shows red for tiles that exist, but have no floor, and blue for tiles with floor."
	func enter():  # Display overlay
		super()
		me.update_cam_view(me.last_cam)
	
	func draw(canvas:Control, cam:Camera3D):
		if not area_polygon.is_empty():
			var clr := Color.WHEAT
			clr.a = 0.4
			me.draw_area_polygon(canvas, area_polygon, clr)
	
	func while_dragging(alt:bool, left:bool, right:bool):
		if me.pallet.get_paint_tool() == "Single":
			if has_placed == false or (last_placed != me.map_hover_tile):
				has_placed = true
				
				var tile : TacTile = me.curr_map.tiles.get_or_add(me.map_hover_tile, TacTile.new())
				queue_update(me.map_hover_tile)
				if alt:
					tile.has_ceiling = left
				else:
					tile.has_floor = left
			me.update_cam_view(me.last_cam)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		return super(alt, left, right)
	
	func left_press(alt:bool):
		if me.pallet.get_paint_tool() == "Single" or me.pallet.get_paint_tool() == "Flood":
				if has_placed == false or (last_placed != me.map_hover_tile):
					has_placed = true
					
					var tile : TacTile = me.curr_map.tiles.get_or_add(me.map_hover_tile, TacTile.new())
					queue_update(me.map_hover_tile)
					if alt:
						tile.has_ceiling = true
					else:
						tile.has_floor = true
				me.update_cam_view(me.last_cam)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
		return super(alt)
	
	func right_press(alt:bool):
		if me.pallet.get_paint_tool() == "Single" or me.pallet.get_paint_tool() == "Flood":
			if has_placed == false or (last_placed != me.map_hover_tile):
				has_placed = true
				
				var tile : TacTile = me.curr_map.tiles.get_or_add(me.map_hover_tile, TacTile.new())
				queue_update(me.map_hover_tile)
				if alt:
					tile.has_ceiling = false
				else:
					tile.has_floor = false
		return super(alt)
		
	
	func left_release(alt:bool):
		match me.pallet.get_paint_tool():
			"Flood":
				if alt:
					flood_fill(me.hover_tile, seek_flood.bind(true, true), oper_flood.bind(true, true))
				else:
					flood_fill(me.hover_tile, seek_flood.bind(true, false), oper_flood.bind(true, false))
			"Area":
				var rect = me.get_map_rect(me.map_start_tile, me.map_hover_tile, true)
				rect = rect.intersection(Rect2i(Vector2i.ZERO, me.curr_map.size))
				for y in range(rect.position.y, rect.end.y):
					for x in range(rect.position.x, rect.end.x):
						var coord = Vector2i(x,y)
						var tile : TacTile = me.curr_map.tiles.get_or_add(coord, TacTile.new())
						queue_update(coord)
						if alt:
							tile.has_ceil = true
						else:
							tile.has_floor = true
		return super(alt)
	
	func right_release(alt:bool):
		match me.pallet.get_paint_tool():
			"Flood":
				
				if alt:
					flood_fill(me.hover_tile, seek_flood.bind(false, true), oper_flood.bind(false, true))
				else:
					flood_fill(me.hover_tile, seek_flood.bind(false, false), oper_flood.bind(false, false))
			"Area":
				var rect = me.get_map_rect(me.map_start_tile, me.map_hover_tile, true)
				rect = rect.intersection(Rect2i(Vector2i.ZERO, me.curr_map.size))
				for y in range(rect.position.y, rect.end.y):
					for x in range(rect.position.x, rect.end.x):
						var coord = Vector2i(x,y)
						var tile : TacTile = me.curr_map.tiles.get_or_add(coord, TacTile.new())
						queue_update(coord)
						if alt:
							tile.has_ceil = false
						else:
							tile.has_floor = false
		return super(alt)
	
	func seek_flood(tile:TacTile, add:bool, ceiling:bool) -> bool:
		if add:
			if tile == null: return true
			if ceiling:
				return not tile.has_ceiling
			return not tile.has_floor
		else:
			if tile == null: return false
			if ceiling: return tile.has_ceiling
			return tile.has_floor
	func oper_flood(cell:Vector2i, tile:TacTile, add:bool, ceiling:bool) -> void:
		queue_update(cell)
		if add:
			if tile == null: tile = me.curr_map.tiles.get_or_add(cell, TacTile.new())
			if ceiling: tile.has_ceiling = true; return
			tile.has_floor = true
		else:
			if tile == null:return
			if ceiling: tile.has_ceiling = false; return
			tile.has_floor = false

class Wall_Mode extends Paint_Mode:
	
	func help() -> String:
		const which = {
			"Single": "The same wall is set under the mouse while the left button is held.",
			"Area": "Makes a room interior, walls on the tiles within the area.",
			}
		const alternate = {
			"Single": "Hold CTRL to make or remove a two-sided wall.",
			"Area": "If CTRL is held, makes room exterior."
			}
		return which.get(me.pallet.get_paint_tool(), "") + " Right-click to remove.\n" + alternate.get(me.pallet.get_paint_tool(), "")  + " The walls will be oriented depending on the side of the first tile pressed."
	
	func while_dragging(alt:bool, left, right):
		super(alt, left, right)
		if me.pallet.get_paint_tool() == "Single":
			if has_placed == false or (last_placed != me.map_hover_tile):
				has_placed = true
				last_placed = me.map_hover_tile
				if left:
					me.set_tile_asset(me.map_hover_tile, me.hover_tile_side)
					if alt:
						var adja = me.map_hover_tile + me.hover_tile_side
						me.set_tile_asset(adja, me.hover_tile_side_opposite)
				if right:
					me.rem_tile_asset(me.map_hover_tile, me.hover_tile_side)
					if alt:
						me.rem_tile_asset(me.map_hover_tile + me.hover_tile_side, me.hover_tile_side_opposite)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func left_press(alt:bool):
		if me.pallet.get_paint_tool() == "Single":
			if has_placed == false or (last_placed != me.map_hover_tile):
				has_placed = true
				last_placed = me.map_hover_tile
				me.set_tile_asset(me.map_hover_tile, me.hover_tile_side)
				queue_update(me.map_hover_tile)
				if alt:
					var adja = me.map_hover_tile + me.hover_tile_side
					me.set_tile_asset(adja, me.hover_tile_side_opposite)
		return super(alt)
	
	func right_press(alt:bool):
		match me.pallet.get_paint_tool():
			"Single":
				if has_placed == false or (last_placed != me.map_hover_tile):
					has_placed = true
					last_placed = me.map_hover_tile
					me.rem_tile_asset(me.map_hover_tile, me.hover_tile_side)
					queue_update(me.map_hover_tile)
					if alt:
						me.rem_tile_asset(me.map_hover_tile + me.hover_tile_side, me.hover_tile_side_opposite)
		return super(alt)
	
	func left_release(alt:bool):
		match me.pallet.get_paint_tool():
			"Area":
				var rect = me.get_map_rect(me.map_start_tile, me.map_hover_tile, true)
				rect = rect.intersection(Rect2i(Vector2i.ZERO, me.curr_map.size))
				var coord1 : Vector2i
				var coord2 : Vector2i
				for x in range(rect.position.x, rect.end.x):
					if alt:  # Make exterior walls
						coord1 = Vector2i(x,rect.position.y - 1)
						coord2 = Vector2i(Vector2i(x,rect.end.y))
						me.set_tile_asset(coord1, Vector2i.DOWN)
						me.set_tile_asset(coord2, Vector2i.UP)
					else:  # Make interior walls
						coord1 = Vector2i(x,rect.position.y)
						coord2 = Vector2i(x,rect.end.y - 1)
						me.set_tile_asset(coord1, Vector2i.UP)
						me.set_tile_asset(coord2, Vector2i.DOWN)
					queue_update(coord1)
					queue_update(coord2)
				
				for y in range(rect.position.y, rect.end.y):
					if alt:  # Make exterior walls
						coord1 = Vector2i(rect.position.x - 1, y)
						coord2 = Vector2i(rect.end.x, y)
						me.set_tile_asset(coord1, Vector2i.RIGHT)
						me.set_tile_asset(coord2, Vector2i.LEFT)
					else:  # Make interior walls
						coord1 = Vector2i(rect.position.x, y)
						coord2 = Vector2i(rect.end.x - 1, y)
						me.set_tile_asset(coord1, Vector2i.LEFT)
						me.set_tile_asset(coord2, Vector2i.RIGHT)
					queue_update(coord1)
					queue_update(coord2)
		return super(alt)
	
	func right_release(alt:bool):
		if not me.camera_moved:
			match me.pallet.get_paint_tool():
				"Area":
					var rect = me.get_map_rect(me.map_start_tile, me.map_hover_tile, true)
					rect = rect.intersection(Rect2i(Vector2i.ZERO, me.curr_map.size))
					for y in range(rect.position.y, rect.end.y):
						for x in range(rect.position.x, rect.end.x):
							var coord = Vector2i(x,y)
							me.rem_tile_asset(coord)
							queue_update(coord)
		return super(alt)
	
	func draw_dragging(canvas:Control, cam:Camera3D):
		if not area_polygon.is_empty():
			me.draw_area_outline(canvas, area_polygon, Color.WHEAT, 6)

class Tall_Wall_Mode extends Wall_Mode:
	pass
class Half_Wall_Mode extends Wall_Mode:
	pass
class Crawl_Wall_Mode extends Wall_Mode:
	pass

class Spawner_Mode extends TacEditorState:
	var spawner_copy : TacEntitySpawner
	
	func help() -> String:
		return "Left-click anywhere to set the starting position of characters. Clicking on an existing spawn point removes it."
	
	func enter():
		me.pallet.force_paint_tool(&"Single")
	
	func left_release(alt:bool):
		if me.map_hover_tile in me.curr_map.spawners:
			me.curr_map.rem_spawner(me.map_hover_tile)
		else:
			var spawner_class = me.pallet.get_spawner()
			var spawner : TacEntitySpawner
			if not spawner_copy == null and spawner_copy.display_name() == spawner_class:
				spawner = spawner_copy.duplicate_deep()
			else:
				spawner = Tac.spawners[spawner_class].new()
			spawner.orientation = Tac.DIR_VEC.values().find(me.hover_tile_side)
			me.curr_map.add_spawner(me.map_hover_tile, spawner)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func pick_tool(alternate:bool):
		if me.map_hover_tile in me.curr_map.spawners:
			spawner_copy = me.curr_map.spawners[me.map_hover_tile]
			me.pallet.show_spawner_copy(spawner_copy)
		return EditorPlugin.AFTER_GUI_INPUT_STOP

class Coord_Capture extends TacEditorState:
	func help() -> String:
		return "Clicking on the map returns a tile's information. You may then select and copy from text fields."
	func enter():
		me.pallet.force_paint_tool(&"Single")
	
	func left_release(alternate:bool):
		var hover_tile_nav = me.curr_nav.map2nav(me.map_hover_tile, me.curr_map)
		var coordi = Vector3i(me.hover_tile.x, me.curr_map.get_layer(), me.hover_tile.y)
		me.pallet.set_tile_info(
			me.hover_tile,
			hover_tile_nav,
			me.map_hover_tile,
			me.curr_nav.navproxy.get(coordi),
			me.curr_map.tiles.get(me.map_hover_tile))
		return EditorPlugin.AFTER_GUI_INPUT_STOP
