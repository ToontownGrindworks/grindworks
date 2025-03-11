extends Resource
class_name PlayerCharacter

@export var character_name := 'Flippy'
@export_multiline var character_summary := ""
@export var dna: ToonDNA
@export var gag_loadout: GagLoadout
@export var starting_laff := 25
@export var starting_items: Array[Item]
@export var base_stats: BattleStats

# sory
@export var random_character_stored_name := ""

# Make custom scripts to set up special character attributes
func character_setup(player: Player):
	player.stats.max_hp = starting_laff
	player.stats.hp = starting_laff
	dna = dna.duplicate()
	if has_method(character_name.to_lower().replace(" ", "")):
		call(character_name.to_lower().replace(" ", ""),player)
	
	for item: Item in starting_items:
		if item.evergreen:
			item = item.duplicate()
		item.apply_item(player)
		ItemService.seen_item(item)

# Flippy starts with a Squirt gag by default.
# Also, starts with a base 5% boost to throw
func flippy(player: Player):
	player.stats.gags_unlocked['Squirt'] = 1
	player.stats.gags_unlocked['Throw'] = 1
	player.stats.gag_effectiveness['Throw'] *= 1.05
	player.stats.luck = 1.05

## Saved stats for player
const RANDOM_CHAR_ITEM_COUNT := 2
func randomtoon(player: Player) -> void:
	# Randomize stats
	var random_stats: Array[String] = [
		'damage', 'defense', 'evasiveness', 'luck', 'speed'
	]
	
	# Randomize stats
	var good_points := 20
	var bad_points := 12
	var point_cost := 0.02
	while good_points > 0:
		var stat := random_stats[RandomService.randi_channel('random_stat_rolls') % random_stats.size()]
		player.stats.set(stat, player.stats.get(stat) + point_cost)
		good_points -= 1
	while bad_points > 0:
		var stat := random_stats[RandomService.randi_channel('random_stat_rolls') % random_stats.size()]
		player.stats.set(stat, player.stats.get(stat) - point_cost)
		bad_points -= 1
	print('stat randomization done :D')
	Util.random_stats = player.stats
	
	var item_pool: ItemPool = load('res://objects/items/pools/accessories.tres')
	var slots_taken := []
	while slots_taken.size() < 2:
		var item: Item = ItemService.get_random_item(item_pool, true)
		if not item in starting_items and not item.slot in slots_taken:
			starting_items.append(item)
			slots_taken.append(item.slot)
			
	# Sneaky way of making sure only gags are randomized later
	character_name = 'RandomGags'

func randomgags(player: Player) -> void:
	# Get one random offense and one random support track
	var offense_tracks: Array[Track] = []
	var support_tracks: Array[Track] = []
	var selected_tracks: Array[Track] = []
	for track in gag_loadout.loadout:
		if track.track_type == Track.TrackType.OFFENSE:
			offense_tracks.append(track)
		else:
			support_tracks.append(track)
	# Choose two random tracks if either support or offense is empty
	# Probably won't ever run but yk
	if offense_tracks.is_empty() or support_tracks.is_empty():
		var selected_track: Track
		while selected_tracks.size() < 2 or not selected_track in selected_tracks:
			selected_track = gag_loadout.loadout[RandomService.randi_channel('true_random') % gag_loadout.loadout.size()]
			if not selected_track in selected_tracks: selected_tracks.append(selected_track)
	# Otherwise run like normal
	else:
		selected_tracks.append(offense_tracks[RandomService.randi_channel('true_random') % offense_tracks.size()])
		selected_tracks.append(support_tracks[RandomService.randi_channel('true_random') % support_tracks.size()])
	
	# Start player off with anywhere from level 1-3 gags
	for track in selected_tracks:
		player.stats.gags_unlocked[track.track_name] += RandomService.randi_channel('true_random') % 2 + 1
	
	# Reset character name
	character_name = 'RandomToon'
	
	var random_stats: Array[String] = [
		'damage', 'defense', 'evasiveness', 'luck', 'speed'
	]
	# Restore stats
	if Util.random_stats:
		for stat in random_stats:
			player.stats.set(stat, Util.random_stats.get(stat))

func juliuswheezer(player: Player) -> void:
	for track in player.stats.gags_unlocked.keys():
		player.stats.gags_unlocked[track] = 1
	player.stats.luck = 1.3
	player.stats.crit_mult = 1.5

func barnaclebessie(player: Player) -> void:
	player.stats.gags_unlocked['Squirt'] = 1
	player.stats.gags_unlocked['Lure'] = 1
	# Bessie does not naturally get this set since Drop is not in her loadout
	player.stats.gag_effectiveness['Drop'] = 1.0
	player.stats.luck = 1.1

func clerkclara(player: Player) -> void:
	player.stats.gags_unlocked['Trap'] = 2
	player.stats.gags_unlocked['Lure'] = 2
	player.stats.luck = 1.05

func moezart(player: Player) -> void:
	player.stats.gags_unlocked['Sound'] = 1
	player.stats.gags_unlocked['Drop'] = 1
	player.stats.luck = 1.05
