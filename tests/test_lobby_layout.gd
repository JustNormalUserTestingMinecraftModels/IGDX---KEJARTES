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
const DESIGN_RECTS := {
	"Student": Rect2(88, 1444, 532, 144),
	"Jadwal": Rect2(88, 1444, 532, 144),
	"Koperasi": Rect2(88, 1656, 285, 160),
	"Inventory": Rect2(397, 1656, 285, 160),
	"ReportStudent": Rect2(706, 1656, 285, 160),
	"ChevronGrip": Rect2(214, 1352, 280, 96),
	"DisplayUang": Rect2(772, 48, 260, 112),
	"IconRail": Rect2(936, 1040, 96, 456),
	"DailyLogin": Rect2(936, 1040, 96, 96),
	"SettingsButton": Rect2(936, 1160, 96, 96),
	"AchievementButton": Rect2(936, 1280, 96, 96),
	"SkinSwitchButton": Rect2(936, 1400, 96, 96),
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
		assert_eq(tile.get_global_rect().size.y, first.get_global_rect().size.y,
			"%s height differs from %s -- the three tiles are one row"
				% [NAV_TILES[i], NAV_TILES[0]])
		assert_eq(tile.get_global_rect().position.y, first.get_global_rect().position.y,
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
