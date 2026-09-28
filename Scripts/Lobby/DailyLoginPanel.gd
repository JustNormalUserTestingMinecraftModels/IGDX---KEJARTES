@tool
class_name DailyLoginPanel
extends TextureRect

## The Lobby's daily-login popup: the seven-day calendar strip, its claim
## button, the streak line above it and the reward it pays. Owns the
## streak rules (a missed day resets to day 1; a claim advances the day,
## wrapping 7 to 1) and writes GameState.player_money, daily_login_day and
## last_claim_date at claim time, so quitting mid-reveal loses nothing.
## It never reaches up: it plays the DailyRewardReveal and, when the
## reveal's coin lands (or close() cuts it short), announces the payout
## with `claimed`; the Lobby then rolls its wallet and fires
## RewardFeedback. The Lobby owns the backdrop blur and calls open() /
## close() / refresh() down.
##
## @tool so the editor's test runner can call claim(), refresh() and the
## static rules. Only _ready (the claim button and reveal signal wiring) is
## gated behind Engine.is_editor_hint(); the writers (refresh, open, close
## and the claim handler) swap texture, modulate, scale and visibility
## ungated. In the game their one caller is Lobby.gd, which is not @tool,
## so nothing restyles the Lobby.tscn open in the editor. The suites do
## call them, but only on a Lobby they instance into the editor root
## themselves and free afterwards, never on the edited scene. A @tool node
## that restyles itself in an edited scene gets that baked into Lobby.tscn
## on save, so never call the writers on an edited scene's panel.

## A claim paid out. `previous_money` is the balance before it, so the
## Lobby can roll its money display up from there.
signal claimed(amount: int, previous_money: int)

## Days in one streak cycle; the day after the last wraps to day 1.
const STREAK_DAYS := 7
## Daily-login reward per streak day (index 0 = day 1). A full 7-day
## streak totals 1500G, the priciest Koperasi item; day 7 is the "peti
## besar" payoff. Our own tunable (daily-login is not a Balance.gd value).
const REWARD_CURVE: Array[int] = [80, 120, 160, 200, 240, 300, 400]
## How the reward amount reads on the panel.
const AMOUNT_FORMAT := "%dG"
## A gap longer than this since the last claim breaks the streak.
const SECONDS_PER_DAY := 86400
## Turns a "YYYY-MM-DD" date into a datetime string Time can parse.
const MIDNIGHT_SUFFIX := " 00:00:00"

## The streak line's text; %d is the day in the 7-day cycle.
const STREAK_FORMAT := "Streak %d hari"
## The teaser under the strip; %d is tomorrow's reward.
const TEASER_FORMAT := "Besok: +%dG"

## Modulate alpha applied to ButtonClaim / RewardCoin / RewardAmount once
## today's reward is already claimed. The panel art always draws the same
## bright gold "claim me" pill regardless of state, and GhostButton draws no
## chrome of its own, so this dim is the only visible cue that the day's
## claim is done once the button goes disabled.
const CLAIMED_CUE_DIM_ALPHA := 0.4

## The daily-login panel, one frame per streak day. The art bakes all
## seven slots with the active one lit, so the whole calendar is a single
## texture swap -- there are no per-day nodes to tint any more.
const DAY_PANELS: Array[Texture2D] = [
	preload("res://Assets/Images/UI/DailyLogin/day1.png"),
	preload("res://Assets/Images/UI/DailyLogin/day2.png"),
	preload("res://Assets/Images/UI/DailyLogin/day3.png"),
	preload("res://Assets/Images/UI/DailyLogin/day4.png"),
	preload("res://Assets/Images/UI/DailyLogin/day5.png"),
	preload("res://Assets/Images/UI/DailyLogin/day6.png"),
	preload("res://Assets/Images/UI/DailyLogin/day7.png"),
]

## The popup's close: how long it fades and shrinks.
const CLOSE_SECONDS := 0.15
## The scale the popup shrinks to as it closes.
const CLOSE_SCALE := Vector2(0.8, 0.8)

