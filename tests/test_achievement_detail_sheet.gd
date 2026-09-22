@tool
extends McpTestSuite

## AchievementDetailSheet.tscn / .gd (spec:
## docs/superpowers/specs/2026-09-18-achievements-polish-plan.md, Task 3):
## the tap-to-expand modal opened from an AchievementTile. Drives real state
## through the live Achievements autoload (debug_unlock/claim/relock) so
## open_for() reads the same path the game does, and always restores the
## touched id back to locked in teardown.

const ACHIEVEMENTS := preload("res://Scripts/Achievements/Achievements.gd")
const SHEET := "res://Scenes/Achievements/AchievementDetailSheet.tscn"
const SHEET_SRC := "res://Scripts/Achievements/AchievementDetailSheet.gd"

## A locked id with no prize.
const PLAIN_ID := "three_star_akademis"
## A numeric-progress id, for the fraction text assertion.
const PROGRESS_ID := "total_10"
## An id with a non-empty prize, for the chip assertions.
const PRIZE_ID := "total_25"

const LOCK_ICON := "res://Assets/Images/UI/Placeholders/icon_lock.svg"
const NOTICE_ICON := "res://Assets/Images/Achievements/notice_icon.png"
const CHECK_ICON := "res://Assets/Images/UI/Placeholders/icon_check.svg"

var _touched_ids: Array[String] = []


func suite_name() -> String:
	return "achievement_detail_sheet"


func teardown() -> void:
	for id in _touched_ids:
		_achievements().relock(id)
	_touched_ids.clear()


func _achievements() -> Node:
	return Engine.get_main_loop().root.get_node("Achievements")


