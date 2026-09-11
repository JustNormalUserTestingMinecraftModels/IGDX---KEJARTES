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


func test_slot_counts_track_the_roster_size() -> void:
	# Grades 7/8/9 approve 2/3/4 students -- student_card.gd:99-102.
	assert_eq(WinLineup.slots_for(2).size(), 2, "grade 7 roster")
	assert_eq(WinLineup.slots_for(3).size(), 3, "grade 8 roster")
	assert_eq(WinLineup.slots_for(4).size(), 4, "grade 9 roster")


func test_every_arrangement_includes_the_front_slot() -> void:
	for n in [2, 3, 4]:
		assert_contains(WinLineup.slots_for(n), WinLineup.SLOT_FRONT_LOW,
			"a roster of %d still has a front figure" % n)


func test_doni_takes_the_front_slot_at_every_roster_size() -> void:
	var rosters := [
		["Andi", "Doni"],
		["Andi", "Citra", "Doni"],
		["Marcel", "Doni", "Andi", "Citra"],
	]
	for roster in rosters:
		for placed in WinLineup.assign(roster):
			if placed["name"] == "Doni":
				assert_eq(placed["slot"], WinLineup.SLOT_FRONT_LOW,
					"Doni is pinned front in a roster of %d" % roster.size())


func test_everyone_else_fills_in_roster_order() -> void:
	## Doni is second in roster order but takes the front slot, so Marcel, Andi
	## and Citra fill the remaining three. The expected slots are named
	## explicitly rather than re-derived from slots_for(): the arrangement order
	## IS the composition, so a reordering of ARRANGEMENTS must fail here.
	var placed := WinLineup.assign(["Marcel", "Doni", "Andi", "Citra"])
	var by_name := {}
	for p in placed:
		by_name[p["name"]] = p["slot"]
	assert_eq(by_name["Doni"], WinLineup.SLOT_FRONT_LOW, "Doni is pinned front")
	assert_eq(by_name["Marcel"], WinLineup.SLOT_SIDE_LEFT,
		"first non-Doni takes the backmost free slot")
	assert_eq(by_name["Andi"], WinLineup.SLOT_SIDE_RIGHT, "second non-Doni")
	assert_eq(by_name["Citra"], WinLineup.SLOT_FRONT_MID, "third non-Doni")


## The array is returned in DRAW order, back to front, so WinStage can
## map element i onto sibling Student{i+1} and get z-order for free. The
## front-low figure is closest to camera and must therefore be last.
func test_placements_come_back_in_draw_order_back_to_front() -> void:
	for roster in [["Andi", "Doni"], ["Andi", "Citra", "Doni"],
			["Marcel", "Doni", "Andi", "Citra"]]:
		var placed: Array[Dictionary] = WinLineup.assign(roster)
		var last: Dictionary = placed[placed.size() - 1]
		assert_eq(last["slot"], WinLineup.SLOT_FRONT_LOW,
			"the front figure is drawn last in a roster of %d" % roster.size())
		assert_eq(last["name"], "Doni", "and it is Doni when he is approved")


func test_a_roster_without_doni_still_fills_the_front() -> void:
	var placed := WinLineup.assign(["Marcel", "Andi", "Citra"])
	var front := ""
	for p in placed:
		if p["slot"] == WinLineup.SLOT_FRONT_LOW:
			front = p["name"]
	assert_eq(front, "Marcel",
		"with Doni absent the front goes to the first student in roster order")


func test_no_two_students_share_a_slot() -> void:
	for roster in [["Andi", "Doni"], ["Andi", "Citra", "Doni"],
			["Marcel", "Doni", "Andi", "Citra"]]:
		var placed := WinLineup.assign(roster)
		assert_eq(placed.size(), roster.size(),
			"every student is placed in a roster of %d" % roster.size())
		var seen := {}
		for p in placed:
			assert_false(seen.has(p["slot"]),
				"%s is used once in a roster of %d" % [p["slot"], roster.size()])
			seen[p["slot"]] = true


func test_a_roster_larger_than_the_slot_map_is_truncated() -> void:
	# Nothing produces five approvals today, but the screen must not throw
	# if the cap ever moves -- it shows the first four and drops the rest.
	var placed := WinLineup.assign(["Marcel", "Doni", "Andi", "Citra", "Thea"])
	assert_eq(placed.size(), 4, "at most four figures fit the composition")


