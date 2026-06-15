extends "res://equipment/action/handgun.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 320)
	description = "A special weapon designed specially for self-defense of divers. The barrel and ammunition are single replaceable unit. As it fires fine above water too and is inherently silent, this model is loaded with fast acting toxins for elimination of sentries in stealth operations."
