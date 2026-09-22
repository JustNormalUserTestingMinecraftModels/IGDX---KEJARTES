@tool
extends McpTestSuite

## AchievementTile.tscn / .gd (spec:
## docs/superpowers/specs/2026-09-18-achievements-polish-plan.md, Task 2):
## the 2-column grid tile that replaces AchievementRow. Drives real state
## through the live Achievements autoload (debug_unlock/claim/relock) so
## setup()/refresh() read the same path the game does, and always restores
## the touched id back to locked in teardown.

const ACHIEVEMENTS := preload("res://Scripts/Achievements/Achievements.gd")
const TILE := "res://Scenes/Achievements/AchievementTile.tscn"

## An id with no prize, for the "neutral chip" / plain states.
const PLAIN_ID := "three_star_akademis"
## An id with a non-empty prize, for the "amber chip" case.
const PRIZE_ID := "total_25"
## A numeric-progress id, for the progress-bar assertion.
const PROGRESS_ID := "total_10"

var _touched_ids: Array[String] = []


func suite_name() -> String:
	return "achievement_tile"


func teardown() -> void:
	for id in _touched_ids:
		_achievements().relock(id)
	_touched_ids.clear()


func _achievements() -> Node:
	return Engine.get_main_loop().root.get_node("Achievements")


func _new_tile() -> AchievementTile:
	var tile: AchievementTile = (load(TILE) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(tile)
	track(tile)
	return tile


## The tile's own label, one step up from CaptionLabel (22) to the body
## step (28), in text_primary rather than text_secondary. The tile's title
## is its most important text and was using the scale's second-smallest
## size, on a tile where the icon took 3% of the area.
func test_title_uses_the_tile_title_variation_at_body_size() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	assert_eq(theme.get_type_variation_base("AchievementTileTitleLabel"), &"Label")
	assert_eq(theme.get_font_size("font_size", "AchievementTileTitleLabel"), tokens.font_body_size)
	assert_eq(theme.get_color("font_color", "AchievementTileTitleLabel"), tokens.text_primary)
	assert_eq(theme.get_font("font", "AchievementTileTitleLabel"), tokens.font_body)


func test_tile_geometry_matches_the_mockup() -> void:
	var src := FileAccess.get_file_as_string(TILE)
	assert_true(src.contains("custom_minimum_size = Vector2(420, 310)"), "tile grows to 420x310")
	assert_true(src.contains("custom_minimum_size = Vector2(132, 132)"), "icon slot doubles to 132")
	assert_true(src.contains("custom_minimum_size = Vector2(0, 80)"), "title band fits two 28px lines")
	assert_true(src.contains('theme_type_variation = &"AchievementTileTitleLabel"'))
	assert_false(src.contains("Vector2(0, 58)"), "the old 58px caption band must be gone")
	assert_false(src.contains("Vector2(72, 72)"), "the old 72px icon slot must be gone")


func test_setup_shows_title_and_icon() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_eq(tile.title_label.text, "Cap-cip-cup kembang kuncup!")
	assert_eq(tile.achievement_id, PLAIN_ID)


## 20 of the 26 catalogue entries set prize to "". A chip reading "—" on
## 77% of the grid teaches nothing and costs the 38px the bigger icon
## needs, so the chip is hidden outright.
func test_prize_chip_is_hidden_when_the_entry_has_no_prize() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_false(tile.prize_chip.visible, "an entry with no prize shows no chip")


## The contrast fix. Fading the tile ROOT took a locked title to 1.78:1
## against its own card (measured live, 2026-09-22) -- under the 3.0 floor
## tests/test_bar_contrast.gd pins and far under the 4.5 body copy wants.
## The root now stays opaque in every state and only the icon is greyed;
## the lock overlay already drawn on it carries the state.
func test_locked_tile_root_stays_fully_opaque() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_eq(tile.modulate, Color.WHITE, "the tile root must never be faded")
	assert_eq(tile.icon.modulate, tile.locked_icon_modulate, "only the icon is greyed while locked")
	assert_true(tile.lock_icon.visible)


func test_unlocked_tile_restores_the_icon_tint() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_eq(tile.modulate, Color.WHITE)
	assert_eq(tile.icon.modulate, Color.WHITE)
	assert_false(tile.lock_icon.visible)


func test_prize_chip_non_empty_is_amber() -> void:
	var tile := _new_tile()
	var entry := AchievementCatalog.get_entry(PRIZE_ID)
	tile.setup(entry)
	assert_eq(tile.prize_label.text, entry.prize)
	assert_eq(tile.prize_chip.theme_type_variation, &"AchievementPrizeChipAmber")


func test_locked_state_shows_lock_and_no_badges() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_true(tile.lock_icon.visible)
	assert_false(tile.baru_badge.visible)
	assert_false(tile.check_badge.visible)


func test_unlocked_state_shows_baru_badge() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_false(tile.lock_icon.visible)
	assert_true(tile.baru_badge.visible)
	assert_false(tile.check_badge.visible)
	assert_true(absf(tile.modulate.a - 1.0) < 0.01, "not dimmed once unlocked")


func test_claimed_state_shows_check_badge() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	_achievements().claim(PLAIN_ID)
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_false(tile.lock_icon.visible)
	assert_false(tile.baru_badge.visible)
	assert_true(tile.check_badge.visible)


func test_progress_bar_reflects_progress_of() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PROGRESS_ID))
	var expected: float = _achievements().progress_of(PROGRESS_ID) * 100.0
	assert_true(absf(tile.progress_bar.value - expected) < 0.01)


