@tool
class_name DailyLoginPanel
extends TextureRect

## The Lobby's daily-login popup: the seven-day calendar strip, its claim
## button and the reward it pays. Owns the streak rules (a missed day
## resets to day 1; a claim advances the day, wrapping 7 to 1) and writes
## GameState.player_money, daily_login_day and last_claim_date. It never
## reaches up: it announces a payout with `claimed`, and the Lobby rolls
## its wallet and fires RewardFeedback. The Lobby owns the backdrop blur
## and calls open() / close() / refresh() down.
##
## @tool so the editor's test runner can call claim() and the static
## rules. Every runtime side effect is gated behind
## Engine.is_editor_hint(): a @tool node that swaps its own texture or
## modulate in the editor gets that baked into Lobby.tscn on save.

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

## The popup's close: how long it fades and shrinks, and to what scale.
const CLOSE_SECONDS := 0.15
const CLOSE_SCALE := Vector2(0.8, 0.8)

@onready var claim_button: Button = %ButtonClaim
@onready var reward_coin: TextureRect = %RewardCoin
@onready var reward_amount: Label = %RewardAmount


func _ready() -> void:
	assert(REWARD_CURVE.size() == STREAK_DAYS, "REWARD_CURVE needs one reward per streak day")
	if Engine.is_editor_hint():
		return
	claim_button.pressed.connect(_on_claim_pressed)


## Resets a broken streak and redraws the strip for `today` (YYYY-MM-DD).
func refresh(today: String) -> void:
	if is_streak_broken(GameState.last_claim_date, today):
		# lewat lebih dari 1 hari tanpa klaim, streak reset ke Day1
		GameState.daily_login_day = 1
	_show_day(GameState.daily_login_day, GameState.last_claim_date == today)


## Pops the whole panel in -- the art bakes all seven slots, so there are
## no separate tiles left to stagger in behind it.
func open() -> void:
	visible = true
	Juice.pop_in(self)


## Fades and shrinks the panel out, then hides it.
func close() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, CLOSE_SECONDS).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", CLOSE_SCALE, CLOSE_SECONDS).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(hide)


## Pays today's reward into GameState and advances the streak. Returns
## the amount paid, or 0 when `today` was already claimed.
func claim(today: String) -> int:
	if GameState.last_claim_date == today:
		return 0
	var amount: int = reward_for_day(GameState.daily_login_day)
	GameState.player_money += amount
	GameState.last_claim_date = today
	GameState.daily_login_day = day_after(GameState.daily_login_day)
	return amount


## The reward for streak `day`, clamped into 1..STREAK_DAYS.
static func reward_for_day(day: int) -> int:
	return REWARD_CURVE[clampi(day, 1, STREAK_DAYS) - 1]


## The streak day after `day`; the last day wraps to day 1.
static func day_after(day: int) -> int:
	return day % STREAK_DAYS + 1


## True when more than one day has passed since `last_claim_date`. Never
## broken before the first claim, nor on the day of a claim.
static func is_streak_broken(last_claim_date: String, today: String) -> bool:
	if last_claim_date == "" or last_claim_date == today:
		return false
	var today_unix: int = Time.get_unix_time_from_datetime_string(today + MIDNIGHT_SUFFIX)
	var last_unix: int = Time.get_unix_time_from_datetime_string(last_claim_date + MIDNIGHT_SUFFIX)
	return today_unix - last_unix > SECONDS_PER_DAY


func _on_claim_pressed() -> void:
	AnimUtils.squash_bounce(claim_button)
	var today: String = Time.get_date_string_from_system()
	if GameState.last_claim_date == today:
		AudioDirector.play_sfx(&"error")
		return
	AudioDirector.play_sfx(&"daily_claim")
	var claimed_day: int = GameState.daily_login_day
	var previous_money: int = GameState.player_money
	var amount: int = claim(today)
	_show_day(claimed_day, true)
	Juice.count_up(reward_amount, 0.0, float(amount), AMOUNT_FORMAT)
	# The tiles are gone -- the panel itself is what pops now.
	Juice.pop_in(self)
	claimed.emit(amount, previous_money)


## Draws the strip for streak `day`, dimmed when today's claim is done.
func _show_day(day: int, is_claimed: bool) -> void:
	texture = DAY_PANELS[clampi(day, 1, STREAK_DAYS) - 1]
	claim_button.disabled = is_claimed
	reward_amount.text = AMOUNT_FORMAT % reward_for_day(day)
	# The art has no separate "claimed" frame, so dim the affordance nodes
	# directly -- restore full modulate once a new day makes the claim
	# available again.
	var cue_alpha: float = CLAIMED_CUE_DIM_ALPHA if is_claimed else 1.0
	for node: CanvasItem in [claim_button, reward_coin, reward_amount]:
		node.modulate.a = cue_alpha
