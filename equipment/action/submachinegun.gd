extends "res://equipment/action/projectile.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 384)
	title = "Shrieker"
	description = "Compact and light weight, but still packing a punch. Faster target aquisition than long rifle, more ergonomic than a pistol. Uses large caliber pistol cartridges in an extended magazine."
