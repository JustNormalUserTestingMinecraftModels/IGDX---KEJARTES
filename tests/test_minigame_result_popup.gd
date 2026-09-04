@tool
extends McpTestSuite

## The end-of-minigame result card: roughly 340 lines of runtime construction
## in BaseMinigame._show_result_overlay(), seen by every player after every
## one of the eight minigames, and impossible to open in the editor.
##
## The shipped version discovers its score row / category badge / stat delta
## labels at animation time by scanning vbox.get_children() for "the
## HBoxContainer that isn't the star row" and similar pattern matches, because
## they were only conditionally built in the first place. Now that every node
## is a fixed, named scene node, configure() addresses them directly and
## toggles .visible instead of building/finding them.
##
## Star rendering moves to its own tiny scene so the row is three real nodes
## instead of a loop building 0-3 Controls at runtime.
##
## Must be @tool; no test here may be a coroutine, so nothing calls play().

func suite_name() -> String:
	return "minigame_result_popup"


const POPUP_PATH := "res://Scenes/Minigames/UI/MinigameResultPopup.tscn"
const STAR_PATH := "res://Scenes/Minigames/UI/ResultStar.tscn"

## The style dictionary configure() takes, with neutral values covering every
## @export _show_result_overlay used to read from BaseMinigame.
const STYLE := {
	"popup_card_texture": null, "popup_card_color": Color.BLACK,
	"popup_border_color": Color.WHITE, "popup_dim_color": Color(0, 0, 0, 0.75),
	"popup_star_texture": null, "popup_star_empty_texture": null,
	"popup_star_color": Color.YELLOW, "popup_star_empty_color": Color.GRAY,
	"popup_star_size": Vector2(88, 88),
	"popup_button_texture": null, "popup_button_color": Color.ORANGE,
	"popup_button_text": "Lanjutkan",
	"popup_title_font": null, "popup_body_font": null,
	"popup_title_font_size": 68, "popup_score_font_size": 52, "popup_stat_font_size": 34,
	"popup_title_win_color": Color.YELLOW, "popup_title_lose_color": Color.ORANGE,
	"win_title_text": "Kamu Berhasil! 🎉",
	"lose_title_text": "Belum Tepat, Coba Lagi Lain Kali!",
}


## The scene is added to the tree so its @onready vars resolve.
func _make() -> Node:
	var node: Node = load(POPUP_PATH).instantiate()
	Engine.get_main_loop().root.add_child(node)
	track(node)
	return node


func test_both_scenes_exist() -> void:
	assert_true(ResourceLoader.exists(POPUP_PATH), "%s is missing" % POPUP_PATH)
	assert_true(ResourceLoader.exists(STAR_PATH), "%s is missing" % STAR_PATH)


func test_popup_scene_carries_every_node_the_script_binds() -> void:
	var node := _make()
	for path in ["Dim", "Dim/ResultConfetti",
			"Dim/Center/Card/Layout/TitleLabel",
			"Dim/Center/Card/Layout/StarRow",
			"Dim/Center/Card/Layout/NameLabel",
			"Dim/Center/Card/Layout/ScorePanel",
			"Dim/Center/Card/Layout/ScorePanel/ScoreRow/ScoreIcon",
			"Dim/Center/Card/Layout/ScorePanel/ScoreRow/ScorePrefixLabel",
			"Dim/Center/Card/Layout/ScorePanel/ScoreRow/ScoreValueLabel",
			"Dim/Center/Card/Layout/CategoryBadge",
			"Dim/Center/Card/Layout/CategoryBadge/BadgeRow/BadgeIcon",
			"Dim/Center/Card/Layout/CategoryBadge/BadgeRow/BadgeLabel",
			"Dim/Center/Card/Layout/DeltaPanel",
			"Dim/Center/Card/Layout/DeltaPanel/DeltaList/StatDeltaRow/StatDeltaIcon",
			"Dim/Center/Card/Layout/DeltaPanel/DeltaList/StatDeltaRow/StatDeltaLabel",
			"Dim/Center/Card/Layout/DeltaPanel/DeltaList/EnergyDeltaRow/EnergyDeltaIcon",
			"Dim/Center/Card/Layout/DeltaPanel/DeltaList/EnergyDeltaRow/EnergyDeltaLabel",
			"Dim/Center/Card/Layout/DeltaPanel/DeltaList/MoodDeltaRow/MoodDeltaIcon",
			"Dim/Center/Card/Layout/DeltaPanel/DeltaList/MoodDeltaRow/MoodDeltaLabel",
			"Dim/Center/Card/Layout/ContinueButtonCenter/ContinueButton"]:
		assert_not_null(node.get_node_or_null(path), "missing node: %s" % path)


