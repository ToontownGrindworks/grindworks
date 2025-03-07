@tool
extends UIPanel

const RELEASES_PATH := "res://scenes/title_screen/release_notes/releases/"

# Put new releases AT THE TOP
static var all_releases: Array[ReleaseNote] = [
	load(RELEASES_PATH + "v1.0.2.tres"),
	load(RELEASES_PATH + "v1.0.1.tres"),
	load(RELEASES_PATH + "v1.0.0.tres"),
]

@onready var releases_dropdown: OptionButton = %ReleasesDropdown
@onready var releases_container: VBoxContainer = %ReleasesContainer

func _ready() -> void:
	super()

	if Engine.is_editor_hint():
		return

	for release: ReleaseNote in all_releases:
		releases_dropdown.add_item(release.release_version)
	releases_dropdown.select(0)
	select_entry(0)

func select_entry(idx: int) -> void:
	for child: Node in releases_container.get_children():
		child.queue_free()
	var selected_release: ReleaseNote = all_releases[idx]
	for note: String in selected_release.notes.split("\n"):
		releases_container.add_child(selected_release.make_label_for_note(note))
