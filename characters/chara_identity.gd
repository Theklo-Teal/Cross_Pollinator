extends Resource
class_name CharacterID

## Here lies default information and flavor lore about the character.

enum SEX{
	RANDOM,
	NONE,
	MALE,
	FEMALE,
	UNISEX
	}

enum BLOOD{
	RANDOM = 	0b11111,
	NONE = 		0b00000,
	A =	 		0b00001,
	B =	 		0b00010,
	AB = 		0b00011,
	O = 		0b00100,
	POS = 		0b01000,
	NEG = 		0b10000,
	APOS = 		0b01001,
	BPOS = 		0b01010,
	ABPOS = 	0b01011,
	OPOS = 		0b01100,
	ANEG = 		0b10001,
	BNEG = 		0b10010,
	ABNEG = 	0b10011,
	ONEG = 		0b10100
	}

@export var portrait : Texture2D = preload("res://addons/tactical_map/assets/chad_wojak.png")

@export var codename : String = "Boogie"  ## Name assigned by the enemies.
@export var proper_name : Array[String] = ["Moe Howard", "Larry Fine", "Shemp Howard"] :  ## Options for the teal name of the character.
	set(val):
		if proper_name.is_empty():
			proper_name = ["Moe Howard"]
		if val.is_empty():
			proper_name.resize(1)
		else:
			proper_name = val

@export var alias : Array[String] = ["Solid Snake", "Liquid Snake", "Naked Snake"] :  ## Options for the name used internally by their team.
	set(val):
		if alias.is_empty():
			alias = ["Solid Snake"]
		if val.is_empty():
			alias.resize(1)
		else:
			alias = val

@export var sex : SEX
@export var blood : BLOOD
@export_multiline() var flavor : String
@export var likes : PackedStringArray
@export var hates : PackedStringArray
@export var hobbies : PackedStringArray

var perks : Array[Status]  ## Effects natural to the character
var bonus : Array[Status]  ## Effect conferred by equipment
var ailment : Array[Status]  ## Effect caused during combat

func get_proper_name() -> String:
	return proper_name.pick_random()

func get_alias() -> String:
	return alias.pick_random()

func get_sex():
	if sex == SEX.RANDOM:
		return SEX.keys().pick_random()

func get_blood():
	if blood == BLOOD.RANDOM:
		return BLOOD.keys().pick_random()
