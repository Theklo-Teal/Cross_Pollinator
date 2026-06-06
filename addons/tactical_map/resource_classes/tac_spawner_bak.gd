extends Resource


@export var min_amount : int :
	set(val):
		min_amount = max(1, val)
		max_amount = max(min_amount, max_amount)
@export var max_amount : int : 
	set(val):
		max_amount = max(min_amount, val)
@export var entities : Array[StringName]  ## UID of the PackedScene which extends TacEntity.
 
## Create character instances and the returns them associated to their tile coordinate.
func generate_characters(coord:Vector2i) -> Dictionary[TacEntity, Vector2i]:
	var ans : Dictionary[TacEntity, Vector2i]
	var amount = entities.size()
	var pack = Saliko.get_square_pack(amount)
	var id : int = -1
	for uid in entities:
		if ResourceUID.ensure_path(uid).is_empty():
			printerr("TacEntitySpawner: Invalid UID given in «entities»! UID: " + uid)
			continue
		id += 1
		var entity = load(uid).instantiate()
		var tile_coord : Vector2i = Saliko.get_grid_cell_coord(id, pack)
		ans[entity] = tile_coord
	return ans
