@tool
extends Node

## Global audio. Autoloaded as `AudioDirector` from
## Scenes/Audio/audio_director.tscn so every stream slot is assignable
## in the inspector — drop an .ogg on a slot, no code changes.
##
## Every slot may be null. Nothing here crashes on a null stream; it
## simply plays nothing. That is deliberate: the project ships with
## empty slots and the user fills them in over time.

const SFX_POOL_SIZE := 12
const SETTINGS_PATH := "user://audio.cfg"

@export_group("SFX")
## `play_sfx(&"tap")`: generic button/tile taps across most screens
## (cutscene advance, inventory slots, koperasi shelf, lobby, main menu).
@export var sfx_tap: AudioStream
## `play_sfx(&"confirm")`: an affirmative action lands (schedule confirm,
## inventory use-item, main menu accept, event/result confirm buttons).
@export var sfx_confirm: AudioStream
## `play_sfx(&"cancel")`: a dialog is dismissed without confirming (main
## menu back, settings, event-select cancel, SchoolDay's skip cancel).
@export var sfx_cancel: AudioStream
## `play_sfx(&"success")`: DaySummaryPopup's win state.
@export var sfx_success: AudioStream
## `play_sfx(&"fail")`: AturJadwal validation failure and
## DaySummaryPopup's loss state.
@export var sfx_fail: AudioStream
## `play_sfx(&"coin")`: a purchase completes (koperasi) or money is
## earned (lobby, SchoolDay's Wirausaha payout).
@export var sfx_coin: AudioStream = preload("res://Assets/Audio/SFX/earnMoney.ogg")
## `play_sfx(&"whoosh")`: a panel slides/closes (inventory, koperasi's
## blur/popup layer) and every Transition.gd scene change.
@export var sfx_whoosh: AudioStream
## `play_sfx(&"pop")`: a small UI element appears (koperasi's basket
## item landing, the settings overlay).
@export var sfx_pop: AudioStream
## `play_sfx(&"swipe")`: paging through report_card/student_card.
@export var sfx_swipe: AudioStream
## `play_sfx(&"stamp")`: student_card's approve-stamp animation.
@export var sfx_stamp: AudioStream
## `play_sfx(&"unstamp")`: student_card's un-approve (erase-stamp)
## animation.
@export var sfx_unstamp: AudioStream
## `play_sfx(&"popup_open")`: a modal opens (atur_jadwal, inventory,
## koperasi, lobby, DailyDecayOverview and most other popups).
@export var sfx_popup_open: AudioStream
## `play_sfx(&"popup_close")`: the closing half of sfx_popup_open's list.
@export var sfx_popup_close: AudioStream
## `play_sfx(&"select")`: a list/grid item is chosen (atur_jadwal,
## cutscene choices, inventory, event student picker, student_list).
@export var sfx_select: AudioStream
## `play_sfx(&"error")`: an action is rejected (atur_jadwal, inventory,
## koperasi's insufficient-funds/empty-cart, lobby, student_card).
@export var sfx_error: AudioStream
## `play_sfx(&"reward")`: a reward is granted (StatCheck, lobby,
## SchoolDay).
@export var sfx_reward: AudioStream
## `play_sfx(&"tally")`: a Daily Results stat row's gold chevron pops in
## on a day that gained. Placeholder: aliases SFX/pop.ogg until a real
## tick lands.
@export var sfx_tally: AudioStream = preload("res://Assets/Audio/SFX/pop.ogg")
## `play_sfx(&"sparkle")`: a reward burst or the weekly celebration
## confetti fires.
@export var sfx_sparkle: AudioStream = preload("res://Assets/Audio/SFX/threeStarredPoints.ogg")
## `play_sfx(&"pill_tap")`: tapping a headline pill on ResultCheckup's
## week recap banner. A dedicated copy of SFX/tap.ogg (not a second id
## on the same file) so it can be retuned independently later.
@export var sfx_pill_tap: AudioStream = preload("res://Assets/Audio/SFX/pill_tap.ogg")
## `play_sfx(&"star_earn_1")`: first star of the result card's reveal. The
## three star_earn_* cues are three separate recordings, not one pitched
## three ways -- three rising cues read as a climb, three identical ones
## read as a list.
@export var sfx_star_earn_1: AudioStream = preload("res://Assets/Audio/SFX/oneStar.ogg")
## `play_sfx(&"star_earn_2")`: second star of the reveal.
@export var sfx_star_earn_2: AudioStream = preload("res://Assets/Audio/SFX/twoStar.ogg")
## `play_sfx(&"star_earn_3")`: third star of the reveal, the top rung.
@export var sfx_star_earn_3: AudioStream = preload("res://Assets/Audio/SFX/threeStar.ogg")
## `play_sfx(&"result_fanfare")`: the result card's arrival sting.
@export var sfx_result_fanfare: AudioStream = preload("res://Assets/Audio/SFX/winSuccessful.ogg")
## `play_sfx(&"score_tick")`: one increment of a counting score readout.
## Placeholder: aliases pop.ogg.
@export var sfx_score_tick: AudioStream = preload("res://Assets/Audio/SFX/pop.ogg")
## `play_sfx(&"combo_up")`: an in-run combo stepping up. Placeholder:
## aliases pop.ogg.
@export var sfx_combo_up: AudioStream = preload("res://Assets/Audio/SFX/pop.ogg")
## `play_sfx(&"specialty_match")`: AturJadwal, a day is assigned to the
## selected student's specialty subject. Placeholder: aliases sfx_reward.
@export var sfx_specialty_match: AudioStream
## `play_sfx(&"event_announce")`: the sliding event warning starts its pass
## (EventWarning, before every minigame and random event). Placeholder:
## aliases reward.ogg via a dedicated copy (event_announce.ogg) until a real
## chime lands (landed 2026-09-21: the Drive pack's eventAlert).
@export var sfx_event_announce: AudioStream = preload("res://Assets/Audio/SFX/eventAlert.ogg")
## `play_sfx(&"pill_popup_open")`: WeekRecapPillInfoPopup opens. A
## dedicated copy of SFX/popup_open.ogg.
@export var sfx_pill_popup_open: AudioStream = preload("res://Assets/Audio/SFX/pill_popup_open.ogg")
## `play_sfx(&"pill_popup_close")`: WeekRecapPillInfoPopup closes. A
## dedicated copy of SFX/popup_close.ogg.
@export var sfx_pill_popup_close: AudioStream = preload("res://Assets/Audio/SFX/pill_popup_close.ogg")

