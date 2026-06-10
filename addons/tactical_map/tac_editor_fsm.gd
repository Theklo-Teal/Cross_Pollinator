@tool
extends EditorPlugin

#TODO Undo/Redo
#TODO Flood Fill
#TODO Enable Picker Tool
#TODO Ladders
#TODO Tags for searching assets and the filter input

#NOTE How to use undo_redo
	##undo_redo.create_action("TacMap: set floor tiles")
	##undo_redo.add_do_property()
	##undo_redo.add_undo_property()
	##undo_redo.commit_action()

#region Boilerplate
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

func _on_state_changed(mode:StringName):
	if not mode.is_empty():
		modes[mode].enter()
		pallet.set_help(modes[curr_mode()].help())

func _on_paint_tool_changed(tool:StringName):
	if not tool.is_empty():
		pallet.set_help(modes[curr_mode()].help())

@abstract class TacEditorState:
	var me : TacticalMapEditor
	
	func _init(manager:TacticalMapEditor):
		me = manager
	
	func help() -> String:
		return ""
	
	func enter():
		# Enable all tools
		me.pallet.force_paint_tool(&"Single", &"Area", &"Flood")
	
	## Given tiles, get an area contained by the current TacMap.
	## By default assumes Map coordinate system, but alternatively does Global space.
	func get_map_area(from:Vector2i, to:Vector2i, map_space:=true) -> Rect2i:
		var rect := Rect2i(from, Vector2i.ZERO)
		rect.end = to
		rect = rect.abs().grow_individual(0,0,1,1)
		return rect.intersection([me.curr_map.global_area, Rect2i(Vector2i.ZERO, me.curr_map.size)][int(map_space)])
	
	func input(event:InputEvent):
		var alternate = Input.is_key_pressed(KEY_CTRL)

		if event is InputEventMouseMotion and me.is_dragging:
			var left_button = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			var right_button = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
			return while_dragging(alternate, left_button, right_button)
		
		if event is InputEventMouseButton:
			if event.is_pressed():
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						return left_press(alternate)
					MOUSE_BUTTON_RIGHT:
						return right_press(alternate)
			elif event.is_released() and not me.camera_moved:
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						return left_release(alternate)
					MOUSE_BUTTON_RIGHT:
						return right_release(alternate)
					MOUSE_BUTTON_MIDDLE:
						if me.within_map:
							return pick_tool(alternate)
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
	
	func draw(canvas:Control):
		pass

class Paint_Mode extends TacEditorState:
	var area_polygon : PackedVector2Array  # The highlighted area as the mouse drags.
	var last_placed : Vector2i  # Remember last affected tile, avoiding it constantly changing while the mouse button is held.
	var has_placed : bool = false  # Whether to acknowledge «last_placed»
	
	## Finding all tiles according to breadth-first search.
	## For flood-fill tool implementations.[br]
	## Define what to cover in the search with a Callable in «searcher».
	func flood_find(origin:Vector2i, searcher:Callable=pick_target) -> Array[Vector2i]:
		#TODO Is «origin» this supposed to be nav coords or map coords?
		var src_tgt = searcher.call(origin)
		var map_area = Rect2i(Vector2i.ZERO, me.curr_map.size)
		var hits : Array[Vector2i]
		var checked : Array[Vector2i]
		var found : Array[Vector2i]
		for dir in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var adja = origin + dir
			if map_area.has_point(adja):
				found.append(adja)
		while not found.is_empty():
			var coordi = found.pop_back()
			var content = pick_target(coordi)
			if searcher.call(content) == src_tgt:
				hits.append(coordi)
			for dir in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
				var adja = origin + dir
				if not (adja in found or adja in checked) and map_area.has_point(adja):
					found.push_front(adja)
		return hits
	
	## Returns what on a tile is of interest for the picker tool or flood-fill tool.
	## If not overriden returns the transition code.
	func pick_target(tile:TacTile) -> Variant:
		var dir = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP].find(me.hover_tile_side)
		var adja = me.curr_map.tiles.get(me.map_hover_tile + me.hover_tile_side)
		return tile.get_transition(dir, adja)
		
	
	func while_dragging(alt:bool, left, right):
		me.update_overlays()
	
	func left_press(alternate:bool):
		if me.within_map:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func right_press(alternate:bool):
		if me.within_map:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func left_release(alt:bool):
		if not area_polygon.is_empty():
			area_polygon.clear()
			me.update_overlays()
		if me.is_dragging:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	func right_release(alt:bool):
		if not area_polygon.is_empty():
			area_polygon.clear()
			me.update_overlays()
		if me.is_dragging:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func draw(canvas:Control):
		if me.is_dragging and me.pallet.get_paint_tool() == "Area":
			var hei = me.curr_map.get_spatial_height() + 0.1
			var area := get_map_area(me.start_tile, me.hover_tile, false)
			var start = Vector3(area.position.x, hei, area.position.y)
			var stop = Vector3(area.end.x, hei, area.end.y)
			area_polygon =  [
				me.cam.unproject_position(start),
				me.cam.unproject_position(Vector3(stop.x, hei, start.z)),
				me.cam.unproject_position(stop),
				me.cam.unproject_position(Vector3(start.x, hei, stop.z)),
				me.cam.unproject_position(start),
				]
			return EditorPlugin.AFTER_GUI_INPUT_STOP

