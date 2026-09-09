@tool
extends McpTestSuiteCompat

## WinLineup (2026-09-09): the win screen's roster arrangement. Doni is
## pinned to the front slot; everyone else fills in roster order. Plain
## static functions over Dictionaries, so these are behavioural tests
## rather than the source scans this project falls back on for scenes it
## cannot instantiate headlessly.

const _SCRIPT := "res://Scripts/EndGame/WinLineup.gd"

const _SPLASHES := ["andi", "citra", "doni", "marcel", "shinta", "thea"]

const _ROSTER := ["Marcel", "Doni", "Andi", "Citra", "Shinta", "Thea"]


func suite_name() -> String:
	return "win_lineup"


func test_the_win_art_imported() -> void:
	var bg := "res://Assets/Images/CG/Win/win_background.png"
	assert_true(ResourceLoader.exists(bg), bg + " exists")
	assert_true(load(bg) is Texture2D, bg + " imports as a texture")
	for n in _SPLASHES:
		var p := "res://Assets/Images/CG/Win/win_%s.png" % n
		assert_true(ResourceLoader.exists(p), p + " exists")
		assert_true(load(p) is Texture2D, p + " imports as a texture")


func test_the_shadow_ellipse_imported_and_is_soft() -> void:
	var p := "res://Assets/Images/UI/Placeholders/shadow_ellipse.png"
	assert_true(ResourceLoader.exists(p), p + " exists")
	var tex: Texture2D = ResourceLoader.load(
		p, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
	var img: Image = tex.get_image()
	assert_not_null(img, "the ellipse rasterised")
	# Opaque at the centre, clear at the corner, and genuinely soft in
	# between -- a hard-edged ellipse would read as a sticker, not a shadow.
	var w := img.get_width()
	var h := img.get_height()
	assert_gt(img.get_pixel(w / 2, h / 2).a, 0.9, "solid at the centre")
	assert_true(img.get_pixel(2, 2).a < 0.05, "clear at the corner")
	var mid := img.get_pixel(int(w * 0.75), h / 2).a
	assert_true(mid > 0.05 and mid < 0.9,
		"partially transparent partway out (got %f) -- the falloff is a gradient" % mid)


func test_every_roster_name_has_a_foot_anchor() -> void:
	for name in _ROSTER:
		assert_has_key(WinLineup.FOOT_ANCHORS, name,
			name + " has a measured foot anchor")
		var a: Dictionary = WinLineup.FOOT_ANCHORS[name]
		assert_has_key(a, "centre_x", name + ".centre_x")
		assert_has_key(a, "span", name + ".span")


## The anchors are measured from the splash alpha at threshold 128 -- see
## the spec's section 5. These pin the measurement so a re-export that
## silently moves a figure is caught here rather than on screen.
func test_the_anchors_match_the_measured_art() -> void:
	var expected := {
		"Doni": [587.0, 597.0],
		"Andi": [488.0, 390.0],
		"Citra": [530.0, 352.0],
		"Shinta": [526.0, 186.0],
		"Marcel": [480.0, 116.0],
		"Thea": [546.0, 100.0],
	}
	for name in expected:
		var a: Dictionary = WinLineup.FOOT_ANCHORS[name]
		assert_true(is_equal_approx(a["centre_x"], expected[name][0]),
			"%s centre_x is %f, expected %f" % [name, a["centre_x"], expected[name][0]])
		assert_true(is_equal_approx(a["span"], expected[name][1]),
			"%s span is %f, expected %f" % [name, a["span"], expected[name][1]])


## Marcel leans on one foot and Thea is mid-stride, so their contact bands
## are far narrower than their bodies. A shadow that narrow reads as a
## smudge, so both carry an explicit widening factor.
func test_the_narrow_contact_poses_are_widened() -> void:
	for name in ["Marcel", "Thea"]:
		var a: Dictionary = WinLineup.FOOT_ANCHORS[name]
		assert_gt(a.get("widen", 1.0), 1.0,
			name + " is one-footed and widens toward the body")
	for name in ["Doni", "Andi", "Citra", "Shinta"]:
		var a: Dictionary = WinLineup.FOOT_ANCHORS[name]
		assert_true(is_equal_approx(a.get("widen", 1.0), 1.0),
			name + " stands on two feet and is not widened")
