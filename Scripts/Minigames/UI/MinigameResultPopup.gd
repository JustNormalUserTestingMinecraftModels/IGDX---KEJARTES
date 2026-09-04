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
	"Jangan Menyerah, Coba Lagi Lain Kali!",
	"Yuk! Terus Berlatih agar Berhasil!",
	"Ingat dan Kamu Pasti Bisa!",
]

## Category -> accent colour for the category badge. Literal per-category
## values in the shipped code, not design tokens -- kept as-is.
const _CATEGORY_COLORS := {
	"Akademis": Color(0.16, 0.27, 1.0),
	"SeniBudaya": Color(0.0, 0.6, 0.25),
	"Olahraga": Color(0.75, 0.1, 0.1),
}
## Category -> icon texture. Replaces the emoji glyph map the shipped card
## used; the project banned emoji as UI iconography during the 2026-09-02 pass.
const _CATEGORY_ICON_PATHS := {
	"Akademis": "res://Assets/Images/UI/Placeholders/icon_akademis.svg",
	"SeniBudaya": "res://Assets/Images/UI/Placeholders/icon_seni.svg",
	"Olahraga": "res://Assets/Images/UI/Placeholders/icon_olahraga.svg",
}
## Icon for a category the map above does not know.
const _CATEGORY_ICON_FALLBACK := "res://Assets/Images/UI/Placeholders/icon_poin.svg"
## The two need-delta rows' icons.
const _ENERGY_ICON := "res://Assets/Images/UI/Placeholders/icon_energy.svg"
const _MOOD_ICON := "res://Assets/Images/UI/Placeholders/icon_mood.svg"

## Per-star pop scale, ascending. The shipped reveal popped all three to the
## same 1.18, so the third star landed no harder than the first and the whole
## sequence read flat. Index is the star's 0-based position.
const STAR_POP_SCALES: Array[float] = [1.14, 1.22, 1.34]
## Seconds each star holds at its pop scale before settling. Ascending for the
## same reason.
const STAR_HOLD_TIMES: Array[float] = [0.06, 0.10, 0.18]
## Stars at or above which the card fires its screen-wide confetti. Three: a
## two-star finish staying quiet is what makes three mean something.
const CONFETTI_STAR_THRESHOLD: int = 3
## Intended seconds for the score readout's tally-up, kept for interface
## completeness -- currently unused. Juice.count_up() (the tally call this
## file actually makes) has no duration parameter; its animation length is
## hardcoded to DesignTokens.dur_slow. Wire this in if Juice.gd ever grows
## a duration override.
const SCORE_COUNT_TIME: float = 0.6

@onready var dim: ColorRect = $Dim
@onready var card: PanelContainer = $Dim/Center/Card
@onready var title_label: Label = $Dim/Center/Card/Layout/TitleLabel
@onready var star_row: HBoxContainer = $Dim/Center/Card/Layout/StarRow
@onready var name_label: Label = $Dim/Center/Card/Layout/NameLabel
@onready var score_panel: PanelContainer = $Dim/Center/Card/Layout/ScorePanel
@onready var score_row: HBoxContainer = $Dim/Center/Card/Layout/ScorePanel/ScoreRow
@onready var score_icon: TextureRect = $Dim/Center/Card/Layout/ScorePanel/ScoreRow/ScoreIcon
@onready var score_prefix_label: Label = $Dim/Center/Card/Layout/ScorePanel/ScoreRow/ScorePrefixLabel
@onready var score_value_label: Label = $Dim/Center/Card/Layout/ScorePanel/ScoreRow/ScoreValueLabel
@onready var category_badge: PanelContainer = $Dim/Center/Card/Layout/CategoryBadge
@onready var category_badge_label: Label = $Dim/Center/Card/Layout/CategoryBadge/BadgeRow/BadgeLabel
@onready var badge_icon: TextureRect = $Dim/Center/Card/Layout/CategoryBadge/BadgeRow/BadgeIcon
@onready var delta_panel: PanelContainer = $Dim/Center/Card/Layout/DeltaPanel
@onready var stat_delta_label: Label = $Dim/Center/Card/Layout/DeltaPanel/DeltaList/StatDeltaRow/StatDeltaLabel
@onready var stat_delta_icon: TextureRect = $Dim/Center/Card/Layout/DeltaPanel/DeltaList/StatDeltaRow/StatDeltaIcon
@onready var energy_delta_label: Label = $Dim/Center/Card/Layout/DeltaPanel/DeltaList/EnergyDeltaRow/EnergyDeltaLabel
@onready var energy_delta_icon: TextureRect = $Dim/Center/Card/Layout/DeltaPanel/DeltaList/EnergyDeltaRow/EnergyDeltaIcon
@onready var mood_delta_label: Label = $Dim/Center/Card/Layout/DeltaPanel/DeltaList/MoodDeltaRow/MoodDeltaLabel
@onready var mood_delta_icon: TextureRect = $Dim/Center/Card/Layout/DeltaPanel/DeltaList/MoodDeltaRow/MoodDeltaIcon
@onready var continue_button_center: CenterContainer = $Dim/Center/Card/Layout/ContinueButtonCenter
@onready var continue_button: Button = $Dim/Center/Card/Layout/ContinueButtonCenter/ContinueButton
@onready var confetti: RewardParticles = $Dim/ResultConfetti

