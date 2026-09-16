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


# ── Koperasi ─────────────────────────────────────────────────────────────────

const KOPERASI := "res://Scenes/Koperasi/koprasi.tscn"


## The room picture behind both views fills the screen and covers.
func test_koperasi_room_fills() -> void:
	_assert_background_fills(_scene(KOPERASI).get_node_or_null("TextureRect") as TextureRect,
		"Koperasi room picture (TextureRect)")


## The shelf view -- shelf picture, items, back button and basket tray -- is
## one piece pinned to the bottom edge, so the tray still ends flush with it.
func test_koperasi_shelf_view_is_one_piece_pinned_bottom() -> void:
	var shelf := _scene(KOPERASI).get_node_or_null("Rak1") as Control
	assert_true(shelf != null, "missing the Rak1 shelf view")
	if shelf == null:
		return
	assert_eq(_anchors(shelf), Vector4(0, 1, 0, 1), "Rak1 pins to the bottom edge")
	assert_eq(_offsets(shelf), Vector4(0, -1803, 1080, -92), "Rak1 keeps its 1080x1711 rect")
	for n in ["BackButton", "Barang1", "Barang2", "Barang3", "Barang4", "BasketTray"]:
		assert_true(shelf.get_node_or_null(n) != null, n + " moves with the shelf")


## The landing's "KEBUTUHAN SEKOLAH" sign pins to the bottom edge, which keeps
## it on the counter's glass front from 9:16 to 9:21.
func test_koperasi_landing_sign_pins_bottom() -> void:
	# Not `sign`: that name shadows the built-in sign() and warns.
	var shelf_sign := _scene(KOPERASI).get_node_or_null("TextureRect/Rak1") as Control
	assert_true(shelf_sign != null, "missing the landing sign TextureRect/Rak1")
	if shelf_sign == null:
		return
	assert_eq(_anchors(shelf_sign), Vector4(0, 1, 0, 1), "the sign pins to the bottom edge")
	assert_eq(_offsets(shelf_sign), Vector4(303, -519, 745, -423), "and keeps its 1080x1920 rect")


## The coin readout sits in the safe area, top-left; Safe lets taps through
## to the shelf underneath.
func test_koperasi_coin_hud_sits_in_the_safe_area() -> void:
	var shop := _scene(KOPERASI)
	var hud := shop.get_node_or_null("%CoinHUD") as Control
	_assert_under_safe_area(hud, "CoinHUD")
	if hud == null:
		return
	assert_eq(_anchors(hud), Vector4.ZERO, "CoinHUD pins top-left")
	for p in ["Safe", "Safe/UI"]:
		var c := shop.get_node_or_null(p) as Control
		assert_true(c != null and c.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			p + " must let taps through to the shelf")


## On a 1080x2400 phone the tray reaches the bottom edge, the shelf rides it,
## and the coins stay at the top.
func test_koperasi_on_a_tall_phone() -> void:
	var shop := _stood_up(KOPERASI, TALL)
	_assert_placed((shop.get_node("TextureRect") as Control),
		Rect2(0, 0, 1080, 2400), "room picture")
	_assert_placed((shop.get_node("Rak1") as Control),
		Rect2(0, 597, 1080, 1711), "shelf view")
	_assert_placed((shop.get_node("Rak1/BasketTray/Body") as Control),
		Rect2(24, 1840, 1032, 560), "basket tray")
	assert_eq(_authored_rect(shop.get_node("TextureRect/Rak1") as Control).position,
		Vector2(303, 1881), "the sign stays on the counter")
	assert_eq(_authored_rect(shop.get_node("%CoinHUD") as Control).position,
		Vector2(20, 20), "the coins stay top-left")


## At 1080x1920 the Koperasi is where it was.
func test_koperasi_at_the_design_size_is_unchanged() -> void:
	var shop := _stood_up(KOPERASI, DESIGN)
	_assert_placed((shop.get_node("Rak1") as Control),
		Rect2(0, 117, 1080, 1711), "shelf view")
	assert_eq(_authored_rect(shop.get_node("TextureRect/Rak1") as Control).position,
		Vector2(303, 1401), "landing sign")
	assert_eq(_authored_rect(shop.get_node("%CoinHUD") as Control).position,
		Vector2(20, 20), "coins")


# ── StudentCard ──────────────────────────────────────────────────────────────

const STUDENT_CARD := "res://Scenes/StudentCard/student_card.tscn"


