@tool
extends McpTestSuite

## Geometry guards for the lobby, from the 2026-09-08 warm-UI pass.
##
## Three defects motivated these, all measured rather than eyeballed:
## ReportStudent ended at x=1059 on a 1080-wide screen with a 6px border
## and a 14px shadow, so it clipped; DisplayUang spanned to x=1120, i.e.
## 40px off-screen entirely; and DisplayUang and DailyLogin sat centred
## on the two front-row students' heads (x~845 y~389 and x~225 y~389).
##
## Since the 2026-09-15 tall-phone pass the HUD lives in Safe/UI/Hud/BookHud
## (the 2026-09-27 scrapbook pass split it into the stepped book and the
## IconRail) and the art in a centred Classroom, so a node's offsets are no
## longer screen coordinates. The Lobby is stood up on the 1080x1920 design
## screen (tests/layout_frame.gd) and every check reads real global rects.
## The 2026-09-29 layout grid pass added the spacing, margin, fit and
## hair-clearance checks at the end of this file.
##
## The Meja_* desk layers' 8-10 px nudges inside the Classroom are deliberate
## (2026-09-10): at zero offset the desks stopped short of the students'
## bodies and left a seam. Do not "correct" them.

const LayoutFrame := preload("res://tests/layout_frame.gd")

const SCREEN_W := 1080.0
const SCREEN_H := 1920.0
const RIM_CLEARANCE := 24.0

const SCENE := "res://Scenes/Lobby/Lobby.tscn"

const NAV_TILES := ["Koperasi", "Inventory", "ReportStudent"]

## Where every HUD control sits on the 1080x1920 design screen. The
## 2026-09-27 scrapbook pass (Task 4) replaced the flat BottomBar row with a
## stepped book (RaisedPage over Student/Jadwal, ShelfPage over the three
## tiles) plus ChevronGrip and a right-edge IconRail. The 2026-09-29 layout
## grid pass put the book back on Safe's 48 px margin (undoing 60d6d7d7's
## nudge), moved the coin box into the book's step beside JADWAL!, lifted the
## rail to end 24 px above it, and made the progress plate a tag in the gap
## between the two back-row heads.
const DESIGN_RECTS := {
	"Student": Rect2(88, 1444, 532, 144),
	"Jadwal": Rect2(88, 1444, 532, 144),
	"Koperasi": Rect2(88, 1656, 285, 160),
	"Inventory": Rect2(397, 1656, 285, 160),
	"ReportStudent": Rect2(706, 1656, 285, 160),
	"ChevronGrip": Rect2(214, 1352, 280, 96),
	"DisplayUang": Rect2(684, 1444, 348, 112),
	"IconRail": Rect2(936, 964, 96, 456),
	"DailyLogin": Rect2(936, 964, 96, 96),
	"SettingsButton": Rect2(936, 1084, 96, 96),
	"AchievementButton": Rect2(936, 1204, 96, 96),
	"SkinSwitchButton": Rect2(936, 1324, 96, 96),
	"ProgressHeader": Rect2(420, 48, 232, 192),
}

var _lobby: Control


func suite_name() -> String:
	return "lobby_layout"


func setup() -> void:
	var frame := track(LayoutFrame.stand_up(SCENE, Vector2(SCREEN_W, SCREEN_H))) as Control
	_lobby = frame.get_child(0) as Control


## The HUD control named `n` (a unique name), or null after a recorded failure.
func _hud(n: String) -> Control:
	var c := _lobby.get_node_or_null("%" + n) as Control
	assert_true(c != null, "lobby is missing HUD node %" + n)
	return c


## `c`'s authored rect on screen: its parent's settled global rect, placed by
## its own anchors and offsets. A control whose text needs more room still
## grows past this when drawn, to a minimum size that depends on font metrics
## (the editor measures wider than a device, so a text button can need
## more than its authored width); the layout promises this rect.
func _authored_rect(c: Control) -> Rect2:
	var pr := (c.get_parent() as Control).get_global_rect()
	var tl := pr.position + pr.size * Vector2(c.anchor_left, c.anchor_top) \
		+ Vector2(c.offset_left, c.offset_top)
	var br := pr.position + pr.size * Vector2(c.anchor_right, c.anchor_bottom) \
		+ Vector2(c.offset_right, c.offset_bottom)
	return Rect2(tl, br - tl)


func test_the_hud_keeps_its_design_rects() -> void:
	for n in DESIGN_RECTS:
		var c := _hud(n)
		if c == null:
			continue
		var got := _authored_rect(c)
		var want: Rect2 = DESIGN_RECTS[n]
		assert_true(got.position.distance_to(want.position) < 0.5
				and got.end.distance_to(want.end) < 0.5,
			"%s sits at %s on the design screen, expected %s" % [n, str(got), str(want)])


