extends Node
class_name BattleManager

const ACTION_TIMEOUT_TIME := 60.0

const ITEM_POOL_PROGRESSIVES := "res://objects/items/pools/progressives.tres"

const CRIT_SFX_1 := preload("res://audio/sfx/battle/gags/crit/crit_1.ogg")
const CRIT_SFX_2 := preload("res://audio/sfx/battle/gags/crit/crit_2.ogg")
const CRIT_SFX_3 := preload("res://audio/sfx/battle/gags/crit/crit_3.ogg")
const CRIT_SFX_4 := preload("res://audio/sfx/battle/gags/crit/crit_4.ogg")
const CRIT_SFX: Array = [CRIT_SFX_1, CRIT_SFX_2, CRIT_SFX_3, CRIT_SFX_4]

## Child references
@onready var scene_timer := $SceneTimer
@onready var attack_label := $AttackLabel
@onready var summary_label := $SummaryLabel

## Locals
var player = Util.get_player()
var cogs: Array[Cog]
var battle_node: BattleNode
var battle_ui: BattleUI
var round_actions: Array[BattleAction] = []
var round_end_actions : Array[BattleAction] = []
var current_action: BattleAction
var battle_stats: Dictionary = {}
var status_effects: Array[StatusEffect]
var battle_win_movie: ActionScript:
	set(x):
		x.manager = self
		x.battle_node = battle_node
		battle_win_movie = x
var illegal_moves : Array[Script] = []
var boss_battle := false
var current_round := 0
var has_moved : Array[Node3D] = []

## Signals
signal s_focus_char(character: Node3D)
signal s_battle_ended
signal s_battle_ending
signal s_round_started(actions: Array[BattleAction])
signal s_round_ended
signal s_actions_ended
signal s_participant_will_die(participant: Node3D)
signal s_participant_died(participant: Node3D)
signal s_action_started(action: BattleAction)
signal s_participant_joined(participant: Node3D)
signal s_status_effect_added(effect: StatusEffect)
signal s_action_added(action: BattleAction)
signal s_action_finished(action: BattleAction)
signal s_ui_initialized

func start_battle(cog_array: Array[Cog], battlenode: BattleNode):
	cogs = cog_array
	battle_node = battlenode
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	battle_ui.s_turn_complete.connect(gags_selected)
	
	# Record the base stats for all combatants
	battle_stats[Util.get_player()] = Util.get_player().stats.duplicate(true)
	s_participant_joined.emit(Util.get_player())
	# Since non-exported variables in a resource won't be copied on duplicate
	battle_stats[Util.get_player()].multipliers = Util.get_player().stats.multipliers
	for cog in cogs:
		battle_stats[cog] = cog.stats.duplicate()
		s_participant_joined.emit(cog)
	
	# Also, add in the specified starting status effects for each Cog
	# (Separated for some status effect logic)
	for cog in cogs:
		for effect: StatusEffect in cog.dna.status_effects:
			var add_eff := effect.duplicate()
			add_eff.target = cog
			add_status_effect(add_eff)
	
	BattleService.battle_started(self)
	
	# UI must be added last
	add_child(battle_ui)
	s_ui_initialized.emit()

func append_action(action: BattleAction):
	round_actions.append(action)
	s_action_added.emit(action)

func gags_selected(gags: Array[ToonAttack]):
	for gag in gags:
		append_action(gag)
	begin_turn()

func apply_battle_speed() -> void:
	# Set the engine speed scale to the battle speed setting
	Engine.time_scale = SettingsFile.SpeedOptions[SaveFileService.settings_file.get('battle_speed_idx')]

func revert_battle_speed() -> void:
	Engine.time_scale = 1.0

