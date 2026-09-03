@tool
extends PanelContainer
class_name WeekRecapBanner

## ResultCheckup's pinned week summary: the week and grade, and the four
## headline totals as WeekRecapPills (2026-09-03 spec sections 3 and 4).
##
## Pinned means it lives OUTSIDE the screen's ScrollContainer, so the
## week's totals stay on screen while the player reads student cards.
##
## Owns entrance stages 1-3 (banner slide, pill count-ups, coin shower).
## Stages 4-5 belong to ResultCheckup, which owns the cards.
##
## @tool so the editor's test runner can instantiate and inspect it.

## Gap between one pill's count-up and the next, in seconds. Long enough
## to read as four separate events rather than one chord.
const PILL_STEP := 0.14

## How far the banner travels down into place on stage 1.
const SLIDE_DISTANCE := 48.0

@onready var week_label: Label = $Header/WeekLabel
@onready var grade_label: Label = $Header/GradeLabel
@onready var pill_uang: WeekRecapPill = $Pills/PillUang
@onready var pill_poin: WeekRecapPill = $Pills/PillPoin
@onready var pill_menang: WeekRecapPill = $Pills/PillMenang
@onready var pill_event: WeekRecapPill = $Pills/PillEvent
@onready var coin_shower: RewardParticles = $CoinShower

# ── Visual - Icons ───────────────────────────────────────────────────
@export_group("Visual - Icons")
## Icon on the money pill.
@export var icon_uang: Texture2D = null
## Icon on the net-skill pill.
@export var icon_poin: Texture2D = null
## Icon on the minigame win/loss pill.
@export var icon_menang: Texture2D = null
## Icon on the event-count pill.
@export var icon_event: Texture2D = null

## The recap this banner is currently showing, cached by set_recap so
## play_entrance can count each pill up to the right number.
var _recap: Dictionary = {}


## Write the week's header line and all four pills. Idempotent -- calling
## it twice simply rewrites the same labels.
func set_recap(recap: Dictionary) -> void:
	_recap = recap
	var t := Juice.tokens()

	if week_label:
		week_label.text = "MINGGU %d" % GameState.minggu_ke
	if grade_label:
		grade_label.text = "%s · Evaluasi Mingguan" % GameState.get_grade_name()

	var money: int = recap.get("money_earned", 0)
	pill_uang.set_pill(icon_uang, WeekRecap.format_money(money),
		t.currency_gold if money > 0 else t.text_primary)

	# The one pill that can report bad news, so the one pill that changes
	# colour with its sign.
	var poin: int = recap.get("net_skill_delta", 0)
	var poin_tint := t.text_primary
	if poin > 0:
		poin_tint = t.state_success
	elif poin < 0:
		poin_tint = t.state_danger
	pill_poin.set_pill(icon_poin, WeekRecap.format_skill_delta(poin),
		poin_tint)

	pill_menang.set_pill(icon_menang, "%d/%d" % [
		recap.get("minigames_won", 0), recap.get("minigames_total", 0)],
		t.text_primary)

	pill_event.set_pill(icon_event,
		str(recap.get("events_count", 0)), t.text_primary)


## Entrance stages 1-3: the banner slides down, the four pills count up
## in sequence, and -- only if the week actually earned money -- coins
## fall from the money pill.
##
## A coroutine; never call it from a test.
func play_entrance() -> void:
	if Engine.is_editor_hint():
		return
	var t := Juice.tokens()

	position.y -= SLIDE_DISTANCE
	modulate.a = 0.0
	AudioDirector.play_sfx(&"whoosh")
	var slide := create_tween().set_parallel(true)
	slide.tween_property(self, "position:y",
		position.y + SLIDE_DISTANCE, t.dur_normal)
	slide.tween_property(self, "modulate:a", 1.0, t.dur_normal)
	await slide.finished

	var pills: Array = [pill_uang, pill_poin, pill_menang, pill_event]
	var values: Array = [
		float(_recap.get("money_earned", 0)),
		float(_recap.get("net_skill_delta", 0)),
		float(_recap.get("minigames_won", 0)),
		float(_recap.get("events_count", 0)),
	]
	var formatters: Array = [
		func(v: float) -> String: return WeekRecap.format_money(int(v)),
		func(v: float) -> String: return WeekRecap.format_skill_delta(int(v)),
		func(v: float) -> String: return "%d/%d" % [int(v),
			_recap.get("minigames_total", 0)],
		func(v: float) -> String: return "%d" % int(v),
	]
	for i in pills.size():
		pills[i].play_count_up(values[i], formatters[i],
			float(i) * PILL_STEP)

	# Stage 3. Gated: a week that earned nothing gets no coin shower and
	# no coin cue, the same discipline the cards use for their sparkle.
	if int(_recap.get("money_earned", 0)) > 0:
		await get_tree().create_timer(PILL_STEP).timeout
		if not is_inside_tree():
			return
		AudioDirector.play_sfx(&"coin")
		coin_shower.fire()