func test_refresh_picks_up_a_new_state_without_setup() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_true(tile.lock_icon.visible)
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	tile.refresh()
	assert_false(tile.lock_icon.visible)
	assert_true(tile.baru_badge.visible)


func test_matches_filter_truth_table() -> void:
	var locked_tile := _new_tile()
	locked_tile.setup(AchievementCatalog.get_entry(PLAIN_ID))

	_touched_ids.append(PRIZE_ID)
	_achievements().debug_unlock(PRIZE_ID)
	var unlocked_tile := _new_tile()
	unlocked_tile.setup(AchievementCatalog.get_entry(PRIZE_ID))

	_touched_ids.append("grade_7")
	_achievements().debug_unlock("grade_7")
	_achievements().claim("grade_7")
	var claimed_tile := _new_tile()
	claimed_tile.setup(AchievementCatalog.get_entry("grade_7"))

	for tile in [locked_tile, unlocked_tile, claimed_tile]:
		assert_true(tile.matches_filter(AchievementTile.Filter.SEMUA))

	assert_true(locked_tile.matches_filter(AchievementTile.Filter.BELUM_DIBUKA))
	assert_false(unlocked_tile.matches_filter(AchievementTile.Filter.BELUM_DIBUKA))
	assert_false(claimed_tile.matches_filter(AchievementTile.Filter.BELUM_DIBUKA))

	assert_false(locked_tile.matches_filter(AchievementTile.Filter.SUDAH_DIBUKA))
	assert_true(unlocked_tile.matches_filter(AchievementTile.Filter.SUDAH_DIBUKA))
	assert_true(claimed_tile.matches_filter(AchievementTile.Filter.SUDAH_DIBUKA))

	assert_false(locked_tile.matches_filter(AchievementTile.Filter.BELUM_DIAMBIL))
	assert_true(unlocked_tile.matches_filter(AchievementTile.Filter.BELUM_DIAMBIL))
	assert_false(claimed_tile.matches_filter(AchievementTile.Filter.BELUM_DIAMBIL))


func test_tile_pressed_emits_the_achievement_id() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	var got := []
	tile.tile_pressed.connect(func(id): got.append(id))
	tile._gui_input(_mouse_button(true, Vector2(10, 10)))
	tile._gui_input(_mouse_button(false, Vector2(10, 10)))
	assert_eq(got, [PLAIN_ID])


## Press then release at (near) the same position is a clean tap: exactly
## one emit. Covers the drag-scroll fix (Task 1): a bare PRESS must no
## longer emit on its own.
func test_press_then_release_same_position_emits_once() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	var got := []
	tile.tile_pressed.connect(func(id): got.append(id))
	tile._gui_input(_mouse_button(true, Vector2(100, 100)))
	assert_eq(got.size(), 0, "a bare press must not emit")
	tile._gui_input(_mouse_button(false, Vector2(104, 101)))
	assert_eq(got, [PLAIN_ID])


## Press, drag past the threshold, release: zero emits (a scroll gesture
## that started on a tile must not open the detail sheet).
func test_press_motion_beyond_threshold_release_emits_nothing() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	var got := []
	tile.tile_pressed.connect(func(id): got.append(id))
	tile._gui_input(_mouse_button(true, Vector2(100, 100)))
	tile._gui_input(_mouse_button(false, Vector2(100, 100 + AchievementTile.TAP_MOVE_THRESHOLD + 10)))
	assert_eq(got.size(), 0, "a drag past the threshold must not emit")


## The device path is touch, but the tile now handles only the emulated
## mouse events those touches produce (project.godot's
## emulate_touch_from_mouse / emulate_mouse_from_touch); a bare
## InputEventScreenTouch, with no mouse emulation delivering the matching
## InputEventMouseButton, must not emit at all. Proves there is exactly one
## input path, not two racing ones.
func test_bare_screen_touch_alone_emits_nothing() -> void:
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	var got := []
	tile.tile_pressed.connect(func(id): got.append(id))
	tile._gui_input(_screen_touch(true, Vector2(50, 50)))
	tile._gui_input(_screen_touch(false, Vector2(52, 51)))
	assert_eq(got.size(), 0, "ScreenTouch alone must not emit; only the emulated mouse path does")


