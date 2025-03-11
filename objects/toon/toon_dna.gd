extends Resource
class_name ToonDNA


## Body Type
enum BodyType {
	SMALL,
	MEDIUM,
	LARGE
}
@export var body_type := BodyType.SMALL

## Species
enum ToonSpecies {
	BEAR,
	CAT,
	DOG,
	DUCK,
	HORSE,
	MONKEY,
	MOUSE,
	PIG,
	RABBIT
}
@export var species := ToonSpecies.DOG
@export var head_index := 0
@export var eyelashes := true
@export var skirt := false

const SPECIES_SCALE := {
	ToonSpecies.BEAR : 1.0,
	ToonSpecies.CAT : 0.86,
	ToonSpecies.DOG : 1.0,
	ToonSpecies.DUCK : 0.78,
	ToonSpecies.HORSE : 1.0,
	ToonSpecies.MONKEY : 0.8,
	ToonSpecies.MOUSE : 0.7,
	ToonSpecies.PIG : 0.9,
	ToonSpecies.RABBIT : 0.87
}
## This is an adjustment to make the Dog (normally 0.85) scale be at 1.0
const BASE_SCALE := 1.17647058824

## Colors
@export var head_color := Color.WHITE
@export var torso_color := Color.WHITE
@export var leg_color := Color.WHITE

## Textures
@export var shirt : ToonShirt
@export var bottoms : ToonBottoms

func randomize_dna() -> void:
	body_type = randi()%BodyType.keys().size() as BodyType
	species = randi()%ToonSpecies.keys().size() as ToonSpecies
	if species == ToonSpecies.MOUSE:
		head_index = randi()%2
	else:
		head_index = randi()%4
	head_color = Globals.random_dna_color
	#2/3 chance of solid body color
	if randi()%3==0:
		torso_color = Globals.random_dna_color
		leg_color = Globals.random_dna_color
	else:
		torso_color = head_color
		leg_color = head_color
	eyelashes = randi()%2==0
	skirt = randi()%2==0
	
	# Random Clothing
	if skirt:
		bottoms = Globals.random_skirt.duplicate()
	else:
		bottoms = Globals.random_shorts.duplicate()
	shirt = Globals.random_shirt.duplicate()
	
	# Random clothing colors
	if bottoms.color_type == ToonClothing.ColorType.RECOLORABLE:
		bottoms.base_color = Globals.random_dna_color
	if shirt.color_type == ToonClothing.ColorType.RECOLORABLE:
		shirt.base_color = Globals.random_dna_color
		shirt.sleeve_color = shirt.base_color
