extends ItemScript

func on_collect(item : Item, object : Node3D) -> void:
	var doodle : RoamingDoodle = object.doodle
	item.arbitrary_data['dna'] = doodle.doodle.dna

func on_load(item : Item) -> void:
	# Create the doodle object from scratch
	var doodle : RoamingDoodle = load('res://objects/doodle/roaming_doodle/roaming_doodle.tscn').instantiate()
	SceneLoader.add_persistent_node(doodle)
	doodle.doodle.hide()
	doodle.shadow.hide()
	
	# Try to re-apply saved DNA
	if item.arbitrary_data.has('dna'):
		var doodle_dna : DoodleDNA = item.arbitrary_data['dna']
		doodle.doodle.dna = doodle_dna
		doodle.doodle.apply_dna()
	else:
		var doodle_dna := DoodleDNA.new()
		doodle_dna.randomize_dna()
		doodle.doodle.dna = doodle_dna
		doodle.doodle.apply_dna()
	
	# Give Doodle the item so that it can modify it
	doodle.item = item
	
	Util.get_player().partners.append(doodle)
	
	# Wait for a moment to set doodle state to avoid error
	await Task.delay(1.0)
	doodle.state = RoamingDoodle.DoodleState.AWAIT
	
	
