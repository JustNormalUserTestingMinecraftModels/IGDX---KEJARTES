@tool
extends McpTestSuite

## The rebuilt Daily Results popup (spec:
## docs/superpowers/specs/2026-08-29-day-summary-mockup-design.md).
##
## Suite constraints carried from tests/test_school_day.gd:
##  * @tool, or the runner reports the class abstract.
##  * No coroutines -- the runner does suite.call(name) without awaiting.
##  * The baked theme is assigned explicitly before a scene enters the
##    tree; ThemeDB's project-theme fallback does not populate under the
##    editor's own root.

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"

const _ART := {
	"card_bg": "res://Assets/Images/DaySummary/card_bg.png",
	"title": "res://Assets/Images/DaySummary/title_daily_results.png",
	"chevron": "res://Assets/Images/DaySummary/icon_chevron_up.png",
	"akademis": "res://Assets/Images/DaySummary/icon_akademis.png",
	"seni": "res://Assets/Images/DaySummary/icon_seni.png",
	"olahraga": "res://Assets/Images/DaySummary/icon_olahraga.png",
}

const _SPLASH := [
	"res://Assets/Images/SplashArtMurid/splash_marcel.png",
	"res://Assets/Images/SplashArtMurid/splash_doni.png",
	"res://Assets/Images/SplashArtMurid/splash_andi.png",
	"res://Assets/Images/SplashArtMurid/splash_citra.png",
	"res://Assets/Images/SplashArtMurid/splash_shinta.png",
	"res://Assets/Images/SplashArtMurid/splash_thea.png",
]


func suite_name() -> String:
	return "day_summary"


## Snapshot the active tweens, run `action`, then fast-forward only the
## tweens it created by `duration` seconds. Lifted from
## tests/test_juice.gd:52 -- the MCP runner calls suite.call(name)
## without awaiting, so Tween.custom_step() is the only way a
## non-coroutine test can see an animation's end state. Diffing against
## the before-snapshot keeps a tween still finishing from an earlier test
## (or from the editor's own UI) from being mistaken for this one's.
func _run_and_step(action: Callable, duration: float) -> void:
	var before: Array = Engine.get_main_loop().get_processed_tweens()
	action.call()
	var after: Array = Engine.get_main_loop().get_processed_tweens()
	for tw in after:
		if not before.has(tw) and is_instance_valid(tw):
			tw.custom_step(duration)


func test_every_day_summary_texture_imports() -> void:
	for key in _ART:
		var path: String = _ART[key]
		assert_true(ResourceLoader.exists(path),
			"missing day-summary art '%s' at %s" % [key, path])
		var tex := load(path) as Texture2D
		assert_not_null(tex, "%s did not load as a Texture2D" % path)


func test_every_new_splash_imports() -> void:
	for path in _SPLASH:
		assert_true(ResourceLoader.exists(path), "missing splash %s" % path)
		var tex := load(path) as Texture2D
		assert_not_null(tex, "%s did not load as a Texture2D" % path)


## Both card art and banner ship letterboxed inside 1:1 canvases from the
## design tool. Godot's KEEP_ASPECT_CENTERED honours the CANVAS aspect, so
## an uncropped 1080x1080 export collapses to a square and the card loses
## its background entirely. These pin the cropped content boxes measured
## with probe.ps1 -Mode bbox.
func test_card_background_is_cropped_to_its_content_box() -> void:
	var tex := load(_ART["card_bg"]) as Texture2D
	assert_eq(tex.get_width(), 992, "card_bg width is not its content box")
	assert_eq(tex.get_height(), 410, "card_bg height is not its content box")


func test_title_banner_is_cropped_to_its_content_box() -> void:
	var tex := load(_ART["title"]) as Texture2D
	assert_eq(tex.get_width(), 1058, "banner width is not its content box")
	assert_eq(tex.get_height(), 325, "banner height is not its content box")


## The bug this plan exists to kill: a 1:1 canvas holding a wide band of
## art. If either asset is ever re-exported square again, this fails loudly
## instead of silently rendering a stamp.
func test_neither_card_art_nor_banner_is_square() -> void:
	for key in ["card_bg", "title"]:
		var tex := load(_ART[key]) as Texture2D
		var aspect := float(tex.get_width()) / float(tex.get_height())
		assert_true(aspect > 1.5,
			"%s is square-ish (aspect %f) -- it must be cropped to its content box" % [key, aspect])


## Every colour here was centroid-sampled from the mockup. A drifted
## token means the rebake will paint something the mockup does not show.
func test_day_summary_tokens_match_the_mockup() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	var expected := {
		"day_avatar_fill": "5e4ebc",
		"day_avatar_border": "3d3d3d",
		"day_bar_track": "585858",
		"day_bar_border": "2b2b2b",
		"day_energy_fill": "6d60c0",
		"day_mood_fill": "c8af57",
		"day_stat_track": "383838",
		"day_glyph_outline": "3d1e48",
	}
	for key in expected:
		var c: Color = tokens.get(key)
		assert_eq(c.to_html(false), expected[key],
			"token %s drifted from the mockup sample" % key)


const _DAY_VARIATIONS := {
	"DaySummaryName": "Label",
	"DaySummaryStat": "Label",
	"DaySummaryAvatarFrame": "Panel",
	"DaySummaryEnergyBar": "ProgressBar",
	"DaySummaryMoodBar": "ProgressBar",
	"DaySummaryStatTrackAkademis": "ProgressBar",
	"DaySummaryStatTrackSeniBudaya": "ProgressBar",
	"DaySummaryStatTrackOlahraga": "ProgressBar",
}


func test_theme_declares_every_day_summary_variation() -> void:
	var theme := load(_THEME_PATH) as Theme
	assert_not_null(theme, "baked theme failed to load")
	for name in _DAY_VARIATIONS:
		assert_true(theme.get_type_list().has(name),
			"theme is missing variation %s -- did you rebake?" % name)
		assert_eq(theme.get_type_variation_base(name), _DAY_VARIATIONS[name],
			"%s is based on the wrong type" % name)


## The name and the numbers are white-on-light with a dark rim; getting
## this inverted (the project's usual dark-on-light) makes them vanish
## against the card's pale fill.
func test_day_summary_text_is_white_with_a_dark_rim() -> void:
	var theme := load(_THEME_PATH) as Theme
	var tokens := DesignTokens.load_default()
	for name in ["DaySummaryName", "DaySummaryStat"]:
		assert_eq(theme.get_color("font_color", name), Color.WHITE,
			"%s should be white" % name)
		assert_eq(theme.get_color("font_outline_color", name),
			tokens.day_glyph_outline, "%s rim drifted" % name)
		assert_true(theme.get_constant("outline_size", name) > 0,
			"%s has no outline" % name)


