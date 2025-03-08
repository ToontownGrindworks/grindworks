extends ItemScript

@export var defense_penalty := -0.05
@export var max_laff_to_defense := 0.05

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
	player.stats.max_hp_changed.connect(hp_changed)
	hp_changed(player.stats.hp)

func hp_changed(hp: int) -> void:
	if hp > 0:
		return
	Util.get_player().stats.defense += defense_penalty

func max_hp_changed(max_hp: int) -> void:
	if max_hp > 1:
		var diff = max_hp - 1
		Util.get_player().stats.defense += max_laff_to_defense * diff
		Util.get_player().stats.hp = 1
		Util.get_player().stats.max_hp = 1

func do_heal(amount: int) -> void:
	Util.get_player().quick_heal(amount)
