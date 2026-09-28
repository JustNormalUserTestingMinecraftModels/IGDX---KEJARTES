@tool
extends PanelContainer
class_name WeekRecapBanner

## ResultCheckup's pinned week summary: the three headline totals (money,
## minigames, events) as WeekRecapPill tiles. Poin and the week line left
## with the 2026-09-19 mockup pass (2026-09-03 spec sections 3 and 4).
##
## Pinned means it lives OUTSIDE the screen's ScrollContainer, so the
## week's totals stay on screen while the player reads student cards.
##
## Owns entrance stages 1-3 (banner slide, pill count-ups, coin shower).
## Stages 4-5 belong to ResultCheckup, which owns the cards.
##
## @tool so the editor's test runner can instantiate and inspect it.

## Gap between one pill's count-up and the next, in seconds. Long enough
## to read as three separate events rather than one chord.
const PILL_STEP := 0.14

## How far each pill starts above its authored slot before sliding down
## into place, in pixels.
const PILL_SLIDE_DISTANCE := 20.0

## Gap between one pill's slide-in STARTING and the next pill's starting
## -- a cascade, not three simultaneous tweens. Each pill's own number
## count-up begins only once THAT pill's slide-in finishes, so the
## numbers read left-to-right in the same rhythm as the pills landing.
const PILL_CASCADE_STEP := 0.10

## How far the banner travels down into place on stage 1.
const SLIDE_DISTANCE := 48.0

## The pills, keyed by the same names WeekRecap.compute() uses, in the
## fixed left-to-right order they're authored in the scene. Read by both
## the idle bounce cycle and the tap handler, so both agree on order and
## on which pill maps to which explainer.
const PILL_ORDER := ["uang", "menang", "event"]

## One sentence per pill, shown by WeekRecapPillInfoPopup on tap. Indonesian,
## matching the project's explanatory tone (2026-09-03 interactivity spec,
## section 3.3).
const PILL_INFO := {
	"uang": {"title": "Uang", "body": "Total penghasilan Wirausaha yang terkumpul minggu ini."},
	"menang": {"title": "Menang", "body": "Jumlah minigame yang dimenangkan dari total yang dimainkan minggu ini."},
	"event": {"title": "Event", "body": "Jumlah kejadian acak yang terjadi minggu ini."},
}

## Gap between one idle-bounce pill and the next, and the pause after the
## last before the cycle repeats.
const IDLE_STEP := 0.9
const IDLE_CYCLE_PAUSE := 1.2

const _POPUP_SCENE := "res://Scenes/UI/WeekRecapPillInfoPopup.tscn"

@onready var pill_uang: WeekRecapPill = $Pills/PillUang
@onready var pill_menang: WeekRecapPill = $Pills/PillMenang
@onready var pill_event: WeekRecapPill = $Pills/PillEvent
@onready var coin_shower: RewardParticles = $CoinShower

# ── Visual - Icons ───────────────────────────────────────────────────
@export_group("Visual - Icons")
## Icon on the money pill.
@export var icon_uang: Texture2D = null
## Icon on the minigame win/loss pill.
@export var icon_menang: Texture2D = null
## Icon on the event-count pill.
@export var icon_event: Texture2D = null

## The recap this banner is currently showing, cached by set_recap so
## play_entrance can count each pill up to the right number.
var _recap: Dictionary = {}

## The looping idle-bounce tween, or null when not running. A single
## tween owned by the banner (not one per pill) so the whole cycle can be
## paused/killed in one call -- see start_idle_bounce/stop_idle_bounce.
var _idle_tween: Tween = null


func _ready() -> void:
	pill_uang.pill_tapped.connect(_on_pill_tapped.bind("uang"))
	pill_menang.pill_tapped.connect(_on_pill_tapped.bind("menang"))
	pill_event.pill_tapped.connect(_on_pill_tapped.bind("event"))


## Open this pill's explainer popup. Pauses the idle bounce first so a
## pill never visibly bounces behind the scrim.
func _on_pill_tapped(pill_key: String) -> void:
	if Engine.is_editor_hint():
		return
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.pause()
	AudioDirector.play_sfx(&"pill_tap")
	var info: Dictionary = PILL_INFO.get(pill_key, {})
	var icon: Texture2D = {
		"uang": icon_uang, "menang": icon_menang, "event": icon_event,
	}.get(pill_key)
	var popup: WeekRecapPillInfoPopup = load(_POPUP_SCENE).instantiate()
	get_tree().root.add_child(popup)
	popup.configure(icon, info.get("title", ""), info.get("body", ""))
	popup.closed.connect(_on_popup_closed)
	popup.open()


