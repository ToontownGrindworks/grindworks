extends FloorModifier


## Increases the Cog level min/max for the floor
func modify_floor() -> void:
	game_floor.level_range.x += 1
	game_floor.level_range.y += 1

func get_mod_name() -> String:
	return "Tightened Security"

func get_mod_quality() -> ModType:
	return ModType.NEGATIVE

func get_mod_icon() -> Texture2D:
	return load("res://ui_assets/player_ui/pause/tightened_security.png")

func get_description() -> String:
	return "Cogs are one level higher"
