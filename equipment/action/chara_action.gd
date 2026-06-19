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

## Is this action available given a character's context?
func can_use() -> bool:
	return me.attitude != Character.ATT.FLYING and me.approach != Character.APPR.PANIC

## Return a value from 0 to 1 about the confidence of whether an NPC should use this action.
func utility_score() -> float:
	return 0.5
