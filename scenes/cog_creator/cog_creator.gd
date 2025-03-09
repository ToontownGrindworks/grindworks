extends Control

const COG_SAVE_PATH := "user://save/custom_cogs/"
const COG_HEAD_PATH := "res://models/cogs/heads/"
const TITLE_SCENE := "res://scenes/title_screen/title_screen.tscn"

@export var safe_cogs : CogPool
@export var suit_a_attacks : Array[CogAttack] = []
@export var suit_b_attacks : Array[CogAttack] = []
@export var suit_c_attacks : Array[CogAttack] = []

@onready var menus := $Menus.get_children()
@onready var cog : Cog = $World3D/Cog
@onready var mouse_blocker : Panel = $MouseBlocker

var menu_index := 0


func _ready() -> void:
	Globals.import_custom_cogs()
	
	# Duplicate the Cog's DNA so we aren't editing anything important wink wink
	cog.set_dna(safe_cogs.cogs[RandomService.randi_channel('true_random') % safe_cogs.cogs.size()].duplicate())
	cog.set_animation("neutral")
	
	_prepare_menus()

func _prepare_menus() -> void:
	_ready_header()
	_ready_body()
	_ready_head_mod()
	_ready_head_tex()
	_ready_colors()
	_ready_attribute()
	_ready_attacks()
	_ready_phrases()


#region TOP LEVEL MENU
@onready var next_menu_button : GeneralButton = $FooterButtons/NextMenuButton
@onready var prev_menu_button : GeneralButton = $FooterButtons/PrevMenuButton
@onready var file_opener : DirectoryViewer = $Opener
@onready var delete_button : GeneralButton = $Opener/DeleteButton
@onready var help_menu : Panel = $HelpMenu
@onready var help_menu_pages : Array[Node] = $HelpMenu/Panel/Pages.get_children()
@onready var help_next_button : GeneralButton = $HelpMenu/Panel/NextMenuButton
@onready var help_prev_button : GeneralButton = $HelpMenu/Panel/PrevMenuButton

var opened_file := ""

func _ready_header() -> void:
	populate_dna_files()
	if SaveFileService.progress_file.needs_custom_cog_help:
		help_pressed()
		SaveFileService.progress_file.needs_custom_cog_help = false

func populate_dna_files() -> void:
	var files : Array[UIFile] = []
	for file_name in DirAccess.get_files_at(COG_SAVE_PATH):
		if not file_name.get_extension() == "tres":
			continue
		var loaded_file = ResourceLoader.load(COG_SAVE_PATH + file_name)
		if loaded_file is CogDNA:
			var new_file := UIFile.new()
			new_file.file_path = COG_SAVE_PATH + file_name
			new_file.icon = await Util.get_cog_head_icon(loaded_file)
			files.append(new_file)
	file_opener.show_custom_file_list(files)
	attach_delete_buttons()

func attach_delete_buttons() -> void:
	for child : FileDisplayer in file_opener.file_grid.get_children():
		var new_button : GeneralButton = delete_button.duplicate()
		child.add_child(new_button)
		new_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT,Control.PRESET_MODE_KEEP_SIZE)
		new_button.show()
		new_button.pressed.connect(delete_file.bind(child.file.file_path))

func delete_file(file_path : String) -> void:
	DirAccess.remove_absolute(file_path)
	populate_dna_files()

func next_menu() -> void:
	set_menu(menu_index + 1)

func prev_menu() -> void:
	set_menu(menu_index - 1)

func set_menu(index : int) -> void:
	for i in menus.size():
		if i == index:
			menus[i].show()
		else:
			menus[i].hide()
	menu_index = index
	
	prev_menu_button.disabled = index == 0
	next_menu_button.disabled = index == menus.size() - 1

func new_pressed() -> void:
	cog.randomize_cog()
	opened_file = ""
	_prepare_menus()

func save_file() -> void:
	ResourceSaver.save(cog.dna, cog_to_file_name(cog.dna.cog_name))
	populate_dna_files()
	Globals.import_cog_dna()

func exit_pressed() -> void:
	SceneLoader.load_into_scene(TITLE_SCENE)

func open_pressed() -> void:
	files_loading()
	file_opener.show()

func close_open_menu() -> void:
	file_opener.hide()
	files_finished_loading()

func open_file(file : UIFile) -> void:
	close_open_menu()
	cog.set_dna(ResourceLoader.load(file.file_path).duplicate())
	_prepare_menus()
	opened_file = file.file_path