func begin_turn():
	# Hide Battle UI
	battle_ui.hide()
	apply_battle_speed()
	current_round += 1
	# Inject partner moves before player's
	for partner in Util.get_player().partners:
		inject_battle_action(partner.get_attack(), 0)
	# Get actions from every Cog
	for cog in cogs:
		for i in cog.stats.turns:
			var attack := get_cog_attack(cog)
			if not attack == null:
				append_action(attack)
	s_round_started.emit(round_actions)
	await run_actions()
	round_over()

## Runs the currently queuedbattle actions
func run_actions():
	# Iterate through batte actions
	while not round_actions.is_empty():
		await Task.delay(0.05)
		current_action = round_actions.pop_front()
		if current_action == null:
			continue
		if current_action is CogAttack:
			if not current_action.action_name == "" :
				show_action_name(current_action.action_name + "!",current_action.summary)
			if not current_action.attack_lines.is_empty():
				current_action.user.speak(current_action.attack_lines[RandomService.randi_channel('true_random') % current_action.attack_lines.size()])
		current_action.manager = self
		current_action.battle_node = battle_node
		if current_action is ActionScript:
			has_moved.append(current_action.user)
			s_action_started.emit(current_action)
			BattleService.s_action_started.emit(current_action)
			await current_action.action()
			s_action_finished.emit(current_action)
			BattleService.s_action_finished.emit(current_action)
			battle_node.face_forward()

	current_action = null

# Removes dead battle participant
func someone_died(who: Node3D) -> void:
	# Allow for revives to take place
	if 'stats' in who:
		var stats: BattleStats = who.stats
		if stats.hp > 0:
			return
	
	# Remove from cog array if is cog
	if who is Cog and who in cogs:
		cogs.remove_at(cogs.find(who))
	
	var check_arrays := [round_actions, round_end_actions]
	
	for arr: Array in check_arrays.duplicate():
		var arr_dup := arr.duplicate()
		for i in range(arr_dup.size() - 1, -1, -1):
			var action = arr_dup[i]
			if action.user == who:
				arr.remove_at(i)
				continue
			elif action.targets.has(who):
				action.targets.remove_at(action.targets.find(who))
			if action.targets.is_empty():
				arr.remove_at(i)

	# Scrub status effects for the Someone in question
	for status: StatusEffect in get_statuses_for_target(who):
		scrub_status_effect(status)
		if not status.target:
			status_effects.erase(status)
			status.cleanup()
			continue

	s_participant_will_die.emit(who)

func kill_someone(who: Node3D, signal_only := false) -> void:
	s_participant_died.emit(who)
	if signal_only:
		return

	if who.has_method('lose'):
		if who is Cog:
			#Util.get_player().toon.duck_and_cover()
			if who.v2:
				create_v2_cog(who)
		
		# Use player cam if player dies
		if who is Player:
			Util.get_player().camera.make_current()
		
		if who is Cog and not round_actions.is_empty():
			who.lose()
		else:
			await who.lose()

func round_over():
	s_actions_ended.emit()
	
	# Run status effects
	await renew_status_effects()
	
	if not round_end_actions.is_empty():
		round_actions.assign(round_end_actions)
		round_end_actions.clear()
		await run_actions()

	# Final check for all cog hp
	await check_pulses(cogs)

	revert_battle_speed()

	if cogs.size() == 0:
		end_battle()
	else:
		s_round_ended.emit()
		s_focus_char.emit(battle_node)
		if Util.get_player() and Util.get_player().stats.hp > 0:
			# Stop showing up when i'm dead!!!!
			battle_ui.reset()
			round_actions = []
			battle_node.reposition_cogs()
			has_moved.clear()