## Where the reward coin flies; wired in Lobby.tscn to %DisplayUang.
@export var wallet_anchor: Control
## Seconds between two idle "tap me" bounces while today is unclaimed.
@export var idle_invite_seconds: float = 3.0

@export_group("Streak")
## Flame scale on day 1 of the streak.
@export var flame_scale_min: float = 0.8
## Flame scale on the last streak day.
@export var flame_scale_max: float = 1.3
## Seconds for one idle flicker (dim and back).
@export var flame_flicker_seconds: float = 0.6
## Flame alpha at the bottom of a flicker.
@export var flame_flicker_alpha: float = 0.75
@export_group("")

@onready var claim_button: Button = %ButtonClaim
@onready var reward_coin: TextureRect = %RewardCoin
@onready var reward_amount: Label = %RewardAmount
@onready var greeting: Label = %DailyGreeting
@onready var streak_row: HBoxContainer = %DailyStreak
@onready var streak_label: Label = %StreakLabel
@onready var streak_flame: TextureRect = %StreakFlame
@onready var reward_row: HBoxContainer = %RewardRow
@onready var reveal: DailyRewardReveal = %DailyRewardReveal
@onready var besok_teaser: Label = %BesokTeaser

var _flicker: Tween
var _invite: Tween
## The date (YYYY-MM-DD) the Lobby last passed to refresh(). open() and the
## claim read it, so the whole panel agrees on which day it drew.
var _today: String = ""
## The claim whose payout waits on the reveal's coin landing.
var _pending_amount: int = 0
var _pending_previous_money: int = 0
var _is_payout_pending: bool = false


func _ready() -> void:
	assert(REWARD_CURVE.size() == STREAK_DAYS, "REWARD_CURVE needs one reward per streak day")
	if Engine.is_editor_hint():
		return
	claim_button.pressed.connect(_on_claim_pressed)
	reveal.burst_started.connect(_on_reveal_burst_started)
	reveal.coin_landed.connect(_pay_out)


## Resets a broken streak and redraws the strip for `today` (YYYY-MM-DD).
## Once today is claimed, daily_login_day is already tomorrow's, so the
## strip, streak line and amount show the day that was claimed, dimmed.
func refresh(today: String) -> void:
	_today = today
	if is_streak_broken(GameState.last_claim_date, today):
		# lewat lebih dari 1 hari tanpa klaim, streak reset ke Day1
		GameState.daily_login_day = 1
	if _is_claimed_today(today):
		_show_day(claimed_day_for(GameState.daily_login_day), true)
	else:
		_show_day(GameState.daily_login_day, false)


## Pops the whole panel in -- the art bakes all seven slots, so there are
## no separate tiles left to stagger in behind it.
func open() -> void:
	visible = true
	Juice.pop_in(self)
	_spring_in_headers()
	reveal.show_ready()
	_start_flicker()
	_start_idle_invite()


## Fades and shrinks the panel out, then hides it. A reveal still playing
## is cut short first, so its payout still reaches the wallet.
func close() -> void:
	reveal.skip()
	_stop_flicker()
	_stop_idle_invite()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, CLOSE_SECONDS).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", CLOSE_SCALE, CLOSE_SECONDS).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(hide)


## Pays today's reward into GameState and advances the streak. Returns
## the amount paid, or 0 when `today` was already claimed.
func claim(today: String) -> int:
	if _is_claimed_today(today):
		return 0
	var amount: int = reward_for_day(GameState.daily_login_day)
	GameState.player_money += amount
	GameState.last_claim_date = today
	GameState.daily_login_day = day_after(GameState.daily_login_day)
	return amount


## The reward for streak `day`, clamped into 1..STREAK_DAYS.
static func reward_for_day(day: int) -> int:
	return REWARD_CURVE[clampi(day, 1, STREAK_DAYS) - 1]


## The streak flame's scale on `day`: it grows from flame_scale_min on
## day 1 to flame_scale_max on the last streak day.
func flame_scale_for(day: int) -> float:
	var progress: float = float(clampi(day, 1, STREAK_DAYS) - 1) / float(STREAK_DAYS - 1)
	return lerpf(flame_scale_min, flame_scale_max, progress)