func test_nav_tiles_share_one_height_and_one_baseline() -> void:
	var first := _hud(NAV_TILES[0])
	if first == null:
		return
	for i in range(1, NAV_TILES.size()):
		var tile := _hud(NAV_TILES[i])
		if tile == null:
			continue
		# The authored rects, not get_global_rect(): the scrapbook tiles carry a
		# slight tilt each, which moves their global position but not their row.
		assert_eq(_authored_rect(tile).size.y, _authored_rect(first).size.y,
			"%s height differs from %s -- the three tiles are one row"
				% [NAV_TILES[i], NAV_TILES[0]])
		assert_eq(_authored_rect(tile).position.y, _authored_rect(first).position.y,
			"%s top differs from %s -- they must share a baseline"
				% [NAV_TILES[i], NAV_TILES[0]])


func test_nothing_clips_the_screen_rim() -> void:
	var offenders := []
	for n in DESIGN_RECTS:
		var c := _hud(n)
		if c == null:
			continue
		var r := c.get_global_rect()
		if r.position.x < RIM_CLEARANCE or r.end.x > SCREEN_W - RIM_CLEARANCE:
			offenders.append("%s spans %f..%f" % [n, r.position.x, r.end.x])
	assert_eq(offenders.size(), 0,
		"lobby controls within %fpx of the rim:\n  " % RIM_CLEARANCE
			+ "\n  ".join(offenders))


func test_hud_does_not_sit_on_the_front_row_faces() -> void:
	# Front-row head centres, derived from the portrait art's opaque
	# bounds (Thea.png: art starts 10.8% down, centred 49.9% across)
	# mapped through Slot3 and Slot4's rects.
	var heads := [Vector2(225, 389), Vector2(845, 389)]
	var radius := 110.0
	for n in ["DisplayUang", "DailyLogin", "SettingsButton", "ProgressHeader", "IconRail"]:
		var c := _hud(n)
		if c == null:
			continue
		var r := c.get_global_rect()
		for head in heads:
			var overlaps: bool = head.x + radius > r.position.x and head.x - radius < r.end.x \
				and head.y + radius > r.position.y and head.y - radius < r.end.y
			assert_true(not overlaps,
				"%s %s covers a student's head at %s" % [n, str(r), str(head)])


# ── back seats and front desks (2026-09-29) ────────────────────────────────

## How far a seat's centre may sit from the centre of its desk's top, px.
const SEAT_TOLERANCE := 2.5
## The rows of a desk's top surface, in the desk plate's own pixels, that the
## seat is centred against (the back desks' tops run from y=343 to about 560).
const DESK_TOP_ROWS := Vector2i(343, 560)


## The mean centre, in plate pixels, of the opaque span across a desk plate's
## top surface.
func _desk_top_centre(tex: Texture2D) -> float:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var total := 0.0
	var rows := 0
	for y in range(DESK_TOP_ROWS.x, DESK_TOP_ROWS.y, 4):
		var lo := -1
		var hi := -1
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				if lo < 0:
					lo = x
				hi = x
		if lo >= 0:
			total += (lo + hi) / 2.0
			rows += 1
	return total / maxf(rows, 1.0)


## The two students in the back row sat 13-18 px right of their desks' centres,
## so they read as off-centre whichever student took the seat (every face rig
## is drawn centred on its own canvas). The slots' Portrait rects, which the
## rigs copy, are what place them.
func test_back_row_students_sit_on_their_desks_centre() -> void:
	var classroom := _lobby.get_node("World/Classroom")
	for pair in [["Slot1", "Meja_KiriAtas"], ["Slot2", "Meja_KananAtas"]]:
		var portrait := classroom.get_node("StudentPortraitsContainer_Back/%s/Portrait" % pair[0]) as Control
		var desk := classroom.get_node(pair[1]) as TextureRect
		var seat := portrait.get_global_rect().get_center().x
		var desk_centre := desk.global_position.x + _desk_top_centre(desk.texture)
		assert_true(absf(seat - desk_centre) <= SEAT_TOLERANCE,
			"%s's student is centred at x=%.1f, its desk's top at x=%.1f" % [pair[0], seat, desk_centre])