func test_an_empty_roster_places_nobody() -> void:
	assert_eq(WinLineup.assign([]).size(), 0, "no students, no placements")


func test_every_placement_carries_an_anchor_and_a_scale() -> void:
	for p in WinLineup.assign(["Marcel", "Doni", "Andi", "Citra"]):
		assert_true(p["anchor"] is Vector2, p["name"] + " has a Vector2 anchor")
		assert_gt(p["scale"], 0.0, p["name"] + " has a positive scale")
		# Art space is 1536x2048; the group sits in the lower half.
		assert_true(p["anchor"].x > 0.0 and p["anchor"].x < 1536.0,
			"%s anchors inside the canvas horizontally" % p["name"])
		assert_true(p["anchor"].y > 1024.0 and p["anchor"].y <= 2048.0,
			"%s stands in the lower half of the painting" % p["name"])


func _placed(name: String) -> Dictionary:
	for p in WinLineup.assign(["Marcel", "Doni", "Andi", "Citra"]):
		if p["name"] == name:
			return p
	return {}


func test_a_shadow_sits_at_its_students_feet() -> void:
	var doni := _placed("Doni")
	var sh := WinLineup.shadow_for(doni, 1.25, 0.28)
	# The splash's feet are on its canvas bottom, so the shadow's centre
	# sits on the anchor's own y -- not above or below it.
	assert_true(is_equal_approx(sh["centre"].y, doni["anchor"].y),
		"the shadow is on the ground line, not floating (%f vs %f)"
			% [sh["centre"].y, doni["anchor"].y])


func test_a_shadow_follows_its_students_foot_centre_not_the_canvas_centre() -> void:
	# Marcel's contact band centres at 480, 60px left of the 540 canvas
	# centre. A shadow that ignored that would sit visibly off his foot.
	var marcel := _placed("Marcel")
	var sh := WinLineup.shadow_for(marcel, 1.25, 0.28)
	var offset: float = (480.0 - 540.0) * marcel["scale"]
	assert_true(is_equal_approx(sh["centre"].x, marcel["anchor"].x + offset),
		"the shadow tracks the measured foot centre")


func test_shadow_width_scales_with_the_foot_span() -> void:
	# Doni's 597px crouch against Citra's 352px stance: the shadows must
	# differ by roughly the same factor, or one of them reads wrong.
	var doni := WinLineup.shadow_for(_placed("Doni"), 1.25, 0.28)
	var citra := WinLineup.shadow_for(_placed("Citra"), 1.25, 0.28)
	assert_gt(doni["size"].x, citra["size"].x,
		"the wide crouch throws the wider shadow")


func test_the_narrow_poses_are_widened_by_their_factor() -> void:
	var marcel := _placed("Marcel")
	var plain: float = 116.0 * 1.25 * float(marcel["scale"])
	var sh := WinLineup.shadow_for(marcel, 1.25, 0.28)
	assert_true(is_equal_approx(sh["size"].x, plain * 2.0),
		"Marcel's one-footed contact is widened toward his body")


func test_flatness_sets_the_ellipse_height() -> void:
	var sh := WinLineup.shadow_for(_placed("Doni"), 1.25, 0.28)
	assert_true(is_equal_approx(sh["size"].y, sh["size"].x * 0.28),
		"height is flatness x width")


func test_spread_widens_every_shadow() -> void:
	var narrow := WinLineup.shadow_for(_placed("Andi"), 1.0, 0.28)
	var wide := WinLineup.shadow_for(_placed("Andi"), 2.0, 0.28)
	assert_true(is_equal_approx(wide["size"].x, narrow["size"].x * 2.0),
		"spread multiplies the width")


func test_an_unknown_name_still_returns_a_usable_shadow() -> void:
	# A roster name with no measured anchor must not crash the end-of-grade
	# sequence -- it falls back to the canvas centre and a nominal span.
	var sh := WinLineup.shadow_for(
		{"name": "Nobody", "slot": WinLineup.SLOT_FRONT_LOW,
		"anchor": Vector2(700.0, 1810.0), "scale": 1.0}, 1.25, 0.28)
	assert_gt(sh["size"].x, 0.0, "a fallback shadow still has a width")