## The two bars share a track and differ only in fill. If they ever share
## a fill too, energy and mood become indistinguishable.
func test_energy_and_mood_bars_differ_only_in_fill() -> void:
	var theme := load(_THEME_PATH) as Theme
	var tokens := DesignTokens.load_default()
	var e_bg := theme.get_stylebox("background", "DaySummaryEnergyBar") as StyleBoxFlat
	var m_bg := theme.get_stylebox("background", "DaySummaryMoodBar") as StyleBoxFlat
	assert_eq(e_bg.bg_color, m_bg.bg_color, "bar tracks diverged")
	assert_eq(e_bg.bg_color, tokens.day_bar_track, "bar track drifted")
	# The fill is the shared progress-bar art (see ThemeFactory's
	# _progress_fill_stylebox), tinted per bar via modulate_color rather
	# than drawn as a flat colour.
	var e_fill := theme.get_stylebox("fill", "DaySummaryEnergyBar") as StyleBoxTexture
	var m_fill := theme.get_stylebox("fill", "DaySummaryMoodBar") as StyleBoxTexture
	assert_eq(e_fill.modulate_color, tokens.day_energy_fill, "energy fill drifted")
	assert_eq(m_fill.modulate_color, tokens.day_mood_fill, "mood fill drifted")


## Which token each stat track fills with. The icons already tell the
## three rows apart by subject; the fills now agree with them.
const _STAT_TRACK_FILL_TOKEN := {
	"DaySummaryStatTrackAkademis": "cat_akademis",
	"DaySummaryStatTrackSeniBudaya": "cat_senibudaya",
	"DaySummaryStatTrackOlahraga": "cat_olahraga",
}


func test_each_stat_track_fills_in_its_category_colour() -> void:
	var theme := load(_THEME_PATH) as Theme
	var tokens := DesignTokens.load_default()
	for name in _STAT_TRACK_FILL_TOKEN:
		var bg := theme.get_stylebox("background", name) as StyleBoxFlat
		assert_not_null(bg, "%s has no background stylebox -- did you rebake?" % name)
		assert_eq(bg.bg_color, tokens.day_stat_track,
			"%s rail drifted off the mockup's stat-track colour" % name)
		# The fill is the shared progress-bar art, tinted via modulate_color.
		var fill := theme.get_stylebox("fill", name) as StyleBoxTexture
		assert_not_null(fill, "%s has no fill stylebox -- did you rebake?" % name)
		assert_eq(fill.modulate_color, tokens.get(_STAT_TRACK_FILL_TOKEN[name]),
			"%s fill is not its category colour" % name)


## The exact defect this change exists to fix: the old single
## DaySummaryStatTrack variation used day_stat_track for BOTH the
## background and the fill, so the bar looked identical at 0% and at
## 100% and read as permanently empty. If a fill ever equals its own
## rail again, the gauge is invisible no matter what value it holds.
func test_no_stat_track_fill_matches_its_own_rail() -> void:
	var theme := load(_THEME_PATH) as Theme
	for name in _STAT_TRACK_FILL_TOKEN:
		var bg := theme.get_stylebox("background", name) as StyleBoxFlat
		var fill := theme.get_stylebox("fill", name) as StyleBoxTexture
		assert_ne(fill.modulate_color, bg.bg_color,
			"%s fill equals its rail -- the bar reads as empty at every value" % name)


const _AVATAR_SCENE := "res://Scenes/SchoolSimulation/DaySummaryAvatar.tscn"

## Frame is 269x286 in the mockup; every crop must match that aspect or
## the splash is stretched. Tolerance is one part in fifty.
const _FRAME_ASPECT := 269.0 / 286.0


func test_every_named_crop_matches_the_frame_aspect() -> void:
	for student_name in DaySummaryAvatar.SPLASH_CROP:
		var r: Rect2 = DaySummaryAvatar.SPLASH_CROP[student_name]
		assert_true(r.size.x > 0.0 and r.size.y > 0.0,
			"%s has an empty crop" % student_name)
		var aspect := r.size.x / r.size.y
		assert_true(absf(aspect - _FRAME_ASPECT) < 0.02,
			"%s crop aspect %f is not the frame's %f"
				% [student_name, aspect, _FRAME_ASPECT])


## Every named crop must sit inside its own texture, or Godot samples
## transparent padding and the head drifts off-centre.
func test_every_named_crop_is_inside_its_texture() -> void:
	var paths := {
		"Marcel": "res://Assets/Images/SplashArtMurid/splash_marcel.png",
		"Doni": "res://Assets/Images/SplashArtMurid/splash_doni.png",
		"Andi": "res://Assets/Images/SplashArtMurid/splash_andi.png",
		"Citra": "res://Assets/Images/SplashArtMurid/splash_citra.png",
		"Shinta": "res://Assets/Images/SplashArtMurid/splash_shinta.png",
		"Thea": "res://Assets/Images/SplashArtMurid/splash_thea.png",
	}
	for student_name in paths:
		var tex := load(paths[student_name]) as Texture2D
		var r: Rect2 = DaySummaryAvatar.SPLASH_CROP[student_name]
		assert_true(r.position.x >= 0.0 and r.position.y >= 0.0,
			"%s crop starts outside the texture" % student_name)
		assert_true(r.end.x <= float(tex.get_width()),
			"%s crop runs past the right edge" % student_name)
		assert_true(r.end.y <= float(tex.get_height()),
			"%s crop runs past the bottom edge" % student_name)


## Every student in the roster now has a named crop, so the fallback is
## reached only by a student who is not in the table at all -- a debug or
## test fixture. It must still produce a usable, correctly-shaped crop.
func test_unknown_students_get_a_computed_crop() -> void:
	var tex := load("res://Assets/Images/SplashArtMurid/splash_marcel.png") as Texture2D
	var r := DaySummaryAvatar.crop_for("Budi", tex)
	assert_true(r.size.x > 0.0 and r.size.y > 0.0,
		"fallback crop is empty")
	var aspect := r.size.x / r.size.y
	assert_true(absf(aspect - _FRAME_ASPECT) < 0.02,
		"fallback crop aspect %f is not the frame's" % aspect)
	assert_true(r.end.y <= float(tex.get_height()),
		"fallback crop runs off the bottom")


func test_avatar_scene_clips_and_wears_the_frame_variation() -> void:
	var scene := load(_AVATAR_SCENE) as PackedScene
	assert_not_null(scene, "DaySummaryAvatar.tscn failed to load")
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	assert_eq(inst.theme_type_variation, &"DaySummaryAvatarFrame",
		"avatar root is not wearing the frame variation")
	assert_true(inst.clip_contents,
		"avatar root must clip, or the splash spills past the rim")
	assert_not_null(inst.get_node_or_null("Art"),
		"avatar is missing its Art TextureRect")
	inst.free()


const _STAT_ROW_SCENE := "res://Scenes/SchoolSimulation/DaySummaryStatRow.tscn"


func test_stat_row_maps_each_key_to_its_mockup_icon() -> void:
	assert_eq(DaySummaryStatRow.ICON_FOR["akademis"],
		"res://Assets/Images/DaySummary/icon_akademis.png")
	assert_eq(DaySummaryStatRow.ICON_FOR["seni_budaya"],
		"res://Assets/Images/DaySummary/icon_seni.png")
	assert_eq(DaySummaryStatRow.ICON_FOR["olahraga"],
		"res://Assets/Images/DaySummary/icon_olahraga.png")


