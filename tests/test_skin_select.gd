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
## SkinSelect.gd's own source, for the SFX call-site scans below -- play_sfx
## is gated behind Engine.is_editor_hint(), which is always true in this
## suite, so a behavioural "did it play" check could only prove the guard
## works, never which cue was chosen or where it is called from.
const SCRIPT := "res://Scripts/Skins/SkinSelect.gd"

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


## open() with no names -- the fallback, which is what _new_screen() drives
## every other test in this suite through -- shows all six characters, not
## just the roster: equipped_skins is keyed by NAME, so a skin follows a
## character across the grade change that clears the roster. This is the
## empty-roster safety net, not the everyday path (Task 1, spec §1).
func test_rail_falls_back_to_all_six_characters_when_open_is_given_no_names() -> void:
	var s := _new_screen()
	assert_eq(s.visible_names(), StudentSkins.NAMES)
	var rail := s.get_node("%Rail")
	assert_eq(rail.get_child_count(), StudentSkins.NAMES.size())
	for i in StudentSkins.NAMES.size():
		var tile := rail.get_child(i) as StudentTile
		assert_eq(tile.student_name, StudentSkins.NAMES[i])
		assert_true(tile.visible)


## The everyday path: the rail shows only the names Lobby hands down, in
## roster order, and hides the rest of the six authored tiles rather than
## freeing them.
func test_open_with_names_shows_only_those_tiles_in_order() -> void:
	var s := _new_screen()
	var two: Array[String] = [StudentSkins.NAMES[0], StudentSkins.NAMES[1]]
	s.open(two)
	assert_eq(s.visible_names(), two)
	assert_eq(_visible_tile_names(s), two)
	assert_eq(s.current_student(), two[0])


func test_open_with_three_or_four_names_shows_that_many_tiles() -> void:
	var s := _new_screen()
	var three: Array[String] = StudentSkins.NAMES.slice(0, 3)
	s.open(three)
	assert_eq(_visible_tile_names(s).size(), 3)
	var four: Array[String] = StudentSkins.NAMES.slice(0, 4)
	s.open(four)
	assert_eq(_visible_tile_names(s).size(), 4)


func test_select_student_is_scoped_to_the_open_names() -> void:
	var s := _new_screen()
	var two: Array[String] = [StudentSkins.NAMES[0], StudentSkins.NAMES[1]]
	s.open(two)
	s.select_student(1)
	assert_eq(s.current_student(), two[1])
	s.select_student(2)
	assert_eq(s.current_student(), two[1], "index 2 is out of range for a 2-name rail")


func test_roster_names_reads_name_skips_non_dicts_and_blanks() -> void:
	var students: Array = [{"name": "A"}, {"name": ""}, 5, {"name": "B"}]
	var names: Array[String] = SkinSelect.roster_names(students)
	assert_eq(names, ["A", "B"] as Array[String])


## Slices one top-level function's body out of SCRIPT's source, from
## `func <name>(` to the next top-level `func `. Mirrors
## tests/test_audio_coverage.gd's own function slicing for the double-fire
## guard, kept local and simple since this suite only ever needs one
## function's body at a time.
func _function_body(func_name: String) -> String:
	var src := FileAccess.get_file_as_string(SCRIPT)
	var start := src.find("func " + func_name + "(")
	assert_true(start != -1, "function must exist: " + func_name)
	if start == -1:
		return ""
	var next := src.find("\nfunc ", start)
	return src.substr(start, (next - start) if next != -1 else src.length() - start)


## The visible rail tiles' student names, in rail order.
func _visible_tile_names(s: SkinSelect) -> Array[String]:
	var rail := s.get_node("%Rail")
	var names: Array[String] = []
	for i in rail.get_child_count():
		var tile := rail.get_child(i) as StudentTile
		if tile != null and tile.visible:
			names.append(tile.student_name)
	return names


