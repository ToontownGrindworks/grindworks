@tool
extends StatusEffect

const SFX := preload("res://audio/sfx/battle/cogs/attacks/SA_audit.ogg")

const PHRASES := [
	"I knew those investments would pay off.",
	"Cogs Inc. stock is through the roof.",
	"I can finally afford that new Cogs Inc. branded clipboard.",
	"You Toons don't know the power of a sound investment."
]

const CALCULATOR := preload('res://models/props/cog_props/calculator/calculator.glb')

var heal_turn := false

func renew() -> void:
	var battle_node := manager.battle_node
	var cog: Cog = target
	heal_turn = not heal_turn
	
	# Don't play if Cog dead
	if not is_instance_valid(cog) or cog.stats.hp == 0:
		return
	
	# Don't play if at full health
	if cog.stats.hp == cog.stats.max_hp:
		return
	
	# Don't play if on off-turn
	if not heal_turn:
		return

	var heal_amount := -(cog.stats.max_hp / 3)
	
	# Movie Start
	var movie := manager.create_tween()
	
	var calculator : Node3D = CALCULATOR.instantiate()
	cog.body.left_hand_bone.add_child(calculator)
	calculator.rotation_degrees = Vector3(-60, 45, 130)
	
	# Focus Cog
	movie.tween_callback(battle_node.focus_character.bind(cog))
	
	movie.tween_callback(cog.speak.bind(RandomService.array_pick_random('true_random', PHRASES)))
	movie.tween_callback(cog.set_animation.bind('phone'))
	movie.tween_interval(2.0)
	movie.tween_callback(manager.affect_target.bind(cog, 'hp', heal_amount, false))
	movie.tween_interval(4.0)

	await Task.delay(0.4)
	AudioManager.play_sound(SFX)

	await movie.finished
	movie.kill()
	calculator.queue_free()

func get_icon() -> Texture2D:
	return load("res://ui_assets/battle/statuses/investment_cog_heal.png")

func get_status_name() -> String:
	return "Investment"
