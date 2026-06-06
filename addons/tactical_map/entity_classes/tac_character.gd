extends TacEntity
class_name TacCharacter

## A state machine manager for characters placed by a TacNav node. Each state is a character's action.

enum ATT{
	WARY,  ## Character is careful and avoids vaulting over small obstacles.
	TINY,  ## The Character is small enough to enter cramped spaces.
	HASTY,  ## The Character will be aggressive, trying to swiftly find the shortest distance physically possible.
	UNTOUCH,  ## The Character doesn't care about obstacles or might even be intangible.
	FLYING,  ## (Don't Use: Tentative feature) The character can travel through holes in the floor, changing level.
	}

enum Team{
	PLAYER, ## Player controlled character
	ALLY,  ## Characters with same objective as player, but not controllable.
	HOSTILE,  ## NPCs that actively target Player characters.
	NEUTRAL,  ## NPCs that avoid combat. Will flee if attacked.
	AGGRO,  ## NPCs that avoid combat, but will retaliate if hurt.
}

@export var team : Team  ## Default alliance of character.
@export var attitude : ATT  ## How the character navigates the environment.

@export_group("Actions")
@export var actions : Array[StringName]

func _ready():
	# Setup state machine.
	states[&"idle"] = Tac.actions.idle.new(self)
	states[&"walk"] = Tac.actions.walk.new(self)
	for each in actions:
		Tac.actions[each].new(self)
	stt.append(states[&"idle"])


var is_busy : bool = false
var stt : Array[CharaAction]  ## State stack. Current state is at the back.
var states : Dictionary[StringName, CharaAction]
func switch_state(next_state:StringName = &""):
	var prev : CharaAction
	var next : CharaAction
	if next_state.is_empty():
		prev = stt.pop_back()
		next = stt.back()
	else:
		assert(next_state in states, "switch_state(): Not a valid state.")
		prev = stt.back()
		next = states[next_state]
		stt.push_back(next)
	if stt.size() >= Con.MAX_STT:
		stt = stt.slice(-Con.MAX_STT, )
	prev.exit(next)
	next.enter(prev)

## Override this if the character responds to a certain TacMap zone in a particular way.
func entered_zone(_zone:String):
	pass
## Override this if the character responds to a certain TacMap zone in a particular way.
func exited_zone(_zone:String):
	pass

func _process(delta: float) -> void:
	stt.back().process(delta)
func _unhandled_input(event: InputEvent) -> void:
	stt.back().input(event)

## Initiate action from external callers
func enact(act : StringName) -> void:
	switch_state(act)
