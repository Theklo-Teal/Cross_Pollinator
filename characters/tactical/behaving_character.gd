extends BaseTacCharacter
class_name Character

## Extending TacCharacter with behaviors using Utility AI to determinate the actions
## of Non-Player Characters.[br]
## Player Characters also have AI because it enables automatic actions,
## status effects taking control from the player, or
## mind-control or defaction type abilities.[br]
## Extend this script and override functions to give unique behaviors to particular
## characters or according to different game rules.
## There are 3 stages:[br]
## [ol]
## [li]Find coordinates the character can go to. Affected by [code]attitude[/code].[/li]
## [li]Use a Markov Chain to decide the [code]approach[/code].[/li]
## [li]Pick actions according to approach and score their utility according to position.[/li]
## [/ol]

enum APPR{
	DEFENCE,
	OFFENSE,
	RETREAT,
	PANIC
}

var approach : APPR

class Decision:
	var path : Array[Vector2i]
	var act : String
	var score : float
	func _init(movement:Array[Vector2i]):
		path = movement

var options : Array[Decision]

## Which coordinates can the character move to.
func movement_options() -> Array[Decision]:
	var opts : Array[Decision] = [Decision.new([Vector2i.ZERO])]  ## Assume not changing position as option.
	
	return opts

## Find the utility score of moving.
func movement_score(path: Array[Vector2i]) -> float:
	return (path.size() - 1) / float(stamina)

func decision_score(movement:Array[Vector2i], _action:String) -> float:
	return movement_score(movement) * 1.0

## Returns value from 0 to 1 of how endangered or fearful a character is.
func threat_score() -> float:
	return 0.5

## Evaluate the possible decisions, score them by utility, then return info about
## the results.
func assess_options() -> Dictionary:
	options.clear()
	var assessment : Dictionary[String, int] = {"max_score":0, "min_score":0}
	
	# Markov Functions
	var chance = randf()
	var threat = threat_score()
	var courage = 0.6  # Take values from character stats: Will * Mental
	if threat > courage:
		approach = APPR.PANIC
	elif chance > courage:
		approach = APPR.RETREAT
	elif chance > threat:
		approach = APPR.DEFENCE
	elif chance < threat:
		approach = APPR.OFFENSE
	
	#TODO couple approach to the actions available
	 
	# Utility Functions
	#for option : Decision in movement_options():
		#for act in actions:
			#option.act = act.title
			#option.score = decision_score(option.path, act.title)
			#assessment["max_score"] = max(assessment["max_score"], option.total_score)
			#assessment["min_score"] = min(assessment["min_score"], option.total_score)
		
	return assessment

## Decide which of the options to pick.
func take_decision() -> Decision:
	if not options.is_empty():
		return options.back()
	else:
		return Decision.new([Vector2i.ZERO])

## Automatically take action.
func perform_action(_decision: Decision):
	pass


#region
var enemy_spotted : Dictionary[TacCharacter, Vector2i]  ## Remember which enemies were detected and where.

func can_see(_chara:TacCharacter) -> bool:
	## Is the "chara" in range and line of sight of this character?
	#NOTE This assumes both this character the "chara" are in the same TacMap.
	if "Blinded_Ailment" in info.ailment:
		return false
	if "Conceal_Bonus" in info.perks: #and not chara.is_in_group(team):
		return false
	return true
#endregion
