extends Control

# Child references
@onready var light := %HealthLight
@onready var glow := %HealthGlow
@onready var face := %CogFace
@onready var level_label := %Level
@onready var hp_label := %CogHP
@onready var status_container := %StatusEffects

var current_cog: Cog

var status_effects: Array[StatusEffect] = []

func set_cog(cog: Cog):
	# Match HP light
	var cog_changed: bool = current_cog != cog
	current_cog = cog

	if cog_changed:
		cog.hp_light.s_color_changed.connect(sync_colors.bind(cog))
	sync_colors(cog.hp_light.get_surface_override_material(0).albedo_color, cog.hp_light.get_child(0).get_surface_override_material(0).albedo_color, cog)
	
	# Show level
	level_label.text = "Level " + str(cog.level)
	if cog.v2:
		level_label.text += ' v2.0'

	hp_label.show()
	hp_label.text = str(cog.stats.hp) + '/' + str(cog.stats.max_hp)

	var head: Node3D = cog.dna.get_head()
	if not cog.dna.head_scale.is_equal_approx(Vector3.ONE * cog.dna.head_scale.x):
		head.scale = cog.dna.head_scale
	face.node = head

	if not BattleService.ongoing_battle:
		await BattleService.s_battle_started
	populate_status_effects(cog)

func sync_colors(light_color: Color, glow_color: Color, cog: Cog):
	if (not is_instance_valid(cog)) or cog != current_cog:
		return
	light.self_modulate = light_color
	glow.self_modulate = glow_color

func populate_status_effects(target : Cog) -> void:
	for effect in BattleService.ongoing_battle.get_statuses_for_target(target):
		if not effect.visible:
			continue
		var new_icon: StatusEffectIcon = StatusEffectIcon.create()
		new_icon.effect = effect
		status_container.add_child(new_icon)