## The teaser line for `next_day`, the streak day tomorrow's claim is.
static func teaser_text(next_day: int) -> String:
	return TEASER_FORMAT % reward_for_day(next_day)


## The streak day after `day`; the last day wraps to day 1.
static func day_after(day: int) -> int:
	return day % STREAK_DAYS + 1


## The streak day that was claimed when `day` is the already-advanced
## GameState.daily_login_day: the day before it, day 1 wrapping back to
## the last streak day. The inverse of day_after.
static func claimed_day_for(day: int) -> int:
	return (day + STREAK_DAYS - 2) % STREAK_DAYS + 1


## True when more than one day has passed since `last_claim_date`. Never
## broken before the first claim, nor on the day of a claim.
static func is_streak_broken(last_claim_date: String, today: String) -> bool:
	if last_claim_date == "" or last_claim_date == today:
		return false
	var today_unix: int = Time.get_unix_time_from_datetime_string(today + MIDNIGHT_SUFFIX)
	var last_unix: int = Time.get_unix_time_from_datetime_string(last_claim_date + MIDNIGHT_SUFFIX)
	return today_unix - last_unix > SECONDS_PER_DAY


## True once `today` (YYYY-MM-DD) has been claimed. The one place the
## panel asks, so refresh, open, the claim and the invite always agree.
func _is_claimed_today(today: String) -> bool:
	return GameState.last_claim_date == today


func _on_claim_pressed() -> void:
	AnimUtils.squash_bounce(claim_button)
	if _today.is_empty():
		push_error("DailyLoginPanel: refresh(today) never ran, so there is no day to claim")
		return
	if _is_claimed_today(_today):
		AudioDirector.play_sfx(&"error")
		return
	AudioDirector.play_sfx(&"daily_claim")
	_stop_idle_invite()
	var claimed_day: int = GameState.daily_login_day
	var previous_money: int = GameState.player_money
	var amount: int = claim(_today)
	_show_day(claimed_day, true)
	# The tiles are gone -- the panel itself is what pops now.
	Juice.pop_in(self)
	_play_claim_moment(amount, claimed_day, previous_money)


## Holds the payout and plays the reveal; the reward row counts up at its
## burst and `claimed` goes out when its coin lands. A payout still owed
## by an earlier reveal is paid first, never overwritten.
func _play_claim_moment(amount: int, claimed_day: int, previous_money: int) -> void:
	_flush_pending_payout()
	_pending_amount = amount
	_pending_previous_money = previous_money
	_is_payout_pending = true
	if wallet_anchor == null:
		push_error("DailyLoginPanel: wallet_anchor is not wired to %DisplayUang in Lobby.tscn")
		_on_reveal_burst_started()
		_pay_out()
		return
	reveal.play(claimed_day == STREAK_DAYS, wallet_anchor.get_global_rect().get_center())


## Cuts an earlier reveal short and pays whatever claim it still owes.
## Both steps are latched, so nothing is emitted when nothing is owed.
func _flush_pending_payout() -> void:
	reveal.skip()
	_pay_out()


## The reward row pops and counts up at the burst; under reduce_motion it
## simply shows the final amount.
func _on_reveal_burst_started() -> void:
	# _show_day dimmed these for the "already claimed" cue before the reveal
	# played; restore full brightness so the count-up pays off bright.
	reward_coin.modulate.a = 1.0
	reward_amount.modulate.a = 1.0
	if GameSettings.reduce_motion:
		reward_row.scale = Vector2.ONE
		reward_row.modulate.a = 1.0
		reward_amount.text = AMOUNT_FORMAT % _pending_amount
		return
	AnimUtils.spring_pop_in(reward_row)
	Juice.count_up(reward_amount, 0.0, float(_pending_amount), AMOUNT_FORMAT)


## Announces the held claim, exactly once however the reveal ends.
func _pay_out() -> void:
	if not _is_payout_pending:
		return
	_is_payout_pending = false
	claimed.emit(_pending_amount, _pending_previous_money)


