@tool
extends McpTestSuite

## Small text on the light result surfaces has to read at WCAG AA.
##
## ResultBodyLabel is cream text_on_brand, made for SemesterEnd's dark
## ground. It outlived that screen and ended up on light surfaces, where
## cream all but vanishes (measured 2026-09-11): the minigame result card's
## name on popup_bg.svg (1.04:1), its "Skor:" prefix on ResultStatPanel
## (1.2:1), and the score HUD's combo count on ResultBadgePanel (1.05:1).
## RunResult's row names had the same bug; see tests/test_run_result.gd.
##
## ResultDeltaLabel was the same bug through another variation. It bakes
## white so self_modulate can colour-code a change, and every one of its
## users sits on a light ground: the result card's delta rows, bright green
## and red, at 1.13:1 and 2.54:1 on ResultStatPanel; the card's category
## badge and the item sheet's effect values, untinted white on white, at
## 1.02:1; the apply-item preview's "(+5)", state_success on a Card, at
## 3.26:1. Its outline was cream and rescued none of them. The tint stays --
## it is the colour code -- and a dark outline carries the text instead.
## No minigame reports its deltas or names a category yet, so the card's
## rows and badge stay hidden in play today; the Inventory rows do not.
##
## Every label is resolved the way the game draws it: the scene wears the
## BAKED theme and goes into the tree, so theme lookup runs as it does in
## game, and the ground is read off the stylebox actually behind the label.
## A tinted label is measured in the colours it is drawn in: its theme
## colours times its self_modulate and every modulate above it.
##
## The cream is not wrong everywhere, which is why ResultBodyLabel was not
## simply recoloured. The HUD's TargetLabel sits on the dark translucent
## ScoreHudPanel and needs it -- the last contrast test here holds that line --
## and TesNotice's body floats on that screen's dark scrim, where it reads.

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _POPUP_PATH := "res://Scenes/Minigames/UI/MinigameResultPopup.tscn"
const _HUD_PATH := "res://Scenes/Minigames/UI/MinigameScoreHUD.tscn"
const _ITEM_SHEET_PATH := "res://Scenes/Inventory/ItemDetailSheet.tscn"
const _APPLY_ROW_PATH := "res://Scenes/Inventory/ApplyStudentRow.tscn"

## The result card's layout, and the two boxes on it whose labels are
## measured below.
const _LAYOUT := "Dim/Center/Card/Layout/"
const _BADGE := _LAYOUT + "CategoryBadge"
const _DELTA_PANEL := _LAYOUT + "DeltaPanel"
## The three delta rows' labels, under _DELTA_PANEL's DeltaList.
const _DELTA_LABELS := [
	"StatDeltaRow/StatDeltaLabel",
	"EnergyDeltaRow/EnergyDeltaLabel",
	"MoodDeltaRow/MoodDeltaLabel",
]
## The categories that show a badge. Every minigame passes "" today, since
## none names one, and "" hides the badge.
const _CATEGORIES := ["Akademis", "SeniBudaya", "Olahraga"]

## Every key configure() reads from BaseMinigame's popup @exports, at neutral
## values. None of them colours anything measured here.
const _STYLE := {
	"popup_dim_color": Color(0, 0, 0, 0.75),
	"popup_star_texture": null, "popup_star_empty_texture": null,
	"popup_star_color": Color(1.0, 0.85, 0.2), "popup_star_empty_color": Color.GRAY,
	"popup_star_size": Vector2(88, 88),
	"popup_button_text": "Lanjutkan",
	"popup_title_win_color": Color(1.0, 0.88, 0.22),
	"popup_title_lose_color": Color(1.0, 0.65, 0.2),
	"win_title_text": "Kamu Berhasil!",
	"lose_title_text": "",
}

## WCAG 2.x AA, the floor for text at body size.
const _AA_BODY_TEXT := 4.5
## WCAG's floor for large text and UI components -- the most a translucent
## pill can promise over art it does not control.
const _AA_LARGE_TEXT := 3.0
## The thinnest outline allowed to carry a label, in design pixels.
## ResultDeltaLabel's bright fills lean on theirs, and it ships at 4px; a
## thinner rim would pass the colour check and still not show.
const _MIN_OUTLINE_PX := 4


func suite_name() -> String:
	return "light_ground_text"


# ─────────────────────────────────────────── the minigame result card

func test_the_minigame_name_reads_on_the_result_card() -> void:
	var popup := _popup()
	var label: Label = popup.get_node("Dim/Center/Card/Layout/NameLabel")
	var ground := _texture_fill(popup.get_node("Dim/Center/Card"))
	var ratio := _contrast(label.get_theme_color("font_color"), ground)
	assert_true(ratio >= _AA_BODY_TEXT,
		"the minigame name is %.2f:1 on the result card; body text needs %.1f:1"
		% [ratio, _AA_BODY_TEXT])


