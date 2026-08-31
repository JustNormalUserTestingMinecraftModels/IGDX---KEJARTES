@tool
class_name MinigameResultPopup
extends CanvasLayer

## The end-of-minigame result card shown after every one of the eight
## minigames.
##
## Instantiated by Scripts/Minigames/UI/BaseMinigame.gd, which previously
## built this whole CanvasLayer/dim/card/title/stars/score/badge/deltas/
## button hierarchy by hand every time a game ended -- roughly 340 lines,
## including runtime pattern-matching over vbox.get_children() to find "the
## HBoxContainer that isn't the star row" and similar, because the score row
## and category badge were only conditionally built in the first place.
##
## Every node here is fixed and named; configure() toggles .visible instead
## of building or searching for anything. The three stars are separate
## ResultStar scene instances (Pattern B) rather than a loop of throwaway
## Controls.
##
## Affects: nothing outside itself. play() awaits the continue button, then
## frees this node. The caller (BaseMinigame) already knows whether the
## result is a win before showing this popup, so there is no "confirmed"
## signal to react to -- only a single continue action.
##
## @tool so the scene previews in the editor.

## Player-facing fallback titles when a subclass leaves lose_title_text
## empty. Shipped as a literal array; kept verbatim.
const _FAIL_TITLES: Array[String] = [
	"Belum Tepat, Coba Lagi Lain Kali!",
	"Jangan Menyerah, Coba Lagi Lain Kali! 🔥",
	"Yuk! Terus Berlatih agar Berhasil! ✨",
	"Ingat dan Kamu Pasti Bisa! 🚀",
]

## Category -> (accent colour, glyph) for the category badge. Literal
## per-category values in the shipped code, not design tokens -- kept as-is.
const _CATEGORY_COLORS := {
	"Akademis": Color(0.16, 0.27, 1.0),
	"SeniBudaya": Color(0.0, 0.6, 0.25),
	"Olahraga": Color(0.75, 0.1, 0.1),
}
const _CATEGORY_ICONS := {
	"Akademis": "📚", "SeniBudaya": "🎨", "Olahraga": "⚽",
}

@onready var dim: ColorRect = $Dim
@onready var card: PanelContainer = $Dim/Center/Card
@onready var title_label: Label = $Dim/Center/Card/Layout/TitleLabel
@onready var star_row: HBoxContainer = $Dim/Center/Card/Layout/StarRow
@onready var name_label: Label = $Dim/Center/Card/Layout/NameLabel
@onready var score_row: HBoxContainer = $Dim/Center/Card/Layout/ScoreRow
@onready var score_prefix_label: Label = $Dim/Center/Card/Layout/ScoreRow/ScorePrefixLabel
@onready var score_value_label: Label = $Dim/Center/Card/Layout/ScoreRow/ScoreValueLabel
@onready var category_badge: Label = $Dim/Center/Card/Layout/CategoryBadge
@onready var stat_delta_label: Label = $Dim/Center/Card/Layout/StatDeltaLabel
@onready var energy_delta_label: Label = $Dim/Center/Card/Layout/EnergyDeltaLabel
@onready var mood_delta_label: Label = $Dim/Center/Card/Layout/MoodDeltaLabel
@onready var continue_button_center: CenterContainer = $Dim/Center/Card/Layout/ContinueButtonCenter
@onready var continue_button: Button = $Dim/Center/Card/Layout/ContinueButtonCenter/ContinueButton

## Cached so play()'s reveal sequence can skip hidden rows in the shipped
## order without re-deriving visibility.
var _dim_target_color: Color
var _is_win: bool = false