# ---------------------------------------- the Drive sound pack, 2026-09-21
# Attribution for every file below is in Assets/Audio/SFX/LICENSES.md.

## `play_sfx(&"school_bell")`: SchoolDay starts a day. Filed under Ambient/
## because that is where the collaborator put it, but it is a one-shot bell
## and its .import must stay loop=false.
@export var sfx_school_bell: AudioStream = preload("res://Assets/Audio/Ambient/Schoolring.ogg")
## `play_sfx(&"stat_up")`: a stat rose on a simulated day.
@export var sfx_stat_up: AudioStream = preload("res://Assets/Audio/SFX/stats-upDing.ogg")
## `play_sfx(&"stat_down")`: a stat fell on a simulated day.
@export var sfx_stat_down: AudioStream = preload("res://Assets/Audio/SFX/stats-downDing.ogg")
## `play_sfx(&"card_flip")`: a StudentCard turns during roster approval.
@export var sfx_card_flip: AudioStream = preload("res://Assets/Audio/SFX/cardFlip.ogg")
## `play_sfx(&"schedule_confirm")`: AturJadwal's week is confirmed.
@export var sfx_schedule_confirm: AudioStream = preload("res://Assets/Audio/SFX/scheduleConfirmChime.ogg")
## `play_sfx(&"timer_tick")`: a minigame's countdown runs low.
@export var sfx_timer_tick: AudioStream = preload("res://Assets/Audio/SFX/minigame/timeTicking.ogg")
## `play_sfx(&"times_up")`: a minigame's timer expires.
@export var sfx_times_up: AudioStream = preload("res://Assets/Audio/SFX/minigame/timesUp.ogg")
## `play_sfx(&"back_tap")`: any screen's back button, and the Android
## hardware back press that now routes to the same handler.
@export var sfx_back_tap: AudioStream = preload("res://Assets/Audio/SFX/BackButtonTap.ogg")
## `play_sfx(&"shop_browse")`: browsing the koperasi shelf.
@export var sfx_shop_browse: AudioStream = preload("res://Assets/Audio/SFX/shopBrowseTap.ogg")
## `play_sfx(&"transaction")`: Beli completes and the cart is paid for.
@export var sfx_transaction: AudioStream = preload("res://Assets/Audio/SFX/transactionShop.ogg")
## `play_sfx(&"item_applied")`: an inventory item lands on a student.
@export var sfx_item_applied: AudioStream = preload("res://Assets/Audio/SFX/itemAfterAppliedEachCharacter.ogg")
## `play_sfx(&"apply")`: a choice is committed on the apply screen.
@export var sfx_apply: AudioStream = preload("res://Assets/Audio/SFX/apply.ogg")
## `play_sfx(&"tutorial_popup")`: a tutorial overlay opens.
@export var sfx_tutorial_popup: AudioStream = preload("res://Assets/Audio/SFX/tutorialPopUp.ogg")
## `play_sfx(&"result_checkup")`: the weekly report opens.
@export var sfx_result_checkup: AudioStream = preload("res://Assets/Audio/SFX/ResultCheckup.ogg")
## `play_sfx(&"daily_claim")`: a daily reward is claimed.
@export var sfx_daily_claim: AudioStream = preload("res://Assets/Audio/SFX/dailyLoginClaim.ogg")