func test_the_score_prefix_reads_on_its_stat_panel() -> void:
	var popup := _popup()
	var label: Label = popup.get_node(
		"Dim/Center/Card/Layout/ScorePanel/ScoreRow/ScorePrefixLabel")
	var ground := _flat_fill(popup.get_node("Dim/Center/Card/Layout/ScorePanel"))
	var ratio := _contrast(label.get_theme_color("font_color"), ground)
	assert_true(ratio >= _AA_BODY_TEXT,
		"\"Skor:\" is %.2f:1 on its stat panel; body text needs %.1f:1"
		% [ratio, _AA_BODY_TEXT])


## Every row goes through the same configure path, so each is measured as a
## gain and, below, as a loss.
func test_every_delta_row_reads_as_a_gain_on_its_stat_panel() -> void:
	_assert_delta_rows_read(1.0, "a gain")


func test_every_delta_row_reads_as_a_loss_on_its_stat_panel() -> void:
	_assert_delta_rows_read(-1.0, "a loss")


## The category's name on its white chip, in every category that shows one.
func test_the_category_name_reads_on_its_badge() -> void:
	for category in _CATEGORIES:
		var popup := _configured_popup(category, 1.0)
		var label: Label = popup.get_node(_BADGE + "/BadgeRow/BadgeLabel")
		_assert_reads(label, _flat_fill(popup.get_node(_BADGE)),
			"on the %s badge" % category)


# ─────────────────────────────────────────────────── the score HUD

func test_the_combo_count_reads_on_its_chip() -> void:
	var hud := _hud()
	var label: Label = hud.get_node("Panel/Row/ComboChip/ComboRow/ComboLabel")
	var ground := _flat_fill(hud.get_node("Panel/Row/ComboChip"))
	var ratio := _contrast(label.get_theme_color("font_color"), ground)
	assert_true(ratio >= _AA_BODY_TEXT,
		"the combo count is %.2f:1 on its chip; body text needs %.1f:1"
		% [ratio, _AA_BODY_TEXT])


## The one label that keeps the cream. TargetLabel ("/ 5") sits on
## ScoreHudPanel, a dark pill at 0.55 alpha over whatever the minigame paints
## -- a football pitch, a batik cloth. Over the two extremes that art can
## take, black and white, cream holds 3.4:1 at its worst and a dark ink falls
## to 1.3:1 -- which is why ResultBodyLabel was not recoloured to fix the rest.
func test_the_hud_target_keeps_reading_on_its_dark_pill() -> void:
	var hud := _hud()
	var ink: Color = (hud.get_node("Panel/Row/TargetLabel") as Label) \
		.get_theme_color("font_color")
	var pill := (hud.get_node("Panel") as Control).get_theme_stylebox("panel") \
		as StyleBoxFlat
	assert_true(pill != null, "ScoreHudPanel must be a flat fill to be measured")
	if pill == null:
		return
	var worst := INF
	for art in [Color.BLACK, Color.WHITE]:
		worst = minf(worst, _contrast(ink, _over(pill.bg_color, art)))
	assert_true(worst >= _AA_LARGE_TEXT,
		"TargetLabel falls to %.2f:1 on its pill over the brightest or darkest "
		% worst + "art; it needs %.1f:1 over both" % _AA_LARGE_TEXT)


# ──────────────────────── Inventory, which shares ResultDeltaLabel

## The item sheet's "+N" beside each stat an item moves. Nothing tints it,
## so its letters are white on the sheet's white Card.
func test_the_item_sheets_effect_values_read_on_its_card() -> void:
	var sheet := _item_sheet()
	var ground := _flat_fill(sheet.get_node("Sheet"))
	for row in ["RowAkademis", "RowSeni", "RowOlahraga", "RowMood", "RowEnergy"]:
		var label: Label = sheet.get_node(
			"Sheet/Margin/VBox/EfekList/%s/ValueLabel" % row)
		_assert_reads(label, ground, "in the item sheet's %s" % row)


## The apply-item preview readout. Since 2026-09-12 it is the DaySummary
## card's stat number laid over its dark track, so it is measured on the
## track's own flat fill in each state the preview leaves it in: standing,
## previewing, and back.
func test_the_apply_rows_preview_reads_on_its_card() -> void:
	var row := _apply_row()
	var value: Label = row.get_node("Card/StatRow1/Value")
	var ground := _track_fill(row.get_node("Card/StatRow1/Track"))
	_assert_reads(value, ground, "on the apply-item card before any preview")
	row.set_preview(true)
	_assert_reads(value, ground, "in the apply-item preview")
	row.set_preview(false)
	_assert_reads(value, ground, "on the apply-item card after the preview")


