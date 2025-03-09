extends CogAttack
class_name SalesDirectorRebrand

const PHRASES := [
	"The marketing team will love this.",
	"This time, it'll stick for good.",
	"A new coat of paint goes a long way.",
	"New look, same great product.",
]

const BUCKET := preload("res://models/props/facility_objects/factory/paint_bucket/Bucket.fbx")
const BucketPos = Vector3(0.735, 0.661, -0.653)
const BucketRot = Vector3(-2.3, 46.8, 58.2)

const SPLASH := preload("res://objects/props/factory/paint_splash_particle.tscn")

const SFX_PAINT_SPLASH := preload("res://audio/sfx/battle/cogs/attacks/special/CHQ_FACT_paint_splash.ogg")
const SFX_PAINT_HIT := preload("res://audio/sfx/battle/cogs/attacks/special/seltzer_hit_only.ogg")

func action() -> void:
	if (not is_instance_valid(user)) or user.stats.hp <= 0:
		return
	if len(manager.cogs) <= 1:
		return

	manager.show_action_name("Rebrand!", "Gives a Max HP buff and Lure Immunity!")
	var cogs = manager.cogs.duplicate()
	cogs.erase(user)
	var new_target: Cog = RandomService.array_pick_random('true_random', cogs)
	targets = [new_target]
	var target: Cog = targets[0]

	var paint_bucket := BUCKET.instantiate()
	user.body.right_hand_bone.add_child(paint_bucket)
	paint_bucket.position = BucketPos
	paint_bucket.rotation_degrees = BucketRot

	battle_node.focus_character(user)
	user.speak(RandomService.array_pick_random('true_random', PHRASES))
	user.set_animation('throw-paper')
	await Task.delay(2.4)
	paint_bucket.reparent(battle_node)
	await user.get_tree().process_frame
	var new_pos: Vector3 = target.body.nametag_node.global_position + Vector3(0, 3, 0)
	var final_pos: Vector3 = target.body.nametag_node.global_position + Vector3(0, -2, 0)
	var projectile := Sequence.new([
		LerpProperty.new(paint_bucket, ^"global_position", 1.0, new_pos).interp(Tween.EASE_OUT, Tween.TRANS_QUAD),
		Parallel.new([
			LerpProperty.new(paint_bucket, ^"global_rotation", 0.4, Vector3(90, 0, 0)).interp(Tween.EASE_IN, Tween.TRANS_QUAD),
			LerpProperty.new(paint_bucket, ^"global_position", 0.6, final_pos).interp(Tween.EASE_IN, Tween.TRANS_QUAD)
		]),
	]).as_tween(user)
	await Task.delay(0.5)
	battle_node.focus_character(target)
	await manager.barrier(projectile.finished, 1.0)
	paint_bucket.queue_free()
	AudioManager.play_sound(SFX_PAINT_SPLASH)
	AudioManager.play_sound(SFX_PAINT_HIT)
	var splash := SPLASH.instantiate()
	target.add_child(splash)
	splash.position.y = target.body.nametag_node.position.y / 2
	splash.restart()
	target.body.set_color(Color("674d78"))
	var old_max_hp: int = target.stats.max_hp
	target.stats.max_hp = ceili(target.stats.max_hp * 1.5)
	var max_hp_diff: int = target.stats.max_hp - old_max_hp
	target.stats.hp += max_hp_diff
	manager.battle_text(target, "Max HP Up!", BattleText.colors.orange[0], BattleText.colors.orange[1])
	await Task.delay(0.6)
	var lure_immunity: StatusEffectGagImmunity = load("res://objects/battle/battle_resources/status_effects/resources/status_effect_gag_immunity.tres").duplicate()
	if lure_immunity.id not in manager.get_status_ids_for_target(target):
		lure_immunity.set_track(load("res://objects/battle/battle_resources/gag_loadouts/gag_tracks/lure.tres"))
		lure_immunity.rounds = 1
		lure_immunity.target = target
		manager.add_status_effect(lure_immunity)
		manager.battle_text(target, "Lure Immunity!", BattleText.colors.orange[0], BattleText.colors.orange[1])
	await Task.delay(1.4)
