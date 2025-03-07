extends Actor
class_name Cog

signal s_dna_set

## Constants
const VIRTUAL_COG_COLOR := Color('ff0000cc')
const COMMON_LEVEL_RANGE := Vector2i(1, 12)
const QUEST_HELP_CHANCE := 20

## For flying in and out
const PROP_PROPELLER := preload('res://objects/props/etc/cog_propeller.tscn')
const SFX_FLY_IN := preload("res://audio/sfx/battle/cogs/misc/ENC_propeller_in.ogg")
const SFX_FLY_OUT := preload("res://audio/sfx/battle/cogs/misc/ENC_propeller_out.ogg")

# Object state
enum CogState {
	IDLE,
	BATTLE,
	PATH
}
@export var state := CogState.IDLE
@export_range(0, 20) var level: int
@export var custom_level_range := Vector2i(1, 12)
@export var level_range_offset := 0
@export var stats: BattleStats
@export var pool: CogPool
@export var use_floor_pool := true

# CogDNA
@export var dna: CogDNA
var dna_set := false
var attacks : Array[CogAttack]
@export var skelecog := false
@export var skelecog_chance := 10
@export var fusion := false
@export var fusion_chance := 0
@export var virtual_cog := false
@export var v2 := false
@export var health_mod := 1.0
var use_mod_cogs_pool := false
var has_forced_dna := false

# Movement Speed
var walk_speed := 4.0

# Optional walking path
@export var path: Path3D

# Body
@onready var body_root := $Body
@onready var drop_shadow: RayCast3D = %DropShadow
var body: Node3D

# Locals
var animator: AnimationPlayer
var skeleton: Skeleton3D

# Emblem/Health Light
var department_emblem: Sprite3D
var hp_light: MeshInstance3D
var light_tween: Tween

# Head position
var head_node: Node3D

# Battle values
var lured := false
var stunned := false
var trap: GagTrap

# Child references
@onready var sfx := $CogDial

var grunt: AudioStream
var murmur: AudioStream
var statement: AudioStream
var question: AudioStream
var question_long: AudioStream

## REGULAR COG VO:
const GRUNT := preload("res://audio/sfx/battle/cogs/COG_VO_grunt.ogg")
const MURMUR := preload("res://audio/sfx/battle/cogs/COG_VO_murmur.ogg")
const STATEMENT := preload("res://audio/sfx/battle/cogs/COG_VO_statement.ogg")
const QUESTION := preload("res://audio/sfx/battle/cogs/COG_VO_question.ogg")
const QUESTION_LONG := preload("res://audio/sfx/battle/cogs/COG_VO_question_old.ogg")

## SKELECOG VO:
const SKELE_GRUNT := preload("res://audio/sfx/battle/cogs/Skel_COG_VO_grunt.ogg")
const SKELE_MURMUR := preload("res://audio/sfx/battle/cogs/Skel_COG_VO_murmur.ogg")
const SKELE_STATEMENT := preload("res://audio/sfx/battle/cogs/Skel_COG_VO_statement.ogg")
const SKELE_QUESTION := preload("res://audio/sfx/battle/cogs/Skel_COG_VO_question.ogg")

func _ready():
	# Announce Cog's existence
	if is_instance_valid(Util.floor_manager):
		Util.floor_manager.s_cog_spawned.emit(self)
	print("running randomize cog")
	# Create a Cog based on the game's current parameters
	randomize_cog()

func face_position(pos: Vector3):
	var face_pos := Vector3(pos.x, global_position.y, pos.z)
	if global_position != face_pos:
		look_at(face_pos)
		rotate_y(deg_to_rad(180))

func randomize_cog() -> void:
	roll_for_attributes()
	roll_for_level()
	roll_for_dna()
	attacks = get_attacks()
	construct_cog()
	set_animation('neutral')
	set_up_stats()
	if skelecog:
		grunt = SKELE_GRUNT
		murmur = SKELE_MURMUR
		statement = SKELE_STATEMENT
		question = SKELE_QUESTION
		question_long = SKELE_QUESTION
	else:
		grunt = GRUNT
		murmur = MURMUR
		statement = STATEMENT
		question = QUESTION
		question_long = QUESTION_LONG

func set_dna(cog_dna: CogDNA, full_reset := true) -> void:
	dna = cog_dna
	
	if full_reset:
		level = 0
		roll_for_attributes()
		roll_for_level()
	attacks = get_attacks()
	construct_cog()
	set_up_stats()
	