## The front desks fill the screen edge to edge; the parallax slides them
## inward by up to travel.x * depth when the phone tilts, which used to open a
## gap at the rim. Each is stretched outward about its inner side by more than
## that swing, so the desk still reaches the rim at full tilt.
func test_front_desks_still_reach_the_rim_at_full_tilt() -> void:
	var classroom := _lobby.get_node("World/Classroom")
	var parallax := classroom.get_node("Parallax")
	var travel: Vector2 = parallax.get("travel")
	var depths: Dictionary = parallax.get("depth_by_child")
	var left := classroom.get_node("Meja_KiriBawah") as TextureRect
	var right := classroom.get_node("Meja_KananBawah") as TextureRect
	var left_swing: float = travel.x * float(depths["Meja_KiriBawah"])
	var right_swing: float = travel.x * float(depths["Meja_KananBawah"])
	# In the Classroom's own space: the World layer is centred on the real
	# viewport, not on this test's frame.
	var to_classroom := (classroom as Control).get_global_transform().affine_inverse()
	var width := (classroom as Control).size.x
	var left_edge := (to_classroom * left.get_global_transform() * Vector2(0, 0)).x
	var right_edge := (to_classroom * right.get_global_transform() * Vector2(width, 0)).x
	assert_true(left_edge <= -left_swing,
		"the left front desk starts at x=%.1f; a tilt slides it in %.1f px" % [left_edge, left_swing])
	assert_true(right_edge >= width + right_swing,
		"the right front desk ends at x=%.1f; a tilt slides it in %.1f px" % [right_edge, right_swing])


# ── the layout grid (2026-09-29) ───────────────────────────────────────────

## Neighbouring HUD pieces sit at least this far apart, px.
const MIN_GAP := 24.0
## The HUD pieces the spacing rule covers.
const SPACED: Array[String] = ["ProgressHeader", "IconRail", "DisplayUang",
	"RaisedBlock", "Shelf", "ChevronGrip"]
## Pairs drawn overlapping on purpose: the grip caps the raised block, and
## the raised block sits on the shelf.
const AUTHORED_OVERLAPS := [["ChevronGrip", "RaisedBlock"], ["RaisedBlock", "Shelf"]]
## How far, px, the book, the coin box and the rail keep from the screen's
## sides and bottom (Safe's margin).
const EDGE_MARGIN := 48.0
## A 20:9 phone in the 1080-wide space.
const TALL_SCREEN_H := 2400.0
## How far, px, the tag keeps from the nearest back-row hair beyond the
## parallax swing. The owner wants hair clear, not only faces (spec §2).
const HAIR_CLEARANCE := 4.0
## Lobby._animate_breathing's inhale scale, about the rig's bottom centre.
const BREATH_PEAK := Vector2(1.01, 1.02)
## StudentFace.canvas_size: the square every face rig's layers draw on.
const RIG_CANVAS := Vector2(1280, 1280)
## Every nth row and column of the art is checked, to keep the suite fast.
## 2 art pixels are about 0.57 screen px at the rig's 0.285 scale, so the
## step misses nothing that matters; do not raise it to speed the suite up.
const HAIR_SAMPLE_STEP := 2


## The distance between two rects: negative when they overlap.
func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(a.position.x - b.end.x, b.position.x - a.end.x)
	var dy := maxf(a.position.y - b.end.y, b.position.y - a.end.y)
	return maxf(dx, dy)


## Every pair in SPACED keeps its gap, except the authored overlaps.
func test_hud_pieces_keep_their_spacing() -> void:
	for i in SPACED.size():
		for j in range(i + 1, SPACED.size()):
			var a: String = SPACED[i]
			var b: String = SPACED[j]
			if [a, b] in AUTHORED_OVERLAPS or [b, a] in AUTHORED_OVERLAPS:
				continue
			var ca := _hud(a)
			var cb := _hud(b)
			if ca == null or cb == null:
				continue
			var gap := _gap(_authored_rect(ca), _authored_rect(cb))
			assert_true(gap >= MIN_GAP - 0.5,
				"%s and %s are %.1f px apart; the grid wants %d" % [a, b, gap, MIN_GAP])


## `lobby`'s book, coin box and rail sit EDGE_MARGIN inside `screen`'s sides
## and bottom.
func _assert_inside_margin(lobby: Control, screen: Vector2) -> void:
	for n: String in ["BookHud", "DisplayUang", "IconRail"]:
		var c := lobby.get_node_or_null("%" + n) as Control
		assert_true(c != null, "lobby is missing %" + n)
		if c == null:
			continue
		var r := c.get_global_rect()
		assert_true(r.position.x >= EDGE_MARGIN - 0.5
				and r.end.x <= screen.x - EDGE_MARGIN + 0.5
				and r.end.y <= screen.y - EDGE_MARGIN + 0.5,
			"%s spans %s on a %s screen; it must sit %d px inside the sides and bottom"
				% [n, str(r), str(screen), EDGE_MARGIN])


