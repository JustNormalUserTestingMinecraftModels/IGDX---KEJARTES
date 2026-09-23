@tool
extends Node

## Reward feedback orchestrator (2026-09-23 spec). Screens call a single
## play(moment, anchor, opts); this fires the four channels -- layered sound,
## a particle burst, a haptic beat, and screenshake -- so no screen wires them
## by hand. It owns no visuals: sound goes through AudioDirector, particles
## through the existing RewardBurst/CelebrationConfetti scenes, shake through
## Juice, haptics through Haptics. Every moment maps to one of three "weight"
## tiers so the whole game speaks one feedback language.

const TIER_TICK := 0
const TIER_POP := 1
const TIER_CELEBRATION := 2

## Haptic duration per tier, ms. Named tunables of ours (CLAUDE.md rule).
const HAPTIC_MS := { TIER_TICK: 8, TIER_POP: 20, TIER_CELEBRATION: 50 }
## Screenshake strength per tier. Tick never shakes; Pop nudges the anchor;
## Celebration shakes the screen root.
const SHAKE_STRENGTH := { TIER_TICK: 0.0, TIER_POP: 4.0, TIER_CELEBRATION: 14.0 }
## Pitch climb per escalation step (stars, combo) for Pop-tier cues.
const PITCH_STEP := 0.09
## Coin arpeggio: how many pings and their spacing.
const ARPEGGIO_COUNT := 3
const ARPEGGIO_GAP := 0.06

## Queued cues (the result screens' per-row stat pings) play one at a time
## this far apart, so a report's many staggered rows chime in a patient
## sequence instead of slapping together. Each successive cue in an unbroken
## run climbs QUEUE_PITCH_STEP higher (capped at QUEUE_PITCH_MAX), turning the
## run into a rising ladder; the climb resets whenever the queue drains.
const QUEUE_GAP := 0.13
const QUEUE_PITCH_STEP := 0.03
const QUEUE_PITCH_MAX := 1.6

## Serial cue queue state (runtime only; never touched under editor hint).
var _cue_queue: Array = []
var _cue_pump_running := false
var _cue_rung := 0

## Particle scenes, by role.
const POP_BURST := "res://Scenes/SchoolSimulation/RewardBurst.tscn"
const CELEBRATION_CONFETTI := "res://Scenes/SchoolSimulation/CelebrationConfetti.tscn"

## moment -> { tier, sfx, particle?, escalates?, dynamic_sfx? }. The single
## readable home of the reward vocabulary; the debug gallery enumerates it.
const RECIPES := {
	&"stat_gain":        { "tier": TIER_TICK, "sfx": &"stat_up" },
	&"stat_loss":        { "tier": TIER_TICK, "sfx": &"stat_down" },
	&"score_tick":       { "tier": TIER_TICK, "sfx": &"score_tick", "escalates": true },
	&"coins_earned":     { "tier": TIER_POP, "sfx": &"coin", "arpeggio": true },
	&"star_earned":      { "tier": TIER_POP, "sfx": &"star_earn_1", "dynamic_sfx": true, "no_particles": true },
	&"schedule_confirmed": { "tier": TIER_POP, "sfx": &"schedule_confirm" },
	# DayStickyNote.play_specialty_match() already fires the gold burst, so
	# RewardFeedback adds only sound + haptic + shake here (no_particles).
	&"specialty_match":  { "tier": TIER_POP, "sfx": &"specialty_match", "no_particles": true },
	&"item_applied":     { "tier": TIER_POP, "sfx": &"item_applied" },
	&"minigame_combo":   { "tier": TIER_POP, "sfx": &"combo_up", "escalates": true },
	&"minigame_win":     { "tier": TIER_CELEBRATION, "sfx": &"result_fanfare", "chord": [&"result_fanfare", &"reward"], "no_particles": true },
	&"achievement_unlocked": { "tier": TIER_POP, "sfx": &"achievement_success" },
	&"achievement_claimed":  { "tier": TIER_CELEBRATION, "sfx": &"achievement_prize", "chord": [&"achievement_prize", &"reward"], "no_particles": true },
	&"week_cleared":     { "tier": TIER_CELEBRATION, "sfx": &"reward", "chord": [&"reward", &"sparkle"] },
	&"run_win":          { "tier": TIER_CELEBRATION, "sfx": &"result_fanfare", "chord": [&"result_fanfare", &"reward"] },
	# badge_reveal: EndCutscene already plays the band cue via
	# badge_reveal_stream(); RewardFeedback adds only the physical channels.
	&"badge_reveal":     { "tier": TIER_POP, "sfx": &"" },
}

## Resolve the effective tier for a call, honouring per-moment escalation.
func moment_tier(moment: StringName, opts: Dictionary = {}) -> int:
	var recipe: Dictionary = RECIPES.get(moment, {})
	var base: int = recipe.get("tier", TIER_POP)
	if moment == &"star_earned" and int(opts.get("step", 1)) >= 3:
		return TIER_CELEBRATION
	if moment == &"badge_reveal":
		var band := String(opts.get("band", "Normal"))
		return TIER_CELEBRATION if band in ["Amazing", "Good"] else TIER_POP
	return base