## The greeting and the streak line spring in as the panel opens; under
## reduce_motion they are simply placed at rest.
func _spring_in_headers() -> void:
	for header: Control in [greeting, streak_row]:
		if GameSettings.reduce_motion:
			header.scale = Vector2.ONE
			header.rotation = 0.0
		else:
			AnimUtils.popup_spring_in(header)


## Draws the strip for streak `day`, dimmed when today's claim is done.
func _show_day(day: int, is_claimed: bool) -> void:
	texture = DAY_PANELS[clampi(day, 1, STREAK_DAYS) - 1]
	claim_button.disabled = is_claimed
	reward_amount.text = AMOUNT_FORMAT % reward_for_day(day)
	# CoinLabel's font colour is already currency_gold, so tinting the same
	# gold here would multiply it darker instead of standing out; leave the
	# amount untinted even on the peak day (the flame still gets the tint).
	reward_amount.modulate = Color.WHITE
	# The art has no separate "claimed" frame, so dim the affordance nodes
	# directly -- restore full modulate once a new day makes the claim
	# available again.
	var cue_alpha: float = CLAIMED_CUE_DIM_ALPHA if is_claimed else 1.0
	for node: CanvasItem in [claim_button, reward_coin, reward_amount]:
		node.modulate.a = cue_alpha
	_show_streak(day)
	_show_teaser(is_claimed)


## Tomorrow's reward, shown only once today is claimed. By then the
## streak day has already advanced, so GameState.daily_login_day is
## tomorrow's day (while the strip shows claimed_day_for of it).
func _show_teaser(is_claimed: bool) -> void:
	besok_teaser.visible = is_claimed
	besok_teaser.text = teaser_text(GameState.daily_login_day)


## The streak line: the day in the 7-day cycle (per the spec, not a
## lifetime count) and a flame that grows with it, gold on the last day.
func _show_streak(day: int) -> void:
	streak_label.text = STREAK_FORMAT % day
	Juice.set_pivot_center(streak_flame)
	var flame_scale: float = flame_scale_for(day)
	streak_flame.scale = Vector2(flame_scale, flame_scale)
	streak_flame.modulate = _peak_tint(day)


## Gold on the last streak day, untinted otherwise.
func _peak_tint(day: int) -> Color:
	return Juice.tokens().currency_gold if day == STREAK_DAYS else Color.WHITE


## The flame's idle flicker: a looped dip of its alpha while the panel is
## open. Off under reduce_motion, and off (with a warning) when
## flame_flicker_seconds is not positive: a zero-length loop never ends.
func _start_flicker() -> void:
	_stop_flicker()
	if GameSettings.reduce_motion:
		return
	if flame_flicker_seconds <= 0.0:
		push_warning("DailyLoginPanel: flame_flicker_seconds must be above 0; the flame will not flicker")
		return
	var half: float = flame_flicker_seconds * 0.5
	_flicker = create_tween().set_loops()
	_flicker.tween_property(streak_flame, "modulate:a", flame_flicker_alpha, half)
	_flicker.tween_property(streak_flame, "modulate:a", 1.0, half)


func _stop_flicker() -> void:
	if _flicker != null:
		_flicker.kill()
	_flicker = null
	streak_flame.modulate.a = 1.0


## While today is unclaimed, the reward row gives a squash bounce every
## idle_invite_seconds. The row, not ButtonClaim: the button draws nothing
## over the baked pill, so bouncing it would move only its "KLAIM" text.
## AnimUtils.wobble is no loop step -- it snaps to scale 0.7 each call.
## Off, with a warning, when idle_invite_seconds is not positive.
func _start_idle_invite() -> void:
	_stop_idle_invite()
	if _is_claimed_today(_today) or GameSettings.reduce_motion:
		return
	if idle_invite_seconds <= 0.0:
		push_warning("DailyLoginPanel: idle_invite_seconds must be above 0; the row will not bounce")
		return
	_invite = create_tween().set_loops()
	_invite.tween_interval(idle_invite_seconds)
	_invite.tween_callback(AnimUtils.squash_bounce.bind(reward_row))


func _stop_idle_invite() -> void:
	if _invite != null:
		_invite.kill()
	_invite = null
