@tool
extends CogAttack
class_name UBLiabilityWaiver

const LIABILITY_WAIVER: UBLiabilityWaiverEffect = preload("res://objects/battle/battle_resources/status_effects/resources/ub_liability_waiver.tres")
const LIABILITY_WAIVER_DEFENSE: StatBoost = preload("res://objects/battle/battle_resources/status_effects/resources/ub_liability_waiver_defense.tres")

const PAPER := preload("res://models/props/cog_props/shredder_paper/shredder_paper.fbx")
const PaperPos = Vector3(-0.007, -0.731, 0.059)
const PaperRot = Vector3(22.5, 147.1, -29.7)
const PaperScale = Vector3.ONE * 0.7

const SFX_PAPER_PULL_OUT := preload("res://audio/sfx/misc/target_impact_only.ogg")
const SFX_PAPER_HIT := preload("res://audio/sfx/misc/MG_sfx_travel_game_no_bonus.ogg")

func action() -> void:
	# Get target Cog
	if targets.is_empty():
		return
	
	var target_cog: Cog = targets[0]

	var paper := PAPER.instantiate()
	user.body.right_hand_bone.add_child(paper)
	paper.position = PaperPos
	paper.rotation_degrees = PaperRot
	paper.scale = PaperScale

	# Focus Cog
	user.set_animation('throw-paper')
	battle_node.focus_character(user)
	AudioManager.play_sound(SFX_PAPER_PULL_OUT)
	
	await manager.sleep(3.1333)

	paper.reparent(battle_node)
	await user.get_tree().process_frame
	var new_pos: Vector3 = target_cog.body.nametag_node.global_position + Vector3(0, 3, 0)
	var final_pos: Vector3 = target_cog.body.nametag_node.global_position + Vector3(0, -2, 0)
	var projectile := Sequence.new([
		LerpProperty.new(paper, ^"global_position", 1.0, new_pos).interp(Tween.EASE_OUT, Tween.TRANS_QUAD),
		Parallel.new([
			LerpProperty.new(paper, ^"global_rotation", 0.4, Vector3(90, 0, 0)).interp(Tween.EASE_IN, Tween.TRANS_QUAD),
			LerpProperty.new(paper, ^"global_position", 0.6, final_pos).interp(Tween.EASE_IN, Tween.TRANS_QUAD)
		]),
	]).as_tween(user)
	await Task.delay(0.5)
	battle_node.focus_character(target_cog)
	await manager.barrier(projectile.finished, 1.0)
	paper.queue_free()
	AudioManager.play_sound(SFX_PAPER_HIT)
	
	# Apply the status effect
	var liability_waiver: UBLiabilityWaiverEffect = LIABILITY_WAIVER.duplicate()
	liability_waiver.target = target_cog
	liability_waiver.union_buster = user
	manager.add_status_effect(liability_waiver)
	
	var liability_defense: UBLiabilityWaiverDefense = LIABILITY_WAIVER_DEFENSE.duplicate()
	liability_defense.target = user
	liability_defense.liability_holder = target_cog
	manager.add_status_effect(liability_defense)
	
	await manager.sleep(4.5)
