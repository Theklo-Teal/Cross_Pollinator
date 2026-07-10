extends CharaState
class_name CharaAction

enum SLOT {
	NONE,
	PRIM,
	SECO,
	UPPER,
	LOWER,
	DPLOY,
	OTHER,
	}

var slot := SLOT.NONE

var stamina_cost : int = 1

func enter(prev:CharaState):
	me.stamina = clamp(me.stamina - stamina_cost, 0, me.max_stamina)

## Is this action available given a character's context?
func can_use() -> bool:
	return me.attitude != Character.ATT.FLYING and me.approach != Character.APPR.PANIC

## Return the list of characters target by this action.
func targets() -> Array[Character]:
	return Ses.player

## Return a value from 0 to 1 about the confidence of whether an NPC should use this action.
func utility_score() -> float:
	return 0.5