## Cached so play()'s reveal sequence can skip hidden rows in the shipped
## order without re-deriving visibility.
var _dim_target_color: Color
var _is_win: bool = false
## How many stars play() should land -- read by its star loop and by the
## confetti gate. Set fresh on every configure() call.
var _star_count: int = 0
## What the score readout counts up to. Set fresh on every configure() call.
var _score_target: int = 0


## Fill every node from the result and BaseMinigame's popup @exports.
##
## `style` keys used now that chrome comes from the theme: popup_dim_color,
## popup_star_texture, popup_star_empty_texture, popup_star_color,
## popup_star_empty_color, popup_star_size, popup_button_text,
## popup_title_win_color, popup_title_lose_color, win_title_text,
## lose_title_text.
##
## Affects: this popup's own nodes only. Does not start the reveal --
## call play() for that.
func configure(is_win: bool, stars: int, score: int, max_score: int,
		minigame_title: String, category: String,
		stat_delta: float, energy_delta: float, mood_delta: float,
		style: Dictionary) -> void:
	_is_win = is_win
	_star_count = stars
	_score_target = score

	# ── Dim + card shell ──
	var dim_color: Color = style["popup_dim_color"]
	dim.color = Color(dim_color.r, dim_color.g, dim_color.b, 0.0)
	_dim_target_color = dim_color

	var viewport_w: float = get_viewport().get_visible_rect().size.x
	card.custom_minimum_size = Vector2(clampf(viewport_w * 0.78, 340, 820), 0)
	card.modulate.a = 0.0
	card.scale = Vector2(0.75, 0.75)

	# ── Title ──
	var fail_title: String = _FAIL_TITLES[randi() % _FAIL_TITLES.size()]
	var lose_title: String = style["lose_title_text"]
	title_label.text = style["win_title_text"] if is_win \
		else (lose_title if lose_title != "" else fail_title)
	title_label.self_modulate = \
		style["popup_title_win_color"] if is_win else style["popup_title_lose_color"]
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
	name_label.modulate.a = 0.0

	# ── Score row ──
	score_panel.visible = score >= 0 and max_score > 0
	score_icon.texture = load("res://Assets/Images/UI/Placeholders/icon_skor.svg")
	# Seeded at zero so play() has something to count up from -- the "0" is
	# never actually seen, since the whole panel fades in already ticking.
	score_value_label.text = "0 / %d" % max_score
	score_value_label.self_modulate = \
		style["popup_title_win_color"] if is_win else Color(0.8, 0.8, 0.8)
	score_panel.modulate.a = 0.0

	# ── Category badge ──
	category_badge.visible = category != ""
	if category != "":
		badge_icon.texture = load(_CATEGORY_ICON_PATHS.get(category, _CATEGORY_ICON_FALLBACK))
		badge_icon.self_modulate = _CATEGORY_COLORS.get(category, Color(0.3, 0.3, 0.4))
		category_badge_label.text = category
	category_badge.modulate.a = 0.0

	# ── Stat deltas ──
	stat_delta_icon.texture = load(_CATEGORY_ICON_PATHS.get(category, _CATEGORY_ICON_FALLBACK))
	energy_delta_icon.texture = load(_ENERGY_ICON)
	mood_delta_icon.texture = load(_MOOD_ICON)
	_configure_delta_label(stat_delta_label, stat_delta, _stat_delta_suffix(category))
	_configure_delta_label(energy_delta_label, energy_delta, "Energy")
	_configure_delta_label(mood_delta_label, mood_delta, "Mood")
	delta_panel.visible = stat_delta_label.get_parent().visible \
		or energy_delta_label.get_parent().visible \
		or mood_delta_label.get_parent().visible
	delta_panel.modulate.a = 0.0

	# ── Continue button ──
	continue_button.text = style["popup_button_text"]
	continue_button.custom_minimum_size = Vector2(280, 90)
	continue_button_center.modulate.a = 0.0


