@tool
extends StatEffectRegeneration
class_name StatEffectPoison

const COG_PARTICLES := preload("res://objects/battle/effects/poison/poison_cog.tscn")

var particles: GPUParticles3D

## Poison effects only trigger at round ends
func apply() -> void:
	if target is Cog:
		place_particles(target.body.health_bone, COG_PARTICLES)

func place_particles(who: Node3D, particle_scene: PackedScene) -> void:
	particles = particle_scene.instantiate()
	if who.get_node_or_null(NodePath(particles.name)):
		var old_particles: Node = who.get_node(NodePath(particles.name))
		old_particles.set_name("removing")
		old_particles.queue_free()
	who.add_child(particles)

func renew() -> void:
	# Don't do movie for dead actors
	if not is_instance_valid(target) or target.stats.hp <= 0:
		return
	
	manager.battle_node.focus_character(target)
	manager.affect_target(target, 'hp', amount, false)
	if target is Player:
		target.set_animation('cringe')
	else:
		target.set_animation('pie-small')
	await manager.sleep(3.0)
	await manager.check_pulses([target])

func expire() -> void:
	if is_instance_valid(particles):
		particles.queue_free()

func get_status_name() -> String:
	return "Poison"

func combine(effect: StatusEffect) -> bool:
	if effect.rounds == rounds:
		amount += effect.amount
		return true
	return false
