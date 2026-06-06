extends CharaAction

func store_history() -> bool:
	return false
func enter(_prev:CharaAction):
	me.is_busy = false
	me.idle_enter()
func input(event:InputEvent):
	if event.is_action_released(Tac.get_action(&"command")):
		me.switch_state(&"walk")
