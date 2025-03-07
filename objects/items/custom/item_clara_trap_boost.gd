extends ItemScript

const BOOST_STATS = ['damage','defense','evasiveness','luck','speed','hp']
const STAGGER_TIME := 0.5

var boosters: Array[StatMultiplier] = []

var text_queue: Array[String] = []
var can_queue_text := true

func on_collect(_item: Item, _object: Node3D) -> void:
	setup()

func on_load(_item: Item) -> void:
	setup()

func setup() -> void:
	Util.s_floor_started.connect(on_floor_start)
	BattleService.s_battle_started.connect(battle_started)

func on_floor_start(game_floor: GameFloor) -> void:
	game_floor.s_floor_ended.connect(on_floor_end)

# Clear out boosters at end of floor
func on_floor_end() -> void:
	var player := Util.get_player()
	for i in range(player.stats.multipliers.size() - 1, -1, -1):
		if player.stats.multipliers[i] in boosters:
			player.stats.multipliers.remove_at(i)
	boosters.clear()


func get_current_battle() -> BattleManager:
	if is_instance_valid(BattleService.ongoing_battle):
		return BattleService.ongoing_battle
	return null

func battle_started(battle: BattleManager) -> void:
	var battle_ui: BattleUI = battle.battle_ui
	battle_ui.s_turn_complete.connect(scan_gags)

func scan_gags(gags: Array[ToonAttack]) -> void:
	for gag in gags:
		if gag is GagTrap:
			gag.s_activate.connect(add_booster)

func add_booster() -> void:
	var stat: String = BOOST_STATS[RandomService.randi_channel('true_random') % BOOST_STATS.size()]
	if stat == 'hp':
		Util.get_player().quick_heal(int(ceil(Util.get_player().stats.max_hp * 0.25)))
	else:
		var booster := StatMultiplier.new()
		booster.stat = stat
		booster.amount = 0.05 * float(RandomService.randi_channel('true_random') % 2 + 1)
		Util.get_player().stats.multipliers.append(booster)
		boosters.append(booster)
		queue_text(stat.to_upper() + " UP!")
	print(stat + " boost applied.")

func do_battle_text(text: String) -> void:
	var battle_manager: BattleManager = BattleService.ongoing_battle
	if is_instance_valid(battle_manager):
		battle_manager.battle_text(Util.get_player(), text, Color.GREEN, Color.DARK_GREEN)

func queue_text(text: String) -> void:
	if text_queue.is_empty() and can_queue_text:
		run_text(text)
	else:
		text_queue.append(text)

func run_text(text: String) -> void:
	do_battle_text(text)
	can_queue_text = false
	await Task.delay(STAGGER_TIME)
	if text_queue.is_empty():
		can_queue_text = true
	else:
		run_text(text_queue.pop_front())