func test_default_open_shows_the_first_students_tile_as_open() -> void:
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
	assert_true(src.contains('theme_type_variation = &"SkinApplyButton"'), "the lipped mint TERAPKAN")


func test_backdrop_still_blurs_the_live_lobby() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	assert_true(src.contains("skin_select_backdrop_material.tres"),
		"the live-screen blur is why this stays an overlay instead of a scene change")


## The room behind the carousel is lit 25% brighter than the shop hub's
## backdrop: 1 - darkness goes 0.45 -> 0.5625 (2026-09-29). Its own copy, so
## ShopHub, CosmeticShop and the achievement popup keep their 0.55.
func test_the_backdrop_is_a_quarter_lighter_than_the_shop_hub() -> void:
	var own := load("res://Scenes/Skins/skin_select_backdrop_material.tres") as ShaderMaterial
	var hub := load("res://Scenes/Koperasi/shop_hub_blur_material.tres") as ShaderMaterial
	assert_true(own != null and hub != null, "both blur materials load")
	if own == null or hub == null:
		return
	var own_light := 1.0 - float(own.get_shader_parameter("darkness"))
	var hub_light := 1.0 - float(hub.get_shader_parameter("darkness"))
	assert_true(absf(own_light - hub_light * 1.25) < 0.0001,
		"%s is 25%% lighter than the hub's %s" % [own_light, hub_light])
	assert_eq(float(own.get_shader_parameter("lod")),
		float(hub.get_shader_parameter("lod")), "same blur strength as the hub")


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


## SkinTray and SkinApplyButton moved to the depth pass's lipped look
## (2026-09-29 skin-select-polish Task 2): a paper tray with no rim, and a
## lipped mint TERAPKAN in place of the 2026-09-23 mockup's flat red/black
## rim. The title keeps its own measured mockup values, untouched by Task 2.
func test_skin_theme_styles_use_the_depth_pass_look() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	var tray := theme.get_stylebox("panel", "SkinTray") as StyleBoxFlat
	assert_true(tray != null, "SkinTray must be a StyleBoxFlat panel")
	if tray != null:
		assert_eq(tray.bg_color, tokens.surface_card, "the lighter of the two paper tokens")
		assert_eq(tray.border_width_top, 0, "the depth pass drops the mockup's black top rim")
	var btn := theme.get_stylebox("normal", "SkinApplyButton") as StyleBoxFlat
	assert_true(btn != null, "SkinApplyButton must be a StyleBoxFlat button")
	if btn != null:
		assert_true(LippedBox.is_lipped(btn), "TERAPKAN is a lipped face, not the flat mockup rim")
		assert_eq(btn.bg_color, tokens.accent_mint, "the main-action colour, never gold")
		assert_eq(btn.corner_radius_top_left, tokens.radius_button)
	assert_eq(theme.get_color("font_color", "SkinApplyButton"), tokens.text_on_brand)
	assert_eq(theme.get_font_size("font_size", "SkinApplyButton"), 73)
	assert_eq(theme.get_color("font_color", "SkinTitleLabel"), Color("F2F2F2"))
	assert_eq(theme.get_color("font_outline_color", "SkinTitleLabel"), Color("201934"))
	assert_eq(theme.get_font_size("font_size", "SkinTitleLabel"), 79)
	assert_eq(theme.get_constant("outline_size", "SkinTitleLabel"), 48)


## The rail centres 2-4 tiles instead of packing them to the left, so a
## grade-7 class of two does not leave a dead gap on the right (Task 3, spec
## §3 "Centered rail").
func test_rail_is_center_aligned() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	assert_true(_node_block(src, "Rail").contains("alignment = 1"))


