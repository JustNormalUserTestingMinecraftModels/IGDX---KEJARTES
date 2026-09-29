@tool
class_name DapatkanUang
extends Control

## "Dapatkan Uang", the earn-money book the Lobby's coin "+" opens
## (2026-09-27 scrapbook HUD spec §7, Phase 2). Three sections: rewarded
## ads that pay now, "ambil dulu" cash-ins that pay now and run up
## GameState.ad_debt, and a tip card pointing at the free path, Wirausaha.
## Dev mode (no ad SDK yet) pays at once and shows a toast tagged DEV MODE,
## and only in a debug build: an exported release has nothing to offer
## until an SDK lands, so the Lobby keeps its "+" disabled there.
## Calls come down (open, close); `paid` goes up so the Lobby can roll its
## wallet. Like DailyLoginPanel, it owns its own GameState writes. @tool so
## the dapatkan_uang suite can drive it; _ready only wires signals.

## Emitted after a payout lands in GameState.player_money; the Lobby rolls
## its wallet up from previous_money.
signal paid(amount: int, previous_money: int)

## Reward amounts (2026-09-27 spec §7). Balance proposals for the
## Balance.gd owner (docs/superpowers/specs/2026-09-27-earn-money-balance-
## proposal.md); ours until accepted, never written into Balance.gd.
const SHORT_AD_REWARD := 150
const FULL_AD_REWARD := 450
const CASH_IN_SMALL := 900
const CASH_IN_SMALL_ADS := 4
const CASH_IN_LARGE := 2000
const CASH_IN_LARGE_ADS := 8

## Toast copy (spec §7's table). Body font: "—" and "…" are not in Boohong.
const AD_TOAST_FORMAT := "Sukses! Mentransfer +%d koin ke kas kelas…"
const CASH_IN_TOAST_FORMAT := "Sukses! +%d koin — %d iklan menunggu"
const OWED_AD_TOAST := "Sukses menonton iklan!"
## The owed-ad button's label; %d is GameState.ad_debt (Q6). No brackets:
## Boohong draws "(4)" as "C4D".
const OWED_AD_BUTTON_FORMAT := "Tonton %d iklan tertunda"

## Dev mode: every option pays at once and the toast wears the DEV MODE
## tag. A real ad SDK turns it off and pays from its reward callback.
@export var is_dev_mode: bool = true
## Seconds the success toast stays up before it fades.
@export var toast_seconds: float = 2.0

## True while the book springs out: a second tap on the close button or the
## scrim must not replay the sound or restart the tween.
var _closing: bool = false
## Dev-mode payouts need a debug build: a release build must never hand out
## free coins (owner decision, 2026-09-28). A var, not a call site, so the
## suite (always a debug build) can stand in for a release.
var _is_debug_build: bool = OS.is_debug_build()

@onready var scrim: Control = %Scrim
@onready var book: NotebookFrame = %Book
@onready var short_ad_button: Button = %IklanSingkat
@onready var full_ad_button: Button = %VideoPenuh
@onready var cash_in_small_button: Button = %AmbilDulu4
@onready var cash_in_large_button: Button = %AmbilDulu8
@onready var owed_ad_button: Button = %TontonUtang
@onready var toast: Control = %Toast
@onready var toast_label: Label = %ToastLabel
@onready var dev_mode_tag: Control = %DevModeTag


## Signal wiring only, so the suite can press the buttons in the editor.
func _ready() -> void:
	short_ad_button.pressed.connect(_on_short_ad_pressed)
	full_ad_button.pressed.connect(_on_full_ad_pressed)
	cash_in_small_button.pressed.connect(
		_on_cash_in_pressed.bind(CASH_IN_SMALL, CASH_IN_SMALL_ADS))
	cash_in_large_button.pressed.connect(
		_on_cash_in_pressed.bind(CASH_IN_LARGE, CASH_IN_LARGE_ADS))
	owed_ad_button.pressed.connect(_on_owed_ad_pressed)
	book.close_pressed.connect(close)
	scrim.gui_input.connect(_on_scrim_gui_input)