func set_new_level(new_level: int):
	level = new_level
	var health_percentage: float = stats.hp / stats.max_hp
	
	set_up_stats()
	
	stats.hp = round(stats.max_hp * health_percentage)

func roll_for_attributes() -> void:
	# Skelecog perchance?
	if RandomService.randi_channel('skelecog_chance') % 100 < skelecog_chance:
		skelecog = true
	# Mayhaps even... fusion?
	if not skelecog and RandomService.randi_channel('fusion_chance') % 100 < fusion_chance:
		fusion = true

func roll_for_level() -> void:
	# Get a random cog level first
	if level == 0:
		if is_instance_valid(Util.floor_manager):
			custom_level_range = Util.floor_manager.level_range
		elif dna: 
			custom_level_range = Vector2i(dna.level_low, dna.level_high)
		level = RandomService.randi_range_channel('cog_levels', custom_level_range.x, custom_level_range.y)
	
	# Allow for Cogs to be higher level than the floor intends
	if sign(level_range_offset) == 1:
		level = custom_level_range.y + level_range_offset
	elif sign(level_range_offset) == -1:
		level = (custom_level_range.y - level_range_offset) + 1

func roll_for_dna() -> void:
	if use_mod_cogs_pool:
		pool = Globals.MOD_COG_POOL.load()
	# Try to get the cog pool from the floor manager
	elif use_floor_pool:
		if is_instance_valid(Util.floor_manager) and Util.floor_manager.cog_pool:
			pool = Util.floor_manager.cog_pool
	
	# Make it more likely for quest related Cogs to appear
	if (not dna) and RandomService.randi_channel('true_random') % 100 < QUEST_HELP_CHANCE and is_instance_valid(Util.get_player()):
		print('attempting to spawn task cog')
		var player := Util.get_player()
		if not player.stats.quests.is_empty():
			var quest := player.stats.quests[RandomService.randi_channel('true_random') % player.stats.quests.size()]
			if quest is QuestCog:
				if quest.specific_cog and test_dna(quest.specific_cog, level):
					print('spawning task cog')
					dna = quest.specific_cog
				else:
					if not quest.specific_cog: print('quest not specific cog')
					else: print('dna test failed')

	# Get a random dna if dna doesn't exist
	if not dna:
		while not test_dna(dna, level):
			dna = pool.cogs[RandomService.randi_channel('cog_dna') % pool.cogs.size()]
	else:
		has_forced_dna = true

	dna = dna.duplicate()

func get_attacks() -> Array[CogAttack]:
	var atk: Array[CogAttack] = []
	atk = dna.attacks
	return atk

func get_debug_attack() -> PickPocket:
	var failsafe_attack := PickPocket.new()
	failsafe_attack.action_name = "ERR: COG HAS NO ATTACKS"
	failsafe_attack.summary = "This is actually a bug."
	failsafe_attack.attack_lines = ["Boy, I really hope someone got fired for that blunder."]
	failsafe_attack.user = self
	failsafe_attack.targets = get_targets(failsafe_attack.target_type)
	return

## Scales the Cog's stats based on its level
func set_up_stats() -> void:
	if not stats: stats = BattleStats.new()
	stats.max_hp = (level + 1) * (level + 2)

	if dna.is_mod_cog:
		health_mod *= Util.get_mod_cog_health_mod()
	if not is_equal_approx(dna.health_mod, 1.0):
		health_mod *= dna.health_mod
	if not is_equal_approx(health_mod, 1.0):
		stats.max_hp = ceili(stats.max_hp * health_mod)
	stats.hp = stats.max_hp
	stats.evasiveness = 0.5 + (level * 0.05)
	stats.damage = 0.4 + (level * 0.1)
	stats.accuracy = 0.75 + (level * 0.05)
	var new_text: String = dna.cog_name + '\n'
	new_text += 'Level ' + str(level)
	if v2: new_text += " v2.0"
	if dna.is_mod_cog: new_text += '\nProxy'
	if dna.is_admin: new_text += '\nAdministrator'
	if dna.custom_nametag_suffix: new_text += '\n%s' % dna.custom_nametag_suffix
	body.nametag.text = new_text
	body.nametag_node.update_position(new_text)
	if not stats.hp_changed.is_connected(update_health_light):
		stats.hp_changed.connect(update_health_light.unbind(1))

