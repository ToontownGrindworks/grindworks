extends CogAttack
class_name PickPocket

@export var do_money_steal := false

func action():
	# Setup
	var hit := manager.roll_for_accuracy(self)
	var target : Player = targets[0]
	user.face_position(target.global_position)
	var dollar : Node3D
	if hit:
		dollar = load("res://models/props/gags/fishing_rod/dollar_bill.tscn").instantiate()
		user.body.right_hand_bone.add_child(dollar)
		dollar.rotation_degrees.x += 180
	AudioManager.play_sound(load('res://audio/sfx/battle/cogs/attacks/SA_pick_pocket.ogg'))
	user.set_animation('pickpocket')
	manager.s_focus_char.emit(user)
	
	# Base toon anim on whether target was hit
	if hit:
		target.set_animation('cringe')
	else:
		target.set_animation('sidestep_left')
		
	
	# Swap camera angle after 0.5 seconds
	await manager.sleep(0.5)
	manager.s_focus_char.emit(target)
	
	# Affect target, or don't
	if hit:
		var money_stolen := 0
		if do_money_steal:
			money_stolen = steal_money(target, damage)
		if money_stolen == 0:
			manager.affect_target(target,'hp',damage,false)
	else:
		manager.battle_text(target,"MISSED")
	
	await manager.barrier(user.animator.animation_finished, 4.0)
	
	# Delete dollar
	if dollar:
		dollar.queue_free()
	
	await manager.check_pulses(targets)

## Steals money. Returns the amount of money successfully stolen
func steal_money(who : Player, quantity : int) -> int:
	var original_balance := who.stats.money
	who.stats.money = max(0, who.stats.money - quantity)
	var total_stolen := original_balance - who.stats.money
	
	if total_stolen > 0:
		manager.battle_text(who, "-%d Jellybeans!" % total_stolen, BattleText.colors.orange[0], BattleText.colors.orange[1])
	return total_stolen
	
