extends Quest
class_name QuestCog

const OBJECTIVE_RANGE := Vector2i(10,15)
const FALLBACK_ICON := preload("res://ui_assets/quests/gear2.png")

@export var specific_cog : CogDNA
@export var department := CogDNA.CogDept.NULL
@export_range(1,12) var min_level := 1


func _init() -> void:
	BattleService.s_battle_started.connect(battle_started)

func setup() -> void:
	# Reset the quest
	reset()
	
	# Get item
	super()
	
	randomize_objective()
	
	title = "WANTED"
	quota_text = "defeated"
	
	if quota == 1: quest_txt += "A "
	else: quest_txt += str(quota) + " "
	
	if min_level > 1:
		quest_txt += "Level "+str(min_level)+"+ "
	
	if specific_cog:
		var cog_name: String
		
		if quota > 1: cog_name = specific_cog.get_plural_name()
		else: cog_name = specific_cog.cog_name
		
		if cog_name.begins_with("The "):
			cog_name = cog_name.lstrip("The ")
		quest_txt += cog_name
	elif not department == CogDNA.CogDept.NULL:
		var dept_name := Cog.get_department_name(department) + "bot"
		dept_name[0] = dept_name[0].to_upper()
		quest_txt += dept_name
	else:
		quest_txt += "Cog"
	if (quota > 1 and not quest_txt.ends_with("s")) and not specific_cog:
		quest_txt += "s"
	
	s_quest_updated.emit()

func randomize_objective() -> void:
	quota = RandomService.randi_range_channel('quests',OBJECTIVE_RANGE.x,OBJECTIVE_RANGE.y)
	var quotaf := float(quota)
	
	var quest_type := RandomService.randi_channel('cog_quest_types') % 3
	
	var minimum_level := maxi(1, min(4, Util.floor_number + 1))
	var maximum_level := maxi(2, min(7, Util.floor_number + 3))
	
	
	# 33% chance of department specific
	if quest_type == 0:
		department = goal_dept
	elif quest_type == 1:
		var cog_pool : CogPool
		match goal_dept:
			CogDNA.CogDept.SELL:
				cog_pool = load('res://objects/cog/presets/pools/sellbot.tres')
			CogDNA.CogDept.CASH:
				cog_pool = load('res://objects/cog/presets/pools/cashbot.tres')
			CogDNA.CogDept.LAW:
				cog_pool = load('res://objects/cog/presets/pools/lawbot.tres')
			CogDNA.CogDept.BOSS:
				cog_pool = load('res://objects/cog/presets/pools/bossbot.tres')
				
		specific_cog = cog_pool.cogs[RandomService.randi_range_channel("cog_quest_types", minimum_level, maximum_level)]
	
	# Reduce quotas for more specific quest types
	if not department == CogDNA.CogDept.NULL:
		quotaf /= 2.0
	elif specific_cog:
		quotaf /= 4.0
	
	# Level minimum objectives
	if RandomService.randi_channel('cog_quest_types') % 3 == 0:
		if specific_cog:
			min_level = RandomService.randi_range_channel('cog_quest_types',specific_cog.level_low + 1,specific_cog.level_low + 3)
			if min_level > specific_cog.level_high or min_level > maximum_level: 
				min_level = 1
		else:
			min_level = RandomService.randi_range_channel('cog_quest_types',minimum_level,maximum_level)
	
	if min_level > 1:
		quotaf /= maxf(min_level/4.0,1.25)
	
	quota = int(round(quotaf))

func battle_started(battle : BattleManager) -> void:
	battle.s_participant_died.connect(participant_died)

func participant_died(participant : Node3D) -> void:
	var cog : Cog
	if not participant is Cog or quota <= current_amount:
		return
	elif participant is Cog:
		cog = participant
	
	if specific_cog:
		if cog.fusion:
			if not specific_cog.battle_phrases.hash() == cog.dna.battle_phrases.hash():
				return
		else:
			if not specific_cog.cog_name == cog.dna.cog_name:
				return
	
	if not department == CogDNA.CogDept.NULL:
		if not cog.dna.department == department:
			return
	
	if min_level > 1:
		if cog.level < min_level:
			return
	
	# If no check has failed, quota increments
	current_amount += 1
	s_quest_updated.emit()
	
	if current_amount == quota:
		s_quest_complete.emit()

func uses_3d_model() -> bool:
	if specific_cog:
		return true

	return false

func get_3d_model() -> Node3D:
	if not specific_cog:
		return Node3D.new()

	var head: Node3D = specific_cog.get_head()
	head.scale = specific_cog.head_scale
	return head

func get_icon() -> Texture2D:
	if not department == CogDNA.CogDept.NULL:
		return Cog.get_department_emblem(department)
	else:
		return FALLBACK_ICON

func reset() -> void:
	super()
	specific_cog = null
	department = CogDNA.CogDept.NULL
	min_level = 1