## Every HUD piece stays EDGE_MARGIN inside the sides and bottom, at 1080x1920
## and on a 20:9 screen.
func test_the_hud_sits_inside_the_screen_margin() -> void:
	_assert_inside_margin(_lobby, Vector2(SCREEN_W, SCREEN_H))
	var tall_screen := Vector2(SCREEN_W, TALL_SCREEN_H)
	var tall := track(LayoutFrame.stand_up(SCENE, tall_screen)) as Control
	_assert_inside_margin(tall.get_child(0) as Control, tall_screen)


## `c`'s minimum size fits its authored rect. A Control whose minimum size
## outgrows its rect draws past it: the old 88x84 grade badge really drew
## 121 wide.
func _assert_fits_rect(c: Control) -> void:
	if c == null:
		return
	var room := Vector2(c.offset_right - c.offset_left, c.offset_bottom - c.offset_top)
	var need := c.get_combined_minimum_size()
	assert_true(need.x <= room.x + 0.5 and need.y <= room.y + 0.5,
		"%s needs %s but its rect is %s" % [c.name, str(need), str(room)])


## The tag's labels fit their rects at the longest grade, week and star text.
func test_the_progress_tag_fits_its_longest_lines() -> void:
	var tag := _hud("ProgressHeader")
	if tag == null:
		return
	(tag.get_node("%GradeNumber") as Label).text = "9"
	(tag.get_node("%WeekLabel") as Label).text = LobbyProgressHeader.WEEK_FORMAT % [8, 8]
	(tag.get_node("%StarNum") as Label).text = LobbyProgressHeader.STAR_FORMAT % [3.0, 3.0]
	for child in tag.get_children():
		_assert_fits_rect(child as Control)


## The coin box's Label fits its rect at the largest balance, 999999G.
func test_the_largest_balance_fits_the_coin_box() -> void:
	var label := _lobby.get_node_or_null("%DisplayUang/Label") as Label
	assert_true(label != null, "the coin box needs its Label")
	if label == null:
		return
	label.text = "999999G"
	_assert_fits_rect(label)


## The Classroom child the back-row seats live in.
const BACK_ROW := "StudentPortraitsContainer_Back"


## `c`'s global rect as it lies on the design screen. The Lobby's World layer
## is a CanvasLayer, which in the editor test frame anchors to the editor's
## own viewport, so a Control under it reports a global rect far from the
## design screen (Slot1's Portrait read (509, -429.5) instead of (89, 26)).
## The Classroom is placed from the screen root by its own anchors and
## offsets, and `c` is shifted by the difference between that spot and where
## the Classroom really reports.
func _design_rect(c: Control) -> Rect2:
	var lr := _lobby.get_global_rect()
	var room := _lobby.get_node("World/Classroom") as Control
	var room_tl := lr.position + lr.size * Vector2(room.anchor_left, room.anchor_top) \
		+ Vector2(room.offset_left, room.offset_top)
	var r := c.get_global_rect()
	r.position += room_tl - room.get_global_rect().position
	return r


## How far, px, Lobby._start_idle_bob lifts the back row, read off the Lobby
## root; it must be a positive float, so the bob cannot silently drop out of
## the check.
func _idle_bob() -> float:
	var bob: Variant = _lobby.get("idle_bob_pixels")
	assert_true(bob is float and float(bob) > 0.0,
		"the Lobby needs a positive float idle_bob_pixels, got " + str(bob))
	return float(bob) if bob is float else 0.0


## The rect no back-row hair may enter around `rect`: grown by the back
## seats' parallax swing and HAIR_CLEARANCE.
func _keep_out_around(rect: Rect2) -> Rect2:
	var parallax := _lobby.get_node("World/Classroom/Parallax")
	var depths := parallax.get("depth_by_child") as Dictionary
	assert_true(depths.has(BACK_ROW), "the parallax needs a depth for " + BACK_ROW)
	var depth: float = depths.get(BACK_ROW, 0.0)
	var reach: Vector2 = (parallax.get("travel") as Vector2) * depth \
		+ Vector2.ONE * HAIR_CLEARANCE
	return rect.grow_individual(reach.x, reach.y, reach.x, reach.y)


