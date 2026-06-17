extends "res://equipment/action/handgun.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 320)
	title = "Seigro's Invention"
	description = "The smart goo processed through the Miracle Machine can be rigid enough to form into a functional firearm. This \"goo gun\" produces its own amunition from the user's blood and its fire rate depends on the emotional intensity of the user."
