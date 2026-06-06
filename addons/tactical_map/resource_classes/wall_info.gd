extends Resource
class_name WallInfo

@export var name : StringName = "Wall"
@export var thumbnail : Texture2D
@export var tags : PackedStringArray
@export var transition : Tac.Trans  ## Defines which characters can cross this wall.
@export var see_thru : bool  ## Can a character see things through this wall? Eg. there's a window, it's jail bars or glass pane.

@export_group("Assets", "asset_")  ## UID of packed scene or 3D model
@export var asset_pillar : StringName  ## When connecting two perpendicular walls on adjacent tiles, making a convex corner.
# Common variants
@export var asset_single : StringName  ## Just one side.
@export var asset_corner : StringName  ## Concave corner, East-South or West-North, for example.
# When tile is at extremity of a wall, so thickness geometry is included:
@export var asset_single_cap : StringName
@export var asset_corner_cap : StringName