class Zone_Mode extends Paint_Mode:
	func help() -> String:
		return "Tiles contained by a zone will trigger events when characters step on them or out of them.\nType a zone title, then drag on map to create a new zone. Clicking zones from the list highlights them on the map.\nSubmitting a title renames the last clicked zone. Submitting an empty title deletes the last clicked zone."
	
	func enter():
		me.pallet.force_paint_tool(&"Area")
		me.update_overlays()
	
	func while_dragging(alt:bool, left, right):
		if not right:
			super(alt, left, right)
	
	func left_release(alt:bool):
		var zone_name = me.pallet.on_add_zone(me.curr_map.zones.keys())
		if not zone_name.is_empty():
			me.curr_map.zones[zone_name] = Rect2i(me.map_start_tile, Vector2i.ONE)
			me.curr_map.zones[zone_name].end = me.map_hover_tile
			me.curr_map.zones[zone_name] = me.curr_map.zones[zone_name].abs()
			me.sel_zones.append(zone_name)
		return super(alt)
	
	func pick_tool(alt:bool):  #TODO Test this
		var hits : PackedStringArray
		for each in me.curr_map.zones:
			var zone_rect : Rect2i = me.curr_map.zones[each]
			if zone_rect.has_point(me.hover_tile):
				hits.append(each)
		if hits.is_empty():
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		else:
			me.pallet.select_zones(hits)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func draw(canvas:Control):
		super(canvas)
		if not area_polygon.is_empty():
			var color = Color.DARK_SLATE_GRAY
			color.a = 0.4
			canvas.draw_colored_polygon(area_polygon, color)
			canvas.draw_polyline(area_polygon, Color.SEA_GREEN, 3)
		
		var hei = me.curr_map.get_height() + 0.1
		for zone in me.sel_zones:
			var rect = me.curr_map.zones[zone]
			var area := get_map_area(
				me.curr_nav.map2spatial_tile(rect.position, me.curr_map),
				me.curr_nav.map2spatial_tile(rect.end, me.curr_map),
				)
			var start = Vector3(area.position.x, hei, area.position.y)
			var stop = Vector3(area.end.x, hei, area.end.y)
			var zone_polygon =  [
				me.cam.unproject_position(start),
				me.cam.unproject_position(Vector3(stop.x, hei, start.z)),
				me.cam.unproject_position(stop),
				me.cam.unproject_position(Vector3(start.x, hei, stop.z)),
				me.cam.unproject_position(start),
				]
			if zone == me.pallet.last_sel_zone:
				var fill = Color.WEB_GREEN
				fill.a = 0.4
				canvas.draw_colored_polygon(zone_polygon, fill)
				canvas.draw_polyline(zone_polygon, Color.WEB_GREEN, 3)
			else:
				var fill = Color.DIM_GRAY
				fill.a = 0.4
				canvas.draw_colored_polygon(zone_polygon, fill)
				canvas.draw_polyline(zone_polygon, Color.DIM_GRAY, 3)