func test_win_and_lose_pick_different_titles() -> void:
	var win := _make()
	win.configure(true, 3, 5, 5, "Budi", "", 0.0, 0.0, 0.0, STYLE)
	assert_eq(win.get_node("Dim/Center/Card/Layout/TitleLabel").text, STYLE["win_title_text"])
	var lose := _make()
	lose.configure(false, 0, 1, 5, "Budi", "", 0.0, 0.0, 0.0, STYLE)
	assert_eq(lose.get_node("Dim/Center/Card/Layout/TitleLabel").text, STYLE["lose_title_text"])


func test_star_row_holds_three_fixed_star_instances() -> void:
	var node := _make()
	var row: Node = node.get_node("Dim/Center/Card/Layout/StarRow")
	assert_eq(row.get_child_count(), 3, "the result card always shows three stars")
	for star in row.get_children():
		assert_true(star is ResultStar, "StarRow children must be ResultStar instances")


func test_configure_fills_and_reveals_the_right_star_count() -> void:
	var node := _make()
	node.configure(true, 2, 4, 5, "Budi", "", 0.0, 0.0, 0.0, STYLE)
	var row: Node = node.get_node("Dim/Center/Card/Layout/StarRow")
	var filled := 0
	for star in row.get_children():
		if star.is_filled:
			filled += 1
	assert_eq(filled, 2)


func test_score_row_hides_when_no_score_data() -> void:
	# The shipped code only showed the score line when mg_score >= 0 and
	# mg_max_score > 0. max_score <= 0 means "this minigame doesn't track a
	# score" -- the row must stay hidden, not show "0 / 0" or similar.
	# Task 12 moved the toggle from ScoreRow onto its new ScorePanel wrapper.
	var node := _make()
	node.configure(true, 1, -1, -1, "Budi", "", 0.0, 0.0, 0.0, STYLE)
	assert_false(node.get_node("Dim/Center/Card/Layout/ScorePanel").visible)


func test_score_row_shows_and_reads_score_over_max() -> void:
	var node := _make()
	node.configure(true, 3, 4, 5, "Budi", "", 0.0, 0.0, 0.0, STYLE)
	var panel: Control = node.get_node("Dim/Center/Card/Layout/ScorePanel")
	assert_true(panel.visible)
	var value_text: String = \
		node.get_node("Dim/Center/Card/Layout/ScorePanel/ScoreRow/ScoreValueLabel").text
	assert_contains(value_text, "4")
	assert_contains(value_text, "5")


func test_category_badge_hides_when_no_category() -> void:
	var node := _make()
	node.configure(true, 1, -1, -1, "Budi", "", 0.0, 0.0, 0.0, STYLE)
	assert_false(node.get_node("Dim/Center/Card/Layout/CategoryBadge").visible)


func test_the_popup_uses_no_emoji_as_iconography() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameResultPopup.gd")
	# GDScript takes \U plus eight hex digits for the astral planes; the
	# three BMP glyphs below are safe as literals. Note \u{...} is NOT valid
	# syntax.
	var banned: Array[String] = [
		"\U0001F4DA", "\U0001F3A8", "⚽", "⚡", "\U0001F60A",
		"\U0001F389", "\U0001F525", "✨", "\U0001F680", "\U0001F3AE",
	]
	for glyph in banned:
		assert_false(src.contains(glyph),
			"emoji-as-iconography has been banned since the 2026-09-02 pass")