# ─────────────────────────────────────────────────────── every label

## A variation the bake does not declare raises no error: Godot quietly falls
## back to the plain Label, which is dark body text -- so a typo in a scene's
## variation name would pass every contrast test above. The badge and the
## delta rows are checked as configure() leaves them, both ways.
func test_every_label_here_wears_a_variation_the_bake_declares() -> void:
	var declared := _baked().get_type_list()
	var popup := _popup()
	var hud := _hud()
	var labels: Array = [
		popup.get_node("Dim/Center/Card/Layout/NameLabel"),
		popup.get_node("Dim/Center/Card/Layout/ScorePanel/ScoreRow/ScorePrefixLabel"),
		hud.get_node("Panel/Row/ComboChip/ComboRow/ComboLabel"),
		hud.get_node("Panel/Row/TargetLabel"),
		_item_sheet().get_node("Sheet/Margin/VBox/EfekList/RowAkademis/ValueLabel"),
		_apply_row().get_node("Card/StatRow1/Value")]
	for direction in [1.0, -1.0]:
		var configured := _configured_popup("Akademis", direction)
		labels.append(configured.get_node(_BADGE + "/BadgeRow/BadgeLabel"))
		for row in _DELTA_LABELS:
			labels.append(configured.get_node(_DELTA_PANEL + "/DeltaList/" + row))
	for label in labels:
		var variation := String((label as Label).theme_type_variation)
		assert_true(declared.has(variation),
			"%s (\"%s\") wears '%s', which the baked theme does not declare -- rebake?"
			% [label.name, (label as Label).text, variation])


# ──────────────────────────────────────────────────────────── helpers

## A fresh copy of the bake. CACHE_MODE_IGNORE: the editor holds the startup
## bake in memory, so a plain load() would hand back the stale copy after a
## rebake.
func _baked() -> Theme:
	return ResourceLoader.load(_THEME_PATH, "",
		ResourceLoader.CACHE_MODE_IGNORE) as Theme


## The result popup, themed from the bake and in the tree. Its root is a
## CanvasLayer, which carries no theme, so the bake goes on Dim -- the
## Control every label descends from. track() frees it after the test.
func _popup() -> Node:
	var popup: Node = load(_POPUP_PATH).instantiate()
	(popup.get_node("Dim") as Control).theme = _baked()
	Engine.get_main_loop().root.add_child(popup)
	track(popup)
	return popup


## The popup configured the way BaseMinigame configures it: a won,
## three-star run scoring 3 of 5 in `category`, with every delta pointing
## `direction` -- 1.0 for a gain, -1.0 for a loss -- so all three rows show.
func _configured_popup(category: String, direction: float) -> Node:
	var popup := _popup()
	popup.configure(true, 3, 3, 5, "Pilihan Ganda", category,
		5.0 * direction, 3.0 * direction, 2.0 * direction, _STYLE)
	return popup


## Measures each delta row against the stat panel behind the rows.
func _assert_delta_rows_read(direction: float, outcome: String) -> void:
	var popup := _configured_popup("", direction)
	var ground := _flat_fill(popup.get_node(_DELTA_PANEL))
	for row in _DELTA_LABELS:
		var label: Label = popup.get_node(_DELTA_PANEL + "/DeltaList/" + row)
		_assert_reads(label, ground, "on its stat panel as %s" % outcome)


## The score HUD, themed from the bake and in the tree.
func _hud() -> Control:
	var hud: Control = load(_HUD_PATH).instantiate()
	hud.theme = _baked()
	Engine.get_main_loop().root.add_child(hud)
	track(hud)
	return hud


## The item detail sheet, themed from the bake and in the tree, filled by
## setup() with an item that moves all five bars, so every effect row shows.
func _item_sheet() -> Control:
	var sheet: Control = load(_ITEM_SHEET_PATH).instantiate()
	sheet.theme = _baked()
	Engine.get_main_loop().root.add_child(sheet)
	track(sheet)
	var item := ItemData.new()
	item.item_name = "Buku Latihan"
	item.category = "Buku"
	item.description = "desc"
	item.akademis_boost = 5
	item.seni_budaya_boost = 4
	item.olahraga_boost = 3
	item.mood_boost = 2
	item.energy_boost = 1
	sheet.setup(item, 1)
	return sheet


## An apply-item row, themed from the bake and in the tree, set up for a
## student the item lifts in akademis and tops out in mood -- so its
## preview shows both a gain and a full bar.
func _apply_row() -> Control:
	var row: Control = load(_APPLY_ROW_PATH).instantiate()
	row.theme = _baked()
	Engine.get_main_loop().root.add_child(row)
	track(row)
	row.setup({"id": 1, "name": "A", "akademis1": 50.0, "akademis2": 50.0,
		"akademis3": 50.0, "kepribadian1": 100.0, "kepribadian2": 50.0},
		{"akademis": 5, "mood": 5})
	return row