class Ladder_Mode extends Paint_Mode:
	func help() -> String:
		return "connects tiles of the same ladder title in maps of different layers allowing characters move between them. Can't have the same ladder title more than once on each map. \nType a ladder title, then click on map to create a warp tile. Clicking ladders from the list highlights them on the map.\nSubmitting a title renames the last clicked ladder. Submitting an empty title deletes the last clicked ladder."
	func enter():
		me.pallet.force_paint_tool(&"Single")
		me.update_overlays()
	
	func left_release(alt:bool):
		if me.within_map:
			var ladder_name = me.pallet.on_add_ladder(me.curr_map.ladders.keys())
			if not ladder_name.is_empty():
				me.curr_map.ladders[ladder_name] = me.map_hover_tile
				me.sel_ladders.append(ladder_name)
				me.update_overlays()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func draw(canvas:Control):
		var hei = me.curr_map.get_height() + 0.1
		for ladder in me.sel_ladders:
			var area := Rect2i( me.curr_map.ladders[ladder], Vector2i.ONE )
			var start = Vector3(area.position.x, hei, area.position.y)
			var stop = Vector3(area.end.x, hei, area.end.y)
			var ladder_polygon =  [
				me.cam.unproject_position(start),
				me.cam.unproject_position(Vector3(stop.x, hei, start.z)),
				me.cam.unproject_position(stop),
				me.cam.unproject_position(Vector3(start.x, hei, stop.z)),
				me.cam.unproject_position(start),
				]
			if ladder == me.pallet.last_sel_ladder:
				var fill = Color.DARK_KHAKI
				fill.a = 0.4
				canvas.draw_colored_polygon(ladder_polygon, fill)
				canvas.draw_polyline(ladder_polygon, Color.KHAKI, 3)
			else:
				var fill = Color.DIM_GRAY
				fill.a = 0.4
				canvas.draw_colored_polygon(ladder_polygon, fill)
				canvas.draw_polyline(ladder_polygon, Color.DIM_GRAY, 3)

