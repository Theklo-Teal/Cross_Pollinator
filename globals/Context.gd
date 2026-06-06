extends Node

const RENEW_SETT = true
const MAX_STT = 256  # How many past states to record in a state machine.

var statuses : Dictionary[StringName, Status]
var phys_layer : Dictionary[StringName, int]
var sett := ConfigFile.new()

func _ready() -> void:
	if not FileAccess.file_exists("user://savedata/settings.cfg") or RENEW_SETT:
		DirAccess.copy_absolute("res://savedata/settings.cfg", "user://savedata/settings.cfg")
	sett.load("user://savedata/settings.cfg")
	
	for n in range(1, 33):
		var layer : String = ProjectSettings.get_setting("layer_names/3d_physics/layer_"+str(n))
		if not layer.is_empty():
			phys_layer[layer] = int(pow(2, n - 1))
	
	for file in DirAccess.get_files_at("res://equipment/status/"):
		if file.get_extension() == "gd":
			statuses[file.get_basename()] = load("res://equipment/status/"+file).new()

func _exit_tree() -> void:
	sett.save("user://savedata/settings.cfg")
