extends Item
class_name ItemAccessory


@export var accessory_placements: Array[AccessoryPlacement]

## Returns the correct placement of the accessory based on head and body
static func get_placement(item: ItemAccessory, dna: ToonDNA) -> AccessoryPlacement:
	if item.slot == ItemSlot.BACKPACK:
		for placement in item.accessory_placements:
			if placement is AccessoryPlacementBody and placement.body_type == dna.body_type:
				return placement
	else:
		for placement in item.accessory_placements:
			if placement is AccessoryPlacementHead:
				if placement.species == dna.species and placement.head_index == dna.head_index:
					return placement
	return null

static func get_bone(item: ItemAccessory, player: Player) -> BoneAttachment3D:
	if not player:
		return null
	
	match item.slot:
		ItemSlot.HAT:
			return player.toon.hat_bone
		ItemSlot.GLASSES:
			return player.toon.glasses_bone
		ItemSlot.BACKPACK:
			return player.toon.backpack_bone
	
	return null


func apply_item(player: Player) -> void:
	super(player)
	
	if not player.is_node_ready():
		await player.ready
	
	var mod := model.instantiate()
	var bone := ItemAccessory.get_bone(self,player)
	for accessory in bone.get_children():
		accessory.queue_free()
	bone.add_child(mod)
	var placement := ItemAccessory.get_placement(self,player.toon.toon_dna)
	mod.position = placement.position
	mod.rotation_degrees = placement.rotation
	mod.scale = placement.scale
	if mod.has_method('setup'):
		mod.setup(self)
