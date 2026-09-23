@tool
extends McpTestSuite

## SkinSelect.tscn / .gd: the full-screen skin picker that replaced
## SkinSelectPopup's card-of-four (spec:
## docs/superpowers/specs/2026-09-22-skin-select-screen-design.md;
## the carousel's continuous-scroll pose:
## docs/superpowers/specs/2026-09-23-skin-select-slide-design.md).
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


## Pins the carousel to `width` for a pose test. It is anchored full-rect,
## so its anchors are collapsed first; setting size on unequal anchors logs
## a warning and is overridden on the next layout.
func _pin_carousel_width(s: SkinSelect, width: float) -> void:
	var carousel := s.get_node("%Carousel") as Control
	carousel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	carousel.size = Vector2(width, carousel.size.y)


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


## The lit dot has to FOLLOW the selection, not just start right. Only
## _rebuild_carousel refreshed the dots at first, so sliding moved the card,
## the skin name and the chip while the lit dot stayed on whichever card was
## centred when the character was opened. Caught in the 2026-09-22 local
## review; the original test asserted the opening state only, which is
## exactly why it passed.
func test_the_lit_dot_follows_the_selection() -> void:
	var s := _new_screen()
	var dots := s.get_node("%Dots")
	s.select_skin(1)
	assert_eq((dots.get_child(0) as Panel).theme_type_variation, &"SkinDotOff")
	assert_eq((dots.get_child(1) as Panel).theme_type_variation, &"SkinDotOn")
	s.select_skin(0)
	assert_eq((dots.get_child(0) as Panel).theme_type_variation, &"SkinDotOn")
	assert_eq((dots.get_child(1) as Panel).theme_type_variation, &"SkinDotOff")


func test_commit_button_is_indonesian_and_not_danger_red() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	assert_true(src.contains('text = "TERAPKAN"'), "UI text is Indonesian; APPLY is not")
	assert_false(src.contains('text = "APPLY"'))
	assert_true(src.contains('theme_type_variation = &"SkinApplyButton"'), "the mockup's red button")


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
	assert_true(block.contains("offset_bottom = -592.0"),
		"the carousel's bottom must track the tray's top edge (y=1328 on a 1920 phone), not a fixed y")
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


## Measured off skinselection_mockup.png (spec 2026-09-23): the centred
## splash at 0.818 from (85,153), the right neighbour at 0.658 from (676,370).
## The design x values are for a 1080-wide carousel -- pin the width so this
## test holds regardless of the editor root's own viewport size.
func test_card_pose_hits_the_mockups_two_slots() -> void:
	var s := _new_screen()
	_pin_carousel_width(s, 1080.0)
	var c: Dictionary = s.card_pose(0.0)
	assert_true((c.position as Vector2).distance_to(Vector2(85, 153)) < 0.01, str(c.position))
	assert_true(absf(float(c.scale) - 0.818) < 0.0001)
	assert_true(absf(float(c.focus) - 1.0) < 0.0001)
	var r: Dictionary = s.card_pose(1.0)
	assert_true((r.position as Vector2).distance_to(Vector2(676, 370)) < 0.01, str(r.position))
	assert_true(absf(float(r.scale) - 0.658) < 0.0001)
	assert_true(absf(float(r.focus) - 0.0) < 0.0001)


## Position, scale and focus are all linear in |t| up to one card, so the
## halfway pose is the midpoint of the two slots. Pinned to a 1080-wide
## carousel, same reason as test_card_pose_hits_the_mockups_two_slots.
func test_card_pose_is_the_midpoint_halfway() -> void:
	var s := _new_screen()
	_pin_carousel_width(s, 1080.0)
	var h: Dictionary = s.card_pose(0.5)
	assert_true((h.position as Vector2).distance_to(Vector2(380.5, 261.5)) < 0.01, str(h.position))
	assert_true(absf(float(h.scale) - 0.738) < 0.0001)
	assert_true(absf(float(h.focus) - 0.5) < 0.0001)


## The left neighbour mirrors the right one around the centred card's middle.
## Pinned to a 1080-wide carousel, same reason as
## test_card_pose_hits_the_mockups_two_slots.
func test_the_left_neighbour_mirrors_the_right() -> void:
	var s := _new_screen()
	_pin_carousel_width(s, 1080.0)
	var mid := 85.0 + 1080.0 * 0.818 * 0.5
	var r: Dictionary = s.card_pose(1.0)
	var l: Dictionary = s.card_pose(-1.0)
	var r_cx: float = (r.position as Vector2).x + 1080.0 * float(r.scale) * 0.5
	var l_cx: float = (l.position as Vector2).x + 1080.0 * float(l.scale) * 0.5
	assert_true(absf((mid - l_cx) - (r_cx - mid)) < 0.01)
	assert_eq((l.position as Vector2).y, (r.position as Vector2).y)
	assert_true(absf(s.pitch_px() - 504.6) < 0.01)


## stretch aspect="expand" widens the canvas on anything wider than 9:16;
## the carousel must stay centred on its own width, as the old code did.
func test_card_pose_recentres_on_a_wider_carousel() -> void:
	var s := _new_screen()
	_pin_carousel_width(s, 1440.0)
	var c: Dictionary = s.card_pose(0.0)
	assert_true(absf((c.position as Vector2).x - (85.0 + 180.0)) < 0.01, str(c.position))