## Scans `tex`, drawn as a face rig into `portrait` (StudentFace.fit_canvas:
## keep aspect, centred), for an opaque pixel inside `keep_out`, at rest and
## at its breathing peak, each also lifted by the idle bob `bob` (px; the
## whole back row rises with its container). Returns {"hit": the first
## on-screen point found, Vector2.INF when none; "scanned": how many art
## pixels were sampled}. A scan of 0 checked nothing.
func _first_hair_in(keep_out: Rect2, tex: Texture2D, portrait: Rect2, bob: float) -> Dictionary:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var scanned := 0
	for lift: float in [0.0, -bob]:
		var seat := Rect2(portrait.position + Vector2(0.0, lift), portrait.size)
		var fit := minf(seat.size.x / RIG_CANVAS.x, seat.size.y / RIG_CANVAS.y)
		var drawn := RIG_CANVAS * fit
		var origin := seat.position + (seat.size - drawn) * 0.5
		var per_pixel := drawn / Vector2(img.get_width(), img.get_height())
		var pivot := Vector2(seat.get_center().x, seat.end.y)
		for peak: Vector2 in [Vector2.ONE, BREATH_PEAK]:
			# Only the art pixels that can land in keep_out at this breath.
			var lo := (pivot + (keep_out.position - pivot) / peak - origin) / per_pixel
			var hi := (pivot + (keep_out.end - pivot) / peak - origin) / per_pixel
			var x0 := clampi(floori(lo.x), 0, img.get_width())
			var x1 := clampi(ceili(hi.x) + 1, 0, img.get_width())
			var y0 := clampi(floori(lo.y), 0, img.get_height())
			var y1 := clampi(ceili(hi.y) + 1, 0, img.get_height())
			for y in range(y0, y1, HAIR_SAMPLE_STEP):
				for x in range(x0, x1, HAIR_SAMPLE_STEP):
					scanned += 1
					# Opaque means alpha above 0.5: fringe below half alpha falls
					# inside HAIR_CLEARANCE, so it is not hair. Do not lower it.
					if img.get_pixel(x, y).a <= 0.5:
						continue
					var at := pivot + (origin + Vector2(x, y) * per_pixel - pivot) * peak
					if keep_out.has_point(at):
						return {"hit": at, "scanned": scanned}
	return {"hit": Vector2.INF, "scanned": scanned}


## The owner's rule for the tag (spec §2): it clears every back-row student's
## hair and face, for every student and skin, in both back seats, breathing,
## bobbing with Lobby.idle_bob_pixels and swaying with the parallax. The seats
## are mapped onto the design screen (_design_rect), and each slot must have
## scanned at least one pixel, so an empty scan cannot pass for a clear one.
func test_the_progress_tag_clears_every_back_row_head() -> void:
	var tag := _hud("ProgressHeader")
	if tag == null:
		return
	var keep_out := _keep_out_around(_authored_rect(tag))
	var bob := _idle_bob()
	var back := _lobby.get_node("World/Classroom/" + BACK_ROW)
	for slot: String in ["Slot1", "Slot2"]:
		var portrait := _design_rect(back.get_node(slot + "/Portrait") as Control)
		var scanned := 0
		for student: String in StudentSkins.NAMES:
			for id: String in StudentSkins.skins_for(student):
				var path := StudentSkins.layer_path(student, id, "face_base")
				var tex := load(path) as Texture2D
				assert_true(tex != null, "no face base at " + path)
				if tex == null:
					continue
				var result := _first_hair_in(keep_out, tex, portrait, bob)
				scanned += result["scanned"] as int
				assert_eq(result["hit"], Vector2.INF,
					"%s (%s) in %s reaches the tag's keep-out %s at %s"
						% [student, id, slot, str(keep_out), str(result["hit"])])
		assert_true(scanned > 0,
			"%s scanned no pixels: the keep-out %s misses its portrait %s"
				% [slot, str(keep_out), str(portrait)])


## Guards the coordinate mapping. The pre-pass header, Rect2(48, 48, 516, 168),
## covers a back-row head, so the hair check must find Andi's hair under it;
## a check that reads the seats at the wrong place scans nothing and would
## pass on this header too (the first version did).
func test_the_hair_check_sees_a_head_under_the_old_header() -> void:
	var keep_out := _keep_out_around(Rect2(48, 48, 516, 168))
	var back := _lobby.get_node("World/Classroom/" + BACK_ROW)
	var portrait := _design_rect(back.get_node("Slot1/Portrait") as Control)
	var path := StudentSkins.layer_path("Andi", StudentSkins.DEFAULT_ID, "face_base")
	var tex := load(path) as Texture2D
	assert_true(tex != null, "no face base at " + path)
	if tex == null:
		return
	var result := _first_hair_in(keep_out, tex, portrait, _idle_bob())
	assert_true(result["hit"] != Vector2.INF,
		"Andi's hair in Slot1 (portrait %s) is missed under the old header %s; scanned %d"
			% [str(portrait), str(keep_out), result["scanned"] as int])