## True when the panel has something to pay: dev mode in a debug build.
## A real ad SDK adds its own readiness here.
func is_available() -> bool:
	return is_dev_mode and _is_debug_build


## Shows the book over a dimmed Lobby, springing in unless reduce_motion.
## Does nothing when no option could pay (a release build, for now).
func open() -> void:
	if visible or not is_available():
		return
	_closing = false
	dev_mode_tag.visible = is_dev_mode
	_refresh_owed_ad()
	scrim.modulate.a = 1.0
	book.scale = Vector2.ONE
	show()
	AudioDirector.play_sfx(&"popup_open")
	if not GameSettings.reduce_motion:
		# book sits inside a CenterContainer; its layout pass resets scale
		# and rotation after this frame, wiping the spring's start pose --
		# defer so the spring starts once that pass has already run.
		# Deferring an instance method (not a bare static call) means a
		# panel closed in its opening frame just drops the call instead of
		# erroring on a stale argument.
		_spring_in.call_deferred()


## Springs the box in once the CenterContainer's first layout pass has run
## (that pass resets scale and rotation). Deferred from open(). Also yields
## to a close already in flight: AnimUtils._safe_tween kills a node's running
## tween, so a spring starting after a close has started would kill the
## spring-out and its hide callback would never run, leaving the panel
## stuck visible.
func _spring_in() -> void:
	if _closing:
		return
	if is_instance_valid(book):
		AnimUtils.popup_spring_in(book)


## Springs the book out and hides the panel; under reduce_motion it hides
## at once.
func close() -> void:
	if not visible or _closing:
		return
	AudioDirector.play_sfx(&"popup_close")
	if GameSettings.reduce_motion:
		hide()
		return
	_closing = true
	AnimUtils.popup_spring_out(book, scrim, hide)


## A tap on the dimmed Lobby around the book closes it, like the daily gift.
func _on_scrim_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) \
			or (touch != null and touch.pressed):
		close()


func _on_short_ad_pressed() -> void:
	_pay(SHORT_AD_REWARD)
	_show_toast(AD_TOAST_FORMAT % SHORT_AD_REWARD)


func _on_full_ad_pressed() -> void:
	_pay(FULL_AD_REWARD)
	_show_toast(AD_TOAST_FORMAT % FULL_AD_REWARD)


## "Ambil dulu": pays `amount` now and owes `ads` ads for later.
func _on_cash_in_pressed(amount: int, ads: int) -> void:
	GameState.ad_debt += ads
	_pay(amount)
	_refresh_owed_ad()
	_show_toast(CASH_IN_TOAST_FORMAT % [amount, ads])


## One owed ad watched: the debt drops by one. Nothing owed, nothing to do.
func _on_owed_ad_pressed() -> void:
	if GameState.ad_debt <= 0:
		return
	GameState.ad_debt -= 1
	_refresh_owed_ad()
	_show_toast(OWED_AD_TOAST)


## Pays `amount` into the class fund and announces it for the Lobby's
## wallet roll. Dev mode pays at once; a real ad SDK would call this from
## its reward callback instead, and nothing else would change.
func _pay(amount: int) -> void:
	var previous_money: int = GameState.player_money
	GameState.player_money += amount
	paid.emit(amount, previous_money)


## The owed-ad button shows only while ads are owed, with the count (Q6).
func _refresh_owed_ad() -> void:
	var owed: int = GameState.ad_debt
	owed_ad_button.visible = owed > 0
	owed_ad_button.text = OWED_AD_BUTTON_FORMAT % owed


## Pops the success toast for toast_seconds, tagged DEV MODE in dev mode.
func _show_toast(text: String) -> void:
	toast_label.text = text
	dev_mode_tag.visible = is_dev_mode
	toast.show()
	AnimUtils.message_pop(toast, toast_seconds)
