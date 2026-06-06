extends ScenarioDirector

## Rules for simple Tactical Combat. Switches turns between player and NPCs.

func setup_fsm():
	super()
	states["tactical"] = Tactical.new(self)
	states["player_turn"] = TacticalPlayer.new(self)
	states["robots_turn"] = TacticalNPC.new(self)

## Generic combat rules for turned-based tactics
class Tactical extends ScenarioState:
	var factions = ["player_turn", "robots_turn"]
	var last_turn : int = -1:
		set(val):
			last_turn = clampi(val, 0, factions.size())
	
	func _init(director:ScenarioDirector):
		super(director)
		#refuse_ui = []
		#keep_ui = []
		#set_ui()
	
	func enter(_prev:ScenarioState):
		last_turn += 1
		me.switch_state(factions[last_turn])


## Player's turn when in generic tactical combat.
class TacticalPlayer extends ScenarioState:
	func enter(_prev:ScenarioState):
		set_ui(true, "Tactical_Player")
	
	func input(event):
		if event is InputEventAction:
			if event.is_action_released("command"):
				print(Ses.select_chara.get_proper_name(), " has been issued a command!")

## NPC's turn when in generic tactical combat.
class TacticalNPC extends ScenarioState:
	func enter(_prev:ScenarioState):
		set_ui(false, "Tactical_Player")
