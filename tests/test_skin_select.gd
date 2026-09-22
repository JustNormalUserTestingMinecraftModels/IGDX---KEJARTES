@tool
extends McpTestSuite

## SkinSelect.tscn / .gd: the full-screen skin picker that replaced
## SkinSelectPopup's card-of-four (spec:
## docs/superpowers/specs/2026-09-22-skin-select-screen-design.md).
##
## Drives real state through GameState.equip_skin, and restores
## equipped_skins / skin_unlock_overrides in teardown.

const SCREEN := "res://Scenes/Skins/SkinSelect.tscn"

var _saved_equipped: Dictionary
var _saved_overrides: Dictionary


func suite_name() -> String:
	return "skin_select"


func setup() -> void:
	_saved_equipped = GameState.equipped_skins.duplicate()
	_saved_overrides = GameState.skin_unlock_overrides.duplicate()
	GameState.equipped_skins = {}
	GameState.skin_unlock_overrides = {}


func teardown() -> void:
	GameState.equipped_skins = _saved_equipped
	GameState.skin_unlock_overrides = _saved_overrides


func _new_screen() -> SkinSelect:
	var s: SkinSelect = (load(SCREEN) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(s)
	track(s)
	s.open()
	return s


## All six characters, not the roster: equipped_skins is keyed by NAME, so a
## skin follows a character across the grade change that clears the roster.
func test_rail_holds_all_six_characters_in_catalogue_order() -> void:
	var s := _new_screen()
	var rail := s.get_node("%Rail")
	assert_eq(rail.get_child_count(), StudentSkins.NAMES.size())
	for i in StudentSkins.NAMES.size():
		assert_eq((rail.get_child(i) as StudentTile).student_name, StudentSkins.NAMES[i])


func test_open_takes_no_argument_and_first_student_is_open() -> void:
	var s := _new_screen()
	assert_eq(s.current_student(), StudentSkins.NAMES[0])
	var rail := s.get_node("%Rail")
	assert_eq((rail.get_child(0) as StudentTile).theme_type_variation, &"SkinStudentTileActive")
	assert_eq((rail.get_child(1) as StudentTile).theme_type_variation, &"SkinStudentTile")


func test_carousel_holds_one_card_per_skin_of_the_open_student() -> void:
	var s := _new_screen()
	assert_eq(s.get_node("%Track").get_child_count(),
		StudentSkins.skins_for(StudentSkins.NAMES[0]).size())


## Sliding is a PENDING choice. Nothing is equipped until TERAPKAN, which is
## what lets one button serve all six characters in one visit.
func test_selecting_a_skin_does_not_equip_it() -> void:
	var s := _new_screen()
	var who := s.current_student()
	s.select_skin(1)
	assert_eq(s.pending_id(who), StudentSkins.skins_for(who)[1])
	assert_eq(GameState.equipped_skin(who), StudentSkins.DEFAULT_ID,
		"sliding must not equip -- TERAPKAN does")


func test_apply_commits_every_pending_student_at_once() -> void:
	var s := _new_screen()
	var first: String = StudentSkins.NAMES[0]
	var second: String = StudentSkins.NAMES[1]
	s.select_skin(1)
	s.select_student(1)
	s.select_skin(1)
	s.apply_without_closing()
	assert_eq(GameState.equipped_skin(first), StudentSkins.skins_for(first)[1])
	assert_eq(GameState.equipped_skin(second), StudentSkins.skins_for(second)[1])


func test_back_discards_every_pending_change() -> void:
	var s := _new_screen()
	var who := s.current_student()
	s.select_skin(1)
	s.go_back()
	assert_eq(GameState.equipped_skin(who), StudentSkins.DEFAULT_ID)


## The chip keys off the COMMITTED skin, not the centred one, so it
## disappears the moment the carousel moves and comes back after TERAPKAN.
## With two skins and both unlocked, that is the only on-screen proof the
## button did anything.
func test_worn_chip_tracks_the_committed_skin_not_the_selection() -> void:
	var s := _new_screen()
	assert_true(s.get_node("%WornChip").visible, "the default skin starts worn")
	s.select_skin(1)
	assert_false(s.get_node("%WornChip").visible)
	s.apply_without_closing()
	assert_true(s.get_node("%WornChip").visible)


func test_switching_students_keeps_each_ones_pending_choice() -> void:
	var s := _new_screen()
	var first: String = StudentSkins.NAMES[0]
	s.select_skin(1)
	s.select_student(1)
	s.select_student(0)
	assert_eq(s.pending_id(first), StudentSkins.skins_for(first)[1])


func test_title_and_skin_name_follow_the_open_student() -> void:
	var s := _new_screen()
	assert_eq((s.get_node("%Title") as Label).text, StudentSkins.NAMES[0].to_upper())
	assert_eq((s.get_node("%SkinName") as Label).text, SkinSelect.skin_label(StudentSkins.DEFAULT_ID))
	s.select_student(1)
	assert_eq((s.get_node("%Title") as Label).text, StudentSkins.NAMES[1].to_upper())


## GameState.is_skin_unlocked is real state the debug overlay can flip, and
## the mockup had nowhere to say a skin was locked.
func test_a_locked_skin_says_so_and_has_no_worn_chip() -> void:
	var who: String = StudentSkins.NAMES[0]
	var locked_id: String = StudentSkins.skins_for(who)[1]
	GameState.skin_unlock_overrides["%s:%s" % [who, locked_id]] = false
	var s := _new_screen()
	s.select_skin(1)
	assert_eq((s.get_node("%SkinName") as Label).text, "TERKUNCI")
	assert_false(s.get_node("%WornChip").visible)
	s.apply_without_closing()
	assert_eq(GameState.equipped_skin(who), StudentSkins.DEFAULT_ID,
		"a locked skin must not be equipped by TERAPKAN")


func test_dots_show_one_per_skin_and_mark_the_centred_one() -> void:
	var s := _new_screen()
	var dots := s.get_node("%Dots")
	var count := StudentSkins.skins_for(StudentSkins.NAMES[0]).size()
	var visible_dots := 0
	for i in dots.get_child_count():
		if (dots.get_child(i) as Panel).visible:
			visible_dots += 1
	assert_eq(visible_dots, count)
	assert_eq((dots.get_child(0) as Panel).theme_type_variation, &"SkinDotOn")
	assert_eq((dots.get_child(1) as Panel).theme_type_variation, &"SkinDotOff")


func test_commit_button_is_indonesian_and_not_danger_red() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	assert_true(src.contains('text = "TERAPKAN"'), "UI text is Indonesian; APPLY is not")
	assert_false(src.contains('text = "APPLY"'))
	assert_true(src.contains('theme_type_variation = &"PrimaryButton"'),
		"brand brown, so the commit button and the red back arrow do not read as a pair")


func test_backdrop_still_blurs_the_live_lobby() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	assert_true(src.contains("shop_hub_blur_material.tres"),
		"the live-screen blur is why this stays an overlay instead of a scene change")


func test_the_popup_era_nodes_are_gone() -> void:
	assert_false(ResourceLoader.exists("res://Scenes/Skins/SkinSlot.tscn"))
	assert_false(ResourceLoader.exists("res://Scenes/Skins/SkinOptionTile.tscn"))
	assert_false(ResourceLoader.exists("res://Scenes/Skins/SkinSelectPopup.tscn"))


## The carousel band must stretch to the tray's top, not stop at a fixed
## 1337, or a 1080x2400 phone leaves a bare strip between the splash and
## the tray.
func test_the_carousel_stretches_to_the_trays_top_edge() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	var at := src.find('[node name="Carousel"')
	assert_true(at != -1, "Carousel must exist")
	var next := src.find("[node", at + 1)
	var block := src.substr(at, (next - at) if next != -1 else src.length() - at)
	assert_true(block.contains("offset_bottom = -583.0"),
		"the carousel's bottom must track the tray's height, not a fixed y")
	assert_true(block.contains("anchor_bottom = 1.0"))
	# And it runs from the very top, with the title floating over it. At
	# offset_top = 200 the band was 1137 tall on a 1920 phone and clipped
	# 200px off a 1337-tall card -- re-cropping the outfit the card's own
	# size exists to stop cropping. A zero offset is the default, so Godot
	# omits the line entirely: assert its ABSENCE, not "offset_top = 0.0".
	assert_false(block.contains("offset_top ="),
		"the splash band must start at the top (no offset_top); the title overlays it")


func test_no_theme_overrides_beyond_layout_constants() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	for line in src.split("\n"):
		if not line.begins_with("theme_override_"):
			continue
		var is_layout := line.begins_with("theme_override_constants/separation") \
			or line.begins_with("theme_override_constants/margin")
		assert_true(is_layout, "unexpected theme override in SkinSelect.tscn: " + line)