func test_the_category_badge_shows_a_texture_not_a_glyph() -> void:
	var node := _make()
	node.configure(true, 3, 3, 3, "Pilihan Ganda", "Akademis", 5.0, -2.0, 1.0, STYLE)
	assert_true(node.badge_icon.texture != null, "the badge carries an icon texture")
	assert_eq(node.category_badge_label.text, "Akademis", "and just the name as text")


func test_each_delta_row_carries_its_own_icon() -> void:
	var node := _make()
	node.configure(true, 3, 3, 3, "Pilihan Ganda", "Olahraga", 5.0, -2.0, 1.0, STYLE)
	assert_true(node.stat_delta_icon.texture != null, "the stat delta has an icon")
	assert_true(node.energy_delta_icon.texture != null, "energy has icon_energy")
	assert_true(node.mood_delta_icon.texture != null, "mood has icon_mood")


func test_configure_builds_no_styleboxes_or_overrides_at_runtime() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameResultPopup.gd")
	assert_false(src.contains("StyleBoxFlat.new()"),
		"card, badge and button chrome come from theme variations now")
	assert_false(src.contains("StyleBoxTexture.new()"), "same for the textured card")
	assert_false(src.contains("add_theme_stylebox_override"), "no stylebox overrides")
	assert_false(src.contains("add_theme_color_override"), "no colour overrides")
	assert_false(src.contains("add_theme_font_size_override"), "no font-size overrides")


func test_the_score_row_shows_for_a_game_with_only_a_target() -> void:
	var node := _make()
	# Badminton's shape after Task 4: a real score, a real target.
	node.configure(true, 3, 7, 7, "Badminton", "Olahraga", 5.0, -2.0, 1.0, STYLE)
	assert_true(node.score_panel.visible,
		"a target-based game gets a score row, not a blank card")


func test_each_delta_label_hides_independently_when_its_delta_is_zero() -> void:
	# Task 12 moved the toggle from each Label onto its own row
	# (StatDeltaRow/EnergyDeltaRow/MoodDeltaRow), so a hidden row takes its
	# icon with it.
	var node := _make()
	node.configure(true, 1, -1, -1, "Budi", "Akademis", 5.0, 0.0, -3.0, STYLE)
	var stat_row := node.get_node("Dim/Center/Card/Layout/DeltaPanel/DeltaList/StatDeltaRow")
	var energy_row := node.get_node("Dim/Center/Card/Layout/DeltaPanel/DeltaList/EnergyDeltaRow")
	var mood_row := node.get_node("Dim/Center/Card/Layout/DeltaPanel/DeltaList/MoodDeltaRow")
	assert_true(stat_row.visible)
	assert_false(energy_row.visible, "energy delta is 0.0 -- its row must stay hidden")
	assert_true(mood_row.visible)
	assert_contains(node.stat_delta_label.text, "+5")
	assert_contains(node.mood_delta_label.text, "-3")


func test_base_minigame_no_longer_builds_the_result_card() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/BaseMinigame.gd")
	assert_contains(src, "MinigameResultPopup", "BaseMinigame should instantiate the scene")
	assert_false(src.contains("func _draw_star_polygon"),
		"star drawing moved to ResultStar.gd")


func test_star_calculation_stayed_on_base_minigame() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/BaseMinigame.gd")
	assert_true(src.contains("static func _calculate_stars(ratio: float, is_win: bool) -> int:"),
		"the rubric still lives on BaseMinigame, not in the popup")
	var popup_src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameResultPopup.gd")
	assert_false(popup_src.contains("_calculate_stars"),
		"the popup renders stars, it does not decide them")


## Every icon this screen now uses instead of an emoji glyph. The project
## banned emoji as UI iconography during the 2026-09-02 pass; these are the
## replacements.
const RESULT_ICONS := [
	"res://Assets/Images/UI/Placeholders/icon_bintang.svg",
	"res://Assets/Images/UI/Placeholders/icon_bintang_kosong.svg",
	"res://Assets/Images/UI/Placeholders/icon_skor.svg",
	"res://Assets/Images/UI/Placeholders/icon_target.svg",
	"res://Assets/Images/UI/Placeholders/icon_akurasi.svg",
	"res://Assets/Images/UI/Placeholders/icon_kombo.svg",
	"res://Assets/Images/UI/Placeholders/icon_waktu.svg",
]


