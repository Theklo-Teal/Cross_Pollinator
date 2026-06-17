@tool
extends Control
class_name StyleboxProgressBar

signal value_changed(value:int)

@export_enum("To Right", "To Left", "Upwards", "Downwards") var direction : int : 
	set(val):
		direction = val
		queue_redraw()

@export var under : StyleBox : 
	set(val):
		queue_redraw()
		under = val
		if not under == null and is_node_ready():
			under.changed.connect(func():queue_redraw())
@export var over : StyleBox : 
	set(val):
		queue_redraw()
		over = val
		if not over == null and is_node_ready():
			over.changed.connect(func():queue_redraw())
@export var segment : StyleBox :
	set(val):
		queue_redraw()
		segment = val
		if not segment == null and is_node_ready():
			segment.changed.connect(func():queue_redraw())
@export var progress : StyleBox : 
	set(val):
		queue_redraw()
		progress = val
		if not progress == null and is_node_ready():
			progress.changed.connect(func():queue_redraw())

@export var max_value : int = 6 : 
	set(val):
		max_value = max(1, val)
		segm_thick = size.x / max_value - SPACING
		queue_redraw()

@export var value : int = 6 : set=_set_value

func _set_value(val):
	value = clamp(val, 0, max_value)
	queue_redraw()
	value_changed.emit(value)

func set_value_no_signal(val:int):
	set_block_signals(true)
	_set_value(true)
	set_block_signals(false)

const SPACING = 3
var segm_thick : float = 0

func _draw() -> void:
	if under != null:
		draw_style_box(under, get_rect())
	
	if progress != null:
		[draw_toright, draw_toleft, draw_upwards, draw_downwards][direction].call()
	
	if over != null:
		draw_style_box(over, get_rect())

func draw_toright():
	var rect := Rect2(Vector2.ZERO, Vector2(segm_thick, size.y))
	for i in range(max_value):
		rect.position.x = i * (segm_thick + SPACING)
		if i < value:
			draw_style_box(progress, rect)
		elif segment != null:
			draw_style_box(segment, rect)
func draw_toleft():
	var rect := Rect2(Vector2.ZERO, Vector2(segm_thick, size.y))
	for i in range(max_value -1, -1, -1):
		rect.position.x = i * (segm_thick + SPACING)
		if i >= max_value - value:
			draw_style_box(progress, rect)
		elif segment != null:
			draw_style_box(segment, rect)
func draw_upwards():
	var rect := Rect2(Vector2.ZERO, Vector2(segm_thick, size.y))
	for i in range(max_value -1, -1, -1):
		rect.position.y = i * (segm_thick + SPACING)
		if i > value:
			draw_style_box(progress, rect)
		elif segment != null:
			draw_style_box(segment, rect)
func draw_downwards():
	var rect := Rect2(Vector2.ZERO, Vector2(segm_thick, size.y))
	for i in range(max_value):
		rect.position.y = i * (segm_thick + SPACING)
		if i > value:
			draw_style_box(progress, rect)
		elif segment != null:
			draw_style_box(segment, rect)