## The "Kelasmu - N murid" header and its "ketuk untuk pilih" hint sit above
## the rail, inside the tray (Task 3, spec §2).
func test_tray_has_roster_header_and_hint_labels() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	var header := _node_block(src, "RosterHeader")
	assert_true(header.contains('type="Label"'))
	assert_true(header.contains("unique_name_in_owner = true"))
	assert_true(header.contains('theme_type_variation = &"SkinRosterHeaderLabel"'))
	var hint := _node_block(src, "RosterHint")
	assert_true(hint.contains('type="Label"'))
	assert_true(hint.contains('theme_type_variation = &"SkinRosterHintLabel"'))
	assert_true(hint.contains('text = "ketuk untuk pilih"'))


## open() sets the header from the roster it was given -- per-call dynamic
## TEXT, not a runtime-built visual (Global Constraints).
func test_open_sets_the_roster_header_text() -> void:
	var s := _new_screen()
	var two: Array[String] = [StudentSkins.NAMES[0], StudentSkins.NAMES[1]]
	s.open(two)
	assert_eq((s.get_node("%RosterHeader") as Label).text, "Kelasmu - 2 murid")
	var four: Array[String] = StudentSkins.NAMES.slice(0, 4)
	s.open(four)
	assert_eq((s.get_node("%RosterHeader") as Label).text, "Kelasmu - 4 murid")


## The tray reads as ruled paper: a tiling Rules TextureRect over
## paper_rule.png (Task 3, spec §2), the same idiom NotebookFrame.tscn uses.
## Behavioral, not a source scan: the editor's own save (2026-09-29 fix
## round 1) drops mouse_filter=2 from a Label/TextureRect that already
## defaults to it, and a node block never contains the real resource path
## anyway -- that lives on the file's [ext_resource] line, not inside the
## node's own text -- so a live instance is the only thing that actually
## proves the wiring.
func test_tray_has_tiling_ruled_paper() -> void:
	var s := _new_screen()
	var rules := s.get_node("%Tray").get_node_or_null("Rules") as TextureRect
	assert_true(rules != null, "Tray must have a Rules TextureRect")
	if rules == null:
		return
	assert_true(rules.texture != null)
	if rules.texture != null:
		assert_eq(rules.texture.resource_path, "res://Assets/Images/UI/Notebook/paper_rule.png")
	assert_eq(rules.stretch_mode, TextureRect.STRETCH_TILE)
	assert_eq(rules.texture_repeat, CanvasItem.TEXTURE_REPEAT_ENABLED)
	assert_eq(rules.mouse_filter, Control.MOUSE_FILTER_IGNORE)


