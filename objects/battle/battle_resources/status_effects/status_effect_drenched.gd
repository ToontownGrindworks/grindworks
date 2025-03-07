@tool
extends StatBoost


func combine(effect : StatusEffect) -> bool:
	if rounds <= effect.rounds:
		rounds = effect.rounds
		return true
	return false

func get_status_name() -> String:
	return "Drenched"
