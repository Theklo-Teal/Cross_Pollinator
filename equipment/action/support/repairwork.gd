extends CharaAction

func _init() -> void:
	noteworthy = true
	icon = preload("res://equipment/action_icons.tres")
	icon.region.position = Vector2(0, 0)
	title = "Telekinesis"
	description = "With the use of Agarthian darts, they can manipulate distant objects for small window of time."
