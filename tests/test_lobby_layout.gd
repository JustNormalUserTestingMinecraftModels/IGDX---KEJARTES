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
## tiles) plus ChevronGrip and a right-edge IconRail; these rects are
## measured from Scenes/Lobby/Lobby.tscn's authored offsets.
## The owner's nudge of the whole Hud (60d6d7d7, 2026-09-29): every control
## inside %Hud sits this far from where the scrapbook pass drew it.
const HUD_NUDGE := Vector2(-41, 112)
const DESIGN_RECTS := {
	"Student": Rect2(Vector2(88, 1444) + HUD_NUDGE, Vector2(532, 144)),
	"Jadwal": Rect2(Vector2(88, 1444) + HUD_NUDGE, Vector2(532, 144)),
	"Koperasi": Rect2(Vector2(88, 1656) + HUD_NUDGE, Vector2(285, 160)),
	"Inventory": Rect2(Vector2(397, 1656) + HUD_NUDGE, Vector2(285, 160)),
	"ReportStudent": Rect2(Vector2(706, 1656) + HUD_NUDGE, Vector2(285, 160)),
	"ChevronGrip": Rect2(Vector2(214, 1352) + HUD_NUDGE, Vector2(280, 96)),
	"DisplayUang": Rect2(672, 48, 360, 112),
	"IconRail": Rect2(Vector2(936, 1040) + HUD_NUDGE, Vector2(96, 456)),
	"DailyLogin": Rect2(Vector2(936, 1040) + HUD_NUDGE, Vector2(96, 96)),
	"SettingsButton": Rect2(Vector2(936, 1160) + HUD_NUDGE, Vector2(96, 96)),
	"AchievementButton": Rect2(Vector2(936, 1280) + HUD_NUDGE, Vector2(96, 96)),
	"SkinSwitchButton": Rect2(Vector2(936, 1400) + HUD_NUDGE, Vector2(96, 96)),
	"ProgressHeader": Rect2(48, 48, 516, 168),
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
