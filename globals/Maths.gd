extends Node

## Return a list of the grid coordinates surrounding the given cell.
## Optionally, rotates the list to have the cell at a certain direction as the first element.
static func adjacent_cells(center : Vector2i, first_cardinal:int=0, include_diagonal:=true) -> Array[Vector2i]:
	const cardinals = [
		Vector2i(0,-1),  # North
		Vector2i(-1,-1),  # NW
		Vector2i(-1,0),  # West
		Vector2i(-1,1),  # SW
		Vector2i(0,1),  # South
		Vector2i(1,1),  # SE
		Vector2i(1,0),  # East
		Vector2i(1,-1),  # NE
	]
	
	var rotated_list : Array[Vector2i]
	for n in range(cardinals.size()):
		if include_diagonal or n % 2 == 0:
			rotated_list.append( cardinals[(n + first_cardinal) % 8] + center )
	
	return rotated_list

## Find grid coordinates which are adjacent to a given tile.
## It can take several tiles, as if contouring the shape produced.
## Optionally, include a list of tiles allowed to be returned, as a boundary.
static func contour_shape(shape : Array[Vector2i], boundary : Array[Vector2i] = []) -> Array[Vector2i]:
	var contour : Array[Vector2i]
	for coord in shape:
		for adjacent in adjacent_cells(coord):
			var rules = [
				adjacent in shape,
				adjacent in contour,
				not ( adjacent in boundary or boundary.is_empty() ),  # If the boundary is empty, we ignore that feature.
				]
			if true in rules:  # The rules exclude coordinates from the solution.
				continue
			else:
				contour.append(adjacent)
	return contour
