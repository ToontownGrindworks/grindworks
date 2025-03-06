extends Node

var isLaffObscured = false
const AVAILABLE_IMAGE_KEYS = ['ttgrindworks', 'tt-grindworks-small', 'character_flippy', 'character_clara', 'character_wheezer', 'character_bessie', 'character_moe', 'character_random_toon', 'da_office', 'The_Mint', 'CGC', 'factory', 'unknown']
func _ready():
	if SaveFileService.settings_file.get("discord_rpc") == false:
		return
	if GDExtensionManager.is_extension_loaded("res://addons/discord-rpc-gd/bin/discord-rpc-gd.gdextension"):
		menu()
	else:
		print("Discord RPC extension not loaded")

func update_presence():
	isLaffObscured = false
	if SaveFileService.settings_file.get("discord_rpc") == false:
		return
	var floor_text = "Floor %d" % [Util.floor_number]
	DiscordRPC.details = ("Infiltrating the Facilities" + " - " + floor_text)
	if Util.floor_manager.anomalies:
		for anomaly in Util.floor_manager.anomalies:
			if anomaly.get_mod_name() == "Out of Touch":
				isLaffObscured = true
				break
	var parts = PackedStringArray([])
	if isLaffObscured:
		parts = PackedStringArray([
			"? / ? Laff",
			"%d Jellybeans" % Util.player.stats.money
		])
	else:
		parts = PackedStringArray([
			"%d / %d Laff" % [Util.player.stats.hp, Util.player.stats.max_hp],
			"%d Jellybeans" % Util.player.stats.money
		])
	
	parts = ' - '.join(parts)
	DiscordRPC.state = parts
	
	DiscordRPC.large_image =  "ttgrindworks"
	DiscordRPC.large_image_text = Util.player.character.character_name
	DiscordRPC.small_image = "ttgrindworks-small"
	DiscordRPC.small_image_text = "Toontown: The Grindworks"

	DiscordRPC.refresh()

func menu():
	if SaveFileService.settings_file.get("discord_rpc") == false:
		return
	DiscordRPC.app_id = 1345901257495412776
	DiscordRPC.state= "Main Menu"
	DiscordRPC.large_image = "ttgrindworks"
	DiscordRPC.large_image_text = "Version %s" % ProjectSettings.get_setting("application/config/version")
	DiscordRPC.small_image = "tt-grindworks-small"
	DiscordRPC.small_image_text = "Toontown: The Grindworks"
	DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system())
	DiscordRPC.refresh()

func stop():
	# clear everything
	DiscordRPC.clear()
	DiscordRPC.refresh()
	