## `play_sfx_variant(&"transition_sweep")`: the scene-change wipe. Three
## variants picked at random, so back-to-back navigation never sounds like
## the same click twice.
@export var sfx_transition_sweep: Array[AudioStream] = [
	preload("res://Assets/Audio/SFX/transitionSweep1.ogg"),
	preload("res://Assets/Audio/SFX/transitionSweep2.ogg"),
	preload("res://Assets/Audio/SFX/transitionSweep3.ogg"),
]
## `play_sfx_variant(&"ball_kick")`: Main Bola's kick. Four variants -- a
## repeated action needs the most spread.
@export var sfx_ball_kick: Array[AudioStream] = [
	preload("res://Assets/Audio/SFX/minigame/ballKick1.ogg"),
	preload("res://Assets/Audio/SFX/minigame/ballKick2.ogg"),
	preload("res://Assets/Audio/SFX/minigame/ballKick3.ogg"),
	preload("res://Assets/Audio/SFX/minigame/ballKick4.ogg"),
]
## `play_sfx_variant(&"racket_hit")`: Badminton's racket. Three variants.
@export var sfx_racket_hit: Array[AudioStream] = [
	preload("res://Assets/Audio/SFX/minigame/racketHit1.ogg"),
	preload("res://Assets/Audio/SFX/minigame/racketHit2.ogg"),
	preload("res://Assets/Audio/SFX/minigame/racketHit3.ogg"),
]
## `play_sfx_variant(&"achievement")`: an achievement unlocks.
@export var sfx_achievement: Array[AudioStream] = [
	preload("res://Assets/Audio/SFX/achievementNotification1.ogg"),
	preload("res://Assets/Audio/SFX/achievementNotification2.ogg"),
	preload("res://Assets/Audio/SFX/achievementNotification3.ogg"),
]
## `play_sfx(&"achievement_prize")`: an achievement that carries a prize.
@export var sfx_achievement_prize: AudioStream = preload("res://Assets/Audio/SFX/achievementNotificationPrize.ogg")
## `play_sfx(&"achievement_success")`: the full-set achievement flourish.
@export var sfx_achievement_success: AudioStream = preload("res://Assets/Audio/SFX/notificationAchievementSuccess.ogg")

## EndCutscene's badge reveal, one cue per grade band. A tier, not one sound:
## the badge word is the payoff of a whole grade, and a single sting would
## flatten "Disaster" and "Amazing" into the same moment. Read through
## badge_reveal_stream(), never directly.
@export var sfx_badge_reveal_amazing: AudioStream = preload("res://Assets/Audio/SFX/badgeRevealAmazing.ogg")
## Band "Good".
@export var sfx_badge_reveal_good: AudioStream = preload("res://Assets/Audio/SFX/badgeRevealGood.ogg")
## Band "Normal", and the fallback for an unknown band.
@export var sfx_badge_reveal_normal: AudioStream = preload("res://Assets/Audio/SFX/badgeRevealNormal.ogg")
## Band "Bad".
@export var sfx_badge_reveal_bad: AudioStream = preload("res://Assets/Audio/SFX/badgeRevealBad.ogg")
## Band "Disaster".
@export var sfx_badge_reveal_disaster: AudioStream = preload("res://Assets/Audio/SFX/badgeRevealDisaster.ogg")

