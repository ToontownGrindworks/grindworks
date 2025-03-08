extends Control


const TEX_LOCKED := preload('res://ui_assets/misc/lock.png')
const TEX_UNLOCKED := preload('res://ui_assets/misc/unlock.png')

const SAD_COLOR = Color("75a34b")

## HP values
@export var max_laff := 15:
	set(x):
		max_laff = x
		update_hp()
@export var laff := 15:
	set(x):
		laff = x
		update_hp()
@export var extra_lives := 0:
	set(x):
		extra_lives = x
		update_extra_lives()

## Child references
@onready var meter := $Anchor/Meter
@onready var dead_face := $Anchor/Meter/Dead
@onready var healthy_face := $Anchor/Meter/Healthy
@onready var grin := $Anchor/Meter/Healthy/Grin
@onready var mouth := $Anchor/Meter/Healthy/Mouth
@onready var laff_eye := $Anchor/Meter/Healthy/Eyes/Health
@onready var max_eye := $Anchor/Meter/Healthy/Eyes/MaxHealth
@onready var animator := $AnimationPlayer

## Locals
var visible_teeth := 6

## For Laff-Lock
var lock_enabled := false:
	set(x):
		lock_enabled = x
		%Lock.visible = x
var locked := false:
	set(x):
		locked = x
		if x:
			%Lock.set_texture(TEX_LOCKED)
		else:
			%Lock.set_texture(TEX_UNLOCKED)

var obscured := false:
	set(x):
		obscured = x
		await NodeGlobals.until_ready(self)
		update_hp()

func _ready() -> void:
	update_hp()

func update_hp():
	# Update eye text
	if obscured:
		laff_eye.set_text("?")
		max_eye.set_text("?")
	else:
		laff_eye.set_text(str(laff))
		max_eye.set_text(str(max_laff))
	
	# Show grin/mouth
	if laff >= max_laff:
		if mouth.visible:
			grin.show()
			mouth.hide()
			animator.play('bounce')
		return
	elif laff > 0:
		if dead_face.visible:
			dead_face.hide()
			healthy_face.show()
			meter.self_modulate = Util.get_player().toon.toon_dna.head_color
		if grin.visible:
			mouth.show()
			grin.hide()
			animator.play('bounce')
	else:
		healthy_face.hide()
		meter.self_modulate = SAD_COLOR
		dead_face.show()
	
	# Calculate visible teeth
	var teeth_ratio := float(laff) / float(max_laff)
	var new_visible_teeth := 0
	while (1.0 / 6.0) * new_visible_teeth < teeth_ratio:
		new_visible_teeth += 1

	# Bounce if tooth amount changed
	if new_visible_teeth != visible_teeth:
		visible_teeth = new_visible_teeth
		animator.play('bounce')

	# Make only the visible teeth visible
	for i in mouth.get_child_count():
		mouth.get_child(i).visible = i < visible_teeth

func set_laff(hp: int):
	laff = hp
	DiscordManager.update_presence()


func set_max_laff(hp: int):
	max_laff = hp
	laff = laff
	DiscordManager.update_presence()

func update_extra_lives() -> void:
	%ReviveLabel.text = "x%s" % extra_lives
	%ReviveLabel.visible = extra_lives >= 1

## Sets the laff meter depending on Toon species
func set_meter(dna: ToonDNA) -> void:
	var species_name: String = ToonDNA.ToonSpecies.keys()[dna.species].to_lower()
	meter.texture = load(Globals.laff_meters[species_name])
	meter.self_modulate = dna.head_color

func hover() -> void:
	if Util.get_player() and Util.get_player().character:
		var player_char: PlayerCharacter = Util.get_player().character
		var char_name: String
		if player_char.random_character_stored_name:
			char_name = player_char.random_character_stored_name
		else:
			char_name = player_char.character_name
		var char_desc := player_char.character_summary
		var char_color := player_char.dna.head_color
		HoverManager.hover(char_desc, 18, 0.025, char_name, char_color.darkened(0.3))

func stop_hover() -> void:
	HoverManager.stop_hover()
