extends Node

## Global data about a play session.

var hover_nav : TacNav
var hover_map : TacMap
var hover_tile : Vector2i  # TacNav relative coordinate
var hover_chara : TacCharacter
var select_chara : Character :
	set(val):
		if val.curr_team == TacCharacter.Team.PLAYER:
			select_chara = val
			get_tree().call_group("observer_character_select", "_on_character_selected", val)

var save_file : String
var save := ConfigFile.new()

func _ready() -> void:
	if not DirAccess.dir_exists_absolute("user://savedata/"):
		DirAccess.make_dir_absolute("user://savedata/")
	
	save_file = Con.sett.get_value("user", "last_save", "")
	if save_file.is_empty() or not FileAccess.file_exists(save_file):
		save_file = "user://savedata/" + Time.get_date_string_from_system()+".toml"
		DirAccess.copy_absolute("res://savedata/session.toml", save_file)
	save.load(save_file)

func _exit_tree() -> void:
	save.save(save_file)