## The regression this pass exists for: with the first skin centred, the
## second must actually be on screen, dim and blurred. Pinned to a
## 1080-wide carousel, then re-posed, same reason as
## test_card_pose_hits_the_mockups_two_slots.
func test_the_neighbour_is_on_screen_when_settled() -> void:
	var s := _new_screen()
	_pin_carousel_width(s, 1080.0)
	s._layout_cards()
	var centre := s.card_for(0)
	var side := s.card_for(1)
	assert_eq(centre.focus, 1.0)
	assert_eq(side.focus, 0.0)
	assert_true(side.position.x < 1080.0 - 150.0,
		"the neighbour must show a real slice of itself, got x=%s" % side.position.x)


## Focus follows the finger, not the selection: half a pitch of drag puts
## both cards at half focus before anything is released.
func test_dragging_half_a_pitch_half_focuses_both_cards() -> void:
	var s := _new_screen()
	s._begin_drag(700.0)
	s._update_drag(700.0 - s.pitch_px() * 0.5)
	assert_true(absf(s.scroll() - 0.5) < 0.0001)
	assert_true(absf(s.card_for(0).focus - 0.5) < 0.0001)
	assert_true(absf(s.card_for(1).focus - 0.5) < 0.0001)


func test_a_drag_past_the_end_stops_at_the_overscroll() -> void:
	var s := _new_screen()
	s._begin_drag(700.0)
	s._update_drag(700.0 + s.pitch_px() * 3.0)
	assert_true(absf(s.scroll() - (-s.overscroll)) < 0.0001)


## Settling snaps (no tween in the editor), and the selected card ends
## centred and crisp. Pinned to a 1080-wide carousel, same reason as
## test_card_pose_hits_the_mockups_two_slots.
func test_select_skin_centres_that_card() -> void:
	var s := _new_screen()
	_pin_carousel_width(s, 1080.0)
	s.select_skin(1)
	assert_true(absf(s.scroll() - 1.0) < 0.0001)
	assert_true(s.card_for(1).position.distance_to(Vector2(85, 153)) < 0.01,
		str(s.card_for(1).position))
	assert_eq(s.card_for(1).focus, 1.0)


## The nearer card draws on top, so a neighbour never covers the centre.
func test_the_centred_card_draws_last() -> void:
	var s := _new_screen()
	var track := s.get_node("%Track")
	assert_eq(track.get_child(track.get_child_count() - 1), s.card_for(0))
	s.select_skin(1)
	assert_eq(track.get_child(track.get_child_count() - 1), s.card_for(1))


func test_track_is_a_plain_control_not_a_box() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	assert_true(_node_block(src, "Track").contains('type="Control"'))


func _node_block(src: String, name: String) -> String:
	var at := src.find('[node name="%s"' % name)
	if at == -1:
		return ""
	var next := src.find("[node", at + 1)
	return src.substr(at, (next - at) if next != -1 else src.length() - at)


## Every offset is measured off skinselection_mockup.png; the tray's own
## origin is y=1328 on a 1920-tall screen.
func test_tray_is_laid_out_to_the_mockup() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	var tray := _node_block(src, "Tray")
	assert_true(tray.contains("offset_top = -592.0"), "divider at y=1328")
	assert_true(tray.contains('theme_type_variation = &"SkinTray"'))
	var rail := _node_block(src, "Rail")
	assert_true(rail.contains("offset_top = 102.0") and rail.contains("offset_bottom = 258.0"),
		"tiles at y 1430-1586")
	var back := _node_block(src, "BackButton")
	# texture_normal has transparent padding, so the rect is sized so the
	# DRAWN arrow, not the rect, lands on the mockup's (40,1677)-(237,1852).
	for v in ["offset_left = 37.0", "offset_top = 344.0", "offset_right = 239.0", "offset_bottom = 546.0"]:
		assert_true(back.contains(v), "BackButton " + v)
	var btn := _node_block(src, "Terapkan")
	for v in ["offset_left = 501.0", "offset_top = 381.0", "offset_right = 1007.0", "offset_bottom = 521.0"]:
		assert_true(btn.contains(v), "Terapkan " + v)


func test_title_uses_the_mockup_title_style() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	assert_true(_node_block(src, "Title").contains('theme_type_variation = &"SkinTitleLabel"'))


## The mockup has no room in the tray for the worn chip, so it sits under
## the title instead.
func test_worn_chip_sits_under_the_title() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	assert_true(src.contains('[node name="WornChip" type="PanelContainer" parent="."'))


func test_mockup_styles_exist_with_measured_values() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	var tray := theme.get_stylebox("panel", "SkinTray") as StyleBoxFlat
	assert_true(tray != null, "SkinTray must be a StyleBoxFlat panel")
	if tray != null:
		assert_eq(tray.bg_color, tokens.surface_card)
		assert_eq(tray.border_width_top, 8)
		assert_eq(tray.border_width_bottom, 0)
		assert_eq(tray.border_color, Color.BLACK)
	var btn := theme.get_stylebox("normal", "SkinApplyButton") as StyleBoxFlat
	assert_true(btn != null, "SkinApplyButton must be a StyleBoxFlat button")
	if btn != null:
		assert_eq(btn.bg_color, Color("D21919"))
		assert_eq(btn.border_width_left, 8)
		assert_eq(btn.corner_radius_top_left, tokens.radius_button)
	assert_eq(theme.get_color("font_color", "SkinApplyButton"), Color("F2F2F2"))
	assert_eq(theme.get_font_size("font_size", "SkinApplyButton"), 73)
	assert_eq(theme.get_color("font_color", "SkinTitleLabel"), Color("F2F2F2"))
	assert_eq(theme.get_color("font_outline_color", "SkinTitleLabel"), Color("201934"))
	assert_eq(theme.get_font_size("font_size", "SkinTitleLabel"), 79)
	assert_eq(theme.get_constant("outline_size", "SkinTitleLabel"), 48)