func end_battle() -> void:
	# End battle
	# Play battle win movie if it exists
	if battle_win_movie:
		await battle_win_movie.action()
	s_battle_ending.emit()
	s_focus_char.emit(player)
	player.set_animation('victory_dance')
	await player.animator.animation_finished
	player.state = Player.PlayerState.WALK
	player.camera.make_current()
	AudioManager.stop_music()
	# Battle drops
	if boss_battle:
		Util.make_boss_chests(battle_node.get_parent(), battle_node)
	else:
		if battle_node.item_pool:
			var chest = load('res://objects/interactables/treasure_chest/treasure_chest.tscn').instantiate()
			battle_node.get_parent().add_child(chest)
			chest.global_position = battle_node.global_position
			chest.global_rotation = battle_node.global_rotation
			if player.better_battle_rewards == true and current_round <= 2:
				chest.item_pool = load(ITEM_POOL_PROGRESSIVES)
				player.boost_queue.queue_text("Bounty!", Color.GREEN)
			else:
				chest.item_pool = battle_node.item_pool
			chest.override_replacement_rolls = RandomService.randi_channel('true_random') % 2 == 0
	# Reset player & partners as persistent nodes
	SceneLoader.add_persistent_node(player)
	for partner in player.partners:
		SceneLoader.add_persistent_node(partner)
	s_round_ended.emit()
	s_battle_ended.emit()

func is_target_dead(target: Node3D) -> bool:
	var health_ratio: float = float(target.stats.hp) / float(target.stats.max_hp)

	if target is Cog and Util.get_player() and not is_equal_approx(Util.get_player().stats.cog_hp_death_threshold, 0.0):
		if target.stats.hp > 0 and health_ratio <= Util.get_player().stats.cog_hp_death_threshold:
			# Need to force the hp to 0 with this condition or there are PROBLEMS!!
			target.stats.hp = 0
			BattleService.s_cog_died_early.emit(target)
			return true
	return target.stats.hp <= 0

# If you need to check for multiple potentially dead targets
func check_pulses(targets):
	var dead_guys := []
	for target in targets:
		if is_target_dead(target):
			dead_guys.append(target)
	for i in dead_guys.size():
		someone_died(dead_guys[i])
		if i < dead_guys.size()-1:
			kill_someone(dead_guys[i])
		else:
			await kill_someone(dead_guys[i])

func sleep(seconds: float):
	await get_tree().create_timer(seconds).timeout

func barrier(_signal: Signal, timeout: float = 10.0) -> Signal:
	return SignalBarrier.new([_signal, Task.delay(timeout)], SignalBarrier.BarrierType.ANY).s_complete

## Returns a positive value if it deals damage, negative if it heals.
func affect_target(target: Node3D, stat: String, amount: float, multiply: bool, ignore_current_action := false) -> int:
	# Some cog attacks may want to do "true damage" and ignore all incoming and outgoing stats.
	# If so, they will set to ignore the current action, making the incoming damage the "true damage"
	if current_action and is_instance_of(current_action, CogAttack) and current_action.ignore_stats:
		ignore_current_action = true

	if stat == 'hp' and not ignore_current_action:
		amount = get_damage(amount, current_action, target)
	
	# Error if stat doesn't exist
	if not stat in target.stats:
		print("No " + stat + " in BattleStats!")
		return 0
	
	# 3d text values
	var string: String
	var text_color: Color
	var outline_color: Color
	var raise_height := 0.0
	
	# Get the stat's current value
	var pre_stat = target.stats.get(stat)
	match multiply:
		true:
			pre_stat = battle_stats[target].get(stat)
			battle_stats[target].set(stat, pre_stat * amount)
			if amount > 1.0:
				text_color = Color('00ff00')
				outline_color = Color('007100')
			string = stat.to_upper() + ' x' + str(amount)
		false:
			var should_crit := false
			# Check for crit on non-player target
			if (current_action and current_action.user and current_action.user is Player) and (not target is Player) and amount > 0:
				should_crit = roll_for_crit(current_action)
				if should_crit:
					amount = roundi(amount * battle_stats[current_action.user].get_stat("crit_mult"))
			target.stats.set(stat, pre_stat - amount)
			if sign(target.stats.get(stat) - pre_stat) == -1:
				if target is Player:
					string = str(target.stats.get(stat) - pre_stat)
					if current_action and current_action.user and current_action.user is Cog:
						# If target is the player, and this guy is a cog,
						# mark it as the player's last damage source for the death screen
						target.last_damage_source = current_action.user.dna.cog_name
					# Also apply a custom death source message if we have one
					if current_action and current_action.custom_player_death_source:
						target.last_damage_source = current_action.custom_player_death_source
				else:
					if should_crit:
						raise_height = 0.4
						string = str("%s\nCRIT!" % -roundi(amount))
						text_color = BattleText.colors.yellow[0]
						outline_color = BattleText.colors.yellow[1]
						AudioManager.play_sound(RandomService.array_pick_random('true_random', CRIT_SFX))
						BattleService.s_toon_crit.emit()
					else:
						string = str(-roundi(amount))
						if current_action and current_action.user is Player:
							BattleService.s_toon_didnt_crit.emit()
					if current_action and current_action.user is Player and target is Cog:
						BattleService.s_toon_dealt_damage.emit(current_action, target, amount)
			else:
				text_color = Color('00ff00')
				outline_color = Color('007100')
				string = '+' + str(roundi(target.stats.get(stat) - pre_stat))
	if text_color:
		battle_text(target, string, text_color, outline_color, raise_height)
	else:
		battle_text(target, string, Color('ff0000'), Color('7a0000'), raise_height)

	# Play boost text if we have any stored on this action
	if current_action and current_action.stored_boost_text:
		for boost_text_arr: Array in current_action.stored_boost_text:
			Util.get_player().boost_queue.queue_text.callv(boost_text_arr)
		current_action.stored_boost_text = []

	return roundi(amount)

