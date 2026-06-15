extends "res://equipment/action/projectile.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 448)
	title = "Ekprovo"
	description = "This is the weapon yielded by Agarthian robots and vehicles. It can be used by hand, but ergonomics are dubious and kicks really hard, amusingly nicknamed \"Agony\". It functions in \"hyper-burst\" by chambering three superimposed cartridges that at the same time that ignite sequentially even before recoil is felt by the user."
