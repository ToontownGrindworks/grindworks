extends ItemScript

func on_collect(_item: Item, _object: Node3D) -> void:
	setup()

func on_load(_item: Item) -> void:
	setup()

func setup() -> void:
	BattleService.s_cog_died_early.connect(cog_died_early)

func cog_died_early(_cog: Cog) -> void:
	if Util.get_player():
		Util.get_player().boost_queue.queue_text("No Mercy!", Color(1.0, 0.287, 0.225))
