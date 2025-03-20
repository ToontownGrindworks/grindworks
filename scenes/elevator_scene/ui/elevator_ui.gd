extends Control


const TIP_FILE := "res://scenes/loading_screen/tips.txt"
var ANOMALY_ICON := LazyLoader.defer('res://objects/player/ui/anomaly_icon.tscn')
const TIP_TIME := 10.0
const FADE_TIME := 1.0

@onready var floor_button := $FloorChooser/FloorTypeButton
@onready var tip_label : Label = $TipLabel
@onready var arrow_left : TextureButton = %ArrowLeft
@onready var arrow_right : TextureButton = %ArrowRight
@onready var anomaly_container : HBoxContainer = %AnomalyContainer

var floors : Array[FloorVariant]
var floor_index := 0
var tip_tween : Tween
var tips : PackedStringArray

signal start_floor(floor_var : FloorVariant)


func _ready() -> void:
	tips = read_tip_file()
	change_tip(tips)
	start_tip_tween()
	if Util.get_player().see_descriptions:
		anomaly_container.show()

func set_floor_index(index : int) -> void:
	floor_button.floor_variant = floors[index]
	refresh_anomalies(floors[index].anomalies)
	floor_index = index

func move_floor_index(by : int) -> void:
	floor_index += by
	if floor_index >= floors.size():
		floor_index = 0
	elif floor_index < 0:
		floor_index = floors.size() -1 
	set_floor_index(floor_index)

func floor_selected(floor_var : FloorVariant) -> void:
	start_floor.emit(floor_var)
	floor_button.hide()

func read_tip_file() -> PackedStringArray:
	if FileAccess.file_exists(TIP_FILE):
		var file_as_string := FileAccess.get_file_as_string(TIP_FILE)
		var file_as_array := file_as_string.split("\n")
		return file_as_array
	return []

func start_tip_tween() -> void:
	tip_tween = create_tween().set_loops()
	tip_tween.tween_interval(TIP_TIME)
	tip_tween.tween_property(tip_label, 'self_modulate:a', 0.0, FADE_TIME)
	tip_tween.tween_callback(change_tip.bind(tips))
	tip_tween.tween_property(tip_label, 'self_modulate:a', 1.0, FADE_TIME)

func change_tip(tips : PackedStringArray) -> void:
	tip_label.set_text("TOON TIP:\n" + tips[RandomService.randi_channel('true_random') % tips.size() - 3])

func refresh_anomalies(anomaly_list : Array[Script]) -> void:
	for child in anomaly_container.get_children():
		child.queue_free()
	for anomaly in anomaly_list:
		var icon : Control = ANOMALY_ICON.load().instantiate()
		icon.anomaly = anomaly
		anomaly_container.add_child(icon)