func cog_to_file_name(cog_name : String) -> String:
	if opened_file == "":
		cog_name = (cog_name.replace(" ", "_")).to_lower()
		var file_name := cog_name
		var try := 1
		while FileAccess.file_exists(COG_SAVE_PATH + file_name + ".tres"):
			file_name = cog_name + "_%d" % try
		opened_file = COG_SAVE_PATH + file_name + ".tres"
	return opened_file

func help_pressed() -> void:
	help_menu.show()

func next_help() -> void:
	set_help_page(get_help_index() + 1)

func prev_help() -> void:
	set_help_page(get_help_index() - 1)

func close_help() -> void:
	set_help_page(0)
	help_menu.hide()

func get_help_index() -> int:
	for i in help_menu_pages.size():
		if help_menu_pages[i].visible:
			return i
	return -1

func set_help_page(index : int) -> void:
	for i in help_menu_pages.size():
		if i == index:
			help_menu_pages[i].show()
		else:
			help_menu_pages[i].hide()
	help_prev_button.set_disabled(index <= 0)
	help_next_button.set_disabled(index >= help_menu_pages.size() - 1)

func rotation_changed(new_rot : float) -> void:
	cog.rotation_degrees.y = 180 + new_rot

#endregion

#region BODY TYPE
@onready var body_scroller : ScrollButton = $Menus/BodySelector/OptionContainer/BodyScroller
@onready var department_scroller : ScrollButton = $Menus/BodySelector/OptionContainer/DepartmentScroller
@onready var scale_slider : HSlider = $Menus/BodySelector/OptionContainer/Scaler/ScaleSlider
@onready var scale_label : Label = $Menus/BodySelector/OptionContainer/Scaler/ScaleLabel

func _ready_body() -> void:
	body_scroller.option_index = cog.dna.suit as int
	department_scroller.option_index = cog.dna.department as int
	update_scale(cog.dna.scale)

func on_body_type_changed(index : int) -> void:
	cog.dna.suit = index as CogDNA.SuitType
	_refresh_cog()

func on_department_changed(index : int) -> void:
	cog.dna.department = index as CogDNA.CogDept
	_refresh_cog()

func update_scale(new_scale : float) -> void:
	cog.dna.scale = new_scale
	scale_slider.value = new_scale
	scale_label.set_text("Scale: %2.2f" % new_scale)
	_refresh_cog()
#endregion

#region HEAD MODEL SELECTOR
@export var head_model_files : Array[PackedScene]

@onready var head_model_directory : DirectoryViewer = $Menus/HeadModelSelector/HeadModDirectory

var head_models: Array[UIFile] = []

func _ready_head_mod() -> void:
	head_models.clear()
	gather_head_models()

func gather_head_models() -> void:
	for head in head_model_files:
		await append_cog_head(head)
	for head in Globals.custom_cog_head_directory:
		await append_cog_head(Globals.custom_cog_head_directory[head])
	
	head_model_directory.show_custom_file_list(head_models)

func append_cog_head(head : PackedScene) -> void:
	var new_file := UIModelFile.new()
	new_file.file_path = head.resource_path
	new_file.model = head
	new_file.icon = await Util.get_ortho_model_tex(head)
	head_models.append(new_file)

func set_head(file : UIModelFile) -> void:
	if file.file_path.begins_with("res://"):
		cog.dna.head = file.model
	else:
		cog.dna.head = null
		cog.dna.external_assets['head_model'] = file.file_path
	_refresh_cog()

func new_head_loaded(head : Variant, file_path : String) -> void:
	if not head is Node3D:
		printerr("Loaded head model not in proper format.")
		return
	var new_file := UIModelFile.new()
	new_file.icon = await Util.get_ortho_model_tex(head)
	var packed_scene := PackedScene.new()
	packed_scene.pack(head)
	new_file.model = packed_scene
	new_file.file_path = file_path
	head_models.append(new_file)
	head_model_directory.show_custom_file_list(head_models)
	Globals.custom_cog_head_directory[file_path] = packed_scene

#endregion

#region HEAD TEXTURE SELECTOR
@export var head_texture_files : Array[Texture2D]

@onready var head_tex_directory : DirectoryViewer = $Menus/HeadTextureSelector/HeadTexDirectory

var head_textures : Array[UIFile] = []

func _ready_head_tex() -> void:
	head_textures.clear()
	gather_head_textures()

func gather_head_textures() -> void:
	for tex : Texture2D in head_texture_files:
		var file := UIFile.new()
		file.file_path = tex.resource_path
		file.icon = tex
		head_textures.append(file)
	for tex in Globals.custom_cog_tex_directory:
		var file := UIFile.new()
		file.file_path = tex
		file.icon = Globals.custom_cog_tex_directory[tex]
		head_textures.append(file)
	head_tex_directory.show_custom_file_list(head_textures)

