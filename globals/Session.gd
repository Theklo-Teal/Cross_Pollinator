extends Node

## Global data about a play session.
var scenario : ScenarioDirector
var selected_action : CharaAction

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