func battle_text(target, string, text_color: Color = Color('ff0000'), outline_color: Color = Color('7a0000'), raise_height := 0.0):
	var txt = load('res://objects/battle/3d_text/3d_text.tscn').instantiate()
	txt.text = string
	txt.modulate = text_color
	txt.outline_modulate = outline_color
	txt.raise_height = raise_height
	target.head_node.add_child(txt)

func get_damage(damage: float, action: BattleAction, target: Node3D) -> int:
	# If the action is a heal, just return the base number
	if sign(damage) == -1 or not action:
		return roundi(damage)
	
	# Get the user
	var user = action.user
	
	# Just return base damage if target has no stats
	if not 'stats' in user or not character_in_battle(user):
		return roundi(damage)
	
	# Get references
	var dmg_boost: float = battle_stats[user].get_stat('damage')
	var defense: float = battle_stats[target].get_stat('defense')
	
	# Enemies that don't take damage set their defense to 999
	if is_equal_approx(defense, Globals.ACCURACY_GUARANTEE_HIT):
		return 0
	
	# Calculate true damage
	var boosted_damage := float(damage) * dmg_boost

	if user is Player:
		var user_stats: PlayerStats = battle_stats[user]
		if action is GagLure:
			boosted_damage *= user_stats.gag_effectiveness['Trap']
		elif action is GagSound:
			boosted_damage *= user_stats.gag_effectiveness['Sound']
		elif action is GagThrow:
			boosted_damage *= user_stats.gag_effectiveness['Throw']
		elif action is GagSquirt:
			boosted_damage *= user_stats.gag_effectiveness['Squirt']
		elif action is DropBig or action is DropSmall:
			boosted_damage *= user_stats.gag_effectiveness['Drop']

		if target is Cog:
			# Mod cog dmg boost
			if target.dna.is_mod_cog and not is_equal_approx(user_stats.mod_cog_dmg_mult, 1.0):
				boosted_damage *= user_stats.mod_cog_dmg_mult
				if not action.contains_boost_text("Proxy Boost!"):
					action.store_boost_text("Proxy Boost!", Color(1, 0.431, 0))

			# Sellbot dmg boost
			if target.dna.department == CogDNA.CogDept.SELL and not is_equal_approx(user_stats.sellbot_boost, 1.0):
				boosted_damage *= user_stats.sellbot_boost
			# Cashbot dmg boost
			elif target.dna.department == CogDNA.CogDept.CASH and not is_equal_approx(user_stats.cashbot_boost, 1.0):
				boosted_damage *= user_stats.cashbot_boost
			# Lawbot dmg boost
			elif target.dna.department == CogDNA.CogDept.LAW and not is_equal_approx(user_stats.lawbot_boost, 1.0):
				boosted_damage *= user_stats.lawbot_boost
			# Bossbot dmg boost
			elif target.dna.department == CogDNA.CogDept.BOSS and not is_equal_approx(user_stats.bossbot_boost, 1.0):
				boosted_damage *= user_stats.bossbot_boost

	return roundi(boosted_damage / defense)

