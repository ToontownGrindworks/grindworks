extends ItemScript

# This item runs a x second battle timer on every round
# And shuffles the order of gags on the menu

const ROUND_TIME := 24
const TIMER_ANCHOR := Control.PRESET_TOP_RIGHT
const SFX_TIMER = preload("res://audio/sfx/objects/moles/MG_sfx_travel_game_bell_for_trolley.ogg")
@export var stat_mods := {
	'damage' = 0.07,
	'defense' = -0.08,
	'evasiveness' = 0.02,
	'luck' = 0.07
} 
@export var timer_mod := -2.0
@export var max_stacks := 8

var stacks: int:
	set(x):
		if item is Item:
			item.arbitrary_data["stacks"] = x
	
var flawless_round := false

## Battle Timer created by Util
var timer: GameTimer

var player: Player
var manager: BattleManager
var current_hp: int

var item: Item

func on_collect(_item: Item, _object: Node3D) -> void:
	item = _item
	stacks = item.arbitrary_data["stacks"]
	var player: Player
	if not Util.get_player():
		player = await Util.s_player_assigned
	else:
		player = Util.get_player()
	setup(player)

func on_load(item: Item) -> void:
	on_collect(item, null)

func setup(_player : Player) -> void:
	player = _player
	BattleService.s_round_ended.connect(on_round_reset)
	BattleService.s_battle_started.connect(on_battle_start)
	# If HP changes, check if HP is lost for flawless round check
	player.stats.hp_changed.connect(player_hp_change)
	
func player_hp_change(new_hp : int) -> void:
	if new_hp < current_hp:
		flawless_round = false
		if stacks > 0:
			modify_stats(-stacks)
			stacks = 0
	current_hp = new_hp

## Connect the gag track elements up to be shuffled
func on_battle_start(_manager: BattleManager) -> void:
	manager = _manager
	flawless_round = false
	await _manager.s_ui_initialized
	initialize_ui(_manager)

func initialize_ui(_manager: BattleManager) -> void:
	var ui := _manager.battle_ui
	for element: Control in ui.gag_tracks.get_children():
		element.s_refreshing.connect(on_track_refresh)
		element.refresh()
	
	# Also run the round reset method for this first round
	on_round_reset(_manager)
	ui.s_turn_complete.connect(on_turn_complete)

## Shuffles the gag order of each track
func on_track_refresh(element: Control) -> void:
	var unlocked: int = element.unlocked
	if unlocked > 0:
		element.gags = element.gags.slice(0,unlocked)
		#element.gags.shuffle()

func modify_stats(factor: float) -> void:
	var stats := player.stats
	var battle_stats : BattleStats
	if manager:
		battle_stats = manager.battle_stats[player]
	
	for key in stat_mods:
		if key in stats:
			stats[key] += stat_mods[key] * factor
			if battle_stats:
				battle_stats[key] += stat_mods[key] * factor

## Runs the battle timer at the beginning of each round
func on_round_reset(_manager: BattleManager) -> void:
	if manager != _manager:
		manager = _manager
	if flawless_round and stacks < max_stacks:
		stacks += 1
		modify_stats(1.0)
	print("Heat: " +str(stacks))
	
	# Give bonus turn 1 heat and at max heat
	var turns_given: int = player.stats.turns
	if stacks > 0:
		turns_given += 1
	if stacks == max_stacks:
		turns_given += 1
	manager.battle_stats[player].turns = turns_given
	manager.battle_ui.refresh_turns()
	
	flawless_round = true
	if stacks >= 1:
		timer = Util.run_timer(ROUND_TIME + (stacks * timer_mod), TIMER_ANCHOR)
		timer.timer.timeout.connect(on_timeout.bind(manager.battle_ui))
		timer.reparent(manager.battle_ui)
		if manager.cogs.size() > 0:
			AudioManager.play_sound(SFX_TIMER)

func on_timeout(ui: BattleUI) -> void:
	# Good way to tell if round isn't over is if the UI is still visible
	if not ui.visible:
		return
	ui.complete_turn()

func on_turn_complete(_gags: Array[ToonAttack]) -> void:
	if is_instance_valid(timer) and not timer.is_queued_for_deletion():
		timer.queue_free()