## Validates DNA and level combinations
static func test_dna(cog_dna: CogDNA, cog_level: int) -> bool:
	if cog_dna == null:
		return false
	
	# Let Cogs exist outside the standard level range if they want to
	if not cog_level in range(COMMON_LEVEL_RANGE.x, COMMON_LEVEL_RANGE.y + 1):
		return true
	
	# If DNA exists and we are in standard range
	# Return whether or not the cog level is within the dna's level range
	return cog_level in range(cog_dna.level_low, cog_dna.level_high + 1)

func construct_cog():
	# Allow Cog DNA to be refreshed and reset
	if body:
		body.queue_free()
	
	if fusion:
		dna = dna.duplicate()
		var second_dna: CogDNA 
		while not second_dna or second_dna.cog_name == dna.cog_name:
			second_dna = pool.cogs[RandomService.randi_channel('cog_dna') % pool.cogs.size()].duplicate()
		dna.combine_attributes(second_dna)
		dna.cog_name = dna.combine_names(dna.cog_name,second_dna.cog_name)
	
	# First, get the body
	var cogsuit: String = CogDNA.SuitType.keys()[dna.suit].to_lower()
	if skelecog:
		cogsuit += "_skelecog"
	body = Globals.suits.load()[cogsuit].instantiate()
	match dna.suit:
		CogDNA.SuitType.SUIT_A:
			body.scale /= 6.06
		CogDNA.SuitType.SUIT_B:
			body.scale /= 5.29
		CogDNA.SuitType.SUIT_C:
			body.scale /= 4.14
	body_root.add_child(body)
	
	if dna.head_shader and dna.head_shader.has_method('randomize_shader'):
		dna.head_shader.randomize_shader()
	
	# Set the body's dna
	body.set_dna(dna)
	
	skeleton = body.skeleton
	animator = body.animator
	animator.animation_finished.connect(animation_end)
	
	# Set the department emblem
	department_emblem = body.department_emblem
	department_emblem.texture = Cog.get_department_emblem(dna.department)
	hp_light = body.health_meter
	
	if virtual_cog:
		body.set_color(VIRTUAL_COG_COLOR)
	
	head_node = body.head_node

	dna_set = true
	s_dna_set.emit()

func animation_end(_anim):
	if lured:
		set_animation('lured')
	else:
		set_animation('neutral')

func battle_start():
	department_emblem.hide()
	hp_light.show()

func update_health_light():
	var health_ratio: float = float(stats.hp) / float(stats.max_hp)

	if light_tween:
		light_tween.kill()
		light_tween = null

	if health_ratio >= .95:
		hp_light.set_color(Color(0, 1, 0), Color(.25, 1, .25, .5))
	elif health_ratio >= .7:
		hp_light.set_color(Color(1, 1, 0), Color(1, 1, .25, .5))
	elif health_ratio >= .3:
		hp_light.set_color(Color(1, .5, 0), Color(1, .5, .25, .5))
	elif health_ratio >= .05:
		hp_light.set_color(Color(1, 0, 0), Color(1, .25, .25, .5))
	elif health_ratio > 0.0:
		light_tween = create_tween()
		light_tween.set_loops()
		light_tween.tween_callback(hp_light.set_color.bind(Color(1, 0, 0), Color(1, .25, .25, .5)))
		light_tween.tween_interval(0.75)
		light_tween.tween_callback(hp_light.set_color.bind(Color(.3, .3, .3), Color(0, 0, 0, 0)))
		light_tween.tween_interval(0.1)
	else:
		light_tween = create_tween()
		light_tween.set_loops()
		light_tween.tween_callback(hp_light.set_color.bind(Color(1, 0, 0), Color(1, .25, .25, .5)))
		light_tween.tween_interval(0.25)
		light_tween.tween_callback(hp_light.set_color.bind(Color(.3, .3, .3), Color(0, 0, 0, 0)))
		light_tween.tween_interval(0.1)

func set_animation(anim: String):
	if animator.has_animation(anim):
		skeleton.reset_bone_poses()
		animator.play(anim)
		animator.advance(0.0)
	else:
		push_warning("Invalid cog animation: %s" % anim)

func pause_animator() -> void:
	if animator:
		animator.pause()

func unpause_animator() -> void:
	if animator:
		animator.play()

func animator_seek(pos: float) -> void:
	if animator:
		animator.seek(pos)

