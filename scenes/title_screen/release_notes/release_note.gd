extends Resource
class_name ReleaseNote

const LABEL_SETTINGS_TITLE := preload("res://scenes/title_screen/release_notes/releases_title_settings.tres")
const LABEL_SETTINGS_ENTRY := preload("res://scenes/title_screen/release_notes/releases_entry_settings.tres")

@export var release_version: String
@export_multiline var notes: String

func make_label_for_note(note: String) -> Label:
	var new_label := Label.new()
	if note.contains("[TITLE]"):
		note = note.replace("[TITLE]", "")
		new_label.label_settings = LABEL_SETTINGS_TITLE
		new_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		new_label.custom_minimum_size.y = 48
	else:
		new_label.label_settings = LABEL_SETTINGS_ENTRY
		note = "- " + note
	new_label.text = note
	new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return new_label
