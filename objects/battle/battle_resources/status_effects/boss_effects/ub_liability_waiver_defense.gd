@tool
extends StatBoost
class_name UBLiabilityWaiverDefense

var liability_holder: Cog

func apply() -> void:
	super()
	manager.s_participant_will_die.connect(check_if_cog_expired)

func cleanup() -> void:
	if manager.s_participant_will_die.is_connected(check_if_cog_expired):
		manager.s_participant_will_die.disconnect(check_if_cog_expired)

func get_description() -> String:
	return "%s%s%% %s" % ["+" if boost > 1.0 else "-", roundi(abs(boost - 1.0) * 100), "Defense until the Cog with Liability Waiver is defeated!"]

func get_status_name() -> String:
	return status_name
	
func check_if_cog_expired(participant):
	if liability_holder != participant:
		return
		
	manager.expire_status_effect(self)