func move_to(new_pos: Vector3, speed: float = walk_speed) -> Tween:
	
	var time = new_pos.distance_to(global_position) / speed
	set_animation('walk')
	if global_position.distance_to(new_pos) > 0.5:
		face_position(new_pos)
	var move_tween = create_tween()
	move_tween.tween_property(self, 'global_position', new_pos,time)
	move_tween.finished.connect(
	func():
		move_tween.kill()
		set_animation('neutral')
	)
	return move_tween

func turn_to_face(global_pos : Vector3, time := 3.0) -> Tween:
	var current_rotation := rotation.y
	face_position(global_pos)
	var goal_rotation := rotation.y
	rotation.y = current_rotation
	var rotation_tween := create_tween()
	rotation_tween.tween_callback(set_animation.bind('walk'))
	rotation_tween.tween_property(self, 'rotation:y', goal_rotation, time)
	rotation_tween.tween_callback(set_animation.bind('neutral'))
	return rotation_tween

func get_attack() -> CogAttack:
	if stunned:
		return null
	else:
		if attacks.size() == 0:
			return get_debug_attack()
		
		var attack: CogAttack = attacks[RandomService.randi_channel('true_random') % attacks.size()].duplicate()
		attack.user = self
		attack.damage += get_damage_boost()
		if Util.get_player().random_cog_heals and RandomService.randi_channel('true_random') % 100 < 5:
			attack.store_boost_text("Lovely Heal!", Color.HOT_PINK)
			attack.damage = -attack.damage
		# Get the target
		attack.targets = get_targets(attack.target_type)
		
		return attack
		
func get_targets(target_type):
	match target_type:
		BattleAction.ActionTarget.SELF:
			return [self]
		BattleAction.ActionTarget.ALLY:
			var valid_cogs = BattleService.ongoing_battle.cogs.duplicate()
			valid_cogs.erase(self)
			if valid_cogs.size() == 0:
				return []
			else:
				return [valid_cogs[randi()%valid_cogs.size()]]
		BattleAction.ActionTarget.ALLIES:
			var valid_cogs = BattleService.ongoing_battle.cogs.duplicate()
			valid_cogs.erase(self)
			return valid_cogs
		_:
			return [Util.get_player()]
func get_damage_boost() -> int:
	return level / 2

func lose():
	# Get the lose model
	# (Should refactor this later because I hate looking at it)
	# ^ This never happened lol
	var lose_mod: Node3D
	if not skelecog:
		match dna.suit:
			CogDNA.SuitType.SUIT_A:
				lose_mod = load("res://objects/cog/suita/suita_lose.tscn").instantiate()
			CogDNA.SuitType.SUIT_B:
				lose_mod = load("res://objects/cog/suitb/suitb_lose.tscn").instantiate()
			CogDNA.SuitType.SUIT_C:
				lose_mod = load("res://objects/cog/suitc/suitc_lose.tscn").instantiate()
	else:
		match dna.suit:
			CogDNA.SuitType.SUIT_A:
				lose_mod = load("res://objects/cog/suita/skelecog_a_lose.tscn").instantiate()
			CogDNA.SuitType.SUIT_B:
				lose_mod = load("res://objects/cog/suitb/skelecog_b_lose.tscn").instantiate()
			CogDNA.SuitType.SUIT_C:
				lose_mod = load("res://objects/cog/suitc/skelecog_c_lose.tscn").instantiate()
	
	body.hide()
	body_root.add_child(lose_mod)
	lose_mod.set_dna(dna)
	lose_mod.scale = body.scale
	lose_mod.animator.play('lose')
	
	if body.body_color != Color.WHITE:
		lose_mod.set_color(body.body_color)
	
	# Play explosion sound
	await get_tree().create_timer(2.1).timeout
	
	# Particles
	var gear_part: GPUParticles3D = load("res://objects/battle/effects/cog_gears/cog_gears.tscn").instantiate()
	lose_mod.add_child(gear_part)
	gear_part.global_position = department_emblem.global_position
	if RandomService.randi_channel('true_random') % 10000 == 0:
		gear_part.amount = 6000
		Globals.s_cog_volcano.emit()
	
	AudioManager.play_sound(load('res://audio/sfx/battle/cogs/Cog_Death.ogg'), -6.0)
	await get_tree().create_timer(3.55).timeout
	AudioManager.play_sound(load('res://audio/sfx/battle/cogs/ENC_cogfall_apart.ogg'), -10.0)
	var explosion : AnimatedSprite3D = load('res://models/cogs/misc/explosion/cog_explosion.tscn').instantiate()
	lose_mod.add_child(explosion)
	explosion.global_position = department_emblem.global_position
	explosion.scale = Vector3(15, 15, 15)
	explosion.play('explode')
	await Util.barrier(explosion.animation_finished, 0.5)
	explosion.hide()
	gear_part.emitting = false
	queue_free()