func roll_for_accuracy(action: BattleAction) -> bool:
	if not 'accuracy' in action or action.accuracy == Globals.ACCURACY_GUARANTEE_HIT:
		return true
	elif action.accuracy == Globals.ACCURACY_GUARANTEE_MISS:
		return false
	
	# Get reference values
	# The base accuracy of the move
	# The accuracy boost of the user
	# The evasiveness of the target
	var acc_base: int = action.accuracy
	var acc_boost: float = battle_stats[action.user].get_stat('accuracy')
	
	# Find average evasiveness
	var evasiveness := 0.0
	for target in action.targets:
		evasiveness += battle_stats[target].get_stat('evasiveness')
	evasiveness /= float(action.targets.size())
	
	# Calculate the true accuracy
	var boosted_acc := float(acc_base)*acc_boost
	var true_acc := int(round(boosted_acc/evasiveness))
	
	# Cap accuracy at 95%
	true_acc = clamp(true_acc, 5, 95)
	
	# Roll
	var roll := RandomService.randi_channel('true_random') % 100
	
	print(action.action_name + " rolled " + str(roll) + " for accuracy, and needed lower than " + str(true_acc) + ".")
	
	return roll < true_acc

func roll_for_crit(action: BattleAction) -> bool:
	var crit_chance: float = get_crit_chance(action)
	var roll: float = RandomService.randf_channel('true_random')
	print("Crit: Needed lower than %s and rolled %s" % [crit_chance, roll])
	return roll < crit_chance

func get_crit_chance(action: BattleAction) -> float:
	if (not action) or not action.user:
		return 0.0
	if not 'luck' in battle_stats[action.user]:
		return 0.0
	if is_instance_of(action, GagLure) and action.current_activating_trap:
		# Crit chance is saved onto the trap
		print("Lure retrieving baked crit chance from trap: %s" % action.current_activating_trap.baked_crit_chance)
		return action.current_activating_trap.baked_crit_chance
	# Crit scales from 1.0 to 2.0
	var crit_chance: float = (battle_stats[action.user].get_stat('luck') - 1.0) * action.crit_chance_mod
	return crit_chance

func show_action_name(action_name : String, action_summary := "", action_color := Color.RED, action_shadow := Color.DARK_RED, summary_color := Color('ff6d00'), summary_shadow := Color('5c2200')):
	attack_label.set_text(action_name)
	attack_label.label_settings.font_color = action_color
	attack_label.label_settings.shadow_color = action_shadow
	attack_label.show()
	summary_label.set_text(action_summary)
	summary_label.label_settings.font_color = summary_color
	summary_label.label_settings.shadow_color = summary_shadow
	summary_label.show()
	await sleep(4.0)
	
	if attack_label.text == action_name:
		attack_label.hide()
		summary_label.hide()

func get_statuses_for_target(target: Node3D) -> Array[StatusEffect]:
	var target_statuses: Array[StatusEffect] = []
	for status_effect: StatusEffect in status_effects:
		if target == status_effect.target:
			target_statuses.append(status_effect)
	return target_statuses

func get_status_ids_for_target(target: Node3D) -> Array[int]:
	var id_array: Array[int]
	id_array.assign(get_statuses_for_target(target).map(func(x: StatusEffect): return x.id))
	return id_array