## Resume the idle bounce once its popup closes.
func _on_popup_closed() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.play()


## Start the looping "tap me" hint: each pill in turn gets a small
## non-destructive scale-pop, left to right, then a longer pause before
## the cycle repeats. Silent -- no SFX; a looping cue every cycle would
## read as an alarm, not a hint (2026-09-03 interactivity spec, section
## 3.2). Safe to call while already running: kills any prior tween first.
func start_idle_bounce() -> void:
	if Engine.is_editor_hint():
		return
	stop_idle_bounce()
	var pills: Array = [pill_uang, pill_menang, pill_event]
	_idle_tween = create_tween().set_loops()
	for pill in pills:
		Juice.set_pivot_center(pill)
		_idle_tween.tween_property(pill, "scale", Vector2(1.08, 1.08), 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_idle_tween.tween_property(pill, "scale", Vector2.ONE, 0.15) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_idle_tween.tween_interval(IDLE_STEP)
	_idle_tween.tween_interval(IDLE_CYCLE_PAUSE)


## Stop the idle bounce outright (not pause -- kill), snapping every
## pill's scale back to 1.0 so none is left mid-bounce. Safe to call when
## not running.
func stop_idle_bounce() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	for pill in [pill_uang, pill_menang, pill_event]:
		if is_instance_valid(pill):
			pill.scale = Vector2.ONE


## Write all three tiles. Idempotent -- calling it twice simply rewrites
## the same labels. One ink for all three: the mockup's white tiles leave
## the old gold money tint unreadable.
func set_recap(recap: Dictionary) -> void:
	_recap = recap
	var ink := Juice.tokens().text_primary
	pill_uang.set_pill(icon_uang,
		WeekRecap.format_money(recap.get("money_earned", 0)), ink)
	pill_menang.set_pill(icon_menang, "%d/%d" % [
		recap.get("minigames_won", 0), recap.get("minigames_total", 0)], ink)
	pill_event.set_pill(icon_event, str(recap.get("events_count", 0)), ink)


## Entrance stages 1-3: the banner slides down, the three tiles count up
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

	var pills: Array = [pill_uang, pill_menang, pill_event]
	var values: Array = [
		float(_recap.get("money_earned", 0)),
		float(_recap.get("minigames_won", 0)),
		float(_recap.get("events_count", 0)),
	]
	var formatters: Array = [
		func(v: float) -> String: return WeekRecap.format_money(int(v)),
		func(v: float) -> String: return "%d/%d" % [int(v),
			_recap.get("minigames_total", 0)],
		func(v: float) -> String: return "%d" % int(v),
	]
	for i in pills.size():
		_slide_in_pill(pills[i], values[i], formatters[i], float(i) * PILL_CASCADE_STEP)

	# Stage 3. Gated: a week that earned nothing gets no coin shower and
	# no coin cue, the same discipline the cards use for their sparkle.
	if int(_recap.get("money_earned", 0)) > 0:
		await get_tree().create_timer(PILL_STEP).timeout
		if not is_inside_tree():
			return
		AudioDirector.play_sfx(&"coin")
		coin_shower.fire()


## One pill's own slide+fade entrance, chained into its number count-up.
## `delay` is this pill's position in the cascade (§5 of the 2026-09-03
## interactivity spec) -- pill 0 starts immediately, pill 1 starts
## PILL_CASCADE_STEP later, and so on, each pill's tween running
## independently once started rather than all three waiting on a shared
## clock.
##
## A coroutine; called only from play_entrance(), never directly by a
## test.
func _slide_in_pill(pill: WeekRecapPill, to_value: float, formatter: Callable,
		delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_instance_valid(pill) or not pill.is_inside_tree():
			return
	var t := Juice.tokens()
	pill.modulate.a = 0.0
	pill.position.y -= PILL_SLIDE_DISTANCE
	var tw := pill.create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(pill, "modulate:a", 1.0, t.dur_fast)
	tw.tween_property(pill, "position:y", pill.position.y + PILL_SLIDE_DISTANCE, t.dur_fast)
	await tw.finished
	if not is_instance_valid(pill):
		return
	pill.play_count_up(to_value, formatter)
