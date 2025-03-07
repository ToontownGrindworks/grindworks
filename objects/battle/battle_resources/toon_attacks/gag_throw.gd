extends ToonAttack
class_name GagThrow

const FALLBACK_THROW_SFX := preload('res://audio/sfx/battle/gags/throw/AA_pie_throw_only.ogg')

@export var model: PackedScene
@export var scale: float = 1.0
@export var splat_color: Color = Color.WHITE
@export var splat_sfx: AudioStream
@export var present_sfx: AudioStream
@export var throw_sfx: AudioStream
@export var miss_sfx: AudioStream

func action():
	user = Util.get_player()
	var cog: Cog = targets[0]
	user.face_position(cog.global_position)
	var throwable = model.instantiate()
	user.toon.right_hand_bone.add_child(throwable)
	throwable.scale *= scale
	user.set_animation('pie_throw')
	manager.s_focus_char.emit(user)
	if present_sfx:
		AudioManager.play_sound(present_sfx)

	if action_name == "Birthday Cake":
		throwable.get_node("AnimationPlayer").play("candles")

	await manager.sleep(2.545)
	if not throw_sfx:
		AudioManager.play_sound(FALLBACK_THROW_SFX)
	else:
		AudioManager.play_sound(throw_sfx)
	await manager.sleep(0.1)
	throwable.top_level = true
	var throw_tween = manager.create_tween()
	throw_tween.tween_property(throwable, 'global_position', cog.head_node.global_position, 0.25)
	
	# Roll for accuracy
	var hit: bool = manager.roll_for_accuracy(self) or cog.lured
	
	if hit:
		await throw_tween.finished
		throw_tween.kill()
		user.face_position(manager.battle_node.global_position)
		manager.s_focus_char.emit(cog)
		throwable.queue_free()
		
		var immune := get_immunity(cog)
		
		if not immune:
			var throw_damage: int = manager.affect_target(cog, 'hp', damage, false)
			if user.throw_heals:
				user.quick_heal(roundi(throw_damage * user.stats.get_stat("throw_heal_boost")))
		else:
			manager.battle_text(cog, "IMMUNE")
		
		var splat = load("res://objects/battle/effects/splat/splat.tscn").instantiate()
		splat.modulate = splat_color
		cog.head_node.add_child(splat)
		if splat_sfx:
			AudioManager.play_sound(splat_sfx)
		
		if not immune:
			if not cog.lured:
				cog.set_animation('pie-small')
			else:
				manager.knockback_cog(cog)
			
		await manager.barrier(cog.animator.animation_finished, 4.0)
		await manager.check_pulses(targets)
	else:
		manager.s_focus_char.emit(cog)
		cog.set_animation('sidestep-left')
		if miss_sfx:
			AudioManager.play_sound(miss_sfx)
		await throw_tween.finished
		throw_tween.kill()
		throwable.queue_free()
		manager.battle_text(cog, "MISSED")
		await cog.animator.animation_finished

func get_stats() -> String:
	var string := "Damage: " + get_true_damage() + "\n"\
	+ "Affects: "
	match target_type:
		ActionTarget.SELF:
			string += "Self"
		ActionTarget.ENEMIES:
			string += "All Cogs"
		ActionTarget.ENEMY:
			string += "One Cog"
		ActionTarget.ENEMY_SPLASH:
			string += "Three Cogs"

	if Util.get_player().throw_heals:
		var player_stats: PlayerStats
		if is_instance_valid(BattleService.ongoing_battle):
			player_stats = BattleService.ongoing_battle.battle_stats[Util.get_player()]
		else:
			player_stats = Util.get_player().stats
		string += "\nSelf-Heal: %s%%" % roundi(player_stats.get_stat('throw_heal_boost') * 100)

	return string
