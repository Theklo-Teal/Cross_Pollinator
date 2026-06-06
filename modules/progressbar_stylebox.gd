@tool
extends Range
class_name StyleboxProgressBar

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
@export var progress : StyleBox : 
	set(val):
		queue_redraw()
		progress = val
		if not progress == null and is_node_ready():
			progress.changed.connect(func():queue_redraw())

var segm_thick : float

func _ready() -> void:
	value_changed.connect(func(): compute_segm())

func compute_segm():
	queue_redraw()
	segm_thick = max_value - min_value
	segm_thick = remap(step, 0, segm_thick, 0, size.x)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if not under == null:
		draw_style_box(under, rect)
	if not progress == null:
		var segm_rect := rect
		segm_rect.size.x = segm_thick
		draw_style_box(progress, segm_rect)
	if not over == null:
		draw_style_box(over, rect)
