extends Resource
class_name BattleStats


# Multiplicative
@export var damage := 1.0:
	set(x):
		damage = x
		if self is PlayerStats:
			print('damage set to ' +str(x))
		s_damage_changed.emit(x)
@export var defense := 1.0:
	set(x):
		defense = x
		if self is PlayerStats:
			print('defense set to ' + str(x))
		s_defense_changed.emit(x)
@export var evasiveness := 1.0:
	set(x):
		evasiveness = x
		if self is PlayerStats:
			print('evasiveness set to ' + str(x))
		s_evasiveness_changed.emit(x)
@export var accuracy := 1.0:
	set(x):
		accuracy = x
		if self is PlayerStats:
			print('accuracy set to ' + str(x))
		s_accuracy_changed.emit(x)
			
@export var speed := 1.0:
	set(x):
		speed = x
		if self is PlayerStats:
			print('speed set to ' + str(x))
		s_speed_changed.emit(x)
@export var max_turns := 3


# Additive
@export var max_hp := 25:
	set(x):
		max_hp = x
		max_hp_changed.emit(x)
@export var hp := 25:
	set(x):
		hp = clamp(x, 0, max_hp)
		hp_changed.emit(hp)
@export var turns := 1


var multipliers: Array[StatMultiplier] = []

# Signals for objects listening
signal hp_changed(health: int)
signal max_hp_changed(health: int)
signal s_damage_changed(new_damaage: float)
signal s_accuracy_changed(new_accuracy: float)
signal s_defense_changed(new_defense: float)
signal s_evasiveness_changed(new_evasiveness: float)
signal s_speed_changed(new_speed: float)



func _to_string():
	var return_string := "Stats: \n"
	var active = false 
	for property in get_property_list():
		if not active and property.name != 'damage':
			continue
		elif property.name == 'damage': 
			active = true
		return_string += property.name + ': ' + str(get(property.name)) + '\n'
	return return_string

func get_stat(stat: String) -> float:
	if stat in self:
		var base_stat = get(stat)
		var additive_total := 0.0
		var multiplier_total := 1.0
		for multiplier in multipliers:
			if multiplier.stat == stat:
				if multiplier.additive:
					additive_total += multiplier.amount
				else:
					multiplier_total += multiplier.amount
		return (base_stat + additive_total) * multiplier_total
	else:
		return 1.0
