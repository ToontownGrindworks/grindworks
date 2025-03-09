extends Node3D

signal s_dna_set

@export var skeleton: Skeleton3D
@export var animator: AnimationPlayer
@export var head_scale := 1.225

@export_category('External')
@export var wrists_and_shoes: MeshInstance3D
@export var department_emblem: Sprite3D
@export var health_meter: MeshInstance3D
@export var nametag_node: Node3D
@export var nametag: Node3D
@export var head_node: Node3D
@export var head_bone: BoneAttachment3D
@export var left_hand_bone: BoneAttachment3D
@export var right_hand_bone: BoneAttachment3D
@export var right_index_bone: BoneAttachment3D
@export var health_bone: BoneAttachment3D
@export var is_lose: bool = false
@export var color_overlay_meshes: Array[GeometryInstance3D]

## Body Parts
@onready var arms := $rig_deform/Skeleton3D/arms
@onready var hands := $rig_deform/Skeleton3D/hands
@onready var legs := $rig_deform/Skeleton3D/legs
@onready var torso := $rig_deform/Skeleton3D/torso


var head: MeshInstance3D
var head_pieces: Array[MeshInstance3D]
var override_mats: Array[StandardMaterial3D] = []
var is_mod := false
var body_color := Color.WHITE

var dna_set := false
var custom_nametag_height := 0.0

var color_overlay_mat := ColorOverlayMaterial.new()

func set_dna(dna: CogDNA):
	# Get the head
	var head_mod := dna.get_head()
	head_bone.add_child(head_mod)
	
	if is_lose:
		head_mod.rotation_degrees.x = -90
		head_mod.rotation_degrees.y = -180.0
	else:
		head_mod.rotation_degrees.x += 90.0
		
	head_mod.scale *= head_scale * dna.head_scale
	# Rotated so swap y and z
	head_mod.position = Vector3(dna.head_pos.x, dna.head_pos.z, dna.head_pos.y)
	for child in head_mod.get_children():
		if child is MeshInstance3D:
			head = child

	if not head:
		# Mole cog exclusion! Yay!
		# Should also support other, more weird head types.
		head_pieces.assign(NodeGlobals.get_children_of_type(head_mod, MeshInstance3D, true))

	scale *= dna.scale
	
	if dna.head_shader:
		dna.head_shader.apply_shader(head)

	# SUIT TEXTURE
	# Get the current working materials
	var torso_mat: StandardMaterial3D = torso.mesh.surface_get_material(0).duplicate()
	var leg_mat: StandardMaterial3D = legs.mesh.surface_get_material(0).duplicate()
	var sleeve_mat: StandardMaterial3D = arms.mesh.surface_get_material(0).duplicate()
	var wrist_mat: StandardMaterial3D = wrists_and_shoes.mesh.surface_get_material(0).duplicate()
	var hand_mat: StandardMaterial3D = hands.mesh.surface_get_material(0).duplicate()
	var shoe_mat: StandardMaterial3D = wrists_and_shoes.mesh.surface_get_material(1).duplicate()
	
	# Get textures
	var torso_tex: Texture2D = torso_mat.albedo_texture
	var sleeve_tex: Texture2D = sleeve_mat.albedo_texture
	var leg_tex: Texture2D = leg_mat.albedo_texture
	var wrist_tex: Texture2D = wrist_mat.albedo_texture
	var hand_tex: Texture2D = hand_mat.albedo_texture
	var shoe_tex: Texture2D = shoe_mat.albedo_texture
	
	# Get department name (not convoluted)
	var dept = CogDNA.CogDept.keys()[int(dna.department)].to_lower()
	# Get each texture for department suits
	torso_tex = load("res://models/cogs/textures/" + dept + "/blazer.png")
	sleeve_tex = load("res://models/cogs/textures/" + dept + "/sleeve.png")
	leg_tex = load("res://models/cogs/textures/" + dept + "/leg.png")
	
	# Allow for custom textures
	torso_tex = load_custom_texture(torso_tex, dna.custom_blazer_tex, dna.external_assets, 'blazer_texture')
	sleeve_tex = load_custom_texture(sleeve_tex, dna.custom_arm_tex, dna.external_assets, 'arm_texture')
	leg_tex = load_custom_texture(leg_tex, dna.custom_leg_tex, dna.external_assets, 'leg_texture')
	wrist_tex = load_custom_texture(wrist_tex, dna.custom_wrist_tex, dna.external_assets, 'wrist_texture')
	hand_tex = load_custom_texture(hand_tex, dna.custom_hand_tex, dna.external_assets, 'hand_texture')
	shoe_tex = load_custom_texture(shoe_tex, dna.custom_shoe_tex, dna.external_assets, 'shoe_texture')
	
	# Replace albedo textures
	torso_mat.albedo_texture = torso_tex
	sleeve_mat.albedo_texture = sleeve_tex
	leg_mat.albedo_texture = leg_tex
	wrist_mat.albedo_texture = wrist_tex
	hand_mat.albedo_texture = hand_tex
	hand_mat.albedo_color = dna.hand_color # Color our hand material
	shoe_mat.albedo_texture = shoe_tex
	
	# Place textures onto body parts
	torso.set_surface_override_material(0, torso_mat)
	legs.set_surface_override_material(0, leg_mat)
	arms.set_surface_override_material(0, sleeve_mat)
	wrists_and_shoes.set_surface_override_material(0, wrist_mat)
	hands.set_surface_override_material(0, hand_mat)
	wrists_and_shoes.set_surface_override_material(1, shoe_mat)

	# Add head mats to the override mats for color
	if head:
		for i in head.mesh.get_surface_count():
			override_mats.append(head.get_surface_override_material(i))
		head.material_overlay = color_overlay_mat
	elif head_pieces:
		for head_piece: MeshInstance3D in head_pieces:
			for i in head_piece.mesh.get_surface_count():
				override_mats.append(head_piece.get_surface_override_material(i))
			head_piece.material_overlay = color_overlay_mat
	
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			for i in child.mesh.get_surface_count():
				var mat = child.get_surface_override_material(i)
				if mat == null:
					var new_mat: StandardMaterial3D = child.mesh.surface_get_material(i).duplicate()
					child.set_surface_override_material(i,new_mat)
					override_mats.append(new_mat)
				else:
					override_mats.append(child.get_surface_override_material(i))

	is_mod = dna.is_mod_cog
	custom_nametag_height = dna.custom_nametag_height
	dna_set = true
	s_dna_set.emit()

	for mesh: GeometryInstance3D in color_overlay_meshes:
		mesh.material_overlay = color_overlay_mat

# Helper function to load custom textures
func load_custom_texture(source, internal, external, external_name):
	if internal:
		return internal
	elif external.has(external_name) and external[external_name] != "":
		return ImageTexture.create_from_image(Image.load_from_file(external[external_name]))
	return source

# Colors every mesh of the body
func set_color(color: Color) -> void:
	body_color = color
	for mat in override_mats:
		mat.albedo_color = color
		if color.a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

func flash_instant(color: Color, time: float = 0.2, strength: float = 0.7) -> void:
	if color_overlay_mat:
		color_overlay_mat.flash_instant(self, color, time, strength)

func flash(color: Color, time: float = 0.2, strength: float = 0.7) -> void:
	if color_overlay_mat:
		color_overlay_mat.flash(self, color, time, strength)
