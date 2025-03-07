@tool
extends Node3D

const PLANE_OCCLUDER := preload('res://general_resources/shaders/plane_occluder.gdshader')

@export_custom(PROPERTY_HINT_NONE, '', PROPERTY_USAGE_EDITOR) var show_debug_visualizer := true:
	set(new):
		show_debug_visualizer = new
		$DebugVisualizer.visible = show_debug_visualizer
		
var plane := Vector3(0, 1, 0)

@onready var last_plane_normal := plane
@onready var last_position := global_position
var active_occluders: Dictionary[String, ShaderMaterial]
var surface_material_swaps: Dictionary[MeshInstance3D, Array]

# Called when the node enters the scene tree for the first time.
func _ready():
	if not Engine.is_editor_hint():
		$DebugVisualizer.queue_free()

func _process(delta: float):
	if last_position != global_position:
		for occluder in active_occluders.values():
			occluder.set_shader_parameter('plane_position', global_position)
		last_position = global_position
	if last_plane_normal != plane:
		# TODO: Not just plane, but also our rotation
		for occluder in active_occluders.values():
			occluder.set_shader_parameter('plane_normal', plane)
		last_plane_normal = plane

func add_plane_occluder_shader(name: String, transparent := false, cull_disabled := false, render_priority := 0) -> ShaderMaterial:
	var occluder := PLANE_OCCLUDER.duplicate()
	if transparent:
		occluder.code = '#define USE_ALPHA\n' + occluder.code
	if cull_disabled:
		occluder.code = occluder.code.replace(
			'shader_type spatial;', 'shader_type spatial;\nrender_mode cull_disabled;'
		)
	var material := ShaderMaterial.new()
	material.shader = occluder
	material.render_priority = render_priority
	active_occluders[name] = material
	return material
		
func apply_to_mesh_instances(mesh_instances: Array[MeshInstance3D]):
	for mesh_instance in mesh_instances:
		if not mesh_instance:
			continue
		
		surface_material_swaps[mesh_instance] = []
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var surface_material := mesh_instance.mesh.surface_get_material(surface_index)
			var override := mesh_instance.get_surface_override_material(surface_index)
			var material: BaseMaterial3D
			#var shader := ShaderMaterial.new()
			#shader.set_shader_parameter('plane_position', global_position)
			if override is BaseMaterial3D:
				surface_material_swaps[mesh_instance].append(override)
				material = override
			elif surface_material is BaseMaterial3D:
				surface_material_swaps[mesh_instance].append(null)
				material = surface_material
			else:
				surface_material_swaps[mesh_instance].append(null)
			
			var transparency := material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			var cull_disabled := material.cull_mode == BaseMaterial3D.CULL_DISABLED
			var render_priority := 1 if 'pupil' in mesh_instance.name else 0
			
			var shader := add_plane_occluder_shader(
				mesh_instance.name, transparency, cull_disabled, render_priority
			)
			shader.set_shader_parameter('albedo_texture', material.albedo_texture)
			shader.set_shader_parameter('albedo_color', material.albedo_color)
			shader.set_shader_parameter('use_vertex_color_as_albedo', material.vertex_color_use_as_albedo)
			mesh_instance.set_surface_override_material(surface_index, shader)
		
func apply_to_node_recursively(node: Node3D):
	apply_to_mesh_instances(
		node.find_children('*', 'MeshInstance3D', true, false) as Array[MeshInstance3D]
	)

func unapply_from_mesh_instances(mesh_instances: Array[MeshInstance3D]):
	for mesh_instance in mesh_instances:
		if mesh_instance not in surface_material_swaps:
			continue
			
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			if surface_index >= surface_material_swaps.size():
				break
			mesh_instance.set_surface_override_material(
				surface_index,
				surface_material_swaps[mesh_instance][surface_index]
			)
		surface_material_swaps.erase(mesh_instance)

func unapply_from_node(node: Node3D):
	unapply_from_mesh_instances(
		node.find_children('*', 'MeshInstance3D', true, false) as Array[MeshInstance3D]
	)