func do_knockback():
	var start_time : float
	#A: 2.4
	#B: 1.9s
	#C: 2.6
	match dna.suit:
		CogDNA.SuitType.SUIT_A:
			start_time = 2.4
		CogDNA.SuitType.SUIT_B:
			start_time = 1.9
		CogDNA.SuitType.SUIT_C:
			start_time = 2.6
	set_animation('slip-forward')
	animator.seek(start_time)
	await animator.animation_finished

# Make the cog say stuff
func speak(phrase: String, want_sfx := true):
	# Check for existing speech bubble and remove it
	for child in body.nametag_node.get_children():
		if child is SpeechBubble and not child.is_queued_for_deletion():
			child.finished.emit()
	
	# If phrase is '.', it's just meant to clear any speech bubble
	if phrase == ".":
		return
	
	# Create a speech bubble with the cog font
	var bubble: SpeechBubble = load('res://objects/misc/speech_bubble/speech_bubble.tscn').instantiate()
	bubble.target = body.nametag_node.cog_nametag.chat_node
	body.nametag_node.add_child(bubble)
	bubble.set_font(load('res://fonts/vtRemingtonPortable.ttf'))
	
	# Hide the nametag temporarily
	body.nametag.hide()
	
	bubble.set_text(phrase)

	if want_sfx:
		# Play speech sfx
		# Figure out the appropriate sound effect
		if phrase.contains("!"):
			sfx.stream = grunt
		elif phrase.contains("?"):
			if phrase.length() > 30 and not skelecog: sfx.stream = question_long
			else: sfx.stream = question
		elif phrase.length() > 60:
			sfx.stream = murmur
		else:
			sfx.stream = statement
		
		if is_inside_tree():
			sfx.play()
	
	await bubble.finished
	body.nametag.show()

func fly_in(y_from := 20.0, y_to := 0.0) -> void:
	# Ready the propeller
	var propeller := PROP_PROPELLER.instantiate()
	body.head_bone.add_child(propeller)
	propeller.position = Vector3(0, -0.4, 0.65)
	propeller.rotation_degrees.x = 90
	var prop_animator : AnimationPlayer = propeller.get_node('AnimationPlayer')
	
	# Create the tween
	var fly_tween := create_tween()
	fly_tween.tween_callback(AudioManager.play_sound.bind(SFX_FLY_IN))
	fly_tween.tween_callback(set_animation.bind('landing'))
	fly_tween.tween_callback(animator.set_speed_scale.bind(0.0))
	fly_tween.tween_property(body,'position:y',y_from, 0.0)
	fly_tween.tween_property(body,'position:y',y_to, 3.5)
	fly_tween.tween_callback(animator.set_speed_scale.bind(1.0))
	fly_tween.tween_callback(prop_animator.play.bind('retract'))
	fly_tween.tween_interval(3.0)
	fly_tween.finished.connect(
	func():
		fly_tween.kill()
		propeller.queue_free()
	)

func fly_out(y_to := 20.0) -> void:
	# Ready the propeller
	var propeller := PROP_PROPELLER.instantiate()
	body.head_bone.add_child(propeller)
	propeller.scale *= 120.0
	propeller.position.y += 80.0
	var prop_animator: AnimationPlayer = propeller.get_node('AnimationPlayer')
	
	# Create the tween
	var fly_tween := create_tween()
	fly_tween.tween_callback(AudioManager.play_sound.bind(SFX_FLY_OUT))
	fly_tween.tween_callback(prop_animator.play_backwards.bind('retract'))
	fly_tween.tween_callback(animator.play_backwards.bind('landing'))
	fly_tween.tween_interval(2.25)
	fly_tween.tween_property(body, 'position:y', y_to, 3.5)
	fly_tween.parallel().tween_callback(pause_animator).set_delay(1.5)
	fly_tween.finished.connect(
	func():
		fly_tween.kill()
		propeller.queue_free()
	)

## Global functions
static func get_department_emblem(dept: CogDNA.CogDept) -> Texture2D:
	return load("res://models/cogs/misc/hp_light/" + Cog.get_department_name(dept) + ".png")

static func get_department_name(dept: CogDNA.CogDept) -> String:
	return CogDNA.CogDept.keys()[int(dept)].to_lower()
