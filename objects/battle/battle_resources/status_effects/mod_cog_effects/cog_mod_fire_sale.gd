@tool
extends StatusEffect

const FIRE = preload("res://objects/battle/effects/fire/fire.tscn")
const SFX_FLAMES := preload("res://audio/sfx/battle/cogs/attacks/SA_hot_air.ogg")
const VISUAL_DOT := preload("res://objects/battle/battle_resources/status_effects/resources/fire_sale_visual_dot.tres")

const APPLY_LINES: Array[String] = [
	"Get 'em while they're hot!",
	"Always strike when the iron is hot.",
	"Things are getting a little heated.",
]

var cog: Cog
var player: Player
var fire: GPUParticles3D
var damage := 0
var applied := false

var dot_visual_status: StatusEffect

func apply() -> void:
	player = Util.get_player()
	damage = roundi(float(-Util.get_hazard_damage()) * 0.8)

func cleanup() -> void:
	if fire:
		fire.queue_free()
		fire = null
	if dot_visual_status:
		manager.expire_status_effect(dot_visual_status)
		dot_visual_status = null

func renew() -> void:
	if not applied:
		await application_movie()
		applied = true
		return
	
	# Movie Start
	var movie := manager.create_tween()
	var battle_node := manager.battle_node
	
	# Focus Player
	movie.tween_callback(battle_node.focus_character.bind(player))
	movie.tween_callback(player.set_animation.bind('cringe'))
	movie.tween_callback(manager.affect_target.bind(player, 'hp', damage, false))
	movie.tween_interval(3.5)

	await movie.finished
	movie.kill()

func application_movie() -> void:
	# Movie Start
	var movie := manager.create_tween()
	var battle_node := manager.battle_node
	fire = FIRE.instantiate()
	
	# Show move name
	movie.tween_callback(manager.show_action_name.bind("Fire Sale!"))
	
	# Focus Cog
	movie.tween_callback(battle_node.focus_character.bind(target))
	movie.tween_callback(target.face_position.bind(player.global_position))
	movie.tween_callback(target.speak.bind(RandomService.array_pick_random('true_random', APPLY_LINES)))
	movie.tween_callback(target.set_animation.bind('magic1'))
	movie.tween_callback(AudioManager.play_sound.bind(SFX_FLAMES))
	movie.tween_interval(2.5)
	
	# Focus Toon
	movie.tween_callback(battle_node.focus_character.bind(player))
	movie.tween_callback(player.set_animation.bind('slip_forwards'))
	movie.tween_callback(player.add_child.bind(fire))
	movie.tween_callback(manager.affect_target.bind(player, 'hp', damage, false))
	movie.tween_interval(4.0)

	dot_visual_status = VISUAL_DOT.duplicate()
	dot_visual_status.description = "%d damage per round" % damage
	dot_visual_status.target = player
	dot_visual_status.rounds = -1
	manager.add_status_effect(dot_visual_status)

	await movie.finished
	movie.kill()