## The root carries no inset, and the wood fills and covers.
func test_student_card_backdrop_fills() -> void:
	var card := _scene(STUDENT_CARD)
	assert_eq(_offsets(card), Vector4.ZERO, "the StudentCard root is not inset")
	_assert_background_fills(card.get_node_or_null("Backdrop") as TextureRect,
		"StudentCard Backdrop")


## Each paper sheet and the approval stamp are Center-anchored at their
## 1080x1920 rects, so a paper and its stamp stay together, centred.
func test_student_card_papers_are_centred() -> void:
	var card := _scene(STUDENT_CARD)
	for i in range(1, 7):
		var sheet := card.get_node_or_null("KertasMurid%d" % i) as Control
		assert_true(sheet != null, "missing KertasMurid%d" % i)
		if sheet == null:
			continue
		assert_eq(_anchors(sheet), Vector4(0.5, 0.5, 0.5, 0.5),
			"KertasMurid%d is Center-anchored" % i)
		assert_eq(_offsets(sheet), Vector4(-540, -960, 540, 960),
			"KertasMurid%d stays 1080x1920" % i)
	var stamp := card.get_node_or_null("StampApprove") as Control
	assert_true(stamp != null, "missing StampApprove")
	if stamp == null:
		return
	assert_eq(_anchors(stamp), Vector4(0.5, 0.5, 0.5, 0.5), "StampApprove rides with the paper")
	assert_eq(_offsets(stamp), Vector4(-485, -608, 514, 212), "StampApprove keeps its rect")


## The title on the top edge; page arrows and page label in a Bottom Wide
## bar; all inside the safe area.
func test_student_card_ui_is_pinned_inside_the_safe_area() -> void:
	var card := _scene(STUDENT_CARD)
	_assert_under_safe_area(card.get_node_or_null("%PilihMurid"), "PilihMurid")
	var bar := card.get_node_or_null("Safe/UI/BottomBar") as Control
	assert_true(bar != null, "StudentCard needs Safe/UI/BottomBar")
	if bar == null:
		return
	assert_eq(_anchors(bar), Vector4(0, 1, 1, 1), "BottomBar is Bottom Wide")
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "BottomBar lets taps through")
	for n in ["NextButtonKiri", "NextButtonKanan", "PageLabel"]:
		var c := card.get_node_or_null("%" + n)
		assert_true(c != null and c.get_parent() == bar, n + " rides in BottomBar")


## On a 1080x2400 phone the paper sits 240 px down, centred, and the page
## row rides the bottom edge.
func test_student_card_on_a_tall_phone() -> void:
	var card := _stood_up(STUDENT_CARD, TALL)
	_assert_placed((card.get_node("Backdrop") as Control),
		Rect2(0, 0, 1080, 2400), "Backdrop")
	_assert_placed((card.get_node("KertasMurid1") as Control),
		Rect2(0, 240, 1080, 1920), "KertasMurid1")
	_assert_placed((card.get_node("%NextButtonKanan") as Control),
		Rect2(860, 2258, 160, 128), "NextButtonKanan")
	assert_eq(_authored_rect(card.get_node("%PilihMurid") as Control).position,
		Vector2(160, 44), "the title stays at the top")


## At 1080x1920 the StudentCard is where it was.
func test_student_card_at_the_design_size_is_unchanged() -> void:
	var card := _stood_up(STUDENT_CARD, DESIGN)
	_assert_placed((card.get_node("KertasMurid1") as Control),
		Rect2(0, 0, 1080, 1920), "KertasMurid1")
	_assert_placed((card.get_node("%NextButtonKiri") as Control),
		Rect2(90, 1778, 160, 128), "NextButtonKiri")
	_assert_placed((card.get_node("%NextButtonKanan") as Control),
		Rect2(860, 1778, 160, 128), "NextButtonKanan")
	assert_eq(_authored_rect(card.get_node("%PageLabel") as Control).position,
		Vector2(440, 1805), "PageLabel")
	assert_eq(_authored_rect(card.get_node("StampApprove") as Control).position,
		Vector2(55, 352), "StampApprove")
	assert_eq(_authored_rect(card.get_node("%PilihMurid") as Control).position,
		Vector2(160, 44), "PilihMurid")


# ── StudentList ──────────────────────────────────────────────────────────────

const STUDENT_LIST := "res://Scenes/StudentList/student_list.tscn"


