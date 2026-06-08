extends TacCharacter
class_name BaseTacCharacter

@export var info : CharacterID
# The functions in CharacterID are defaults.
# These functions here can be overridden for different results.
func get_proper_name():
	return info.get_proper_name()
func get_alias():
	return info.get_alias()

@export var rank : int

@export_group("Stats")
@export var max_health : int
@export var max_stamina : int
@export var max_mental : int
@export var max_spritilo : int
@export var max_ectoplasm : int

@export var appeal : int  ## Charisma
@export var speed : int  ## Movement
@export var will : int  ## Determination

var health : int
var stamina : int
var mental : int
var spritilo : int
var ectoplasm : int


func _ready():
	super()
	interact_action = &"interact"
	command_action = &"command"
	collision_layer = Con.phys_layer["tac_entity"]