## The mockup prints "+12/65" -- delta over target, with an explicit
## plus. A bare "12/65" or a "+12/65.0" both miss it.
func test_stat_row_formats_delta_over_target() -> void:
	assert_eq(DaySummaryStatRow.format_value(12.0, 65.0), "+12/65")
	assert_eq(DaySummaryStatRow.format_value(9.0, 65.0), "+9/65")
	assert_eq(DaySummaryStatRow.format_value(0.0, 65.0), "+0/65")


## A stat can fall (an event or a lost minigame), and "+-3" would be
## nonsense. The sign must follow the number.
func test_stat_row_formats_a_loss_without_a_stray_plus() -> void:
	assert_eq(DaySummaryStatRow.format_value(-3.0, 65.0), "-3/65")


## The gauge contract the director set: a full bar means the student has
## reached the target for that stat this run. Floats are compared with
## is_equal_approx -- McpTestSuite has no assert_almost_eq, and
## 39.0/50.0*100.0 is not bit-exact.
func test_track_ratio_is_progress_toward_the_target() -> void:
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(39.0, 50.0), 78.0),
		"39 of a 50 target must read 78%")
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(25.0, 50.0), 50.0),
		"half the target must read 50%")
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(50.0, 50.0), 100.0),
		"at target must read a full bar")
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(0.0, 78.0), 0.0),
		"a zeroed stat must read an empty bar")


## Every degenerate input a real roster can produce. StudentData's
## target_akademis1/2/3 all default to 50.0, but a row built with no
## student at all passes target 0.0 -- that must not divide by zero, and
## overshooting a target must not paint outside the rail.
func test_track_ratio_clamps_and_survives_a_missing_target() -> void:
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(65.0, 50.0), 100.0),
		"past the target must clamp to full, not overflow")
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(30.0, 0.0), 0.0),
		"a zero target must return 0, not divide by zero")
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(30.0, -10.0), 0.0),
		"a negative target must return 0")
	assert_true(is_equal_approx(DaySummaryStatRow.track_ratio(-5.0, 50.0), 0.0),
		"a negative stat must clamp to empty")


## The row must wear the variation matching its own stat, or all three
## bars come out akademis blue (the scene's default from Task 1).
func test_stat_row_wears_the_variation_for_its_stat() -> void:
	assert_eq(DaySummaryStatRow.TRACK_VARIATION_FOR["akademis"],
		&"DaySummaryStatTrackAkademis", "akademis track variation is wrong")
	assert_eq(DaySummaryStatRow.TRACK_VARIATION_FOR["seni_budaya"],
		&"DaySummaryStatTrackSeniBudaya", "seni_budaya track variation is wrong")
	assert_eq(DaySummaryStatRow.TRACK_VARIATION_FOR["olahraga"],
		&"DaySummaryStatTrackOlahraga", "olahraga track variation is wrong")