## Fill every node from the result and BaseMinigame's popup @exports.
##
## `style` keys: popup_card_texture, popup_card_color, popup_border_color,
## popup_dim_color, popup_star_texture, popup_star_empty_texture,
## popup_star_color, popup_star_empty_color, popup_star_size,
## popup_button_texture, popup_button_color, popup_button_text,
## popup_title_font, popup_body_font, popup_title_font_size,
## popup_score_font_size, popup_stat_font_size, popup_title_win_color,
## popup_title_lose_color, win_title_text, lose_title_text.
##
## Affects: this popup's own nodes only. Does not start the reveal --
## call play() for that.
func configure(is_win: bool, stars: int, score: int, max_score: int,
		minigame_title: String, category: String,
		stat_delta: float, energy_delta: float, mood_delta: float,
		style: Dictionary) -> void:
	_is_win = is_win

	# ── Dim + card shell ──
	var dim_color: Color = style["popup_dim_color"]
	dim.color = Color(dim_color.r, dim_color.g, dim_color.b, 0.0)
	_dim_target_color = dim_color

	var viewport_w: float = get_viewport().get_visible_rect().size.x
	card.custom_minimum_size = Vector2(clampf(viewport_w * 0.78, 340, 820), 0)

	var card_texture: Texture2D = style["popup_card_texture"]
	if card_texture:
		var sb := StyleBoxTexture.new()
		sb.texture = card_texture
		sb.content_margin_left = 32
		sb.content_margin_top = 28
		sb.content_margin_right = 32
		sb.content_margin_bottom = 28
		card.add_theme_stylebox_override("panel", sb)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = style["popup_card_color"]
		sb.border_color = style["popup_border_color"]
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(22)
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 14
		sb.content_margin_left = 32
		sb.content_margin_top = 28
		sb.content_margin_right = 32
		sb.content_margin_bottom = 28
		card.add_theme_stylebox_override("panel", sb)
	card.modulate.a = 0.0
	card.scale = Vector2(0.75, 0.75)

	# ── Title ──
	var fail_title: String = _FAIL_TITLES[randi() % _FAIL_TITLES.size()]
	var lose_title: String = style["lose_title_text"]
	title_label.text = style["win_title_text"] if is_win \
		else (lose_title if lose_title != "" else fail_title)
	title_label.add_theme_font_size_override("font_size", style["popup_title_font_size"])
	title_label.add_theme_color_override("font_color",
		style["popup_title_win_color"] if is_win else style["popup_title_lose_color"])
	if style["popup_title_font"]:
		title_label.add_theme_font_override("font", style["popup_title_font"])
	title_label.modulate.a = 0.0

	# ── Stars ──
	var star_tex: Texture2D = style["popup_star_texture"]
	var star_empty_tex: Texture2D = style["popup_star_empty_texture"]
	var star_color: Color = style["popup_star_color"]
	var star_empty_color: Color = style["popup_star_empty_color"]
	var star_size: Vector2 = style["popup_star_size"]
	var i := 0
	for star in star_row.get_children():
		var filled: bool = i < stars
		star.custom_minimum_size = star_size
		star.set_filled(filled, star_tex, star_empty_tex, star_color, star_empty_color)
		star.modulate.a = 0.0
		star.scale = Vector2(0.3, 0.3)
		star.pivot_offset = star_size / 2.0
		i += 1

	# ── Minigame name ──
	name_label.text = minigame_title
	name_label.add_theme_font_size_override("font_size", style["popup_stat_font_size"] + 4)
	if style["popup_body_font"]:
		name_label.add_theme_font_override("font", style["popup_body_font"])
	name_label.modulate.a = 0.0

	# ── Score row ──
	score_row.visible = score >= 0 and max_score > 0
	score_prefix_label.add_theme_font_size_override("font_size", style["popup_score_font_size"])
	if style["popup_body_font"]:
		score_prefix_label.add_theme_font_override("font", style["popup_body_font"])
	score_value_label.text = "%d / %d" % [score, max_score]
	score_value_label.add_theme_font_size_override("font_size", style["popup_score_font_size"])
	score_value_label.add_theme_color_override("font_color",
		style["popup_title_win_color"] if is_win else Color(0.8, 0.8, 0.8))
	if style["popup_body_font"]:
		score_value_label.add_theme_font_override("font", style["popup_body_font"])
	score_row.modulate.a = 0.0

	# ── Category badge ──
	category_badge.visible = category != ""
	if category != "":
		category_badge.text = " %s %s " % [_CATEGORY_ICONS.get(category, "🎮"), category]
		category_badge.add_theme_font_size_override("font_size", style["popup_stat_font_size"])
		if style["popup_body_font"]:
			category_badge.add_theme_font_override("font", style["popup_body_font"])
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = _CATEGORY_COLORS.get(category, Color(0.3, 0.3, 0.4))
		badge_style.set_corner_radius_all(10)
		category_badge.add_theme_stylebox_override("normal", badge_style)
	category_badge.modulate.a = 0.0

	# ── Stat deltas ──
	_configure_delta_label(stat_delta_label, stat_delta,
		_stat_delta_suffix(category), style["popup_stat_font_size"], style["popup_body_font"])
	_configure_delta_label(energy_delta_label, energy_delta,
		"Energy ⚡", style["popup_stat_font_size"], style["popup_body_font"])
	_configure_delta_label(mood_delta_label, mood_delta,
		"Mood 😊", style["popup_stat_font_size"], style["popup_body_font"])

	# ── Continue button ──
	var button_texture: Texture2D = style["popup_button_texture"]
	continue_button.text = "" if button_texture else style["popup_button_text"]
	continue_button.custom_minimum_size = Vector2(280, 90)
	if button_texture:
		var sb := StyleBoxTexture.new()
		sb.texture = button_texture
		continue_button.add_theme_stylebox_override("normal", sb)
		continue_button.add_theme_stylebox_override("hover", sb)
		continue_button.add_theme_stylebox_override("pressed", sb)
	else:
		continue_button.add_theme_font_size_override("font_size", style["popup_stat_font_size"] + 4)
		continue_button.add_theme_color_override("font_color", Color.WHITE)
		if style["popup_body_font"]:
			continue_button.add_theme_font_override("font", style["popup_body_font"])
		var button_color: Color = style["popup_button_color"]
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = button_color
		btn_style.set_corner_radius_all(14)
		continue_button.add_theme_stylebox_override("normal", btn_style)
		var btn_hover := btn_style.duplicate() as StyleBoxFlat
		btn_hover.bg_color = button_color.lightened(0.18)
		continue_button.add_theme_stylebox_override("hover", btn_hover)
	continue_button_center.modulate.a = 0.0


