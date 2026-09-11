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
## Every label is resolved the way the game draws it: the scene wears the
## BAKED theme and goes into the tree, so theme lookup runs as it does in
## game, and the ground is read off the stylebox actually behind the label.
##
## The cream is not wrong everywhere, which is why ResultBodyLabel was not
## simply recoloured. The HUD's TargetLabel sits on the dark translucent
## ScoreHudPanel and needs it -- the last contrast test here holds that line --
## and TesNotice's body floats on that screen's dark scrim, where it reads.

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _POPUP_PATH := "res://Scenes/Minigames/UI/MinigameResultPopup.tscn"
const _HUD_PATH := "res://Scenes/Minigames/UI/MinigameScoreHUD.tscn"

## WCAG 2.x AA, the floor for text at body size.
const _AA_BODY_TEXT := 4.5
## WCAG's floor for large text and UI components -- the most a translucent
## pill can promise over art it does not control.
const _AA_LARGE_TEXT := 3.0


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


## A variation the bake does not declare raises no error: Godot quietly falls
## back to the plain Label, which is dark body text -- so a typo in a scene's
## variation name would pass every contrast test above.
func test_every_label_here_wears_a_variation_the_bake_declares() -> void:
	var declared := _baked().get_type_list()
	var popup := _popup()
	var hud := _hud()
	for label in [
			popup.get_node("Dim/Center/Card/Layout/NameLabel"),
			popup.get_node("Dim/Center/Card/Layout/ScorePanel/ScoreRow/ScorePrefixLabel"),
			hud.get_node("Panel/Row/ComboChip/ComboRow/ComboLabel"),
			hud.get_node("Panel/Row/TargetLabel")]:
		var variation := String((label as Label).theme_type_variation)
		assert_true(declared.has(variation),
			"%s wears '%s', which the baked theme does not declare -- rebake?"
			% [label.name, variation])


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


## The score HUD, themed from the bake and in the tree.
func _hud() -> Control:
	var hud: Control = load(_HUD_PATH).instantiate()
	hud.theme = _baked()
	Engine.get_main_loop().root.add_child(hud)
	track(hud)
	return hud


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