## set_stat is the whole point of this change, so exercise it on a live
## instance rather than only asserting the pure helper. The scene is
## added to the tree so its @onready vars resolve, and the baked theme is
## assigned explicitly -- ThemeDB's project-theme fallback does not
## populate under the editor's own root.
func test_set_stat_fills_the_track_and_leaves_the_number_alone() -> void:
	var scene := load(_STAT_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	inst.set_stat("olahraga", 6.0, 50.0, 39.0)

	assert_true(is_equal_approx(inst.track.value, 78.0),
		"track must fill to current/target, not sit at max")
	assert_eq(inst.value.text, "+6/50",
		"the number must still be the DAY'S GAIN over the target")
	assert_eq(inst.track.theme_type_variation, &"DaySummaryStatTrackOlahraga",
		"track must switch to its own stat's variation")


## The mockup's gold arrow is an UP arrow and the asset folder ships no
## down variant, so it may only appear on a genuine gain. A stat that did
## not move (+0) or went backwards leaves the track bare rather than
## claiming progress the student did not make.
func test_shows_chevron_only_on_a_gain() -> void:
	assert_true(DaySummaryStatRow.shows_chevron(12.0),
		"a +12 day must show the up arrow")
	assert_true(DaySummaryStatRow.shows_chevron(0.4),
		"any positive gain, however small, must show the arrow")
	assert_false(DaySummaryStatRow.shows_chevron(0.0),
		"a +0 day must not show an up arrow")
	assert_false(DaySummaryStatRow.shows_chevron(-3.0),
		"a losing day must not show an UP arrow -- there is no down asset")


## The gate has to be wired into set_stat, not just available as a
## helper. Three live rows, one per case, because set_stat writes the
## visibility and nothing resets it between calls.
func test_set_stat_gates_the_chevron_on_the_days_delta() -> void:
	var scene := load(_STAT_ROW_SCENE) as PackedScene

	var gained := scene.instantiate()
	gained.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(gained)
	track(gained)
	gained.set_stat("akademis", 12.0, 65.0, 40.0)
	assert_true(gained.chevron.visible, "a +12 row must show its chevron")
	assert_eq(gained.value.text, "+12/65",
		"gating the chevron must not disturb the number")

	var flat := scene.instantiate()
	flat.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(flat)
	track(flat)
	flat.set_stat("seni_budaya", 0.0, 65.0, 40.0)
	assert_false(flat.chevron.visible, "a +0 row must hide its chevron")
	assert_eq(flat.value.text, "+0/65",
		"a +0 row still shows its number -- only the arrow goes")

	var lost := scene.instantiate()
	lost.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(lost)
	track(lost)
	lost.set_stat("olahraga", -3.0, 65.0, 40.0)
	assert_false(lost.chevron.visible, "a losing row must hide its chevron")
	assert_eq(lost.value.text, "-3/65",
		"a loss still reads -3/65, as format_value already guarantees")


## Where the track stood this morning. The day's gain has already been
## applied to the StudentData by the time the popup is built, so the
## starting point is current MINUS the delta -- not plus.
func test_track_ratio_before_backs_todays_gain_out() -> void:
	assert_true(is_equal_approx(
		DaySummaryStatRow.track_ratio_before(39.0, 6.0, 50.0), 66.0),
		"39 after a +6 day means the morning read 33/50 = 66%")
	assert_true(is_equal_approx(
		DaySummaryStatRow.track_ratio_before(39.0, 0.0, 50.0), 78.0),
		"a day that gained nothing must start exactly where it ends")
	assert_true(is_equal_approx(
		DaySummaryStatRow.track_ratio_before(4.0, 10.0, 50.0), 0.0),
		"a gain larger than the standing stat must clamp to empty, not go negative")
	assert_true(is_equal_approx(
		DaySummaryStatRow.track_ratio_before(30.0, -5.0, 50.0), 70.0),
		"a losing day must start ABOVE where it ends, so the bar shrinks")
	assert_true(is_equal_approx(
		DaySummaryStatRow.track_ratio_before(30.0, 5.0, 0.0), 0.0),
		"a zero target must return 0, not divide by zero")


## set_stat must still land the final value on its own, so a row that is
## never animated -- the editor preview, a future caller -- is still
## correct. play_gain then rewinds and grows back.
func test_play_gain_rewinds_the_track_to_this_mornings_value() -> void:
	var scene := load(_STAT_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	inst.set_stat("akademis", 6.0, 50.0, 39.0)
	assert_true(absf(inst.track.value - 78.0) <= 0.01,
		"set_stat must still leave the DAY'S FINAL value on the track")

	inst.play_gain()
	assert_true(absf(inst.track.value - 66.0) <= 0.01,
		"play_gain must rewind the track to 33/50 = 66% before it grows")
	assert_eq(inst.value.text, "+0/50",
		"play_gain must rewind the number to 0 alongside the track, so it can count back up")


## ...and the growth must end exactly where set_stat put it. Stepping the
## tween past dur_slow is what proves the fill is a real animation and
## not just a second assignment.
func test_a_played_gain_lands_on_the_days_final_value() -> void:
	var scene := load(_STAT_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	var tokens := DesignTokens.load_default()
	inst.set_stat("olahraga", 6.0, 50.0, 39.0)
	_run_and_step(func(): inst.play_gain(), tokens.dur_slow + 0.2)

	assert_true(absf(inst.track.value - 78.0) <= 0.01,
		"the fill must end exactly on current/target")
	assert_eq(inst.track.theme_type_variation, &"DaySummaryStatTrackOlahraga",
		"replaying the fill must not disturb the row's category colour")
	assert_eq(inst.value.text, "+6/50",
		"the number must land exactly on the day's real gain, not a float-eased approximation")


## A loss must count DOWN from 0 to a negative number -- format_value's
## sign flips on the interpolated value itself, not on the final total,
## so this is the one case a naive "always positive" counter would get
## wrong.
func test_a_losing_days_number_counts_down_to_negative() -> void:
	var scene := load(_STAT_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	var tokens := DesignTokens.load_default()
	inst.set_stat("olahraga", -5.0, 50.0, 30.0)
	assert_eq(inst.value.text, "-5/50",
		"set_stat must still leave the DAY'S FINAL number showing")

	_run_and_step(func(): inst.play_gain(), tokens.dur_slow + 0.2)
	assert_eq(inst.value.text, "-5/50",
		"the number must land exactly on the day's real loss")


## Juice.pop_in zeroes the chevron's alpha and shrinks it before tweening
## both back, so a row that has animated once carries a mutated chevron.
## Re-arming that row for another student must restore it -- otherwise
## set_stat's "visible" is a lie and the arrow never appears.
func test_set_stat_rearms_a_chevron_that_play_gain_already_popped() -> void:
	var scene := load(_STAT_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	inst.set_stat("akademis", 6.0, 50.0, 39.0)
	inst.play_gain()
	assert_true(inst.chevron.modulate.a <= 0.01,
		"pop_in must have zeroed the chevron's alpha at the start of the gain")

	# The row is re-used for another student without a second play_gain.
	inst.set_stat("akademis", 4.0, 50.0, 20.0)

	assert_true(inst.chevron.visible, "a +4 row must show its chevron")
	assert_true(is_equal_approx(inst.chevron.modulate.a, 1.0),
		"set_stat must restore the alpha pop_in zeroed")
	assert_true(is_equal_approx(inst.chevron.scale.x, 1.0),
		"set_stat must restore the scale pop_in shrank")


## The card drives all three of its rows, including the ones that did not
## move -- those simply rewind to where they already are and hold still.
func test_the_card_replays_every_stat_track() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	var s := StudentData.new()
	s.student_name = "Marcel"
	s.akademis = 39.0
	s.seni_budaya = 20.0
	s.olahraga = 10.0
	s.target_akademis1 = 50.0
	s.target_akademis2 = 50.0
	s.target_akademis3 = 50.0
	inst.setup_row("Marcel", [
		{"stat_key": "akademis", "delta": 6.0},
		{"stat_key": "seni_budaya", "delta": 4.0},
	], s)

	inst.play_gain()

	assert_true(absf(inst.stat_rows[0].track.value - 66.0) <= 0.01,
		"akademis must rewind to 33/50 = 66%")
	assert_true(absf(inst.stat_rows[1].track.value - 32.0) <= 0.01,
		"seni_budaya must rewind to 16/50 = 32%")
	assert_true(absf(inst.stat_rows[2].track.value - 20.0) <= 0.01,
		"olahraga did not move, so it must hold still at 10/50 = 20%")


## The card staggers its three rows rather than firing them together. Step
## half a GAIN_STEP in: row 0's fill has started moving off its rewound
## value while row 1 is still sitting exactly on its own, which is only
## true if the per-row delay is real. Dropping the stagger leaves both
## moving and fails the second assertion.
func test_the_cards_three_rows_do_not_all_fill_at_once() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	var s := StudentData.new()
	s.student_name = "Marcel"
	s.akademis = 39.0
	s.seni_budaya = 20.0
	s.olahraga = 10.0
	s.target_akademis1 = 50.0
	s.target_akademis2 = 50.0
	s.target_akademis3 = 50.0
	inst.setup_row("Marcel", [
		{"stat_key": "akademis", "delta": 6.0},
		{"stat_key": "seni_budaya", "delta": 4.0},
	], s)

	_run_and_step(func(): inst.play_gain(),
		DaySummaryStudentRow.GAIN_STEP * 0.5)

	assert_true(inst.stat_rows[0].track.value > 66.0,
		"row 0 has no delay, so it must already be climbing off 66%")
	assert_true(is_equal_approx(inst.stat_rows[1].track.value, 32.0),
		"row 1 is still inside its GAIN_STEP delay and must not have moved")


## A day that LOST ground must rewind ABOVE where it ends and shrink into
## place, and must not pop a chevron it is not showing -- play_gain's
## `if chevron.visible` guard has no other coverage.
func test_a_losing_day_shrinks_the_track_and_pops_no_chevron() -> void:
	var scene := load(_STAT_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	inst.set_stat("olahraga", -5.0, 50.0, 30.0)
	assert_false(inst.chevron.visible, "a losing row shows no arrow")

	inst.play_gain()
	assert_true(absf(inst.track.value - 70.0) <= 0.01,
		"a loss must rewind to 35/50 = 70%, ABOVE where it lands")
	assert_true(is_equal_approx(inst.chevron.modulate.a, 1.0),
		"play_gain must not pop a chevron that is hidden")

	var tokens := DesignTokens.load_default()
	_run_and_step(func(): inst.play_gain(), tokens.dur_slow + 0.2)
	assert_true(absf(inst.track.value - 60.0) <= 0.01,
		"the track must settle at 30/50 = 60%, having shrunk")


## The popup owns the beat: the bars grow after the cards have landed,
## not while the stack is still fading in. A source scan because
## setup_summary is a coroutine and this suite may not await one.
func test_popup_replays_each_cards_gain_once_the_cards_start_landing() -> void:
	var src := FileAccess.get_file_as_string(_POPUP_SCRIPT)
	assert_true(src.contains("Juice.stagger_in(rows)"),
		"the cards must still stagger in")
	assert_true(src.contains("play_gain("),
		"the popup must replay each card's stat-track growth")
	assert_true(src.find("Juice.stagger_in(rows)") < src.find("play_gain("),
		"the fill must be kicked off after stagger_in, not before it")


func test_stat_row_scene_wears_the_theme_and_has_no_overrides() -> void:
	var scene := load(_STAT_ROW_SCENE) as PackedScene
	assert_not_null(scene, "DaySummaryStatRow.tscn failed to load")
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	var track := inst.get_node_or_null("Track")
	assert_not_null(track, "stat row is missing its Track")
	assert_eq(track.theme_type_variation, &"DaySummaryStatTrackAkademis",
		"Track is not wearing a DaySummaryStatTrack* variation")
	var value := inst.get_node_or_null("Value")
	assert_not_null(value, "stat row is missing its Value label")
	assert_eq(value.theme_type_variation, &"DaySummaryStat",
		"Value is not wearing DaySummaryStat")
	assert_not_null(inst.get_node_or_null("Icon"), "stat row is missing Icon")
	assert_not_null(inst.get_node_or_null("Chevron"),
		"stat row is missing Chevron")
	inst.free()


const _ROW_SCENE := "res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn"
const _ROW_SCRIPT := "res://Scripts/SchoolSimulation/DaySummaryStudentRow.gd"


## The card art is placed at native size, so the row must reserve
## exactly the mockup's box. A row that shrink-wraps its children
## instead would slide every child off the painted background.
##
## 992x410, not the original 992x405 estimate: card_bg.png's own
## content box (measured via probe.ps1 -Mode bbox, see the
## 2026-08-29-day-summary-mockup-fixes plan) is 992x410, and the art
## itself is the authority once it has been cropped to that box.
func test_row_reserves_the_mockup_card_box() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	assert_eq(inst.custom_minimum_size, Vector2(992, 410),
		"card box drifted from the card art's cropped content box")
	inst.free()


func test_row_carries_the_card_art_and_the_three_stat_rows() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)

	var bg := inst.get_node_or_null("CardArt") as TextureRect
	assert_not_null(bg, "row is missing its CardArt")
	assert_not_null(bg.texture, "CardArt has no texture assigned")

	assert_not_null(inst.get_node_or_null("Avatar"), "row is missing Avatar")
	for i in range(1, 4):
		assert_not_null(inst.get_node_or_null("StatRow%d" % i),
			"row is missing StatRow%d" % i)
	inst.free()


## Energy is the TOP bar and mood the BOTTOM one, and they are violet
## and gold respectively. The existing DayScreen cards use the opposite
## tints (spec section 5); this pins the popup to the mockup so a later
## reconciliation cannot silently swap them here.
func test_energy_is_the_top_bar_and_mood_the_bottom() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	var energy := inst.get_node_or_null("EnergyBar") as ProgressBar
	var mood := inst.get_node_or_null("MoodBar") as ProgressBar
	assert_not_null(energy, "row is missing EnergyBar")
	assert_not_null(mood, "row is missing MoodBar")
	assert_eq(energy.theme_type_variation, &"DaySummaryEnergyBar",
		"EnergyBar is wearing the wrong variation")
	assert_eq(mood.theme_type_variation, &"DaySummaryMoodBar",
		"MoodBar is wearing the wrong variation")
	assert_true(energy.offset_top < mood.offset_top,
		"energy must sit above mood, as in the mockup")
	inst.free()


## The two bars the mockup annotates red and yellow. Both are 0-100
## scales, so `value` IS the percentage and no conversion is involved --
## the assertion on max_value pins that, because a later scene edit that
## rescaled the bar would silently turn 21 energy into 21% of something
## else.
##
## The values below are deliberately NOT the scene's baked 36/82: those
## are the mockup's placeholders, and a test using them would pass even
## if the assignment were deleted entirely.
func test_setup_row_writes_the_students_real_energy_and_mood() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	var s := StudentData.new()
	s.student_name = "Marcel"
	s.energy = 21.0
	s.mood = 64.0
	inst.setup_row("Marcel", [], s)

	assert_true(is_equal_approx(inst.energy_bar.max_value, 100.0),
		"energy bar must stay a 0-100 scale so `value` IS the percentage")
	assert_true(is_equal_approx(inst.mood_bar.max_value, 100.0),
		"mood bar must stay a 0-100 scale so `value` IS the percentage")
	assert_true(is_equal_approx(inst.energy_bar.value, 21.0),
		"energy bar must read the student's energy, not the scene placeholder")
	assert_true(is_equal_approx(inst.mood_bar.value, 64.0),
		"mood bar must read the student's mood, not the scene placeholder")
	assert_eq(inst.name_label.text, "Marcel",
		"the card must be labelled with the student it was built for")


## The popup looks each student up by name and passes null when the
## lookup misses. Leaving the scene's baked 36/82 there would paint a
## confident, fabricated reading of a student we could not find; empty
## bars are the honest answer, and they match the avatar, which already
## clears its texture on null.
func test_setup_row_empties_the_needs_bars_for_an_unknown_student() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	inst.setup_row("Nobody", [], null)

	assert_true(is_equal_approx(inst.energy_bar.value, 0.0),
		"an unknown student must not inherit the mockup's 36% energy")
	assert_true(is_equal_approx(inst.mood_bar.value, 0.0),
		"an unknown student must not inherit the mockup's 82% mood")


## The two DeltaLabels exist for ResultCheckup's weekly card. The mockup
## has no needs number, so the daily path must leave them hidden -- if a
## later edit shows them unconditionally, the daily card silently grows a
## readout the design does not have.
func test_setup_row_leaves_the_needs_deltas_hidden() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(inst)
	track(inst)

	var s := StudentData.new()
	s.student_name = "Marcel"
	s.energy = 40.0
	s.mood = 50.0
	inst.setup_row("Marcel", [], s)

	assert_false(inst.energy_delta_label.visible,
		"the daily card must not show an energy delta")
	assert_false(inst.mood_delta_label.visible,
		"the daily card must not show a mood delta")


## The naming trap this project documents in CLAUDE.md: target_akademis2
## is the SENI target and target_akademis3 the OLAHRAGA one. Getting it
## wrong shows the right number against the wrong icon.
func test_row_pairs_each_stat_with_its_correct_target_field() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("\"akademis\": \"target_akademis1\""),
		"akademis must read target_akademis1")
	assert_true(src.contains("\"seni_budaya\": \"target_akademis2\""),
		"seni_budaya must read target_akademis2, not target_akademis3")
	assert_true(src.contains("\"olahraga\": \"target_akademis3\""),
		"olahraga must read target_akademis3")


## The mockup shows a fixed three-row block; a card whose height varied
## with how many stats happened to move would break the stack rhythm.
func test_row_always_shows_three_stat_rows() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCRIPT)
	assert_true(src.contains("STAT_ORDER"),
		"row should drive its three rows from a fixed STAT_ORDER")
	assert_eq(DaySummaryStudentRow.STAT_ORDER.size(), 3,
		"the mockup shows exactly three stat rows")
	# The old row skipped any stat whose delta was zero, which made the
	# card's height depend on the day. Nothing may `continue` on a zero
	# delta any more.
	assert_false(src.contains("if delta == 0.0:"),
		"row must not skip stats that did not move")


## _sum_deltas is the only genuinely stateful logic this row adds, and it
## had zero behavioral coverage -- only a source-text scan confirming the
## naming-trap dictionary literal exists, not that it's actually the value
## the row uses. Both checks below work on a bare instantiate()d instance
## with no tree attachment: _sum_deltas touches no @onready var, and
## TARGET_FOR is a const readable without an instance at all (same
## pattern this file already uses for STAT_ORDER).
func test_row_sums_same_stat_deltas_and_reads_the_correct_target_field() -> void:
	assert_eq(DaySummaryStudentRow.TARGET_FOR["akademis"], "target_akademis1",
		"akademis must read target_akademis1")
	assert_eq(DaySummaryStudentRow.TARGET_FOR["seni_budaya"], "target_akademis2",
		"seni_budaya must read target_akademis2, not target_akademis3")
	assert_eq(DaySummaryStudentRow.TARGET_FOR["olahraga"], "target_akademis3",
		"olahraga must read target_akademis3, not target_akademis2")

	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()

	# Two changes to the SAME stat in one day must sum, not overwrite.
	var changes := [
		{"stat_key": "seni_budaya", "delta": 4.0},
		{"stat_key": "seni_budaya", "delta": 3.0},
		{"stat_key": "olahraga", "delta": 5.0},
		{"stat_key": "energy", "delta": 999.0},
	]
	var deltas: Dictionary = inst._sum_deltas(changes)

	assert_eq(deltas.get("seni_budaya"), 7.0,
		"seni_budaya deltas (4+3) must sum to 7, not overwrite to 3")
	assert_eq(deltas.get("olahraga"), 5.0, "olahraga must be unaffected by the seni_budaya sum")
	assert_false(deltas.has("energy"),
		"_sum_deltas must drop stat keys that have no TARGET_FOR entry (e.g. energy)")

	inst.free()


## No theme_override_* anywhere -- the project's hard styling rule.
func test_row_scene_declares_no_theme_overrides() -> void:
	var src := FileAccess.get_file_as_string(_ROW_SCENE)
	assert_false(src.contains("theme_override_colors"),
		"colour override found -- use a ThemeFactory variation")
	assert_false(src.contains("theme_override_fonts"),
		"font override found -- use a ThemeFactory variation")
	assert_false(src.contains("theme_override_styles"),
		"stylebox override found -- use a ThemeFactory variation")


const _POPUP_SCENE := "res://Scenes/SchoolSimulation/DaySummaryPopup.tscn"
const _POPUP_SCRIPT := "res://Scripts/SchoolSimulation/DaySummaryPopup.gd"


func test_popup_shows_the_banner_art_not_a_text_title() -> void:
	var scene := load(_POPUP_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	var banner := inst.find_child("TitleBanner", true, false) as TextureRect
	assert_not_null(banner, "popup is missing its TitleBanner")
	assert_not_null(banner.texture, "TitleBanner has no texture")
	# custom_minimum_size, not size: the scene is instantiated but never
	# enters a tree here, so no container sort has run and `size` is
	# still zero. This suite must not await one (no coroutines).
	assert_eq(banner.custom_minimum_size.x, 932.0,
		"banner width drifted from the mockup")
	inst.free()


## The mockup puts the banner and the cards straight on the scrim. A
## surviving Card panel would draw a white slab behind both.
func test_popup_has_no_card_panel_behind_the_stack() -> void:
	var src := FileAccess.get_file_as_string(_POPUP_SCENE)
	assert_false(src.contains("theme_type_variation = &\"Card\""),
		"the popup still carries a Card panel behind the stack")


## Up to six students can move in a day; six 405px cards overflow 1920px.
func test_popup_scrolls_its_rows() -> void:
	var scene := load(_POPUP_SCENE) as PackedScene
	var inst := scene.instantiate()
	var scroll := inst.find_child("RowsScroll", true, false)
	assert_true(scroll is ScrollContainer,
		"rows must live in a ScrollContainer -- six cards overflow the screen")
	var rows := inst.find_child("RowsContainer", true, false)
	assert_not_null(rows, "popup is missing RowsContainer")
	inst.free()


## SchoolDay hands the popup a real summary and expects the rows built
## from it (Task 8 removes the reparenting that used to bypass this).
func test_popup_still_exposes_its_contract() -> void:
	var src := FileAccess.get_file_as_string(_POPUP_SCRIPT)
	assert_true(src.contains("signal summary_dismissed"),
		"summary_dismissed is gone -- SchoolDay awaits it")
	assert_true(src.contains("func setup_summary("),
		"setup_summary is gone")
	assert_true(src.contains("func dismiss()"), "dismiss is gone")


const _SCHOOL_DAY_SCRIPT := "res://Scripts/SchoolSimulation/SchoolDay.gd"


## The popup now owns its rows. Reparenting DayScreen's live scroll into
## it would stack the mid-day cards on top of the mockup cards.
func test_school_day_no_longer_reparents_its_scroll_into_the_popup() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_false(src.contains("rows_container.add_child(scroll)"),
		"SchoolDay still reparents StudentScroll into the popup")
	assert_false(src.contains("scroll_back"),
		"SchoolDay still reparents StudentScroll back out")


func test_school_day_asks_the_popup_to_build_its_own_rows() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_false(src.contains("student_manager.students, false)"),
		"SchoolDay still passes build_rows=false")
	assert_true(src.contains("summary_instance.setup_summary("),
		"SchoolDay no longer calls setup_summary")


## The mid-day DayScreen cards are explicitly out of scope and must
## survive this task intact.
func test_school_day_still_renders_its_embedded_day_cards() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("func _render_embedded_student_status()"),
		"the mid-day DayScreen cards were removed -- out of scope")


## STRETCH_SCALE (0) is correct ONLY because Task 1 made the texture's
## aspect equal the box's. KEEP_ASPECT_CENTERED (5) was what collapsed the
## art to a square, so this pins the mode as much as the size.
func test_card_art_fills_the_card_box_without_letterboxing() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	assert_eq(inst.custom_minimum_size, Vector2(992, 410),
		"card box must equal the card art's content box")
	var art := inst.get_node_or_null("CardArt") as TextureRect
	assert_not_null(art, "row is missing CardArt")
	assert_eq(art.stretch_mode, TextureRect.STRETCH_SCALE,
		"CardArt must STRETCH_SCALE -- KEEP_ASPECT_CENTERED squares the art")
	var tex: Texture2D = art.texture
	assert_not_null(tex, "CardArt has no texture")
	var box_aspect := 992.0 / 410.0
	var tex_aspect := float(tex.get_width()) / float(tex.get_height())
	assert_true(absf(box_aspect - tex_aspect) < 0.01,
		"card box aspect %f does not match the texture's %f" % [box_aspect, tex_aspect])
	inst.free()


func test_banner_box_matches_the_banner_art_aspect() -> void:
	var scene := load(_POPUP_SCENE) as PackedScene
	var inst := scene.instantiate()
	var banner := inst.find_child("TitleBanner", true, false) as TextureRect
	assert_not_null(banner, "popup is missing TitleBanner")
	var tex: Texture2D = banner.texture
	assert_not_null(tex, "TitleBanner has no texture")
	var box := banner.custom_minimum_size
	assert_true(box.x > 0.0 and box.y > 0.0, "TitleBanner has no reserved box")
	var box_aspect := box.x / box.y
	var tex_aspect := float(tex.get_width()) / float(tex.get_height())
	assert_true(absf(box_aspect - tex_aspect) < 0.05,
		"banner box aspect %f does not match the art's %f" % [box_aspect, tex_aspect])
	inst.free()


## The splash batch has landed (spec section 3.1), so the full-body art is
## now the source of truth and the portrait is the fallback. Source-scanned
## because building a StudentData with both textures set requires resources
## this suite cannot load headlessly.
func test_avatar_prefers_the_splash_over_the_portrait() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/DaySummaryAvatar.gd")
	var portrait_at := src.find("student.avatar_texture")
	var splash_at := src.find("student.splash_path")
	assert_true(portrait_at != -1, "avatar no longer reads avatar_texture")
	assert_true(splash_at != -1, "avatar no longer reads splash_path")
	assert_true(splash_at < portrait_at,
		"splash_path must be tried BEFORE avatar_texture")


## A named splash crop applied to a portrait would cut the wrong region,
## so the table is gated behind the is_splash flag.
func test_named_crops_apply_only_to_splash_art() -> void:
	var tex := load("res://Assets/Images/SplashArtMurid/splash_marcel.png") as Texture2D
	var as_splash := DaySummaryAvatar.crop_for("Marcel", tex, true)
	var as_portrait := DaySummaryAvatar.crop_for("Marcel", tex, false)
	assert_eq(as_splash, DaySummaryAvatar.SPLASH_CROP["Marcel"],
		"splash lookup must return the named crop")
	assert_true(as_portrait != as_splash,
		"a portrait must NOT get the named splash crop")
	var aspect := as_portrait.size.x / as_portrait.size.y
	assert_true(absf(aspect - DaySummaryAvatar.FRAME_ASPECT) < 0.02,
		"computed portrait crop aspect %f is not the frame's" % aspect)


## The popup is a scrim over the live DayScreen, so anything left visible
## underneath collides with the card stack. The mockup shows the banner and
## cards on an empty field.
func test_school_day_hides_its_chrome_behind_the_summary() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	assert_true(src.contains("_set_day_chrome_visible(false)"),
		"SchoolDay must hide its DayScreen chrome before showing the popup")
	assert_true(src.contains("_set_day_chrome_visible(true)"),
		"SchoolDay must restore its chrome after the popup is dismissed")
	assert_true(src.contains("func _set_day_chrome_visible("),
		"SchoolDay is missing the chrome helper")


## The roster is declared verbatim in four places with no single source of
## truth (spec section 3.2). A student whose splash is updated in one file
## and not another shows different art depending on which screen built the
## dictionary, so all four are pinned together here.
func test_every_roster_points_at_the_new_splash_batch() -> void:
	var sources := [
		"res://Scripts/StudentCard/student_card.gd",
		"res://Scripts/StudentList/student_list.gd",
		"res://Scripts/Debug/DebugManager.gd",
		"res://Scripts/AturJadwal/atur_jadwal.gd",
	]
	for path in sources:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("SplashArtMurid/SplashMurid"),
			"%s still points at the legacy SplashMurid*.jpg batch" % path)


## The popup sits over the live SchoolDay screen. An opaque blurred-
## classroom backdrop replaces that view so the recap reads as its own
## setting, and it must sit BEHIND the scrim -- in front, it would hide
## the dimming that keeps the white row text legible.
func test_popup_has_a_blurred_backdrop_behind_the_scrim() -> void:
	var scene := load(_POPUP_SCENE) as PackedScene
	assert_not_null(scene, "DaySummaryPopup.tscn failed to load")
	var inst := scene.instantiate()

	var backdrop := inst.get_node_or_null("Backdrop") as TextureRect
	assert_not_null(backdrop, "popup is missing its Backdrop TextureRect")
	assert_not_null(backdrop.texture, "Backdrop has no texture assigned")
	assert_eq(backdrop.texture.resource_path,
		"res://Assets/Images/UI/blur_background.png",
		"Backdrop is not drawing blur_background.png")

	var dim := inst.get_node_or_null("DimOverlay")
	assert_not_null(dim, "popup is missing its DimOverlay")
	assert_true(backdrop.get_index() < dim.get_index(),
		"Backdrop must render behind DimOverlay")

	# 369x654 art on a 1080x1920 screen: it must fill, not letterbox.
	assert_eq(backdrop.expand_mode, TextureRect.EXPAND_IGNORE_SIZE,
		"Backdrop must ignore its texture's native size")
	assert_eq(backdrop.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"Backdrop must cover the screen without distorting")

	inst.free()

## The 2026-09-03 fix: the "+12/65" label owns the row's right-hand
## VALUE_WIDTH and nothing else. It used to be offset -321/-121, which
## laid it straight over the Track and is what "StatRow is bugged" meant.
func test_stat_row_value_label_sits_right_of_the_track() -> void:
	var row_scene: PackedScene = load("res://Scenes/SchoolSimulation/DaySummaryStatRow.tscn")
	var row := row_scene.instantiate()
	var value: Label = row.get_node("Value")
	var track: ProgressBar = row.get_node("Track")
	assert_eq(value.offset_left, -float(DaySummaryStatRow.VALUE_WIDTH),
		"Value.offset_left must be -VALUE_WIDTH")
	assert_eq(value.offset_right, 0.0,
		"Value must reach the row's right edge")
	assert_true(track.offset_right <= value.offset_left,
		"Track must end where Value begins -- they must not overlap")
	row.free()


## Three rows, one pitch. They were 97 / 100 apart, which reads as a
## misaligned bottom row against the card art.
func test_card_pitches_its_three_stat_rows_evenly() -> void:
	var card_scene: PackedScene = load("res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn")
	var card := card_scene.instantiate()
	var tops: Array[float] = []
	for n in ["StatRow1", "StatRow2", "StatRow3"]:
		var r: Control = card.get_node(n)
		tops.append(r.offset_top)
		assert_eq(r.offset_bottom - r.offset_top,
			float(DaySummaryStatRow.ROW_HEIGHT),
			"%s must be ROW_HEIGHT tall" % n)
	assert_eq(tops[1] - tops[0], tops[2] - tops[1],
		"the three stat rows must be evenly pitched")
	card.free()


## The bar shows a word, not a number: the precise value is already
## carried by the bar's own fill, and the week's delta by DeltaLabel.
func test_needs_bar_words_follow_the_spec_tiers() -> void:
	assert_eq(DaySummaryNeedsBar.word_for("energy", 0.0), "Lelah")
	assert_eq(DaySummaryNeedsBar.word_for("energy", 33.0), "Lelah")
	assert_eq(DaySummaryNeedsBar.word_for("energy", 34.0), "Cukup")
	assert_eq(DaySummaryNeedsBar.word_for("energy", 66.0), "Cukup")
	assert_eq(DaySummaryNeedsBar.word_for("energy", 67.0), "Bugar")
	assert_eq(DaySummaryNeedsBar.word_for("energy", 100.0), "Bugar")
	assert_eq(DaySummaryNeedsBar.word_for("mood", 10.0), "Sedih")
	assert_eq(DaySummaryNeedsBar.word_for("mood", 50.0), "Biasa")
	assert_eq(DaySummaryNeedsBar.word_for("mood", 90.0), "Senang")
	# An unknown need must not fabricate a mood.
	assert_eq(DaySummaryNeedsBar.word_for("stamina", 50.0), "")


## The word's variation must survive the bake, or it renders as a bare
## default Label -- dark, unrimmed, illegible on the bar's fill.
func test_theme_bakes_the_needs_label_variation() -> void:
	var theme: Theme = load(_THEME_PATH)
	assert_true(theme.has_font_size("font_size", "DaySummaryNeedsLabel"),
		"DaySummaryNeedsLabel must bake a font size")
	assert_true(theme.has_color("font_color", "DaySummaryNeedsLabel"),
		"DaySummaryNeedsLabel must bake a font colour")


## One node per need, not two. The icon and word live INSIDE the bar --
## a sibling chip beside it would duplicate the bar's own shape, which is
## the redundancy this design rules out.
func test_needs_bars_carry_their_icon_and_word_inside_themselves() -> void:
	var card_scene: PackedScene = load("res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn")
	var card := card_scene.instantiate()
	for n in ["EnergyBar", "MoodBar"]:
		var bar := card.get_node_or_null(n) as DaySummaryNeedsBar
		assert_true(bar != null, "%s must be a DaySummaryNeedsBar" % n)
		assert_true(bar.get_node_or_null("Icon") != null,
			"%s must own its Icon" % n)
		assert_true(bar.get_node_or_null("Word") != null,
			"%s must own its Word" % n)
		assert_true(bar.get_node_or_null("DeltaLabel") != null,
			"%s must keep its existing DeltaLabel" % n)
	# No stacked second element per need.
	assert_true(card.get_node_or_null("EnergyPill") == null,
		"there must be no separate energy chip node")
	assert_true(card.get_node_or_null("MoodPill") == null,
		"there must be no separate mood chip node")
	card.free()


## Both entry points write the bars through set_need, so the fill and the
## word can never disagree.
func test_card_fills_its_needs_bars_on_both_paths() -> void:
	var theme: Theme = load(_THEME_PATH)
	var card_scene: PackedScene = load("res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn")
	var card := card_scene.instantiate()
	card.theme = theme
	Engine.get_main_loop().root.add_child(card)

	var student := StudentData.new()
	student.student_name = "Shinta"
	student.energy = 20.0
	student.mood = 90.0

	card.setup_row("Shinta", [], student)
	assert_eq(card.energy_bar.value, 20.0)
	assert_eq(card.energy_bar.get_node("Word").text, "Lelah")
	assert_eq(card.mood_bar.get_node("Word").text, "Senang")
	assert_true(card.energy_bar.get_node("Icon").texture != null,
		"the energy bar must carry icon_energy")

	card.setup_week_row(student)
	assert_eq(card.energy_bar.get_node("Word").text, "Lelah",
		"the weekly path must write the same word")
	assert_eq(card.mood_bar.value, 90.0)

	card.queue_free()


## The particle art is a placeholder by contract: the visual team drops
## real PNGs in at these exact names, so the names are load-bearing and
## a rename must break the build here.
func test_particle_sprites_exist_and_are_transparent() -> void:
	var paths := [
		"res://Assets/Images/Particles/particle_star.png",
		"res://Assets/Images/Particles/particle_confetti.png",
		"res://Assets/Images/Particles/particle_ring.png",
	]
	for p in paths:
		assert_true(ResourceLoader.exists(p), "missing particle sprite: " + p)
		var tex: Texture2D = load(p)
		assert_true(tex != null, "must load as a texture: " + p)
		var img := tex.get_image()
		assert_true(img.detect_alpha() != Image.ALPHA_NONE,
			"particle sprite must have a transparent background: " + p)



## Both bursts must be one-shot and start idle: a looping emitter left
## running under a card would never free and would leak per row, per day.
func test_particle_scenes_are_one_shot_and_start_idle() -> void:
	for path in [
		"res://Scenes/SchoolSimulation/RewardBurst.tscn",
		"res://Scenes/SchoolSimulation/CelebrationConfetti.tscn",
	]:
		var fx_scene: PackedScene = load(path)
		var fx := fx_scene.instantiate() as GPUParticles2D
		assert_true(fx != null, "must be a GPUParticles2D: " + path)
		assert_true(fx.one_shot, "must be one_shot: " + path)
		assert_true(not fx.emitting, "must start idle: " + path)
		assert_true(fx.texture != null, "must carry a sprite: " + path)
		assert_true(fx.process_material != null,
			"must carry a ParticleProcessMaterial: " + path)
		fx.free()


## Read a .gd as text. Many tests here are source scans rather than
## behavioural, because a lot of this UI cannot be driven headlessly.
func _script_source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, "script must exist: " + path)
	if f == null:
		return ""
	return f.get_as_text()


## Only a real gain earns a burst. A flat or losing day must stay quiet,
## or the reward stops meaning anything.
func test_only_a_gaining_card_reports_ground_gained() -> void:
	var theme: Theme = load(_THEME_PATH)
	var card_scene: PackedScene = load("res://Scenes/SchoolSimulation/DaySummaryStudentRow.tscn")
	var card := card_scene.instantiate()
	card.theme = theme
	Engine.get_main_loop().root.add_child(card)

	var student := StudentData.new()
	student.student_name = "Shinta"
	student.target_akademis1 = 65.0
	student.target_akademis2 = 65.0
	student.target_akademis3 = 65.0
	student.akademis = 30.0

	card.setup_row("Shinta", [], student)
	assert_true(not card.gained_ground(),
		"a day with no changes must not celebrate")

	card.setup_row("Shinta", [{"stat_key": "akademis", "delta": -4.0}], student)
	assert_true(not card.gained_ground(),
		"a losing day must not celebrate")

	card.setup_row("Shinta", [{"stat_key": "akademis", "delta": 12.0}], student)
	assert_true(card.gained_ground(),
		"a gaining day must celebrate")

	card.queue_free()


## The burst rides the chevron: same condition, same beat.
func test_stat_row_bursts_exactly_when_it_shows_a_chevron() -> void:
	var src := _script_source(
		"res://Scripts/SchoolSimulation/DaySummaryStatRow.gd")
	assert_true(src.contains("BURST_SCENE"),
		"the stat row must instance the authored burst scene")
	assert_true(src.contains('play_sfx(&"tally")'),
		"the chevron pop must play the tally cue")
	assert_true(not src.contains("GPUParticles2D.new()"),
		"particles must come from the .tscn, never be built at runtime")

