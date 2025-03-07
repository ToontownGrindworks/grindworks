extends ItemScript

const BOOST_STATS :={
	'luck': 0.01,
	'evasiveness': 0.01,
	'defense': 0.01,
	'damage': 0.01,
	'speed': 0.01
}
var multipliers: Array[StatMultiplier]


func on_collect(_item: Item, _object: Node3D) -> void:
	setup()

func on_load(_item: Item) -> void:
	setup()

func setup() -> void:
	if not Util.get_player():
		await Util.s_player_assigned
	var player := Util.get_player()
	player.stats.s_money_changed.connect(on_money_changed)
	create_multipliers()
	on_money_changed(player.stats.money)

## Sync multipliers to current money amount
func on_money_changed(money: int) -> void:
	for mult: StatMultiplier in multipliers:
		if mult.stat in BOOST_STATS.keys():
			mult.amount = floori(money / 5) * BOOST_STATS[mult.stat]

func create_multipliers() -> void:
	for stat in BOOST_STATS.keys():
		var mult := StatMultiplier.new()
		mult.stat = stat
		mult.amount = 0.0
		mult.additive = true
		multipliers.append(mult)
		Util.get_player().stats.multipliers.append(mult)
