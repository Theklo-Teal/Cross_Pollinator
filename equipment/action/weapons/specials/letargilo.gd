extends "res://equipment/action/weapons/projectile.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 448)
	title = "Letargilo"
	description = "Formally codenamed 'Ghostbuster' by the Warehouse, but Seigro insists using a different name. It uses dense pellets of ectoplasm as ammunition and will overwhelm the special senses of Agarthians. To anyone else, it's just ice cold."
	slot = SLOT.SECO
