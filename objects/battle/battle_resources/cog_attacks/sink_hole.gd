extends CogAttack
class_name CogAttackSinkHole

const MINIGAME := preload('res://objects/battle/misc_battle_objects/spam_game/spam_game.tscn')
const MUD := preload('res://models/props/gags/quicksand/quicksand.glb')

var damage_active := true


func action() -> void:
	var player: Player = targets[0]
	var cog: Cog = user
	var mud := MUD.instantiate()
	var minigame := MINIGAME.instantiate()
	
	# MOVIE START
	var movie1 := manager.create_tween()

	manager.revert_battle_speed()

	# Focus Cog
	movie1.tween_callback(battle_node.focus_character.bind(cog))
	movie1.tween_callback(cog.set_animation.bind('magic1'))
	movie1.tween_interval(1.5)
	
	# Focus player
	movie1.tween_callback(func():
		battle_node.add_child(mud)
		mud.scale *= 0.5
		mud.global_position = player.global_position
		mud.position.y += 0.05
	)
	movie1.tween_callback(battle_node.focus_character.bind(player))
	movie1.tween_callback(player.set_animation.bind('melt'))
	movie1.tween_interval(3.0)
	await movie1.finished
	movie1.kill()
	
	# Play minigame
	player.stats.hp_changed.connect(hp_check.bind(minigame))
	do_damage(player)
	manager.get_tree().get_root().add_child(minigame)
	var game_won = await minigame.s_game_finished
	minigame.queue_free()
	damage_active = false
	player.toon.position.y -= 1.0
	
	# Movie resume
	var movie2 := manager.create_tween()
	movie2.tween_callback(player.set_animation.bind('happy'))
	movie2.tween_callback(player.toon.animator.seek.bind(0.5))
	movie2.tween_property(player.toon, 'position:y', 0.0, 0.25)
	if not game_won:
		movie2.tween_callback(manager.affect_target.bind(player, 'hp', damage, false))
	movie2.tween_interval(3.0)
	await movie2.finished
	movie2.kill()
	mud.queue_free()
	manager.apply_battle_speed()
	await manager.check_pulses(targets)

func do_damage(player: Player) -> void:
	while damage_active:
		if manager.roll_for_accuracy(self):
			player.last_damage_source = "Quicksand"
			manager.affect_target(player, 'hp', ceili(damage / 3), false)
		else:
			manager.battle_text(player, 'MISSED')
		await Task.delay(1.5)

func hp_check(hp: int, minigame: Control) -> void:
	if hp <= 0 and is_instance_valid(minigame):
		minigame.s_game_finished.emit(false)