func get_statuses_of_id_for_target(target: Node3D, id: int) -> Array[StatusEffect]:
	var target_statuses: Array[StatusEffect] = []
	target_statuses.assign(get_statuses_for_target(target).filter(func(x: StatusEffect): return x.id == id))
	return target_statuses

# Add the status effect to the given target and run the apply script
func add_status_effect(status_effect: StatusEffect) -> void:
	if attempt_to_combine(status_effect, get_repeat_status_effects(status_effect)):
		return
	status_effect.manager = self
	status_effects.append(status_effect)
	status_effect.apply()
	s_status_effect_added.emit(status_effect)

func attempt_to_combine(effect: StatusEffect, repeat_effects: Array[StatusEffect]) -> bool:
	for r_effect in repeat_effects:
		if r_effect.combine(effect):
			return true
	return false

func get_repeat_status_effects(stat_effect: StatusEffect) -> Array[StatusEffect]:
	var effects: Array[StatusEffect] = []
	for effect: StatusEffect in get_statuses_for_target(stat_effect.target):
		if effect.id == stat_effect.id:
			effects.append(effect)
	return effects

# Tell all status effects to renew
func renew_status_effects():
	# Check for invalid effects
	audit_status_effects()
	# Start by addressing any lured Cogs
	check_lures()
	var statuses: Array[StatusEffect] = status_effects.duplicate()
	for i: int in statuses.size():
		var effect := statuses[i]
		# Clean status effect
		# If no targets remain, skip it.
		scrub_status_effect(effect)
		if not effect.target:
			status_effects.erase(effect)
			effect.cleanup()
			continue
		# Renew the effect
		await effect.renew()
		if effect.rounds == 0:
			await expire_status_effect(effect)
		elif effect.rounds > 0:
			effect.rounds -= 1
		await Task.delay(0.05)

## Removes all effects with no targets
func audit_status_effects() -> void:
	var statuses: Array[StatusEffect] = status_effects.duplicate()
	for i in range(statuses.size() - 1, -1, -1):
		var effect := statuses[i]
		if effect.target == null and effect in status_effects:
			status_effects.erase(effect)

# Expire a status effect by removing it
func expire_status_effect(status_effect: StatusEffect) -> void:
	if status_effect in status_effects:
		status_effects.erase(status_effect)
		await status_effect.expire()
		status_effect.s_expire.emit()
		status_effect.cleanup()

## Removes all dead targets from a status effect
func scrub_status_effect(effect: StatusEffect) -> void:
	if not is_instance_valid(effect.target) or effect.target.stats.hp <= 0:
		effect.target = null

func skip_turn(who: Node3D) -> void:
	var dup_round_actions: Array[BattleAction] = round_actions.duplicate()
	for i in range(dup_round_actions.size() - 1, -1, -1):
		var round_action := dup_round_actions[i]
		if round_action.user == who and round_action in round_actions:
			round_actions.remove_at(i)

# Check lure status effects and bring any expiring to the front
func check_lures() -> void:
	for i in range(cogs.size() - 1, -1, -1):
		var cog = cogs[i]
		if not cog.lured:
			continue
		else:
			for effect in status_effects.duplicate():
				if effect is StatusLured and effect.target == cog and effect.rounds == 0 and effect in status_effects:
					status_effects.erase(effect)
					status_effects.insert(0, effect)
					break

func force_unlure(target: Cog) -> void:
	target.lured = false
	target.stunned = false
	var lure_effect: StatusLured
	for i in range(status_effects.size() - 1, -1, -1):
		var effect = status_effects[i]
		if effect is StatusLured and target == effect.target:
			effect.target = null
			lure_effect = effect
	if not lure_effect:
		return
	if target.stats.hp > 0 and lure_effect.lure_type == StatusLured.LureType.STUN and not target in has_moved:
		unskip_turn(target)