func test_student_list_backdrop_fills() -> void:
	_assert_background_fills(_scene(STUDENT_LIST).get_node_or_null("Backdrop") as TextureRect,
		"StudentList Backdrop")


## The roster cards are one Center-anchored piece at their 980x1410 rect.
func test_student_list_cards_are_centred() -> void:
	var cards := _scene(STUDENT_LIST).get_node_or_null("CardContainer") as Control
	assert_true(cards != null, "missing CardContainer")
	if cards == null:
		return
	assert_eq(_anchors(cards), Vector4(0.5, 0.5, 0.5, 0.5), "CardContainer is Center-anchored")
	assert_eq(_offsets(cards), Vector4(-490, -650, 490, 760), "CardContainer keeps its rect")


## The header and avatar strip on the top edge; the arrows and page dots in a
## Bottom Wide bar; all inside the safe area. The tutorial overlay stays the
## last child, over the HUD.
func test_student_list_ui_is_pinned_inside_the_safe_area() -> void:
	var list := _scene(STUDENT_LIST)
	_assert_under_safe_area(list.get_node_or_null("%HeaderLabel"), "HeaderLabel")
	_assert_under_safe_area(list.get_node_or_null("%RosterStrip"), "RosterStrip")
	var bar := list.get_node_or_null("Safe/UI/BottomBar") as Control
	assert_true(bar != null, "StudentList needs Safe/UI/BottomBar")
	if bar == null:
		return
	assert_eq(_anchors(bar), Vector4(0, 1, 1, 1), "BottomBar is Bottom Wide")
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "BottomBar lets taps through")
	for n in ["LeftArrow", "RightArrow", "PageIndicator"]:
		var c := list.get_node_or_null("%" + n)
		assert_true(c != null and c.get_parent() == bar, n + " rides in BottomBar")
	var overlay := list.get_node_or_null("ColorRect")
	assert_true(overlay != null and overlay.get_index() == list.get_child_count() - 1,
		"the tutorial overlay stays the last child, over the HUD")


## On a 1080x2400 phone the cards sit centred and the nav row rides the
## bottom edge; the header stays on top.
func test_student_list_on_a_tall_phone() -> void:
	var list := _stood_up(STUDENT_LIST, TALL)
	_assert_placed((list.get_node("CardContainer") as Control),
		Rect2(50, 550, 980, 1410), "CardContainer")
	_assert_placed((list.get_node("%RightArrow") as Control),
		Rect2(850, 2252, 160, 128), "RightArrow")
	assert_eq(_authored_rect(list.get_node("%HeaderLabel") as Control).position,
		Vector2(190, 24), "the header stays at the top")


## At 1080x1920 the StudentList is where it was.
func test_student_list_at_the_design_size_is_unchanged() -> void:
	var list := _stood_up(STUDENT_LIST, DESIGN)
	_assert_placed((list.get_node("CardContainer") as Control),
		Rect2(50, 310, 980, 1410), "CardContainer")
	_assert_placed((list.get_node("%LeftArrow") as Control),
		Rect2(70, 1772, 160, 128), "LeftArrow")
	_assert_placed((list.get_node("%RosterStrip") as Control),
		Rect2(70, 128, 940, 150), "RosterStrip")
	assert_eq(_authored_rect(list.get_node("%PageIndicator") as Control).position,
		Vector2(400, 1794), "PageIndicator")


# ── Rapor ────────────────────────────────────────────────────────────────────

const REPORT_CARD := "res://Scenes/ReportCard/report_card.tscn"


## Rapor was StudentCard before the tall-phone pass: a root inset by
## 70/254/-77/-352 with every child carrying a negative offset that cancels
## it. The inset is gone and the desk fills, which is what closes the 480px
## of empty grey a 1080x2400 phone used to show below it.
func test_report_card_backdrop_fills() -> void:
	var rapor := _scene(REPORT_CARD)
	assert_eq(_offsets(rapor), Vector4.ZERO, "the Rapor root is not inset")
	_assert_background_fills(rapor.get_node_or_null("Backdrop") as TextureRect,
		"Rapor Backdrop")


