@tool
extends StatusEffect
class_name UBContractLimitBomb

const STOMPER := preload("res://objects/battle/battle_resources/misc_movies/union_buster/contract_stomper.tscn")
const STOMPER_SFX := preload("res://audio/sfx/objects/stomper/CHQ_FACT_stomper_large.ogg")

const DMG_MULT: float = 1.0
const SCALE_MULT: float = 0.1
const SCALE_LIM: float = 8.0

var response_lines: Array[String] = [
	"Ah... Well... It was a good run.",
	"Wait, what? I thought I was doing good work!"
]

var union_buster: Cog

func apply() -> void:
	BattleService.s_battle_participant_died.connect(participant_died)

	var battle_node := manager.battle_node
	var movie := manager.create_tween()
	
	var dialogue_choice: String = RandomService.array_pick_random('true_random', response_lines)
	
	movie.tween_callback(target.speak.bind(dialogue_choice))
	movie.tween_callback(battle_node.focus_character.bind(target))
	movie.tween_callback(target.set_animation.bind("pie-small"))
	await movie.finished
	movie.kill()

func participant_died(who: Node3D) -> void:
	if who == union_buster:
		manager.expire_status_effect(self)

func cleanup() -> void:
	if BattleService.s_battle_participant_died.is_connected(participant_died):
		BattleService.s_battle_participant_died.disconnect(participant_died)

func renew() -> void:
	if not is_instance_valid(target) or target.stats.hp <= 0:
		rounds = 0
		return
	if not is_instance_valid(union_buster) or union_buster.stats.hp <= 0:
		rounds = 0
		return

	if rounds > 0:
		return

	var battle_node := manager.battle_node

	var movie := manager.create_tween()

	var stomper: Node3D = STOMPER.instantiate()
	battle_node.add_child(stomper)
	stomper.global_position = target.global_position

	var _stomper_tween := get_stomper_tween(stomper)

	movie.tween_callback(battle_node.focus_character.bind(target))
	# Damage multiplied by how much health was left on the Cog
	var cog_health_difference = max(target.stats.hp / target.stats.max_hp, 0.2)
	target.stats.hp = -1
	
	var boost_amount = cog_health_difference * DMG_MULT
	
	# Union Buster gets big!!
	# he gets sooo big
	var scale_amount = boost_amount * SCALE_MULT
	var scale_vector = union_buster.body.scale + Vector3(scale_amount, scale_amount, scale_amount)
	
	scale_vector.clamp(Vector3.ZERO, Vector3(SCALE_LIM, SCALE_LIM, SCALE_LIM))

	apply_buff(union_buster, boost_amount)
	# Cog dies, uh oh!
	movie.tween_callback(manager.show_action_name.bind('Time/`s up!', "You are busted!"))
	movie.tween_callback(target.set_animation.bind("soak"))
	movie.tween_interval(1.6)
	movie.tween_callback(target.animator.pause)
	movie.tween_interval(0.12)
	movie.tween_callback(make_explosion.bind(target))
	movie.tween_callback(manager.kill_someone.bind(target, true))
	movie.tween_callback(manager.someone_died.bind(target))
	movie.tween_callback(target.hide)
	movie.tween_interval(4.5)
	movie.tween_callback(target.queue_free)
	
	# Now you are screwed
	movie.tween_callback(battle_node.focus_character.bind(union_buster))
	movie.tween_callback(union_buster.speak.bind("More power for me."))
	movie.tween_callback(union_buster.set_animation.bind("effort"))
	movie.tween_callback(manager.battle_text.bind(union_buster, "Damage Up!", BattleText.colors.orange[0], BattleText.colors.orange[1]))
	movie.tween_property(union_buster.body, "scale", scale_vector, 6).set_ease(Tween.EASE_IN)
	
	await movie.finished
	movie.kill()

func apply_buff(_target: Cog, boost_amount: float) -> void:
	if manager.battle_stats.has(_target):
		manager.battle_stats[_target].damage += boost_amount

func make_explosion(_target: Cog) -> void:
	var explosion: AnimatedSprite3D = load('res://models/cogs/misc/explosion/cog_explosion.tscn').instantiate()
	manager.battle_node.add_child(explosion)
	explosion.global_position = _target.department_emblem.global_position
	explosion.scale = Vector3(15, 15, 15)
	explosion.play('explode')
	await Util.barrier(explosion.animation_finished, 0.5)
	explosion.hide()

func get_stomper_tween(stomper: Node3D) -> Tween:
	return Sequence.new([
		Wait.new(1.6),
		LerpProperty.new(stomper, ^"position:y", 0.18, -4.0),
		Func.new(AudioManager.play_sound.bind(STOMPER_SFX)),
		Wait.new(1.5),
		LerpProperty.new(stomper, ^"position:y", 2.0, 4.0),
		Func.new(stomper.queue_free),
	]).as_tween(manager)
