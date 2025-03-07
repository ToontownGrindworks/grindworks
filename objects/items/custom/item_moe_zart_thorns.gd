extends ItemScript

const STAGGER_TIME := 0.5
const HEAL_AMT := 0.8
const DMG_BOOST := 0.5

var health_monitoring := false
var current_hp := 0
var boost := 0
var inverted := false

var heal_queue: Array[int] = []
var can_queue_heal := true


func on_collect(_item: Item, _object: Node3D) -> void:
	setup()

func on_load(_item: Item) -> void:
	setup()

func setup() -> void:
	BattleService.s_battle_started.connect(battle_started)
	
	var player: Player
	if not is_instance_valid(Util.get_player()):
		player = await Util.s_player_assigned
	else:
		player = Util.get_player()
	
	player.stats.hp_changed.connect(hp_changed)
	hp_changed(player.stats.hp)

func battle_started(battle: BattleManager) -> void:
	battle.s_round_started.connect(round_started)
	battle.s_round_ended.connect(round_ended)
	battle.s_action_started.connect(action_started)
	battle.s_participant_died.connect(participant_died)

func round_started(round_actions: Array[BattleAction]) -> void:
	var index := 0
	var seen_actions : Array[BattleAction] = []
	
	health_monitoring = true
	
	while index < round_actions.size():
		var action := round_actions[index]
		
		# Move all toon attacks to the back of the round actions
		if not action is ToonAttack or action in seen_actions:
			index += 1
			seen_actions.append(action)
		else:
			round_actions.remove_at(index)
			round_actions.append(action)
			seen_actions.append(action)
	
	BattleService.ongoing_battle.round_actions = round_actions

func round_ended() -> void:
	health_monitoring = false
	boost = 0

func action_started(action: BattleAction) -> void:
	if action is ToonAttack:
		action.damage += boost

func hp_changed(hp: int) -> void:
	var previous_hp := current_hp
	current_hp = hp
	
	if not health_monitoring:
		return
	
	if sign(current_hp - previous_hp) == -1:
		if inverted:
			boost -= ceili((abs(current_hp - previous_hp)) * DMG_BOOST)
		else:
			boost += ceili((abs(current_hp - previous_hp)) * DMG_BOOST)
		print("Moe Zart: Boost set to %d" % boost)

func participant_died(participant: Node3D) -> void:
	if participant is Cog:
		queue_heal(ceili(participant.level * HEAL_AMT))

func do_heal(amount: int) -> void:
	Util.get_player().quick_heal(amount)

func queue_heal(amount: int) -> void:
	if heal_queue.is_empty() and can_queue_heal:
		run_heal(amount)
	else:
		heal_queue.append(amount)

func run_heal(amount: int) -> void:
	do_heal(amount)
	can_queue_heal = false
	await Task.delay(STAGGER_TIME)
	if heal_queue.is_empty():
		can_queue_heal = true
	else:
		run_heal(heal_queue.pop_front())