func unskip_turn(who: Actor) -> void:
	if who is Cog:
		var cog_index := cogs.find(who)
		var action_index : int
		for i in round_actions.size():
			if cog_index > 0 and round_actions[i].user == cogs[cog_index - 1]:
				action_index = i + 1
				break
			# NOTE: This may need to change later(?)
			# All current battle participants extend the Actor class
			# Boss fights inject themselves as a participant for an action at the end of a round
			# Meaning it's currently ok to assume that non-actor moves should come last
			elif (cog_index < cogs.size() -1 and round_actions[i].user == cogs[cog_index + 1]) or not round_actions[i].user is Actor:
				action_index = i
				break
		if action_index:
			for i in who.stats.turns:
				inject_battle_action(get_cog_attack(who), action_index)
		else:
			# Failsafe
			for i in who.stats.turns:
				append_action(get_cog_attack(who))

func get_cog_attack(cog: Cog) -> CogAttack:
	var cog_attack : CogAttack
	# Disallow illegal moves to be added to the round
	while not cog_attack or cog_attack.get_script() in illegal_moves:
		cog_attack = cog.get_attack()
		if cog_attack == null: break
	# Illegalize one_time_use attacks
	if cog_attack and cog_attack.one_time_use:
		illegal_moves.append(cog_attack.get_script())
	return cog_attack

func knockback_cog(cog : Cog) -> void:
	var damage := get_knockback_damage(cog)
	cog.stats.hp-=damage
	cog.do_knockback()
	force_unlure(cog)
	var kb_tween := create_tween()
	kb_tween.tween_property(cog.get_node('Body'), 'position:z', 0.0, 0.5)
	await kb_tween.finished
	kb_tween.kill()
	battle_text(cog,"-"+str(damage),Color('ff4d00'),Color('802200'))

func get_knockback_damage(cog: Cog) -> int:
	return find_cog_lure(cog).knockback_effect

func find_cog_lure(cog: Cog) -> StatusLured:
	for effect in status_effects:
		if effect is StatusLured:
			if cog == effect.target:
				return effect
	return null

func inject_battle_action(battle_action : BattleAction,position : int):
	print("Action injected")
	round_actions.insert(position,battle_action)
	s_action_added.emit(battle_action)

# Set the camera angle to the specified transform
func set_camera_angle(transform : Transform3D):
	battle_node.battle_cam.transform = transform

func _process(_delta):
	if Input.is_action_just_pressed('ui_copy'):
		DisplayServer.clipboard_set(str(battle_node.battle_cam.transform))

## Determines whether a character is accounted for in the battle manager
func character_in_battle(who: Node3D) -> bool:
	if who is Cog:
		for cog in cogs:
			if who == cog:
				return true
	elif who is Player:
		return true
	else:
		for partner in Util.get_player().partners:
			if who == partner:
				return true
	return false

func add_cog(cog: Cog, pos := -1) -> void:
	if not cog:
		return
	if pos == -1 or pos >= cogs.size():
		cogs.append(cog)
	else:
		cogs.insert(pos, cog)
	battle_stats[cog] = cog.stats.duplicate()
	s_participant_joined.emit(cog)
	for effect: StatusEffect in cog.dna.status_effects:
		var add_eff := effect.duplicate()
		add_eff.target = cog
		add_status_effect(add_eff)

## Creates a Skelecog based on the Cog specified
func create_v2_cog(cog: Cog) -> Cog:
	var new_cog: Cog = load('res://objects/cog/cog.tscn').instantiate()
	new_cog.skelecog_chance = 0
	new_cog.level = cog.level - 1
	new_cog.skelecog = true
	new_cog.dna = cog.dna
	battle_node.add_child(new_cog)
	new_cog.global_transform = cog.global_transform
	new_cog.battle_start()
	new_cog.hide()
	add_cog(new_cog)
	Task.delay(6.0).connect(new_cog.show)
	return new_cog