func _new_sheet() -> AchievementDetailSheet:
	var sheet: AchievementDetailSheet = (load(SHEET) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(sheet)
	track(sheet)
	return sheet


func test_locked_state_icon_is_the_lock() -> void:
	var sheet := _new_sheet()
	sheet.open_for(PLAIN_ID)
	assert_true(sheet.visible)
	assert_eq((sheet.get_node("%StateIcon") as TextureRect).texture.resource_path, LOCK_ICON)


func test_claimed_state_icon_is_the_check() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	_achievements().claim(PLAIN_ID)
	var sheet := _new_sheet()
	sheet.open_for(PLAIN_ID)
	assert_eq((sheet.get_node("%StateIcon") as TextureRect).texture.resource_path, CHECK_ICON)


## The prize used to print twice: description_of() appended
## "\nHadiah: <prize>" to the desc AND %PrizeLabel repeated the same string
## underneath. The desc is now the entry's own text and the prize lives
## only in the chip.
func test_desc_is_the_entry_text_and_the_prize_is_only_in_the_chip() -> void:
	var sheet := _new_sheet()
	var entry := AchievementCatalog.get_entry(PRIZE_ID)
	sheet.open_for(PRIZE_ID)
	var desc := (sheet.get_node("%Desc") as Label).text
	assert_eq(desc, entry.desc)
	assert_false(desc.contains("Hadiah"), "the prize must not be baked into the desc")
	assert_true(sheet.get_node("%PrizeChip").visible)
	assert_eq((sheet.get_node("%PrizeChipLabel") as Label).text, entry.prize)


func test_prize_chip_hidden_for_an_entry_without_one() -> void:
	var sheet := _new_sheet()
	sheet.open_for(PLAIN_ID)
	assert_false(sheet.get_node("%PrizeChip").visible)


## The card was anchored 0.3-0.78 vertically, so it was 922px tall at
## 1080x1920 and 1152px at 1080x2400 for ~350px of content -- emptier the
## taller the phone. Centred anchors with GROW_DIRECTION_BOTH make a
## Control clamp up to its combined minimum size and split the extra evenly
## about the anchor, so the card is exactly as tall as its content.
func test_sheet_card_is_content_sized_and_centred() -> void:
	var src := FileAccess.get_file_as_string(SHEET)
	assert_false(src.contains("anchor_top = 0.3"), "the fractional height anchors must be gone")
	assert_false(src.contains("anchor_bottom = 0.78"))
	assert_true(src.contains("offset_left = -432.0") and src.contains("offset_right = 432.0"),
		"width stays 864, expressed as offsets about the centre")
	assert_true(src.contains("grow_horizontal = 2") and src.contains("grow_vertical = 2"))


func test_sheet_uses_the_space_lg_rhythm() -> void:
	var src := FileAccess.get_file_as_string(SHEET)
	assert_true(src.contains("theme_override_constants/separation = 44"),
		"the stack is on space_lg (44), not the old 12")
	assert_true(src.contains("custom_minimum_size = Vector2(0, 300)"), "the icon slot is 300 tall")
	assert_true(src.contains("custom_minimum_size = Vector2(96, 96)"), "the back arrow meets the touch floor")
	assert_true(src.contains('[node name="StateRow" type="HBoxContainer"'))
	assert_false(src.contains('[node name="ActionArea"'))


func test_sheet_body_label_variation_is_body_size() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	assert_eq(theme.get_type_variation_base("AchievementSheetBodyLabel"), &"Label")
	assert_eq(theme.get_font_size("font_size", "AchievementSheetBodyLabel"), tokens.font_body_size)
	assert_eq(theme.get_color("font_color", "AchievementSheetBodyLabel"), tokens.text_secondary)


func test_fraction_text_matches_progress_fraction_of() -> void:
	var sheet := _new_sheet()
	sheet.open_for(PROGRESS_ID)
	var frac: Vector2i = _achievements().progress_fraction_of(PROGRESS_ID)
	var label := sheet.get_node("%ProgressLabel") as Label
	assert_true(label.visible)
	assert_eq(label.text, "%d / %d" % [frac.x, frac.y])


func test_fraction_text_hidden_for_one_shot_kind() -> void:
	var sheet := _new_sheet()
	sheet.open_for(PLAIN_ID)
	assert_false(sheet.get_node("%ProgressLabel").visible)


func test_close_hides_and_emits_closed() -> void:
	var sheet := _new_sheet()
	sheet.open_for(PLAIN_ID)
	var closed_count := [0]
	sheet.closed.connect(func(): closed_count[0] += 1)
	sheet.close()
	assert_false(sheet.visible)
	assert_eq(closed_count[0], 1)


func test_close_when_already_closed_does_not_emit_again() -> void:
	var sheet := _new_sheet()
	var closed_count := [0]
	sheet.closed.connect(func(): closed_count[0] += 1)
	sheet.close()
	assert_eq(closed_count[0], 0)


## The Klaim button is gone (the user's brief). Opening the popup on an
## unlocked achievement is the claim. The emit is deferred so the sheet is
## already visible and laid out when the host screen's celebration lands on
## top of it -- so the test calls the deferred half directly rather than
## awaiting a frame, which the runner forbids. That is also why that half
## is its own named function.
func test_opening_an_unlocked_entry_requests_the_claim() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	var sheet := _new_sheet()
	var got: Array[String] = []
	sheet.claim_requested.connect(func(id: String): got.append(id))
	sheet.open_for(PLAIN_ID)
	assert_true(sheet.visible, "the sheet shows before the claim goes out")
	sheet._emit_claim_if_unlocked()
	assert_eq(got, [PLAIN_ID])
	# The sheet itself never calls Achievements.claim -- that is the host
	# screen's job (see the script header). State stays UNLOCKED here.
	assert_eq(_achievements().state_of(PLAIN_ID), ACHIEVEMENTS.STATE_UNLOCKED)


func test_opening_a_locked_entry_requests_nothing() -> void:
	var sheet := _new_sheet()
	var got: Array[String] = []
	sheet.claim_requested.connect(func(id: String): got.append(id))
	sheet.open_for(PLAIN_ID)
	sheet._emit_claim_if_unlocked()
	assert_eq(got, [])


func test_opening_a_claimed_entry_requests_nothing() -> void:
	_touched_ids.append(PLAIN_ID)
	_achievements().debug_unlock(PLAIN_ID)
	_achievements().claim(PLAIN_ID)
	var sheet := _new_sheet()
	var got: Array[String] = []
	sheet.claim_requested.connect(func(id: String): got.append(id))
	sheet.open_for(PLAIN_ID)
	sheet._emit_claim_if_unlocked()
	assert_eq(got, [])


func test_no_claim_button_remains_in_the_scene() -> void:
	var src := FileAccess.get_file_as_string(SHEET)
	assert_false(src.contains("ClaimButton"))
	assert_false(src.contains('text = "Klaim"'))


func test_no_theme_overrides_and_scrim_variation_present() -> void:
	# The project rule: styling flows from the theme, never from per-node
	# overrides. Layout-only constants (separation, margin_*) are exempt.
	var src := FileAccess.get_file_as_string(SHEET)
	for line in src.split("\n"):
		if not line.begins_with("theme_override_"):
			continue
		var is_layout := line.begins_with("theme_override_constants/separation") \
			or line.begins_with("theme_override_constants/margin")
		assert_true(is_layout, "unexpected theme override in AchievementDetailSheet.tscn: " + line)
	assert_true(src.contains('theme_type_variation = &"Scrim"'), "Scrim variation must be present")


func test_root_and_scrim_stop_mouse_input() -> void:
	# A scrim tap that closes the sheet must not also reach whatever is
	# underneath (the grid tile that opened it). PASS (1) or IGNORE (2) on
	# either the sheet root or the Scrim would let that tap fall through.
	var src := FileAccess.get_file_as_string(SHEET)
	var lines := src.split("\n")
	var i := 0
	while i < lines.size():
		var line := lines[i]
		if line.begins_with('[node name="AchievementDetailSheet"') \
				or line.begins_with('[node name="Scrim"'):
			var j := i + 1
			while j < lines.size() and not lines[j].begins_with("[node") and not lines[j].begins_with("["):
				assert_false(lines[j].begins_with("mouse_filter = 1"), line + " must not be mouse_filter PASS: " + lines[j])
				assert_false(lines[j].begins_with("mouse_filter = 2"), line + " must not be mouse_filter IGNORE: " + lines[j])
				j += 1
		i += 1


func test_sheet_starts_hidden() -> void:
	var sheet := _new_sheet()
	assert_false(sheet.visible)