@export_group("Ambience")
## `play_ambience(&"classroom_1")`: classroom murmur under a simulated day.
@export var amb_classroom_1: AudioStream = preload("res://Assets/Audio/Ambient/classroomAmbient1.ogg")
## Second classroom bed. Two, not the pack's three: classroomAmbient3.ogg
## arrived corrupt -- a 4 KB stub whose Vorbis identification header declares
## zero channels. Godot loads it but logs OV_EBADHEADER, which fails CI's
## error scan, so the file is out until it is re-exported at source. See
## DEBT.md.
@export var amb_classroom_2: AudioStream = preload("res://Assets/Audio/Ambient/classroomAmbient2.ogg")
## `play_ambience(&"thunderstorm")`: the Hujan random event.
@export var amb_thunderstorm: AudioStream = preload("res://Assets/Audio/Ambient/thunderstorm1.ogg")
## `play_ambience(&"writing")`: pencils and paper under an academic day.
@export var amb_writing: AudioStream = preload("res://Assets/Audio/Ambient/writing.ogg")
## Outdoor schoolyard bed.
@export var amb_schoolyard_1: AudioStream = preload("res://Assets/Audio/Ambient/schoolsimulation1.ogg")
## Second schoolyard bed.
@export var amb_schoolyard_2: AudioStream = preload("res://Assets/Audio/Ambient/schoolsimulation2.ogg")

@export_group("BGM")
## `play_bgm(&"titlescreen")`: Splashscreen/MainMenu.
@export var bgm_titlescreen: AudioStream
## `play_bgm(&"introcutscene")`: the opening CutScene.
@export var bgm_introcutscene: AudioStream
## `play_bgm_playlist(&"lobby")`: the Lobby hub, shuffled track-to-track
## via `_on_bgm_finished` -- never a single fixed track.
@export var bgm_lobby_playlist: Array[AudioStream] = []
## `play_bgm(&"simulation")`: SchoolDay's day-simulation screen, paused
## (not stopped) via pause_bgm() whenever a minigame or event interrupts it.
@export var bgm_simulation: AudioStream
## `play_bgm(&"result_win")`: DaySummaryPopup/ResultCheckup's win state.
@export var bgm_result_win: AudioStream
## `play_bgm(&"result_lose")`: DaySummaryPopup/ResultCheckup's loss state.
@export var bgm_result_lose: AudioStream
## `play_bgm(&"exam_notice")`: the Tes Besar announcement screen.
@export var bgm_exam_notice: AudioStream = preload("res://Assets/Audio/BGM/schoolsimulation.mp3")
## `play_bgm(&"run_result")`: the end-of-grade run report.
@export var bgm_run_result: AudioStream = preload("res://Assets/Audio/BGM/result_win.mp3")

@export_group("Minigame BGM")
## `play_minigame_bgm(&"minigame_olahraga")`: Badminton and MainBola.
@export var bgm_minigame_olahraga: AudioStream
## `play_minigame_bgm(&"minigame_senibudaya_batik")`: BuatBatik.
@export var bgm_minigame_senibudaya_batik: AudioStream
## `play_minigame_bgm(&"minigame_senibudaya_menari")`: LombaMenari.
@export var bgm_minigame_senibudaya_menari: AudioStream
## `play_minigame_bgm(&"minigame_akademis")`: Menjodohkan, Password,
## PilihanGanda and Variabel. Not a single track -- loops through this
## array in sequence via `_on_minigame_bgm_finished`, one entry per
## Akademis minigame's natural end, instead of crossfading.
@export var bgm_minigame_akademis: Array[AudioStream] = []

@export_group("Mixing")
## Default crossfade for play_bgm/stop_bgm when no explicit fade is given.
@export var default_bgm_fade: float = 0.8
## Random pitch spread on each SFX so repeated taps do not sound robotic.
@export_range(0.0, 0.3) var sfx_pitch_variance: float = 0.06
## Fade for pausing/resuming bgm_simulation around a minigame, and for
## minigame music itself. Deliberately quicker than default_bgm_fade so
## ducking for a minigame doesn't feel sluggish.
@export var minigame_bgm_fade: float = 0.4

var _sfx_pool: Array[AudioStreamPlayer] = []
## The single looping ambience voice. On the SFX bus -- see play_ambience().
var _ambience: AudioStreamPlayer
var _sfx_next: int = 0
var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _bgm_active: AudioStreamPlayer
var _bgm_current_id: StringName = &""
var _bgm_tween: Tween
var _bgm_minigame: AudioStreamPlayer
var _akademis_sequence_index: int = 0
var _bgm_minigame_id: StringName = &""
var _bgm_playlist_id: StringName = &""
var _save_timer: SceneTreeTimer
var _save_count: int = 0
var _setup_ran: bool = false


