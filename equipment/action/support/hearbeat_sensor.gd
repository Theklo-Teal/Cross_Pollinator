extends CharaAction

func _init() -> void:
	noteworthy = true
	icon = preload("res://equipment/action_icons.tres")
	icon.region.position = Vector2(0, 0)
	title = "Heartbeat Locator"
	description = "And advanced acoustic device tuned to the particular hearbeat of humans and tell their proximity. Particularly effective with Agarthians due their overly complicated hearts."
