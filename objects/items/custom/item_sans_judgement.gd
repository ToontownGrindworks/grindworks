extends ItemScript

func on_collect(_item: Item, _object: Node3D) -> void:
	setup()

func on_load(_item: Item) -> void:
	setup()

func setup() -> void:
	var player: Player
	if not is_instance_valid(Util.get_player()):
		player = await Util.s_player_assigned
	else:
		player = Util.get_player()
	
	player.stats.hp_changed.connect(hp_changed)
	hp_changed(player.stats.hp)

func hp_changed(hp: int) -> void:
	if hp > 0:
		return
	Util.get_player().stats.defense -= 0.05

func do_heal(amount: int) -> void:
	Util.get_player().quick_heal(amount)