class Floor_Mode extends Paint_Mode:
	func help() -> String:
		const which = {
			"Single": "Tiles are set under the mouse while the left button is held.",
			"Area": "All tiles within the area will be set.",
			}
		return which.get(me.pallet.get_paint_tool()) + " Right-click to remove, Right-click and CTRL to set whether tiles are walkable if needed.\nIf CTRL is held, the floors become ceilings. The tiles will be oriented depending on the side of the first tile pressed."
	
	func while_dragging(alt:bool, left, right):
		super(alt, left, right)
		match me.pallet.get_paint_tool():
			"Single":
				if has_placed == false or (last_placed != me.map_hover_tile):
					has_placed = true
					last_placed = me.map_hover_tile
					if left:
						me.set_tile_asset(me.map_hover_tile, me.hover_tile_side)
						if alt:
							var tile : TacTile = me.curr_map.tiles.get(me.hover_tile)
							tile.is_ceiling = not tile.is_ceiling
					if right:
						if alt:
							var tile : TacTile = me.curr_map.tiles.get_or_add(me.map_hover_tile, TacTile.new())
							tile.has_floor = not tile.has_floor
						else:
							me.rem_tile_asset(me.map_hover_tile, me.hover_tile_side)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func left_press(alt:bool):
		match me.pallet.get_paint_tool():
			"Single":
				if me.within_map:
					if has_placed == false or (last_placed != me.map_hover_tile):
						has_placed = true
						last_placed = me.map_hover_tile
						me.set_tile_asset(me.map_hover_tile, me.hover_tile_side)
						if alt:
							var tile : TacTile = me.curr_map.tiles.get(me.hover_tile)
							tile.is_ceiling = not tile.is_ceiling
		return super(alt)
	
	func right_press(alt:bool):
		match me.pallet.get_paint_tool():
			"Single":
				if me.within_map:
					if has_placed == false or (last_placed != me.map_hover_tile):
						if alt:
							var tile : TacTile = me.curr_map.tiles.get_or_add(me.map_hover_tile, TacTile.new())
							tile.has_floor = not tile.has_floor
						else:
							has_placed = true
							last_placed = me.map_hover_tile
							me.rem_tile_asset(me.map_hover_tile, me.hover_tile_side)
		return super(alt)
	
	func left_release(alt:bool):
		has_placed = false
		match me.pallet.get_paint_tool():
			"Area":
				var area = get_map_area(me.map_start_tile, me.map_hover_tile)
				for y in range(area.position.y, area.end.y):
					for x in range(area.position.x, area.end.x):
						var coord = Vector2i(x,y)
						me.set_tile_asset(coord, me.hover_tile_side)
						if alt:  # raise ceiling
							var tile : TacTile = me.curr_map.tiles.get(coord)
							tile.is_ceiling = not tile.is_ceiling
		return super(alt)
	
	func right_release(alt:bool):
		match me.pallet.get_paint_tool():
			"Area":
				var area = get_map_area(me.map_start_tile, me.map_hover_tile)
				for y in range(area.position.y, area.end.y):
					for x in range(area.position.x, area.end.x):
						var coord = Vector2i(x,y)
						if alt:
							var tile : TacTile = me.curr_map.tiles.get_or_add(me.map_hover_tile, TacTile.new())
							tile.has_floor = not tile.has_floor
						else:
							me.rem_tile_asset(coord)
		return super(alt)
	
	func pick_target(tile:TacTile):
		return tile.floor
	
	func pick_tool(alternate:bool):
		if me.within_map:
			var tile = me.curr_map.tiles.get(me.map_hover_tile)
			if tile == null:
				return
			var asset_uid = pick_target(tile)
			var info_uid = asset_uid  #FIXME
			me.pallet.set_active_asset(info_uid)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func draw(canvas:Control):
		super(canvas)
		if not area_polygon.is_empty():
			var color = Color.WHEAT
			color.a = 0.4
			canvas.draw_colored_polygon(area_polygon, color)
			canvas.draw_polyline(area_polygon, Color.BISQUE, 3)

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
		match me.pallet.get_paint_tool():
			"Single":
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
		match me.pallet.get_paint_tool():
			"Single":
				if me.within_map:
					if has_placed == false or (last_placed != me.map_hover_tile):
						has_placed = true
						last_placed = me.map_hover_tile
						me.set_tile_asset(me.map_hover_tile, me.hover_tile_side)
						if alt:
							var adja = me.map_hover_tile + me.hover_tile_side
							me.set_tile_asset(adja, me.hover_tile_side_opposite)
		return super(alt)
	
	func right_press(alt:bool):
		match me.pallet.get_paint_tool():
			"Single":
				if me.within_map:
					if has_placed == false or (last_placed != me.map_hover_tile):
						has_placed = true
						last_placed = me.map_hover_tile
						me.rem_tile_asset(me.map_hover_tile, me.hover_tile_side)
						if alt:
							me.rem_tile_asset(me.map_hover_tile + me.hover_tile_side, me.hover_tile_side_opposite)
		return super(alt)
	
	func left_release(alt:bool):
		has_placed = false
		match me.pallet.get_paint_tool():
			"Area":
				var area = get_map_area(me.map_start_tile, me.map_hover_tile)
				for x in range(area.position.x, area.end.x):
					if alt:  # Make exterior walls
						me.set_tile_asset(Vector2i(x,area.position.y - 1), Vector2i.DOWN)
						me.set_tile_asset(Vector2i(x,area.end.y), Vector2i.UP)
					else:  # Make interior walls
						me.set_tile_asset(Vector2i(x,area.position.y), Vector2i.UP)
						me.set_tile_asset(Vector2i(x,area.end.y - 1), Vector2i.DOWN)
				
				for y in range(area.position.y, area.end.y):
					if alt:  # Make exterior walls
						me.set_tile_asset(Vector2i(area.position.x - 1, y), Vector2i.RIGHT)
						me.set_tile_asset(Vector2i(area.end.x, y), Vector2i.LEFT)
					else:  # Make interior walls
						me.set_tile_asset(Vector2i(area.position.x, y), Vector2i.LEFT)
						me.set_tile_asset(Vector2i(area.end.x - 1, y), Vector2i.RIGHT)
		return super(alt)
	
	func right_release(alt:bool):
		has_placed = false
		match me.pallet.get_paint_tool():
			"Area":
				var area = get_map_area(me.map_start_tile, me.map_hover_tile)
				for y in range(area.position.y, area.end.y):
					for x in range(area.position.x, area.end.x):
						var coord = Vector2i(x,y)
						me.rem_tile_asset(coord)
		return super(alt)
	
	func draw(canvas:Control):
		super(canvas)
		if not area_polygon.is_empty():
			canvas.draw_polyline(area_polygon, Color.WHEAT, 6)

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
		if me.within_map:
			if me.map_hover_tile in me.curr_map.spawners:
				me.curr_map.rem_spawner(me.map_hover_tile)
			else:
				var spawner_class = me.pallet.get_spawner()
				var spawner : TacEntitySpawner
				if not spawner_copy == null and spawner_copy.display_name() == spawner_class:
					spawner = spawner_copy.duplicate_deep()
				else:
					spawner = Tac.spawners[spawner_class].new()
				me.curr_map.add_spawner(me.map_hover_tile, spawner)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	func pick_tool(alternate:bool):
		if me.within_map:
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
		if me.within_map:
			var hover_tile_nav = me.curr_nav.map2nav(me.map_hover_tile, me.curr_map)
			var coordi = Vector3i(me.hover_tile.x, me.curr_map.get_layer(), me.hover_tile.y)
			me.pallet.set_tile_info(
				hover_tile_nav,
				me.map_hover_tile,
				me.curr_nav.navproxy.get(coordi, {}),
				me.curr_map.tiles.get(me.map_hover_tile))
			return EditorPlugin.AFTER_GUI_INPUT_STOP