func _ready() -> void:
	# @tool makes this script a "real" instance (not a placeholder) when the
	# in-editor test runner instantiates audio_director.tscn programmatically
	# and parents it under Engine.get_main_loop().root — that path must keep
	# running full setup so tests can exercise it.
	#
	# But @tool ALSO means _ready() fires for real when a human just opens
	# Scenes/Audio/audio_director.tscn in the editor (e.g. to drag an .ogg
	# onto a slot, per Assets/Audio/README.md). In that case this node IS
	# (or is inside) the editor's edited-scene tree, and running setup would
	# spawn live AudioStreamPlayers in the editor and let _load_volumes()/
	# _save_volumes() read and overwrite the real user://audio.cfg just from
	# having the scene open. Skip setup only for that case.
	if Engine.is_editor_hint():
		var tree := get_tree()
		var edited_root: Node = tree.edited_scene_root if tree else null
		if edited_root != null and (self == edited_root or edited_root.is_ancestor_of(self)):
			return

	_setup_ran = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)

	# One looping ambience voice, on the SFX bus. See play_ambience() for why
	# this is not a third bus.
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = &"SFX"
	add_child(_ambience)

	_bgm_a = _make_bgm_player()
	_bgm_b = _make_bgm_player()
	_bgm_a.finished.connect(_on_bgm_finished.bind(_bgm_a))
	_bgm_b.finished.connect(_on_bgm_finished.bind(_bgm_b))
	_bgm_active = _bgm_a
	_bgm_minigame = _make_bgm_player()
	_bgm_minigame.finished.connect(_on_minigame_bgm_finished)

	_load_volumes()


func _make_bgm_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"BGM"
	add_child(p)
	return p


# -------------------------------------------------------------------- sfx

## Play one sfx cue. `pitch` scales the voice on top of the usual random
## spread: 1.0, every call's default, leaves it exactly as before; the
## weekly report's reveal climbs it one step per pop.
func play_sfx(id: StringName, pitch: float = 1.0) -> void:
	var stream := _resolve_sfx(id)
	if stream == null:
		return
	var player := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	player.stream = stream
	player.pitch_scale = pitch * (1.0 + randf_range(-sfx_pitch_variance, sfx_pitch_variance))
	player.play()


func _resolve_sfx(id: StringName) -> AudioStream:
	match id:
		&"tap": return sfx_tap
		&"confirm": return sfx_confirm
		&"cancel": return sfx_cancel
		&"success": return sfx_success
		&"fail": return sfx_fail
		&"coin": return sfx_coin
		&"whoosh": return sfx_whoosh
		&"pop": return sfx_pop
		&"swipe": return sfx_swipe
		&"stamp": return sfx_stamp
		&"unstamp": return sfx_unstamp
		&"popup_open": return sfx_popup_open
		&"popup_close": return sfx_popup_close
		&"select": return sfx_select
		&"error": return sfx_error
		&"reward": return sfx_reward
		&"tally": return sfx_tally
		&"sparkle": return sfx_sparkle
		&"pill_tap": return sfx_pill_tap
		&"pill_popup_open": return sfx_pill_popup_open
		&"pill_popup_close": return sfx_pill_popup_close
		&"star_earn_1": return sfx_star_earn_1
		&"star_earn_2": return sfx_star_earn_2
		&"star_earn_3": return sfx_star_earn_3
		&"result_fanfare": return sfx_result_fanfare
		&"score_tick": return sfx_score_tick
		&"combo_up": return sfx_combo_up
		&"specialty_match": return sfx_specialty_match
		&"event_announce": return sfx_event_announce
		&"school_bell": return sfx_school_bell
		&"stat_up": return sfx_stat_up
		&"stat_down": return sfx_stat_down
		&"card_flip": return sfx_card_flip
		&"schedule_confirm": return sfx_schedule_confirm
		&"timer_tick": return sfx_timer_tick
		&"times_up": return sfx_times_up
		&"back_tap": return sfx_back_tap
		&"shop_browse": return sfx_shop_browse
		&"transaction": return sfx_transaction
		&"item_applied": return sfx_item_applied
		&"apply": return sfx_apply
		&"tutorial_popup": return sfx_tutorial_popup
		&"result_checkup": return sfx_result_checkup
		&"daily_claim": return sfx_daily_claim
		&"achievement_prize": return sfx_achievement_prize
		&"achievement_success": return sfx_achievement_success
		_: return null


