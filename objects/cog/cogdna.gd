extends Resource
class_name CogDNA

enum CogDept {
	SELL,
	CASH,
	LAW,
	BOSS,
	NULL,
}
@export var department := CogDept.SELL

enum SuitType {
	SUIT_A,
	SUIT_B,
	SUIT_C
}
@export var suit := SuitType.SUIT_A

@export var custom_blazer_tex: Texture2D
@export var custom_arm_tex: Texture2D
@export var custom_leg_tex: Texture2D
@export var custom_wrist_tex: Texture2D
@export var custom_hand_tex: Texture2D
@export var custom_shoe_tex: Texture2D
@export var custom_emblem_tex: Texture2D

@export var cog_name: String = "Cog"
@export var name_plural: String = ""
@export var head: PackedScene
@export var head_scale: Vector3 = Vector3.ONE
@export var head_pos: Vector3 = Vector3.ZERO
@export var scale: float = 1.0
@export var head_textures: Array[Texture2D]
@export var head_shader: CogShader
@export var hand_color: Color = Color.WHITE
@export var head_color: Color = Color.WHITE
@export var custom_nametag_height := 0.0
@export var custom_nametag_suffix := ""

@export var attacks: Array[CogAttack]
@export var level_low := 1
@export var level_high := 12
@export var status_effects: Array[StatusEffect]
@export var is_mod_cog := false
@export var is_admin := false
@export var health_mod := 1.0

@export_multiline var battle_phrases: Array[String] = ["We are gonna fight now."]
@export var battle_start_movie: BattleStartMovie

@export var external_assets := {
	head_model = "",
	head_textures = [],
	blazer_texture = "",
	arm_texture = "",
	leg_texture = "",
	wrist_texture = "",
	hand_texture = "",
	shoe_texture = "",
	emblem_texture = ""
}

func get_head() -> Node3D:
	var head_mod: Node3D
	if head:
		head_mod = head.instantiate()
	elif external_assets['head_model'] in Globals.custom_cog_head_directory.keys():
		head_mod = Globals.custom_cog_head_directory.get(external_assets['head_model']).instantiate()
	else:
		head_mod = load(DEFAULT_HEAD).instantiate()
	
	var head_tex := head_textures.duplicate()
	for path in external_assets['head_textures']:
		head_tex.append(ImageTexture.create_from_image(Image.load_from_file(path)))
	
	var head_mesh: MeshInstance3D
	
	for child in head_mod.get_children():
		if child is MeshInstance3D:
			head_mesh = child
	if head_mesh:
		for i in head_mesh.mesh.get_surface_count():
			if not head_mesh.mesh.surface_get_material(i):
				continue
			var mat: StandardMaterial3D = head_mesh.mesh.surface_get_material(i).duplicate()
			if head_tex.size() > i:
				mat.albedo_texture = head_tex[i]
			mat.albedo_color = head_color
			head_mesh.set_surface_override_material(i,mat)
	
	return head_mod

func combine_attributes(second_dna: CogDNA) -> void:
	# Copy certain attributes from the second DNA to self
	head = second_dna.head
	head_textures = second_dna.head_textures
	hand_color = second_dna.hand_color
	if not second_dna.head_color == Color.WHITE:
		head_color = second_dna.head_color

## Create epic fusion name
func combine_names(name1: String, name2: String) -> String:
	var prefix := ""
	var suffix := ""
	
	# Contains the suffixes of every single-word Cog name.
	var extra_suffixes: Array[String] = [
		"wad", "-Face", "sucker", "marketer", "man",
		"cog", "hander", "sizer", "manager", "-Talker",
		
	]
	
	# Get prefix from the first name
	match name1:
		"The Big Cheese":
			prefix = "The Big"
		_:
			prefix = name1.split(" ")[0]
	
	# Get suffix from second name
	if name2.split(" ").size() == 3:
		suffix = name2.split(" ")[2]
	elif name2.split(" ").size() == 1:
		suffix = name2
	else:
		suffix = " " +name2.split(" ")[1]
	
	# Parse single-word names for prefixes
	for extra_suffix in extra_suffixes:
		if prefix.ends_with(extra_suffix):
			prefix = prefix.rstrip(extra_suffix)
	
	# Parse single-word names for suffixes
	for extra_suffix in extra_suffixes:
		if suffix.ends_with(extra_suffix):
			# Add a space after Mr.
			if prefix == "Mr.":
				suffix = " "
				# Mr. Face
				if extra_suffix == "-Face":
					suffix += 'Face'
				else:
					suffix += extra_suffix
					suffix[0] = suffix[0].to_upper()
			else:
				suffix = extra_suffix
			break
	
	if prefix == "Mr.":
		suffix[0] = suffix[0].to_upper()
		suffix = suffix.insert(0," ")
	
	# Return combined name
	return prefix + suffix

# Helper function to load custom textures
func load_custom_texture(source, internal, external):
	if internal:
		return internal
	elif external_assets.has(external) and external_assets[external] != "":
		return ImageTexture.create_from_image(Image.load_from_file(external_assets[external]))
	return source

func get_plural_name() -> String:
	if not name_plural == "": return name_plural
	return cog_name + "s"

const DEFAULT_HEAD := "res://models/cogs/heads/flunky.glb"