## Fire the full multi-sensory combo for `moment`. Pass opts["queued"] = true
## (the result screens do, for their per-row stat cues) to route the cue
## through the serial queue instead of firing it now, so a burst of cues
## paces itself out rather than slapping together.
func play(moment: StringName, anchor: Node = null, opts: Dictionary = {}) -> void:
	if Engine.is_editor_hint():
		return
	if not RECIPES.has(moment):
		return
	if opts.get("queued", false):
		_cue_queue.append({"moment": moment, "anchor": anchor, "opts": opts})
		if not _cue_pump_running:
			_pump_cue_queue()
		return
	_play_now(moment, anchor, opts)

## Plays queued cues one at a time, QUEUE_GAP apart, each a step higher in
## pitch than the last -- a rising ladder rather than a pile. A coroutine,
## fire-and-forget; it clears its own running flag when the queue drains.
func _pump_cue_queue() -> void:
	_cue_pump_running = true
	while not _cue_queue.is_empty():
		var item: Dictionary = _cue_queue.pop_front()
		var opts: Dictionary = (item["opts"] as Dictionary).duplicate()
		opts["queue_pitch"] = minf(1.0 + QUEUE_PITCH_STEP * float(_cue_rung), QUEUE_PITCH_MAX)
		_cue_rung += 1
		_play_now(item["moment"], item["anchor"], opts)
		await get_tree().create_timer(QUEUE_GAP).timeout
	_cue_rung = 0
	_cue_pump_running = false

## Fire the full multi-sensory combo for `moment` immediately (no queueing).
func _play_now(moment: StringName, anchor: Node, opts: Dictionary) -> void:
	var recipe: Dictionary = RECIPES.get(moment, {})
	if recipe.is_empty():
		return
	var tier := moment_tier(moment, opts)
	_play_sound(moment, recipe, tier, opts)
	Haptics.buzz(HAPTIC_MS.get(tier, 20))
	if not GameSettings.reduce_motion:
		_play_particles(recipe, tier, anchor)
		_play_shake(tier, anchor)

func _play_sound(_moment: StringName, recipe: Dictionary, _tier: int, opts: Dictionary) -> void:
	if recipe.get("arpeggio", false):
		_arpeggio(recipe.get("sfx", &"coin"))
		return
	if recipe.has("chord"):
		AudioDirector.play_chord(recipe["chord"])
		return
	var sfx: StringName = recipe.get("sfx", &"")
	if sfx == &"":
		return
	var pitch := 1.0
	if recipe.get("dynamic_sfx", false):
		sfx = StringName("star_earn_%d" % clampi(int(opts.get("step", 1)), 1, 3))
	elif recipe.get("escalates", false):
		pitch = 1.0 + PITCH_STEP * float(opts.get("step", 0))
	# A queued run climbs in pitch (see _pump_cue_queue) so the paced pings
	# read as a rising ladder rather than a flat metronome.
	pitch *= float(opts.get("queue_pitch", 1.0))
	AudioDirector.play_sfx(sfx, pitch)

func _arpeggio(id: StringName) -> void:
	for i in ARPEGGIO_COUNT:
		AudioDirector.play_sfx(id, 1.0 + PITCH_STEP * float(i))
		await get_tree().create_timer(ARPEGGIO_GAP).timeout

func _play_particles(recipe: Dictionary, tier: int, anchor: Node) -> void:
	# Screens with their own authored particles (the minigame result popup's
	# fireworks, the claim popup's confetti) mark no_particles so this channel
	# stays silent there -- RewardFeedback still adds sound, haptic and shake.
	if recipe.get("no_particles", false):
		return
	var scene_path: String = recipe.get("particle", "")
	if scene_path == "":
		if tier == TIER_CELEBRATION:
			scene_path = CELEBRATION_CONFETTI
		elif tier == TIER_POP:
			scene_path = POP_BURST
		else:
			return  # Tick has no particles
	var host := anchor if anchor != null else _screen_root()
	if host == null:
		return
	var burst := load(scene_path).instantiate() as RewardParticles
	if burst == null:
		return
	burst.plays_sfx = false  # RewardFeedback owns the sound channel
	if anchor is Node2D:
		burst.position = (anchor as Node2D).position
	host.add_child(burst)
	burst.fire()

func _play_shake(tier: int, anchor: Node) -> void:
	var strength: float = SHAKE_STRENGTH.get(tier, 0.0)
	if strength <= 0.0:
		return
	var target: Node = anchor if (tier == TIER_POP and anchor is Control) else _screen_root()
	if target is Control:
		Juice.shake(target as Control, strength)

func _screen_root() -> Node:
	var tree := get_tree()
	return tree.current_scene if tree != null else null