## Plays one stream at random from a variant family -- sfx_ball_kick and
## friends. A four-variant family on a repeated action is the difference
## between a game that sounds alive and one that sounds like a metronome.
##
## An unknown or empty family is a no-op, matching play_sfx's null-safety:
## a missing sound must never be the thing that stops a minigame.
func play_sfx_variant(family: StringName, pitch: float = 1.0) -> void:
	var variants: Variant = get("sfx_%s" % family)
	if not (variants is Array) or (variants as Array).is_empty():
		return
	var list: Array = variants
	var stream: AudioStream = list[randi() % list.size()]
	if stream == null:
		return
	var player := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	player.stream = stream
	player.pitch_scale = pitch * (1.0 + randf_range(-sfx_pitch_variance, sfx_pitch_variance))
	player.play()


## The badge cue for a grade band. An unknown band falls back to Normal
## rather than returning null into a player -- a silent badge reveal is a
## worse bug than a slightly wrong one.
func badge_reveal_stream(band: String) -> AudioStream:
	match band:
		"Amazing": return sfx_badge_reveal_amazing
		"Good": return sfx_badge_reveal_good
		"Bad": return sfx_badge_reveal_bad
		"Disaster": return sfx_badge_reveal_disaster
		_: return sfx_badge_reveal_normal


## Starts the looping ambience bed `id` -- the amb_* slot name without its
## prefix -- replacing whatever was playing. Re-calling it with the bed
## already playing is a no-op, so a screen may call it every frame safely.
##
## On the SFX bus rather than a bus of its own: default_bus_layout.tres is
## rewritten on boot, and a third bus would need a third settings slider to
## be honest about. Ambience following the SFX slider is what a player
## expects from a control labelled "sound effects".
func play_ambience(id: StringName) -> void:
	if _ambience == null:
		return
	var stream: Variant = get("amb_%s" % id)
	if not (stream is AudioStream):
		return
	if _ambience.stream == stream and _ambience.playing:
		return
	_ambience.stream = stream
	_ambience.play()


## Stops the ambience bed. Safe to call when nothing is playing.
func stop_ambience() -> void:
	if _ambience != null:
		_ambience.stop()


## The ambience voice. Exists so tests need not know the node layout.
func get_ambience_player() -> AudioStreamPlayer:
	return _ambience


## True only when `id` maps to a slot AND that slot holds a stream.
## Screens never need this — play_sfx is already null-safe — but tests
## and the audio-coverage suite use it to prove a slot got filled.
func has_sfx(id: StringName) -> bool:
	return _resolve_sfx(id) != null


# -------------------------------------------------------------------- bgm

func play_bgm(id: StringName, fade: float = -1.0) -> void:
	if id == _bgm_current_id and _bgm_active.playing:
		return
	var stream := _resolve_bgm(id)
	if stream == null:
		_bgm_current_id = id
		return

	var duration := default_bgm_fade if fade < 0.0 else fade
	var incoming := _bgm_b if _bgm_active == _bgm_a else _bgm_a
	var outgoing := _bgm_active

	incoming.stream = stream
	incoming.stream_paused = false
	incoming.volume_db = -60.0
	incoming.play()

	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween().set_parallel(true)
	_bgm_tween.tween_property(incoming, "volume_db", 0.0, duration)
	_bgm_tween.tween_property(outgoing, "volume_db", -60.0, duration)
	_bgm_tween.chain().tween_callback(outgoing.stop)

	_bgm_active = incoming
	_bgm_current_id = id


## Like play_bgm, but for an array-backed id: starts on a random track,
## and (via _on_bgm_finished) keeps shuffling to a new track --
## excluding whichever just played -- indefinitely.
func play_bgm_playlist(id: StringName, fade: float = -1.0) -> void:
	var tracks := _resolve_playlist(id)
	if tracks.is_empty():
		_bgm_playlist_id = id
		_bgm_current_id = id
		return
	if id == _bgm_current_id and _bgm_active.playing:
		return

	var duration := default_bgm_fade if fade < 0.0 else fade
	var incoming := _bgm_b if _bgm_active == _bgm_a else _bgm_a
	var outgoing := _bgm_active

	incoming.stream = tracks[randi() % tracks.size()]
	incoming.stream_paused = false
	incoming.volume_db = -60.0
	incoming.play()

	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween().set_parallel(true)
	_bgm_tween.tween_property(incoming, "volume_db", 0.0, duration)
	_bgm_tween.tween_property(outgoing, "volume_db", -60.0, duration)
	_bgm_tween.chain().tween_callback(outgoing.stop)

	_bgm_active = incoming
	_bgm_current_id = id
	_bgm_playlist_id = id