## "Akademis 📚" / "Seni Budaya 🎨" / "Olahraga ⚽" / the category name as-is
## for anything else -- matches the shipped stat_labels_map fallback.
func _stat_delta_suffix(category: String) -> String:
	match category:
		"Akademis": return "Akademis 📚"
		"SeniBudaya": return "Seni Budaya 🎨"
		"Olahraga": return "Olahraga ⚽"
	return category


## One stat/energy/mood delta row: hidden when delta is exactly 0.0 (the
## shipped rule -- a student who gained nothing in that stat gets no row for
## it, not a "+0" row).
func _configure_delta_label(label: Label, delta: float, suffix: String,
		font_size: int, font: Font) -> void:
	label.visible = delta != 0.0
	if delta == 0.0:
		return
	label.text = "%s%d %s" % ["+" if delta > 0 else "", int(delta), suffix]
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color",
		Color(0.3, 0.95, 0.5) if delta > 0 else Color(0.95, 0.35, 0.35))
	if font:
		label.add_theme_font_override("font", font)
	label.modulate.a = 0.0


## Run the full reveal -> wait for the player -> fade out -> free sequence.
## Callers must await it; is_win was already known when configure() was
## called, so there is nothing for this popup to report back.
##
## Affects: this popup's own nodes. Frees this node when it returns.
func play() -> void:
	# 1. Dim overlay fades in
	var tw_dim := get_tree().create_tween()
	tw_dim.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_dim.tween_property(dim, "color", _dim_target_color, 0.35)
	await tw_dim.finished

	# 2. Card bounces in
	var tw_card := get_tree().create_tween().set_parallel(true)
	tw_card.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_card.tween_property(card, "modulate:a", 1.0, 0.25)
	tw_card.tween_property(card, "scale", Vector2(1.0, 1.0), 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw_card.finished

	# 3. Title fades in
	var tw_title := get_tree().create_tween()
	tw_title.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_title.tween_property(title_label, "modulate:a", 1.0, 0.2)
	await tw_title.finished

	# 4. Stars pop in one by one, filled or not
	for star in star_row.get_children():
		var tw_star := get_tree().create_tween().set_parallel(true)
		tw_star.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_star.tween_property(star, "modulate:a", 1.0, 0.15)
		tw_star.tween_property(star, "scale", Vector2(1.18, 1.18), 0.18)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw_star.finished
		var tw_settle := get_tree().create_tween()
		tw_settle.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_settle.tween_property(star, "scale", Vector2(1.0, 1.0), 0.1)\
			.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		await tw_settle.finished

	# 5. Name, score, badge and deltas fade in in shipped order, skipping
	# whichever rows configure() left hidden.
	var fade_nodes: Array = [name_label]
	if score_row.visible: fade_nodes.append(score_row)
	if category_badge.visible: fade_nodes.append(category_badge)
	if stat_delta_label.visible: fade_nodes.append(stat_delta_label)
	if energy_delta_label.visible: fade_nodes.append(energy_delta_label)
	if mood_delta_label.visible: fade_nodes.append(mood_delta_label)
	fade_nodes.append(continue_button_center)

	for fn in fade_nodes:
		if is_instance_valid(fn):
			var tw_f := get_tree().create_tween()
			tw_f.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw_f.tween_property(fn, "modulate:a", 1.0, 0.18)
			await tw_f.finished
			await get_tree().create_timer(0.04).timeout

	# 6. Wait for the player
	await continue_button.pressed

	# 7. Fade out everything
	var tw_out := get_tree().create_tween().set_parallel(true)
	tw_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_out.tween_property(card, "modulate:a", 0.0, 0.2)
	tw_out.tween_property(dim, "modulate:a", 0.0, 0.25)
	await tw_out.finished

	queue_free()
