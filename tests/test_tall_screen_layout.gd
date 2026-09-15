@tool
extends McpTestSuite

## Tall-phone layout (spec: docs/superpowers/specs/2026-09-15-tall-phone-layout-design.md).
##
## A 20:9 phone gives the game a 1080x2400 viewport, not 1080x1920. Every
## screen must fill it by four rules: (1) backgrounds are Full Rect and Keep
## Aspect Covered; (2) UI is anchored to the edge it belongs to; (3) that UI
## sits in a SafeAreaMargin; (4) a picture and the items drawn on it move as
## one fixed-size piece. Each screen gets two kinds of test: the contract
## (anchors and stretch modes read from the saved scene, out of the tree) and
## the behaviour (the screen stood up at 1080x2400 and at 1080x1920 through
## tests/layout_frame.gd, with real global rects checked).
##
## Must be @tool, and no test here may be a coroutine.

const LayoutFrame := preload("res://tests/layout_frame.gd")

const TALL := Vector2(1080, 2400)
const DESIGN := Vector2(1080, 1920)

const LOBBY := "res://Scenes/Lobby/loby.tscn"


func suite_name() -> String:
	return "tall_screen_layout"


## `path` instanced out of the tree (no _ready runs), freed after the test.
func _scene(path: String) -> Control:
	var root := (load(path) as PackedScene).instantiate() as Control
	track(root)
	return root


## `path` stood up at `screen` size and settled; returns the screen's root.
func _stood_up(path: String, screen: Vector2) -> Control:
	var frame := track(LayoutFrame.stand_up(path, screen)) as Control
	return frame.get_child(0) as Control


## The four anchors as (left, top, right, bottom).
func _anchors(c: Control) -> Vector4:
	return Vector4(c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom)


## The four offsets as (left, top, right, bottom).
func _offsets(c: Control) -> Vector4:
	return Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom)


## Rule 1: fills its parent and covers without distortion.
func _assert_background_fills(tex: TextureRect, label: String) -> void:
	assert_true(tex != null, label + " is missing")
	if tex == null:
		return
	assert_eq(_anchors(tex), Vector4(0, 0, 1, 1), label + " must be Full Rect")
	assert_eq(_offsets(tex), Vector4.ZERO, label + " must not be inset")
	assert_eq(tex.expand_mode, TextureRect.EXPAND_IGNORE_SIZE,
		label + " must ignore its texture's size")
	assert_eq(tex.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		label + " must cover, not fit or stretch")


## Rule 3: `node` sits somewhere under a SafeAreaMargin.
func _assert_under_safe_area(node: Node, label: String) -> void:
	assert_true(node != null, label + " is missing")
	if node == null:
		return
	var p := node.get_parent()
	while p != null and not (p is SafeAreaMargin):
		p = p.get_parent()
	assert_true(p != null, label + " must sit under a SafeAreaMargin")


## `got` equals `want` to within half a pixel on both corners.
func _assert_rect(got: Rect2, want: Rect2, label: String) -> void:
	var close := got.position.distance_to(want.position) < 0.5 \
		and got.end.distance_to(want.end) < 0.5
	assert_true(close, "%s sits at %s, expected %s" % [label, str(got), str(want)])


## `c`'s authored rect on screen: its parent's settled global rect, placed by
## its own anchors and offsets. A control whose text needs more room still
## grows past this when drawn, to a minimum size that depends on font metrics
## (the editor measures wider than a device); the layout promises this rect.
func _authored_rect(c: Control) -> Rect2:
	var pr := (c.get_parent() as Control).get_global_rect()
	var tl := pr.position + pr.size * Vector2(c.anchor_left, c.anchor_top) \
		+ Vector2(c.offset_left, c.offset_top)
	var br := pr.position + pr.size * Vector2(c.anchor_right, c.anchor_bottom) \
		+ Vector2(c.offset_right, c.offset_bottom)
	return Rect2(tl, br - tl)


## `c` is placed at `want` on screen (its authored rect; see _authored_rect).
func _assert_placed(c: Control, want: Rect2, label: String) -> void:
	assert_true(c != null, label + " is missing")
	if c != null:
		_assert_rect(_authored_rect(c), want, label)


# ── Lobby ────────────────────────────────────────────────────────────────────