func test_every_result_icon_exists_and_loads_as_a_texture() -> void:
	for path in RESULT_ICONS:
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		assert_true(load(path) is Texture2D, "%s loads as a Texture2D" % path)


const PARTICLE_SCENES := [
	"res://Scenes/Minigames/UI/StarBurst.tscn",
	"res://Scenes/Minigames/UI/ResultConfetti.tscn",
	"res://Scenes/Minigames/UI/ScorePopBurst.tscn",
]


func test_every_particle_scene_is_a_one_shot_reward_particles_emitter() -> void:
	for path in PARTICLE_SCENES:
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		var node: Node = load(path).instantiate()
		track(node)
		assert_true(node is GPUParticles2D, "%s roots at a GPUParticles2D" % path)
		assert_true(node is RewardParticles,
			"%s reuses RewardParticles rather than a new script" % path)
		assert_true(node.one_shot, "%s is one-shot" % path)
		assert_false(node.emitting, "%s does not emit until fired" % path)
		assert_true(node.texture != null, "%s has an authored texture" % path)
		assert_true(node.process_material != null, "%s has an authored material" % path)


## The variations the result card and score HUD are styled by. Their existence
## in the baked theme is what lets Tasks 12 and 14 delete every runtime
## StyleBox and theme_override_* from MinigameResultPopup.configure().
const RESULT_VARIATIONS := [
	"ResultCardPanel", "ResultStatPanel", "ResultBadgePanel", "ResultStarSlot",
	"ResultDeltaLabel", "ScoreHudPanel", "ScoreHudValueLabel",
]


func test_every_result_variation_is_in_the_baked_theme() -> void:
	var theme: Theme = load("res://Assets/Theme/kejartes_theme.tres")
	# Base type "Panel", not "PanelContainer" -- every panel-style variation
	# in ThemeFactory.gd is registered with set_type_variation(name, "Panel")
	# even though the nodes that use them are PanelContainer in the .tscn.
	var types := theme.get_type_variation_list("Panel") \
		+ theme.get_type_variation_list("Label") \
		+ theme.get_type_variation_list("Control")
	for variation in RESULT_VARIATIONS:
		assert_true(variation in types,
			"%s is a baked type variation -- rebake ThemeFactory if not" % variation)


func test_a_star_defaults_to_real_art_not_the_procedural_polygon() -> void:
	var star: Control = load(STAR_PATH).instantiate()
	Engine.get_main_loop().root.add_child(star)
	track(star)
	star.set_filled(true, null, null, Color.WHITE, Color.GRAY)
	assert_true(star.icon.texture != null,
		"a null texture argument falls back to the shipped star art, not to _draw()")
	assert_true(star.is_filled, "and the star reads as earned")


func test_an_unearned_star_uses_the_hollow_art() -> void:
	var star: Control = load(STAR_PATH).instantiate()
	Engine.get_main_loop().root.add_child(star)
	track(star)
	star.set_filled(false, null, null, Color.WHITE, Color.GRAY)
	assert_true(star.icon.texture != null, "the empty star has art too")
	assert_false(star.is_filled, "and reads as unearned")


func test_the_star_scene_carries_a_glow_and_a_burst_slot() -> void:
	var star: Control = load(STAR_PATH).instantiate()
	track(star)
	assert_true(star.has_node("Glow"), "an authored Glow layer, not a runtime one")
	assert_true(star.has_node("BurstSlot"), "an authored slot the burst mounts into")


func test_celebrate_is_not_a_coroutine() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/ResultStar.gd")
	var body: String = src.split("func celebrate(")[1].split("\nfunc ")[0]
	assert_false(body.contains("await "),
		"celebrate() must be callable from a test and from the reveal loop")
