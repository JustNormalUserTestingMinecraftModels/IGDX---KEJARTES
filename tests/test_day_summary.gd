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
	"res://Assets/Images/SplashArtMurid/splash_andi.png",
	"res://Assets/Images/SplashArtMurid/splash_shinta.png",
	"res://Assets/Images/SplashArtMurid/splash_thea.png",
]


func suite_name() -> String:
	return "day_summary"


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


## The card art is placed at native size (spec section 1), so a resized
## or re-exported PNG would silently break every card-relative offset in
## this plan. Pin its dimensions.
func test_card_background_is_native_size() -> void:
	var tex := load(_ART["card_bg"]) as Texture2D
	assert_eq(tex.get_width(), 1080, "card_bg width changed")
	assert_eq(tex.get_height(), 1080, "card_bg height changed")


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
	"DaySummaryStatTrack": "ProgressBar",
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
	var e_fill := theme.get_stylebox("fill", "DaySummaryEnergyBar") as StyleBoxFlat
	var m_fill := theme.get_stylebox("fill", "DaySummaryMoodBar") as StyleBoxFlat
	assert_eq(e_fill.bg_color, tokens.day_energy_fill, "energy fill drifted")
	assert_eq(m_fill.bg_color, tokens.day_mood_fill, "mood fill drifted")


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
		"Andi": "res://Assets/Images/SplashArtMurid/splash_andi.png",
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


## Doni and Citra have no new art (spec section 3). The fallback must
## still produce a usable, correctly-shaped crop rather than nothing.
func test_unknown_students_get_a_computed_crop() -> void:
	var tex := load("res://Assets/Images/SplashArtMurid/splash_marcel.png") as Texture2D
	var r := DaySummaryAvatar.crop_for("Doni", tex)
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