func _resolve_playlist(id: StringName) -> Array[AudioStream]:
	match id:
		&"lobby": return bgm_lobby_playlist
		_: return []


## Uniform random pick over every index except `exclude`. count <= 1
## always returns 0 (nothing else to pick).
func _pick_playlist_index(exclude: int, count: int) -> int:
	if count <= 1:
		return 0
	var idx := randi_range(0, count - 2)
	if idx >= exclude:
		idx += 1
	return idx


## Fires whenever _bgm_a or _bgm_b's current track ends naturally.
## Only playlist mode reacts -- every other bgm id loops forever via
## its own import setting and never reaches here. Guarded against
## firing for a player that is no longer the active one (e.g. the
## scene moved on to a different bgm context between when this track
## started and when it naturally ended).
func _on_bgm_finished(player: AudioStreamPlayer) -> void:
	if player != _bgm_active:
		return
	if _bgm_playlist_id == &"" or _bgm_current_id != _bgm_playlist_id:
		return
	var tracks := _resolve_playlist(_bgm_playlist_id)
	if tracks.is_empty():
		return
	var previous_index := tracks.find(player.stream)
	var next_index := _pick_playlist_index(maxi(previous_index, 0), tracks.size())
	player.stream = tracks[next_index]
	player.play()


func stop_bgm(fade: float = -1.0) -> void:
	var duration := default_bgm_fade if fade < 0.0 else fade
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_active, "volume_db", -60.0, duration)
	_bgm_tween.tween_callback(_bgm_active.stop)
	_bgm_current_id = &""


## Fades the currently-playing bgm to silence and pauses it IN PLACE --
## unlike stop_bgm, playback position is preserved. Used around a
## minigame interruption, where the school-day music must pick back up
## exactly where it left off rather than restarting. Safe no-op if
## nothing is currently playing.
func pause_bgm(fade: float = -1.0) -> void:
	if _bgm_active == null or not _bgm_active.playing:
		return
	var duration := minigame_bgm_fade if fade < 0.0 else fade
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_active, "volume_db", -60.0, duration)
	_bgm_tween.tween_callback(func() -> void: _bgm_active.stream_paused = true)


## Reverses pause_bgm: unpauses in place and fades back up. Safe no-op
## if nothing is paused.
func resume_bgm(fade: float = -1.0) -> void:
	if _bgm_active == null or not _bgm_active.stream_paused:
		return
	_bgm_active.stream_paused = false
	var duration := minigame_bgm_fade if fade < 0.0 else fade
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_active, "volume_db", 0.0, duration)


# --------------------------------------------------------------- minigame bgm

## Single entry point for all minigame music. Always plays on the
## dedicated _bgm_minigame player (never the main A/B pair), always
## starting fresh from silence -- minigames never overlap, so there is
## no crossfade-between-minigame-tracks case to handle.
##
## &"minigame_akademis" is handled by Task 4's extension to this
## function (a looping 3-track sequence); the ids here are single,
## already-looping tracks.
func play_minigame_bgm(id: StringName) -> void:
	_bgm_minigame_id = id
	if id == &"minigame_akademis":
		if bgm_minigame_akademis.is_empty():
			return
		_akademis_sequence_index = 0
		_bgm_minigame.stream = bgm_minigame_akademis[0]
		_bgm_minigame.volume_db = -60.0
		_bgm_minigame.play()
		var tw := create_tween()
		tw.tween_property(_bgm_minigame, "volume_db", 0.0, minigame_bgm_fade)
		return

	var stream := _resolve_minigame_bgm(id)
	if stream == null:
		return
	_bgm_minigame.stream = stream
	_bgm_minigame.volume_db = -60.0
	_bgm_minigame.play()
	var tw := create_tween()
	tw.tween_property(_bgm_minigame, "volume_db", 0.0, minigame_bgm_fade)