## Two washi-tape strips at the tray's top corners, reusing the existing
## washi_tape.svg (Task 3, spec §2) -- no new art. Behavioral, same reason
## as test_tray_has_tiling_ruled_paper.
func test_tray_has_corner_tape() -> void:
	var s := _new_screen()
	var tray := s.get_node("%Tray")
	var left := tray.get_node_or_null("TapeLeft") as TextureRect
	var right := tray.get_node_or_null("TapeRight") as TextureRect
	assert_true(left != null and right != null, "Tray must have TapeLeft and TapeRight")
	if left == null or right == null:
		return
	assert_true(left.texture != null and right.texture != null)
	if left.texture != null:
		assert_eq(left.texture.resource_path, "res://Assets/Images/AturJadwal/washi_tape.svg")
	if right.texture != null:
		assert_eq(right.texture.resource_path, "res://Assets/Images/AturJadwal/washi_tape.svg")
	assert_eq(left.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(right.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	# Left and right must actually be different corners, not two copies of
	# the same offsets.
	assert_ne(left.position, right.position)


## Paper-divider dots flank the skin name, matching the mockup's description
## in spec §2 ("paper-divider dots either side").
func test_skin_name_has_dividers_either_side() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	var left := _node_block(src, "NameDividerLeft")
	assert_true(left.contains('type="Panel"'))
	assert_true(left.contains('theme_type_variation = &"SkinDotOn"'))
	var right := _node_block(src, "NameDividerRight")
	assert_true(right.contains('type="Panel"'))
	assert_true(right.contains('theme_type_variation = &"SkinDotOn"'))


## TERAPKAN gets a small "PAKAI!" sticker on its corner (Task 3, spec §4).
func test_terapkan_has_a_pakai_sticker() -> void:
	var src := FileAccess.get_file_as_string(SCREEN)
	var at := src.find('[node name="PakaiTag"')
	assert_true(at != -1, "PakaiTag must exist")
	if at == -1:
		return
	var next := src.find("[node", at + 1)
	var block := src.substr(at, (next - at) if next != -1 else src.length() - at)
	assert_true(block.contains('parent="Tray/Terapkan"'), "PakaiTag must be a child of Terapkan")
	assert_true(block.contains('theme_type_variation = &"SkinApplyTag"'))
	assert_true(block.contains('text = "PAKAI!"'))


## SkinStudentTile / SkinStudentTileActive are lipped photo cards: cream at
## rest, sunflower when open (the palette's highlight colour, never an
## action -- ui-depth-pass-design.md, "Palette").
func test_skin_tiles_are_lipped_cream_and_sunflower() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	var idle := theme.get_stylebox("normal", "SkinStudentTile") as StyleBoxFlat
	var open := theme.get_stylebox("normal", "SkinStudentTileActive") as StyleBoxFlat
	assert_true(idle != null and open != null, "both variations must carry a normal stylebox")
	if idle == null or open == null:
		return
	assert_true(LippedBox.is_lipped(idle), "idle tile is a lipped button_cream face")
	assert_eq(idle.bg_color, tokens.button_cream)
	assert_true(LippedBox.is_lipped(open), "open tile is a lipped accent_sunflower face")
	assert_eq(open.bg_color, tokens.accent_sunflower)


## The caption reads poorly straight over a light portrait (fix round 1,
## 2026-09-29 live screenshot), so it gets a small button_cream backing --
## a written caption tag on the photo, not a bare label. Flat, not lipped:
## this is not a tap target.
func test_tile_caption_has_a_cream_backing() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	var box := theme.get_stylebox("normal", "SkinTileCaptionLabel") as StyleBoxFlat
	assert_true(box != null, "SkinTileCaptionLabel must carry a normal stylebox")
	if box == null:
		return
	assert_eq(box.bg_color, tokens.button_cream)
	assert_eq(box.corner_radius_top_left, tokens.radius_pill)
	assert_eq(theme.get_color("font_color", "SkinTileCaptionLabel"), tokens.text_primary)


# ============================================================
# SFX (2026-09-29 skin-select-polish Task 4; spec §5 "Sound").
# open() already plays "tap" on arrival; these cover the rest of the
# picker's cues. Every id used here must resolve in AudioDirector's
# registry -- test_audio_coverage.gd's test_every_play_sfx_id_in_the_
# project_is_known re-checks that project-wide.
# ============================================================

func test_the_skin_select_cues_resolve_to_real_streams() -> void:
	for id in [&"select", &"swipe", &"apply"]:
		assert_true(AudioDirector.has_sfx(id), "%s must resolve to a stream" % id)


## Card select: a rail tile choice plays AudioDirector's "select" cue (the
## same id atur_jadwal/student_list/inventory use for a list/grid pick).
func test_select_student_plays_the_rail_select_cue() -> void:
	var body := _function_body("select_student")
	assert_true(body.contains('play_sfx(&"select")'),
		"select_student must play the select cue")


## Gated on a genuine change so re-tapping the already-open tile, and
## open()'s own initial select_student(0) call, stay silent -- open() has
## its own "tap" for the screen's entrance.
func test_select_student_gates_its_cue_on_an_index_change() -> void:
	var body := _function_body("select_student")
	var cue_at := body.find('play_sfx(&"select")')
	assert_true(cue_at != -1)
	assert_true(body.substr(0, cue_at).contains("changed"),
		"select_student must compare old vs new _student_index before its cue")


## Skin snap: the carousel settling on a new skin plays "swipe" -- paging
## through report_card/student_card is the closest documented meaning to a
## carousel settling on a new card, closer than "pop" ("a small UI element
## appears"), since nothing appears here; the carousel already exists and
## just comes to rest at a new position.
func test_select_skin_plays_the_settle_cue() -> void:
	var body := _function_body("select_skin")
	assert_true(body.contains('play_sfx(&"swipe")'),
		"select_skin must play the carousel-settle cue")


## Gated the same way as select_student's: only a real _skin_index change
## snaps, so a drag release that lands back on the already-centred card
## (a short flick that overshoots and settles home) is silent.
func test_select_skin_gates_its_cue_on_an_index_change() -> void:
	var body := _function_body("select_skin")
	var cue_at := body.find('play_sfx(&"swipe")')
	assert_true(cue_at != -1)
	assert_true(body.substr(0, cue_at).contains("changed"),
		"select_skin must compare old vs new _skin_index before its cue")


## The regression this guards against: a cue wired into the per-frame drag
## callback instead of the once-per-settle select_skin would buzz on every
## pixel of finger travel rather than snapping once on release.
func test_no_sfx_call_lives_in_the_per_frame_drag_path() -> void:
	var body := _function_body("_update_drag")
	assert_false(body.contains("play_sfx"),
		"_update_drag runs every drag frame and must never play a cue directly")


## Apply: committing the picker's choices on TERAPKAN plays "apply" -- the
## registry's own doc for the id ("a choice is committed on the apply
## screen") was already unused anywhere in Scripts/ before this pass.
func test_apply_without_closing_plays_the_apply_cue() -> void:
	var body := _function_body("apply_without_closing")
	assert_true(body.contains('play_sfx(&"apply")'),
		"apply_without_closing must play the apply cue")


# ============================================================
# Whole-branch review, fix round 2 (2026-09-29).
# ============================================================

## The roster header used a "·" middle dot Boohong, the display face it
## renders in, does not carry (verified with fontTools) -- exactly the
## defect ObjectiveHint.title hit first and fixed with a plain hyphen
## (tests/test_objective_hint.gd). Every character the header, the rail
## hint, a tile caption or the PAKAI! sticker can produce must be one
## Boohong actually has, or a device falls back to another font or a box.
func test_the_tray_text_only_uses_glyphs_the_display_face_has() -> void:
	var face: Font = DesignTokens.load_default().font_display
	assert_true(face != null, "no display face")
	if face == null:
		return
	var texts: Array[String] = []
	for count in [2, 3, 4]:
		texts.append(SkinSelect.ROSTER_HEADER_FORMAT % count)
	texts.append("ketuk untuk pilih")
	texts.append("PAKAI!")
	for who in StudentSkins.NAMES:
		texts.append(who)
	for text in texts:
		for i in text.length():
			var code := text.unicode_at(i)
			assert_true(face.has_char(code),
				"'%s' in '%s' is not in the display face" % [String.chr(code), text])


## TERAPKAN commits every pending skin choice at once -- the same weight as
## ResultButton or SuccessButton -- so it ticks the phone's motor on press
## like the game's other main actions (PressFeel.MAIN_ACTION_ROLES).
func test_terapkan_gets_the_main_action_haptic_tick() -> void:
	assert_true(PressFeel.ticks(&"SkinApplyButton"),
		"TERAPKAN must be a main-action role")


## The rail's six tiles are authored, never built at runtime (Task 1), so a
## 7th name would index past %Rail's last child. open() trims _names to the
## rail's own tile count instead. Behavioral: the point is that a 7-name
## roster settles on exactly 6 visible tiles rather than crashing.
func test_open_clamps_names_past_the_rails_tile_count() -> void:
	var s := _new_screen()
	var seven: Array[String] = StudentSkins.NAMES.duplicate()
	seven.append("Extra")
	s.open(seven)
	assert_eq(s.visible_names().size(), 6, "the rail has only 6 authored tiles")
	assert_eq(_visible_tile_names(s).size(), 6)


## -- The frozen backdrop (2026-09-30 mobile performance pass) -------------
##
## The backdrop used to blur the live Lobby: the whole room kept rendering
## under an opaque screen, and the blur copied the screen and rebuilt its mip
## chain every frame. Measured on the dev PC, hiding the Lobby under the
## picker took the frame from 1.29 ms to 0.52 ms. The picker now freezes one
## small, blurred still of the room and tells the Lobby when it may stop
## drawing.

func test_the_frozen_backdrop_node_is_authored_and_starts_hidden() -> void:
	var s := _new_screen()
	var frozen := s.get_node_or_null("%Frozen") as TextureRect
	assert_true(frozen != null, "Frozen is a TextureRect in SkinSelect.tscn")
	if frozen == null:
		return
	assert_false(frozen.visible, "hidden until a still has been taken")
	assert_eq(frozen.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(frozen.stretch_mode, TextureRect.STRETCH_SCALE, "the small still fills the screen")
	assert_true(frozen.get_index() < s.get_node("%Carousel").get_index(), "behind the carousel")


func test_the_still_is_a_small_fraction_of_the_frame() -> void:
	var frame := Image.create_empty(1080, 2400, false, Image.FORMAT_RGBA8)
	frame.fill(Color(0.8, 0.6, 0.4, 1.0))
	var still := SkinSelect.frozen_backdrop(frame, 12)
	assert_true(still != null, "a readable frame yields a still")
	if still == null:
		return
	assert_eq(still.get_size(), Vector2i(90, 200), "one twelfth of the frame each way")
	assert_eq(frame.get_size(), Vector2i(1080, 2400), "the frame itself is left alone")
	var c := still.get_pixel(45, 100)
	assert_true(absf(c.r - 0.8) < 0.02 and absf(c.b - 0.4) < 0.02, "the colour survives: %s" % c)


func test_no_frame_means_no_still() -> void:
	assert_true(SkinSelect.frozen_backdrop(null, 12) == null)
	assert_true(SkinSelect.frozen_backdrop(Image.new(), 12) == null)


## The still is dimmed by the backdrop material's own darkness, so the number
## tests pin above stays the one place the backdrop's brightness is set.
func test_showing_a_still_dims_it_like_the_live_blur_and_drops_the_screen_read() -> void:
	var s := _new_screen()
	var still := Image.create_empty(90, 160, false, Image.FORMAT_RGB8)
	s.show_still(still)
	var frozen := s.get_node("%Frozen") as TextureRect
	var blur := s.get_node("Blur") as ColorRect
	assert_true(frozen.visible and frozen.texture != null, "the still is shown")
	assert_false(blur.visible, "the live blur, and its screen read, is off")
	var darkness := float((blur.material as ShaderMaterial).get_shader_parameter("darkness"))
	assert_true(absf(frozen.self_modulate.r - (1.0 - darkness)) < 0.0001, "dimmed by the same darkness")


func test_closing_announces_it_before_the_fade() -> void:
	var s := _new_screen()
	var heard := [0]
	s.uncovering.connect(func() -> void: heard[0] += 1)
	s.close()
	s.close()
	assert_eq(heard[0], 1, "uncovering fires once, on the first close")


func test_a_screen_already_closing_never_reports_covered() -> void:
	var s := _new_screen()
	var heard := [0]
	s.covered.connect(func() -> void: heard[0] += 1)
	s._on_faded_in()
	assert_eq(heard[0], 1, "the fade-in's end reports covered")
	s.close()
	s._on_faded_in()
	assert_eq(heard[0], 1, "a late fade-in callback after close() must not hide the room")


func test_the_lobby_stops_drawing_the_room_under_the_picker() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Lobby/Lobby.gd")
	assert_true(src.contains("screen.covered.connect(_set_room_drawn.bind(false))"))
	assert_true(src.contains("screen.uncovering.connect(_set_room_drawn.bind(true))"))
