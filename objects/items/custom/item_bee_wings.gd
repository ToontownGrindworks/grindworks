extends ItemScript

var multiplier: StatMultiplier

func on_collect(_item: Item, _object: Node3D) -> void:
	setup()

func on_load(_item: Item) -> void:
	setup()

func setup() -> void:
	if not Util.get_player():
		await Util.s_player_assigned
	var player := Util.get_player()
	player.stats.s_speed_changed.connect(on_speed_changed)
	create_multiplier()
	on_speed_changed(player.stats.speed)

## Sync multipliers to current speed amount
func on_speed_changed(speed: float) -> void:
	multiplier.amount = maxf(0.0, (speed - 1.0) * 0.75)

func create_multiplier() -> void:
	multiplier = StatMultiplier.new()
	multiplier.stat = 'crit_mult'
	multiplier.amount = 0.0
	multiplier.additive = true
	Util.get_player().stats.multipliers.append(multiplier)