func _resolve_minigame_bgm(id: StringName) -> AudioStream:
	match id:
		&"minigame_olahraga": return bgm_minigame_olahraga
		&"minigame_senibudaya_batik": return bgm_minigame_senibudaya_batik
		&"minigame_senibudaya_menari": return bgm_minigame_senibudaya_menari
		_: return null


## Fades out and stops the minigame player. Unlike pause_bgm, position
## does not need to be preserved here -- a minigame always starts its
## music fresh next time, never resumes a previous minigame's track.
func stop_minigame_bgm(fade: float = -1.0) -> void:
	if not _bgm_minigame.playing:
		return
	var duration := minigame_bgm_fade if fade < 0.0 else fade
	var tw := create_tween()
	tw.tween_property(_bgm_minigame, "volume_db", -60.0, duration)
	tw.tween_callback(_bgm_minigame.stop)


## Fires whenever _bgm_minigame's current track ends naturally (i.e.
## the track's loop is disabled -- see bgm_minigame_akademis' import
## settings). Only the Akademis sequence reacts to this; every other
## minigame track loops forever via its own import setting and never
## reaches here.
func _on_minigame_bgm_finished() -> void:
	if _bgm_minigame_id != &"minigame_akademis":
		return
	if bgm_minigame_akademis.is_empty():
		return
	_akademis_sequence_index = (_akademis_sequence_index + 1) % bgm_minigame_akademis.size()
	_bgm_minigame.stream = bgm_minigame_akademis[_akademis_sequence_index]
	_bgm_minigame.play()


func _resolve_bgm(id: StringName) -> AudioStream:
	match id:
		&"titlescreen": return bgm_titlescreen
		&"introcutscene": return bgm_introcutscene
		&"simulation": return bgm_simulation
		&"result_win": return bgm_result_win
		&"result_lose": return bgm_result_lose
		&"exam_notice": return bgm_exam_notice
		&"run_result": return bgm_run_result
		_: return null


# ------------------------------------------------------------------ mixing

## Set a bus volume as a 0.0-1.0 linear value. Clamped. Persisted.
func set_bus_volume(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		push_warning("AudioDirector: unknown bus " + String(bus))
		return
	var v := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(v))
	# linear_to_db(0.0) is -inf, which AudioServer stores but which reads
	# back as -inf; mute the bus instead so get_bus_volume returns 0.0.
	AudioServer.set_bus_mute(idx, is_zero_approx(v))
	_schedule_volume_save()


func get_bus_volume(bus: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return 0.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(idx)), 0.0, 1.0)


func _save_volumes() -> void:
	_save_count += 1
	var cfg := ConfigFile.new()
	for bus in ["Master", "BGM", "SFX"]:
		cfg.set_value("volume", bus, get_bus_volume(bus))
	cfg.save(SETTINGS_PATH)


## Coalesce a burst of slider changes into one disk write. Dragging a
## slider fires value_changed per pixel; writing user://audio.cfg that
## often stutters on mobile storage.
func _schedule_volume_save() -> void:
	if _save_timer != null:
		return
	# _schedule_volume_save is only reached via set_bus_volume, and
	# _load_volumes() (the only caller before user interaction) runs from
	# _ready() once this node is already inside the tree, so get_tree()
	# is always valid here.
	var tree := get_tree()
	_save_timer = tree.create_timer(0.4, true, false, true)
	_save_timer.timeout.connect(func() -> void:
		_save_timer = null
		_save_volumes())


## Write any pending volume change immediately. Called on quit and by
## tests that need the file on disk before reading it back.
func flush_volume_save() -> void:
	_save_timer = null
	_save_volumes()


## Number of times the config has actually been written. Test hook.
func get_volume_save_count() -> int:
	return _save_count


## True while a debounced volume save is still scheduled. Test hook: lets a
## non-coroutine test prove the write was queued rather than silently dropped,
## without waiting out the 0.4s debounce window.
func has_pending_volume_save() -> bool:
	return _save_timer != null


func _notification(what: int) -> void:
	# Guard mirrors _ready(): if setup never ran (this instance is merely
	# sitting in an edited scene in the editor), there is nothing pending
	# to flush and doing so would read/write the real user://audio.cfg
	# just from the scene being open, e.g. on an editor focus-loss pause.
	if not _setup_ran:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush_volume_save()


func _load_volumes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus in ["Master", "BGM", "SFX"]:
		set_bus_volume(bus, cfg.get_value("volume", bus, 1.0))