## Asserts `label` reads on `ground` at body-text contrast, by its fill or
## by an outline at least _MIN_OUTLINE_PX thick. Both inks are measured
## under the label's tint, since self_modulate multiplies the outline too.
func _assert_reads(label: Label, ground: Color, where: String) -> void:
	var tint := _tint(label)
	var fill := _contrast(label.get_theme_color("font_color") * tint, ground)
	var outline_px := label.get_theme_constant("outline_size")
	var rim := 0.0
	if outline_px >= _MIN_OUTLINE_PX:
		rim = _contrast(label.get_theme_color("font_outline_color") * tint, ground)
	assert_true(maxf(fill, rim) >= _AA_BODY_TEXT,
		"\"%s\" %s: its fill is %.2f:1 and its %dpx outline %.2f:1; body text "
		% [label.text, where, fill, outline_px, rim]
		+ "needs %.1f:1 from one of them" % _AA_BODY_TEXT)


## What a CanvasItem's drawing is multiplied by: its own self_modulate, and
## the modulate of it and of every CanvasItem above it. Colour only: alpha
## is dropped, because configure() zeroes each fade slot for play() to bring
## back. Dropping it once hid that play() never brought the delta rows back;
## test_minigame_result_popup.gd holds that now.
static func _tint(item: CanvasItem) -> Color:
	var tint := item.self_modulate
	var node: Node = item
	while node is CanvasItem:
		tint *= (node as CanvasItem).modulate
		node = node.get_parent()
	tint.a = 1.0
	return tint


## The fill a flat panel paints behind its content. Asserted opaque: a
## translucent fill would put whatever lies beneath into the ground too.
func _flat_fill(panel: Control) -> Color:
	var box := panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_true(box != null,
		"%s must be a flat fill for its colour to be measured" % panel.name)
	if box == null:
		return Color.BLACK
	assert_true(box.bg_color.a >= 0.99,
		"%s's fill is translucent; measure what shows through it" % panel.name)
	return box.bg_color


## A ProgressBar's empty-track colour: the flat fill of its "background"
## stylebox, which is what a label laid over the track reads against.
func _track_fill(bar: Control) -> Color:
	var box := bar.get_theme_stylebox("background") as StyleBoxFlat
	assert_true(box != null, "%s's track must be a flat fill to be measured" % bar.name)
	return box.bg_color if box != null else Color.BLACK


## The colour a textured panel paints behind its content: the mean of the
## art's centre patch, which the nine-patch stretches under whatever the panel
## holds. Transparent texels are skipped.
func _texture_fill(panel: Control) -> Color:
	var box := panel.get_theme_stylebox("panel") as StyleBoxTexture
	assert_true(box != null and box.texture != null,
		"%s must be a textured panel for its art to be sampled" % panel.name)
	if box == null or box.texture == null:
		return Color.BLACK
	var image := box.texture.get_image()
	if image.is_compressed():
		image.decompress()
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var count := 0
	for y in range(int(box.texture_margin_top),
			image.get_height() - int(box.texture_margin_bottom)):
		for x in range(int(box.texture_margin_left),
				image.get_width() - int(box.texture_margin_right)):
			var c := image.get_pixel(x, y)
			if c.a < 0.5:
				continue
			r += c.r
			g += c.g
			b += c.b
			count += 1
	assert_true(count > 0, "%s's centre patch is empty" % panel.name)
	if count == 0:
		return Color.BLACK
	return Color(r / count, g / count, b / count)


## `top`, with its alpha, painted over an opaque `bottom` the way 2D blends:
## straight alpha on the sRGB-encoded channels.
static func _over(top: Color, bottom: Color) -> Color:
	return Color(lerpf(bottom.r, top.r, top.a), lerpf(bottom.g, top.g, top.a),
		lerpf(bottom.b, top.b, top.a), 1.0)


## sRGB relative luminance, per WCAG 2.x. Copied verbatim from
## tests/test_bar_contrast.gd, with _contrast() below.
static func _relative_luminance(c: Color) -> float:
	var out := 0.0
	var weights := [0.2126, 0.7152, 0.0722]
	var channels := [c.r, c.g, c.b]
	for i in 3:
		var v: float = channels[i]
		var lin: float = v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
		out += weights[i] * lin
	return out


static func _contrast(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	var hi: float = max(la, lb)
	var lo: float = min(la, lb)
	return (hi + 0.05) / (lo + 0.05)