## The classroom -- background, four desk layers, seats and hands -- is one
## 1080x1920 piece held at the centre, so the students always sit at their
## desks. The root carries no stray inset.
func test_lobby_classroom_is_one_centred_piece() -> void:
	var lobby := _scene(LOBBY)
	assert_eq(_offsets(lobby), Vector4.ZERO, "the Lobby root is not inset")
	var room := lobby.get_node_or_null("Classroom") as Control
	assert_true(room != null, "the Lobby needs a Classroom node")
	if room == null:
		return
	assert_eq(_anchors(room), Vector4(0.5, 0.5, 0.5, 0.5), "Classroom is Center-anchored")
	assert_eq(_offsets(room), Vector4(-540, -960, 540, 960), "Classroom stays 1080x1920")
	assert_eq(room.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Classroom is art: no clicks")
	for n in ["BGLayer", "Meja_KiriAtas", "Meja_KananAtas",
			"StudentPortraitsContainer_Back", "StudentHandsContainer_Back",
			"Meja_KiriBawah", "Meja_KananBawah",
			"StudentPortraitsContainer_Front", "StudentHandsContainer_Front"]:
		assert_true(room.get_node_or_null(n) != null, n + " moves with the Classroom")
	_assert_background_fills(room.get_node_or_null("BGLayer") as TextureRect,
		"Classroom/BGLayer")


## A black Full Rect behind the classroom fills the bands a tall phone adds.
func test_lobby_backdrop_is_black_and_full_rect() -> void:
	var back := _scene(LOBBY).get_node_or_null("Backdrop") as ColorRect
	assert_true(back != null, "the Lobby needs a Backdrop ColorRect")
	if back == null:
		return
	assert_eq(back.get_index(), 0, "Backdrop draws first, behind the Classroom")
	assert_eq(_anchors(back), Vector4(0, 0, 1, 1), "Backdrop is Full Rect")
	assert_eq(back.color, Color.BLACK, "the bands are black")
	assert_eq(back.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Backdrop takes no clicks")


## The HUD sits in Safe/UI: the title on the top edge, the button block in a
## Bottom Wide bar. Every HUD node is a unique name, so loby.gd and the
## tutorial find it wherever it sits.
func test_lobby_hud_is_pinned_inside_the_safe_area() -> void:
	var lobby := _scene(LOBBY)
	var safe := lobby.get_node_or_null("Safe")
	assert_true(safe is SafeAreaMargin, "the Lobby HUD needs a SafeAreaMargin named Safe")
	if not safe is SafeAreaMargin:
		return
	assert_eq(_anchors(safe as Control), Vector4(0, 0, 1, 1), "Safe is Full Rect")
	assert_eq((safe as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"Safe lets clicks through")
	var ui := lobby.get_node_or_null("Safe/UI") as Control
	assert_true(ui != null and ui.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Safe/UI exists and lets clicks through")
	_assert_under_safe_area(lobby.get_node_or_null("%JUDUL"), "JUDUL")
	var bar := lobby.get_node_or_null("Safe/UI/BottomBar") as Control
	assert_true(bar != null, "the Lobby needs Safe/UI/BottomBar")
	if bar == null:
		return
	assert_eq(_anchors(bar), Vector4(0, 1, 1, 1), "BottomBar is Bottom Wide")
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "BottomBar lets clicks through")
	for n in ["Student", "Jadwal", "Koperasi", "Inventory", "ReportStudent",
			"DisplayUang", "ShortenButton", "DailyLogin"]:
		var c := lobby.get_node_or_null("%" + n) as Control
		assert_true(c != null, n + " must be a unique name")
		if c != null:
			assert_eq(c.get_parent(), bar, n + " rides in BottomBar")


## On a 1080x2400 phone the classroom sits 240 px down, centred; the HUD rides
## the bottom edge 48 px up; the title stays on top; the popup stays centred.
func test_lobby_on_a_tall_phone() -> void:
	var lobby := _stood_up(LOBBY, TALL)
	_assert_placed((lobby.get_node("Backdrop") as Control),
		Rect2(0, 0, 1080, 2400), "Backdrop")
	_assert_placed((lobby.get_node("Classroom") as Control),
		Rect2(0, 240, 1080, 1920), "Classroom")
	_assert_placed((lobby.get_node("%Jadwal") as Control),
		Rect2(48, 2000, 984, 160), "Jadwal")
	_assert_placed((lobby.get_node("%ReportStudent") as Control),
		Rect2(724, 2192, 306, 160), "ReportStudent")
	_assert_placed((lobby.get_node("%DailyLogin") as Control),
		Rect2(48, 1872, 96, 96), "DailyLogin")
	_assert_placed((lobby.get_node("%JUDUL") as Control),
		Rect2(381, 40, 323, 100), "JUDUL")
	_assert_placed((lobby.get_node("DailyReward") as Control),
		Rect2(80, 798, 942, 418), "DailyReward")


## At 1080x1920 the classroom fills the screen and the popup is where it was.
## (The HUD's design rects are pinned in test_lobby_layout.gd.)
func test_lobby_at_the_design_size_is_unchanged() -> void:
	var lobby := _stood_up(LOBBY, DESIGN)
	_assert_placed((lobby.get_node("Classroom") as Control),
		Rect2(0, 0, 1080, 1920), "Classroom")
	_assert_placed((lobby.get_node("DailyReward") as Control),
		Rect2(80, 558, 942, 418), "DailyReward")