func set_head_texture(file : UIFile) -> void:
	if file.file_path.begins_with("res://"):
		cog.dna.head_textures = [load(file.file_path)]
	else:
		cog.dna.head_textures = []
		cog.dna.external_assets['head_textures'] = [file.file_path]
	
	_refresh_cog()

func new_texture_loaded(texture : Variant, file_path : String) -> void:
	if not texture is Texture2D:
		printerr("Loaded texture not in proper format!")
	var new_file := UIFile.new()
	new_file.icon = texture
	new_file.file_path = file_path
	head_textures.append(new_file)
	head_tex_directory.show_custom_file_list(head_textures)
	Globals.custom_cog_tex_directory[file_path] = texture

func reset_textures() -> void:
	cog.dna.head_textures.clear()
	cog.dna.external_assets['head_textures'].clear()
	_refresh_cog()

#endregion

#region SUIT TEXTURE SELECTOR
@export var suits : Array[Dictionary]

func suit_changed(index : int) -> void:
	var suit := suits[index]
	cog.dna.custom_arm_tex = suit['custom_arm_tex']
	cog.dna.custom_blazer_tex = suit['custom_blazer_tex']
	cog.dna.custom_leg_tex = suit['custom_leg_tex']
	_refresh_cog()

#endregion

#region COLORING SELECTION
@onready var head_color_button : ColorPickerButton = $Menus/BodyColors/OptionContainer/HeadColor/ColorPickerButton
@onready var hand_color_button : ColorPickerButton = $Menus/BodyColors/OptionContainer/HandColor/ColorPickerButton

func _ready_colors() -> void:
	head_color_button.color = cog.dna.head_color
	hand_color_button.color = cog.dna.hand_color

func set_head_color(color : Color) -> void:
	cog.dna.head_color = color
	_refresh_cog()

func set_hand_color(color : Color) -> void:
	cog.dna.hand_color = color
	_refresh_cog()

#endregion

#region ATTRIBUTE SELECTION
@onready var name_editor : LineEdit = $Menus/AtrributeSelectors/VBoxContainer/NameSelector/LineEdit
@onready var name_plural_editor : LineEdit = $Menus/AtrributeSelectors/VBoxContainer/NameSelectorPlural/LineEdit
@onready var level_min_slider : HSlider = $Menus/AtrributeSelectors/VBoxContainer/LevelMinimum/HSlider
@onready var level_min_label : Label = $Menus/AtrributeSelectors/VBoxContainer/LevelMinimum/Label
@onready var level_max_slider : HSlider = $Menus/AtrributeSelectors/VBoxContainer/LevelMaximum/HSlider
@onready var level_max_label : Label = $Menus/AtrributeSelectors/VBoxContainer/LevelMaximum/Label
@onready var proxy_button : CheckBox = $Menus/AtrributeSelectors/VBoxContainer/ProxyToggle/CheckBox


func _ready_attribute() -> void:
	name_editor.set_text(cog.dna.cog_name)
	level_max_slider.set_value(cog.dna.level_high)
	level_min_slider.set_value(cog.dna.level_low)
	refresh_plural_name()
	proxy_button.set_pressed(cog.dna.is_mod_cog)

func set_cog_name(new_name : String) -> void:
	cog.dna.cog_name = new_name
	_refresh_cog()
	refresh_plural_name()

func refresh_plural_name() -> void:
	name_plural_editor.placeholder_text = cog.dna.cog_name + "s"

func set_plural_name(new_name : String) -> void:
	cog.dna.name_plural = new_name

func set_minimum_level(value : float) -> void:
	level_min_label.set_text("Minimum Level: %d" % value)
	cog.dna.level_low = round(value)
	if value > level_max_slider.value:
		level_max_slider.set_value(value)
	if cog.level < cog.dna.level_low:
		_refresh_cog()

func set_maximum_level(value : float) -> void:
	level_max_label.set_text("Maximum Level: %d" % value)
	cog.dna.level_high = round(value)
	if value < level_min_slider.value:
		level_min_slider.set_value(value)
	if cog.level > cog.dna.level_high:
		_refresh_cog()

const PROXY_EFFECT := preload('res://objects/battle/battle_resources/status_effects/resources/status_effect_mod_cog.tres')
func proxy_toggled(yes : bool) -> void:
	if yes:
		cog.dna.is_mod_cog = true
		cog.dna.status_effects.append(PROXY_EFFECT)
	else:
		cog.dna.is_mod_cog = false
		cog.dna.status_effects.erase(PROXY_EFFECT)
	_refresh_cog()

#endregion

#region ATTACK SELECTION

