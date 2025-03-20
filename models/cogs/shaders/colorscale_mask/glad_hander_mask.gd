extends ColorMask

## A RainbowHander exclusive 


const PHRASES := [
	"I've caught you %s handed.",
	"Why so %s, Toon?",
	"Stop it, you’ll make me turn %s.",
]

func tweak_cog(cog : Cog) -> void:
	var color := Globals.random_dna_color
	base_color = color
	var color_name : String = Globals.dna_colors.find_key(color)
	color_name = color_name.replace("_", " ")
	
	cog.dna.hand_color = base_color
	#cog.dna.cog_name = color_name[0].to_upper() + color_name.substr(1) + " Hander"
	
	for phrase in PHRASES:
		cog.dna.battle_phrases.append(phrase % color_name)