func _mouse_button(pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.global_position = pos
	event.position = pos
	return event


func _screen_touch(pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	event.position = pos
	return event


func test_scene_has_no_theme_overrides() -> void:
	# The project rule: styling flows from the theme, never from per-node
	# overrides. Layout-only constants (separation, margin_*) are exempt.
	var src := FileAccess.get_file_as_string(TILE)
	for line in src.split("\n"):
		if not line.begins_with("theme_override_"):
			continue
		var is_layout := line.begins_with("theme_override_constants/separation") \
			or line.begins_with("theme_override_constants/margin")
		assert_true(is_layout, "unexpected theme override in AchievementTile.tscn: " + line)


func test_every_label_uses_a_theme_type_variation() -> void:
	var src := FileAccess.get_file_as_string(TILE)
	var lines := src.split("\n")
	var i := 0
	while i < lines.size():
		if lines[i].begins_with('[node name=') and 'type="Label"' in lines[i]:
			var found := false
			var j := i + 1
			while j < lines.size() and not lines[j].begins_with("[node") and not lines[j].begins_with("["):
				if lines[j].begins_with("theme_type_variation"):
					found = true
				j += 1
			assert_true(found, "Label node at line %d has no theme_type_variation" % i)
		i += 1


func test_badges_stay_top_right_corner() -> void:
	# BaruBadge/CheckBadge sit directly under the root PanelContainer, so
	# their size_flags decide corner placement: horizontal 8 (SHRINK_END,
	# right) + vertical 0 (SHRINK_BEGIN, top). Vertical 0 is "shrink to
	# minimum size and align to top", not FILL (FILL is bit 1) -- pinning
	# this so nobody "fixes" it into stretching to full height.
	var src := FileAccess.get_file_as_string(TILE)
	var lines := src.split("\n")
	var i := 0
	while i < lines.size():
		var line := lines[i]
		if line.begins_with('[node name="BaruBadge"') or line.begins_with('[node name="CheckBadge"'):
			var got_h := false
			var got_v := false
			var j := i + 1
			while j < lines.size() and not lines[j].begins_with("[node") and not lines[j].begins_with("["):
				if lines[j].begins_with("size_flags_horizontal"):
					assert_eq(lines[j], "size_flags_horizontal = 8", line + " must stay right-anchored: " + lines[j])
					got_h = true
				if lines[j].begins_with("size_flags_vertical"):
					assert_eq(lines[j], "size_flags_vertical = 0", line + " must stay top-anchored: " + lines[j])
					got_v = true
				j += 1
			assert_true(got_h and got_v, line + " must set both size_flags for corner placement")
		i += 1


func test_relock_clears_baru_shown_so_it_replays_on_reunlock() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	var tile := _new_tile()
	tile.setup(AchievementCatalog.get_entry(PLAIN_ID))
	assert_true(AchievementTile._baru_shown.has(PLAIN_ID))

	_achievements().relock(PLAIN_ID)
	tile.refresh()
	assert_false(AchievementTile._baru_shown.has(PLAIN_ID), "relock must clear the once-per-session BARU flag")

	_achievements().debug_unlock(PLAIN_ID)
	tile.refresh()
	assert_true(tile.baru_badge.visible)
	assert_true(AchievementTile._baru_shown.has(PLAIN_ID), "re-unlock must be able to replay the BARU pop_in")


## Task 8: StatBar's min height (~36px) wins over the tile's 4px
## custom_minimum_size override, so the progress bar must use the dedicated
## thin AchievementTileBar variation instead.
func test_progress_bar_uses_the_thin_achievement_tile_bar_variation() -> void:
	var src := FileAccess.get_file_as_string(TILE)
	assert_true(src.contains('theme_type_variation = &"AchievementTileBar"'),
		"ProgressBar must use AchievementTileBar, not StatBar")
	assert_false(src.contains('theme_type_variation = &"StatBar"'))


func test_root_expands_to_fill_grid_column() -> void:
	var src := FileAccess.get_file_as_string(TILE)
	# No closing bracket in the anchor: an editor save stamps every node with
	# a `unique_id=`, the format the other scenes here already carry, and an
	# exact-match anchor breaks the first time the scene is re-saved.
	var root_idx := src.find('[node name="AchievementTile" type="PanelContainer"')
	assert_true(root_idx != -1, "tile root found")
	var next_idx := src.find("[node name=", root_idx + 1)
	var body := src.substr(root_idx, next_idx - root_idx)
	assert_true(body.contains("size_flags_horizontal = 3"),
		"root must EXPAND_FILL so the GridContainer splits width evenly between columns")