@onready var attack_template : HBoxContainer = $Menus/AttackPicker/CheckBoxContainer
@onready var attack_container_a : VBoxContainer = $Menus/AttackPicker/MenuA/ScrollContainer/AttackContainer
@onready var attack_container_b : VBoxContainer = $Menus/AttackPicker/MenuB/ScrollContainer/AttackContainer
@onready var attack_container_c : VBoxContainer = $Menus/AttackPicker/MenuC/ScrollContainer/AttackContainer
@onready var attack_master_list := [suit_a_attacks, suit_b_attacks, suit_c_attacks]
@onready var all_attack_containers := [attack_container_a, attack_container_b, attack_container_c]

var attack_menu_current : VBoxContainer:
	get:
		match cog.dna.suit:
			CogDNA.SuitType.SUIT_A: return attack_container_a
			CogDNA.SuitType.SUIT_B: return attack_container_b
			_: return attack_container_c

func _ready_attacks() -> void:
	populate_attack_menus()
	refresh_attacks()
	show_correct_menu()

func show_correct_menu() -> void:
	for container in all_attack_containers:
		container.get_parent().get_parent().visible = (container == attack_menu_current)

func populate_attack_menus() -> void:
	if attack_menu_current.get_child_count() == 0:
		for list in attack_master_list:
			for attack : CogAttack in list:
				all_attack_containers[attack_master_list.find(list)].add_child(create_attack_element(attack))

func refresh_attacks() -> void:
	for i in all_attack_containers.size():
		var container : VBoxContainer = all_attack_containers[i]
		for j in container.get_child_count():
			var element : Control = container.get_child(j)
			element.get_node('CheckBox').button_pressed = (attack_master_list[i][j] in cog.dna.attacks and container == attack_menu_current)

func create_attack_element(attack : CogAttack) -> HBoxContainer:
	var element := attack_template.duplicate()
	element.get_node('CheckBox').toggled.connect(attack_pressed.bind(attack))
	element.get_node('Title').set_text(attack.action_name)
	element.show()
	return element

func attack_pressed(toggle : bool, attack : CogAttack) -> void:
	if toggle and not attack in cog.dna.attacks:
		cog.dna.attacks.append(attack)
	elif not toggle:
		cog.dna.attacks.erase(attack)

func reset_attacks(_index : int) -> void:
	cog.dna.attacks.clear()
	show_correct_menu()
	refresh_attacks()

#endregion

#region BATTLE PHRASES
@onready var phrase_template : HBoxContainer = $Menus/BattlePhraseEditor/BattlePhraseTemplate
@onready var phrase_container : VBoxContainer = $Menus/BattlePhraseEditor/Panel/ScrollContainer/PhraseContainer

func _ready_phrases() -> void:
	clear_phrases()
	populate_phrases()

func clear_phrases() -> void:
	for child in phrase_container.get_children():
		child.queue_free()

func populate_phrases() -> void:
	for phrase in cog.dna.battle_phrases:
		var new_element := create_phrase_element(phrase)
		phrase_container.add_child(new_element)
		connect_phrase_element(new_element)

func create_phrase_element(phrase := "") ->  HBoxContainer:
	var new_phrase := phrase_template.duplicate()
	new_phrase.show()
	new_phrase.get_node('LineEdit').set_text(phrase)
	return new_phrase

func connect_phrase_element(element : HBoxContainer) -> void:
	element.get_node('LineEdit').text_changed.connect(phrase_text_changed.bind(element))
	element.get_node('DeleteButton').pressed.connect(delete_phrase.bind(element))
	element.get_node('LineEdit').text_submitted.connect(speak_phrase)

func phrase_text_changed(phrase : String, element : HBoxContainer) -> void:
	var index := get_phrase_element_index(element)
	if index < cog.dna.battle_phrases.size():
		cog.dna.battle_phrases[index] = phrase

func delete_phrase(element : HBoxContainer) -> void:
	var index := get_phrase_element_index(element)
	cog.dna.battle_phrases.remove_at(index)
	element.queue_free()

func get_phrase_element_index(element : HBoxContainer) -> int:
	for i in phrase_container.get_child_count():
		if phrase_container.get_child(i) == element:
			return i
	return -1

func add_battle_phrase() -> void:
	cog.dna.battle_phrases.append("")
	var new_element := create_phrase_element()
	phrase_container.add_child(new_element)
	connect_phrase_element(new_element)

func speak_phrase(phrase : String) -> void:
	cog.speak(phrase)

#endregion

func _refresh_cog() -> void:
	cog.set_dna(cog.dna)
	cog.set_animation('neutral')

func files_loading() -> void:
	mouse_blocker.show()

func files_finished_loading() -> void:
	mouse_blocker.hide()