## Each paper sheet is Center-anchored at its 1080x1920 rect, as
## StudentCard's are, so the stack sits centred on any screen.
func test_report_card_papers_are_centred() -> void:
	var rapor := _scene(REPORT_CARD)
	for i in range(1, 7):
		var sheet := rapor.get_node_or_null("KertasMurid%d" % i) as Control
		assert_true(sheet != null, "missing KertasMurid%d" % i)
		if sheet == null:
			continue
		assert_eq(_anchors(sheet), Vector4(0.5, 0.5, 0.5, 0.5),
			"KertasMurid%d is Center-anchored" % i)
		assert_eq(_offsets(sheet), Vector4(-540, -960, 540, 960),
			"KertasMurid%d stays 1080x1920" % i)


## Title and KEMBALI on the top edge, page arrows and page label in a Bottom
## Wide bar, all inside the safe area -- the same group StudentCard carries.
func test_report_card_ui_is_pinned_inside_the_safe_area() -> void:
	var rapor := _scene(REPORT_CARD)
	_assert_under_safe_area(rapor.get_node_or_null("%PilihMurid"), "PilihMurid")
	_assert_under_safe_area(rapor.get_node_or_null("%BackButton"), "BackButton")
	var bar := rapor.get_node_or_null("Safe/UI/BottomBar") as Control
	assert_true(bar != null, "Rapor needs Safe/UI/BottomBar")
	if bar == null:
		return
	assert_eq(_anchors(bar), Vector4(0, 1, 1, 1), "BottomBar is Bottom Wide")
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "BottomBar lets taps through")
	for n in ["NextButtonKiri", "NextButtonKanan", "PageLabel"]:
		var c := rapor.get_node_or_null("%" + n)
		assert_true(c != null and c.get_parent() == bar, n + " rides in BottomBar")


## On a 1080x2400 phone the paper sits 240px down, centred, and the page row
## rides the bottom edge instead of stopping at 1920.
func test_report_card_on_a_tall_phone() -> void:
	var rapor := _stood_up(REPORT_CARD, TALL)
	_assert_placed((rapor.get_node("Backdrop") as Control),
		Rect2(0, 0, 1080, 2400), "Backdrop")
	_assert_placed((rapor.get_node("KertasMurid1") as Control),
		Rect2(0, 240, 1080, 1920), "KertasMurid1")
	_assert_placed((rapor.get_node("%NextButtonKanan") as Control),
		Rect2(870, 2260, 120, 120), "NextButtonKanan")
	assert_eq(_authored_rect(rapor.get_node("%PilihMurid") as Control).position,
		Vector2(160, 82), "the title stays at the top")


## At 1080x1920 every piece of Rapor is exactly where it was.
func test_report_card_at_the_design_size_is_unchanged() -> void:
	var rapor := _stood_up(REPORT_CARD, DESIGN)
	_assert_placed((rapor.get_node("KertasMurid1") as Control),
		Rect2(0, 0, 1080, 1920), "KertasMurid1")
	_assert_placed((rapor.get_node("%NextButtonKiri") as Control),
		Rect2(90, 1780, 120, 120), "NextButtonKiri")
	_assert_placed((rapor.get_node("%NextButtonKanan") as Control),
		Rect2(870, 1780, 120, 120), "NextButtonKanan")
	assert_eq(_authored_rect(rapor.get_node("%PageLabel") as Control).position,
		Vector2(440, 1805), "PageLabel")
	assert_eq(_authored_rect(rapor.get_node("%PilihMurid") as Control).position,
		Vector2(160, 82), "PilihMurid")
	assert_eq(_authored_rect(rapor.get_node("%BackButton") as Control).position,
		Vector2(90, 82), "BackButton")


# ── Cross-screen ─────────────────────────────────────────────────────────────

## A unique-name path used as a format string ("%RosterStrip/Avatar%d" % i)
## reads its leading "%R" as a format character and fails at run time, which
## the stood-up screens above never reach (their scripts' _ready does not run
## here). Such a string writes its leading "%" as "%%".
func test_unique_name_paths_are_not_format_strings() -> void:
	var re := RegEx.create_from_string("\"%[A-WYZabeghijklmnpqrtuwyz_][^\"]*\"\\s*%[^=]")
	for path in ["res://Scripts/Lobby/loby.gd", "res://Scripts/Koperasi/koprasi.gd",
			"res://Scripts/StudentCard/student_card.gd",
			"res://Scripts/StudentList/student_list.gd"]:
		var m := re.search(FileAccess.get_file_as_string(path))
		assert_true(m == null, "%s formats a unique-name path: %s"
			% [path, m.get_string() if m else ""])
