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


func test_stat_row_scene_wears_the_theme_and_has_no_overrides() -> void:
	var scene := load(_STAT_ROW_SCENE) as PackedScene
	assert_not_null(scene, "DaySummaryStatRow.tscn failed to load")
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	var track := inst.get_node_or_null("Track")
	assert_not_null(track, "stat row is missing its Track")
	assert_eq(track.theme_type_variation, &"DaySummaryStatTrack",
		"Track is not wearing DaySummaryStatTrack")
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
func test_row_reserves_the_mockup_card_box() -> void:
	var scene := load(_ROW_SCENE) as PackedScene
	var inst := scene.instantiate()
	inst.theme = load(_THEME_PATH)
	assert_eq(inst.custom_minimum_size, Vector2(992, 405),
		"card box drifted from the mockup's 992x393 fill + 12px shadow")
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


## The portrait is the source of truth for now -- the splash art is being
## replaced, so the avatar must not reach for it even when a student has
## one. Source-scanned because building a StudentData with both textures
## set requires resources this suite cannot load headlessly.
func test_avatar_prefers_the_portrait_over_the_splash() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/SchoolSimulation/DaySummaryAvatar.gd")
	var portrait_at := src.find("student.avatar_texture")
	var splash_at := src.find("student.splash_path")
	assert_true(portrait_at != -1, "avatar no longer reads avatar_texture")
	assert_true(splash_at != -1, "avatar no longer reads splash_path")
	assert_true(portrait_at < splash_at,
		"avatar_texture must be tried BEFORE splash_path")


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
