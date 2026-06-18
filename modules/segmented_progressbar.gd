@tool
extends Control
class_name SegmentedProgressBar

## A Progress bar which displays StyleBox resources as segments. It only deals with
## integers unlike other progress bars.[br]
## StyleBoxes can be used to show textures, allowing for a custom look to segments.

signal value_changed(value:int)

@export_enum("To Right", "To Left", "Downwards", "Upwards") var direction : int : 
	set(val):
		direction = val
		_dirty = true
		queue_redraw()

@export var under : StyleBox :  ## The visual look of a background.
	set(val):
		queue_redraw()
		under = val
		if not under == null and is_node_ready():
			under.changed.connect(func():queue_redraw())

@export var over : StyleBox :  ## The visual look of something in front of the segments.
	set(val):
		queue_redraw()
		over = val
		if not over == null and is_node_ready():
			over.changed.connect(func():queue_redraw())

@export var segment : StyleBox :  ## The visual look of an empty segment.
	set(val):
		queue_redraw()
		segment = val
		if not segment == null and is_node_ready():
			segment.changed.connect(func():queue_redraw())
@export var progress : StyleBox :  ## The visual look of a filled segment.
	set(val):
		queue_redraw()
		progress = val
		if not progress == null and is_node_ready():
			progress.changed.connect(func():queue_redraw())

@export var spacing : int = 3 : 
	set(val):
		spacing = max(0, val)
		_dirty = true
		queue_redraw()

@export var max_value : int = 6 : 
	set(val):
		max_value = max(1, val)
		_dirty = true
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

var _dirty := true
func _recalculate():
	_dirty = false
	value = clamp(value, 0, max_value)
	_segm_thick = (size[int(direction > 1)] + spacing) / max_value - spacing
	spacing = clamp(spacing, 0, _segm_thick)

var _segm_thick : float

func _draw() -> void:
	if _dirty:
		_recalculate()
	
	if under != null:
		draw_style_box(under, get_rect())
	
	if progress != null:
		[draw_toright, draw_toleft, draw_downwards, draw_upwards][direction].call()
	
	if over != null:
		draw_style_box(over, get_rect())

func draw_toright():
	var rect := Rect2(Vector2.ZERO, Vector2(_segm_thick, size.y))
	for i in range(max_value):
		rect.position.x = i * (_segm_thick + spacing)
		if i < value:
			draw_style_box(progress, rect)
		elif segment != null:
			draw_style_box(segment, rect)
func draw_toleft():
	var rect := Rect2(Vector2.ZERO, Vector2(_segm_thick, size.y))
	for i in range(max_value -1, -1, -1):
		rect.position.x = i * (_segm_thick + spacing)
		if i >= max_value - value:
			draw_style_box(progress, rect)
		elif segment != null:
			draw_style_box(segment, rect)
func draw_downwards():
	var rect := Rect2(Vector2.ZERO, Vector2(size.x, _segm_thick))
	for i in range(max_value):
		rect.position.y = i * (_segm_thick + spacing)
		if i < value:
			draw_style_box(progress, rect)
		elif segment != null:
			draw_style_box(segment, rect)
func draw_upwards():
	var rect := Rect2(Vector2.ZERO, Vector2(size.x, _segm_thick))
	for i in range(max_value -1, -1, -1):
		rect.position.y = i * (_segm_thick + spacing)
		if i >= max_value - value:
			draw_style_box(progress, rect)
		elif segment != null:
			draw_style_box(segment, rect)
