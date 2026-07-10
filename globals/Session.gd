extends Node

## Global data about a play session.
var scenario : ScenarioDirector
var player : Array[Character]
var robots : Array[Character]  ## Characters other than player characters.
var player_centroid : Dictionary[int, Vector2i]  ## [tacnav_layer] -> average position of player character in that layer.

#WARNING getting values from ConfigFile will return a reference, if a data type
# is passed by reference (like Array or Dictionary), so modifying the returned
# value will also modify the contents of the ConfigFile. Use `duplicate()`!
var save_filename : String
var save := ConfigFile.new()

func _ready() -> void:
	if not DirAccess.dir_exists_absolute("user://savedata/"):
		DirAccess.make_dir_absolute("user://savedata/")
	
	save_filename = Con.sett.get_value("user", "last_save", "")
	if save_filename.is_empty() or not FileAccess.file_exists(save_filename):
		save_filename = "user://savedata/" + Time.get_date_string_from_system()+".toml"
		DirAccess.copy_absolute("res://savedata/session.toml", save_filename)
	save.load(save_filename)

func _exit_tree() -> void:
	save.save(save_filename)


func pausing(to_pause:bool):
	if not get_tree().paused and to_pause:
		scenario.switch_state_of.call_deferred(&"pause")
	elif scenario.stt == scenario.states[&"pause"]:
		scenario.switch_state(scenario.stt.interrupted)