## "Akademis" / "Seni Budaya" / "Olahraga" / the category name as-is for
## anything else -- matches the shipped stat_labels_map fallback. The icon
## that used to ride along in the same string is now a separate TextureRect
## (stat_delta_icon), set by configure() directly.
func _stat_delta_suffix(category: String) -> String:
	match category:
		"Akademis": return "Akademis"
		"SeniBudaya": return "Seni Budaya"
		"Olahraga": return "Olahraga"
	return category


## One stat/energy/mood delta row: hides the row's own HBoxContainer (not
## just the label) when delta is exactly 0.0, so a hidden row takes its icon
## with it -- the shipped rule is that a student who gained nothing in that
## stat gets no row for it, not a "+0" row.
func _configure_delta_label(label: Label, delta: float, suffix: String) -> void:
	var row: Control = label.get_parent()
	row.visible = delta != 0.0
	if delta == 0.0:
		return
	label.text = "%s%d %s" % ["+" if delta > 0 else "", int(delta), suffix]
	label.self_modulate = Color(0.3, 0.95, 0.5) if delta > 0 else Color(0.95, 0.35, 0.35)
	row.modulate.a = 0.0


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
	AudioDirector.play_sfx(&"result_fanfare")

	# 3. Title fades in
	var tw_title := get_tree().create_tween()
	tw_title.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_title.tween_property(title_label, "modulate:a", 1.0, 0.2)
	await tw_title.finished

	# 4. Stars pop in one by one, escalating. An unearned star still appears
	# -- silently, and without a burst -- so the contrast makes an earned
	# one land.
	var star_index := 0
	for star in star_row.get_children():
		var pop_scale: float = STAR_POP_SCALES[mini(star_index, STAR_POP_SCALES.size() - 1)]
		var tw_star := get_tree().create_tween().set_parallel(true)
		tw_star.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_star.tween_property(star, "modulate:a", 1.0, 0.15)
		tw_star.tween_property(star, "scale", Vector2(pop_scale, pop_scale), 0.18)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw_star.finished
		star.celebrate(star_index)
		await get_tree().create_timer(
			STAR_HOLD_TIMES[mini(star_index, STAR_HOLD_TIMES.size() - 1)]).timeout
		var tw_settle := get_tree().create_tween()
		tw_settle.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_settle.tween_property(star, "scale", Vector2(1.0, 1.0), 0.1)\
			.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		await tw_settle.finished
		star_index += 1

	# 4b. A full house, and only a full house, gets the confetti.
	if _star_count >= CONFETTI_STAR_THRESHOLD:
		confetti.fire()

	# 5. Name, score, badge and deltas fade in in shipped order, skipping
	# whichever boxes configure() left hidden. The three delta rows share
	# one fade slot (delta_panel) now that they're grouped in one box --
	# checking each row's old Label.visible would be stale, since
	# _configure_delta_label() toggles the row, not the label.
	var fade_nodes: Array = [name_label]
	if score_panel.visible: fade_nodes.append(score_panel)
	if category_badge.visible: fade_nodes.append(category_badge)
	if delta_panel.visible: fade_nodes.append(delta_panel)
	fade_nodes.append(continue_button_center)

	for fn in fade_nodes:
		if is_instance_valid(fn):
			if fn == score_panel and _score_target > 0:
				AudioDirector.play_sfx(&"score_tick")
				Juice.count_up(score_value_label, 0.0, float(_score_target),
					"%d / " + str(_score_target))
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
