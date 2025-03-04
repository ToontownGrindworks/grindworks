extends ItemScript

var current_hp := 0

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
		current_hp = hp
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Util.get_tree().get_root().add_child(load("res://objects/battle/misc_battle_objects/clutch_dodge/clutch_dodge.tscn").instantiate())
	var won = await Util.s_clutch_ended
	current_hp = hp
	if won:
		++current_hp

func do_heal(amount: int) -> void:
	Util.get_player().quick_heal(amount)
