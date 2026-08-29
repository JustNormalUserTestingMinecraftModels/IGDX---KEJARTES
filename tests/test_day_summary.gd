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
