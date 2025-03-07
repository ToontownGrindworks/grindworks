extends CogAttack
class_name BKCookTheBooks

const COOKED := preload("res://objects/battle/battle_resources/status_effects/resources/bk_cooked.tres")
const BOOKSHELF := preload("res://objects/battle/battle_resources/misc_movies/bookkeeper/burning_bookshelf.tscn")
const SFX_DECOMPRESS := preload("res://audio/sfx/objects/stomper/toon_decompress.ogg")
const SFX_HOT_AIR := preload("res://audio/sfx/battle/cogs/attacks/SA_hot_air.ogg")

var player: Player:
	get: return Util.get_player()

func action() -> void:
	if (not is_instance_valid(user)) or user.stats.hp <= 0:
		return

	battle_node.focus_character(user)
	manager.show_action_name("Cook the Books!", "Applies lingering damage over time!")
	user.set_animation('magic2')
	var bookshelf: Node3D = BOOKSHELF.instantiate()
	battle_node.add_child(bookshelf)
	bookshelf.scale = Vector3.ONE * 2.0
	bookshelf.position = Vector3(0, 0.02, 7.0)
	bookshelf.rotation_degrees.y = 180.0
	await Task.delay(1.5)
	battle_node.focus_character(targets[0])
	AudioManager.play_snippet(SFX_HOT_AIR, 0.0, 1.43)
	await Task.delay(0.6)
	var book_rot: Tween = Sequence.new([
		Wait.new(0.6),
		Func.new(func(): await Task.delay(0.3); squish_toon(); AudioManager.play_sound(load("res://audio/sfx/misc/CHQ_SOS_cage_land.ogg"))),
		LerpProperty.new(bookshelf, ^"rotation_degrees:x", 0.4, 90.0).interp(Tween.EASE_IN, Tween.TRANS_QUAD),
		Wait.new(0.7),
		LerpProperty.new(bookshelf, ^"rotation_degrees:x", 1.0, 0.0).interp(Tween.EASE_IN, Tween.TRANS_QUAD),
	]).as_tween(battle_node)
	await book_rot.finished
	manager.battle_text(targets[0], "Cooked!", BattleText.colors.orange[0], BattleText.colors.orange[1])
	await Task.delay(0.5)
	await apply_cooked()
	await Task.delay(0.5)
	bookshelf.queue_free()

func squish_toon() -> void:
	var base_scale: float = player.toon.scale.y
	var tween := manager.create_tween()
	AudioManager.play_sound(player.toon.yelp)
	tween.tween_property(player.toon, 'scale:y', 0.05, 0.05)
	tween.tween_interval(1.0)
	tween.tween_callback(AudioManager.play_sound.bind(SFX_DECOMPRESS))
	tween.tween_callback(player.set_animation.bind('happy'))
	tween.tween_property(player.toon, 'scale:y', base_scale, 0.25)
	await player.animator.animation_finished
	tween.kill()

func apply_cooked() -> void:
	if COOKED.id in manager.get_status_ids_for_target(targets[0]):
		# If they already have the cooked effect, simply increase its damage value.
		var cooked: StatEffectBKCooked = manager.get_statuses_of_id_for_target(targets[0], COOKED.id)[0]
		cooked.amount += 2
	else:
		# Apply cooked fresh
		var cooked := COOKED.duplicate()
		cooked.amount = 10
		cooked.rounds = -1
		cooked.target = targets[0]
		cooked.bookkeeper = user
		manager.add_status_effect(cooked)

	# No instant effect, so do it ourselves.
	manager.affect_target(targets[0], 'hp', 10, false)
	await manager.check_pulses(targets)
