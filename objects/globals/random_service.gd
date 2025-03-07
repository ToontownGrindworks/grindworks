extends Node

## Simplified seeding for runs

## Base seeed
var base_seed: int

## Channels
var channels := {
}

func add_channel(channel_name: String) -> void:
	channels[channel_name] = base_seed

func get_channel_seed(channel_name: String) -> int:
	# Cool channel for true non-seeded randomness
	if channel_name == 'true_random':
		randomize()
		var newseed := randi()
		return newseed
		
	if not channels.has(channel_name):
		add_channel(channel_name)
	return channels[channel_name]

func increment_channel(channel_name: String) -> void:
	if not channel_name == "base_seed" and channels.has(channel_name):
		channels[channel_name] = str(channels[channel_name] + 1).hash()

func generate_seed() -> int:
	randomize()
	base_seed = randi()
	seed(base_seed)
	return base_seed

func randi_channel(channel_name : String) -> int:
	seed(get_channel_seed(channel_name))
	var integer := randi()
	seed(base_seed)
	increment_channel(channel_name)
	return integer

func randi_range_channel(channel_name: String, from: int, to: int) -> int:
	seed(get_channel_seed(channel_name))
	var integer := randi_range(from,to)
	seed(base_seed)
	increment_channel(channel_name)
	return integer

func randf_channel(channel_name: String) -> float:
	seed(get_channel_seed(channel_name))
	var fl := randf()
	seed(base_seed)
	increment_channel(channel_name)
	return fl

func randf_range_channel(channel_name: String, from: float, to: float) -> float:
	seed(get_channel_seed(channel_name))
	var fl := randf_range(from,to)
	seed(base_seed)
	increment_channel(channel_name)
	return fl

func array_shuffle_channel(channel_name: String, array: Array) -> void:
	seed(get_channel_seed(channel_name))
	array.shuffle()
	seed(base_seed)
	increment_channel(channel_name)

func array_pick_random(channel_name: String, array: Array):
	seed(get_channel_seed(channel_name))
	var ret = array.pick_random()
	seed(base_seed)
	increment_channel(channel_name)
	return ret

func random_weights(channel: String, dict: Dictionary):
	var weight_sum: float = dict.values().reduce(func (x, y): return x + y)
	var weight_rng: float = randf_channel(channel) * weight_sum
	var total: float = 0
	for key in dict.keys():
		total += dict[key]
		if total >= weight_rng:
			return key

func _ready() -> void: 
	generate_seed()
	SaveFileService.s_reset.connect(reset)

func reset() -> void:
	channels.clear()
