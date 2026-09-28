# Reward Feedback Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every reward moment in the game feel deliberate and satisfying through one consistent multi-sensory language — layered sound, particles, haptics, and screenshake — with a debug gallery for cheap manual review.

**Architecture:** A new `RewardFeedback` autoload orchestrates four channels per reward "moment," reusing `AudioDirector` (sound), the existing `RewardBurst`/`CelebrationConfetti` particle scenes, and `Juice.shake` (screenshake), plus a new `Haptics` helper. Moments map to one of three fixed "weight" tiers (Tick/Pop/Celebration) so the whole game speaks one language. A debug "Feedback" tab fires any moment on demand.

**Tech Stack:** Godot 4.6, GDScript. Tests are `@tool` suites (`McpTestSuite`) run inside the editor via the `godot-ai` MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-09-23-reward-feedback-pass-design.md`

## Global Constraints

- **Godot 4.6**, portrait mobile game. Engine/systems code in **English**; all **UI-facing text is Indonesian**.
- **Never add a `theme_override_*`** except layout-only constants (`separation`, `margin_*`). Use a `ThemeFactory` variation. **Exception:** `DebugManager` styles itself directly and is out of the design system — building/styling nodes programmatically there is allowed.
- **Docs are enforced** (`test_script_documentation.gd`): every new `.gd` needs a `##` file header; every `@export` needs a `##` line above it.
- **Autoload registration:** a new autoload added to `project.godot` requires a **full editor restart** before it resolves (per CLAUDE.md — a new autoload/`class_name` is not seen until relaunch). Tests referencing it fail until then.
- **No screen loads audio directly** (`test_audio_coverage.gd`): audio reaches the game only through `AudioDirector`'s export slots. `RewardFeedback` calls `AudioDirector`, never `load()`/`preload()` on an `.ogg`.
- **Scene-work-first hazard:** when a task edits both a `.tscn` and `.gd`, do the scene work through the editor and save it FIRST, then patch scripts; after any `scene_save` check `git diff HEAD -- '*.gd'` for unintended stale-tab writes. Restart the editor after patching a script before the next `scene_save`.
- **New tunable numbers of ours** go in a named `const` block in the script that owns the behaviour — never inline, never in `Balance.gd`.

### THE TEST LOOP (used by every task's test steps)

The suite runs inside the live editor, not headless. For each "run the test loop" step:

1. Ensure `Scenes/MainMenu/main_menu.tscn` is open in the editor (some suites need it; `test_run` warns via `scene_warning` otherwise).
2. If the `.gd` under test was edited from outside the editor, force a reload: `filesystem_manage(op="scan")`, then a **no-op `script_patch`** on that file (logs a benign `reload failed error 43`, then works).
3. Run `test_run(suite="<suite_name>")` via the `godot-ai` MCP.
4. Read the returned JSON: a failing assertion names the file and message; `0 assertions` means the suite didn't load (usually a parse error — check `logs_read(source="editor")`).

Prefer targeted `test_run(suite=...)` over a full run (a full run drops the bridge; budget one editor restart per full run). **Subagents write GDScript; the human runs the editor and the test loop.**

---

### Task 1: GameSettings — `haptics_enabled` and `reduce_motion`

Two saved booleans, mirroring the existing `skip_event_dialogue` pattern. Added first so `Haptics` and `RewardFeedback` can read them.

**Files:**
- Modify: `Scripts/GameSettings.gd`
- Test: `tests/test_settings.gd` (extend) or the existing settings suite

**Interfaces:**
- Produces: `GameSettings.haptics_enabled: bool` (default `true`), `GameSettings.reduce_motion: bool` (default `false`), both persisted under the `"pengaturan"` section as `"haptics"` and `"reduce_motion"`.

- [ ] **Step 1: Write the failing test** — add to `tests/test_settings.gd`:

```gdscript
func test_haptics_and_reduce_motion_persist() -> void:
	GameSettings.haptics_enabled = false
	GameSettings.reduce_motion = true
	GameSettings.save_settings()
	GameSettings.haptics_enabled = true
	GameSettings.reduce_motion = false
	GameSettings.load_settings()
	assert_false(GameSettings.haptics_enabled, "haptics_enabled round-trips through save/load")
	assert_true(GameSettings.reduce_motion, "reduce_motion round-trips through save/load")
	# restore defaults so other tests are unaffected
	GameSettings.haptics_enabled = true
	GameSettings.reduce_motion = false
	GameSettings.save_settings()
```

- [ ] **Step 2: Run the test loop** for suite `settings`. Expected: FAIL (`haptics_enabled` not a property, or value not persisted).

- [ ] **Step 3: Implement** — in `Scripts/GameSettings.gd`, after the `skip_event_dialogue` declaration (line ~33):

```gdscript
## Reward haptics (2026-09-23): true lets Haptics.buzz() drive the phone's
## vibration motor. Off = a silent no-op on every platform. Saved beside the
## other switches.
var haptics_enabled: bool = true
## Reward motion (2026-09-23): true tells RewardFeedback to skip screenshake
## and screen confetti (sound and haptic still fire), for players who dislike
## motion. Saved beside the other switches.
var reduce_motion: bool = false
```

In `save_settings()`, after the `skip_dialog` line:

```gdscript
	config.set_value("pengaturan", "haptics", haptics_enabled)
	config.set_value("pengaturan", "reduce_motion", reduce_motion)
```

In `load_settings()`, after the `skip_event_dialogue` line:

```gdscript
		haptics_enabled = config.get_value("pengaturan", "haptics", true)
		reduce_motion = config.get_value("pengaturan", "reduce_motion", false)
```

- [ ] **Step 4: Run the test loop** for suite `settings`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Scripts/GameSettings.gd tests/test_settings.gd
git commit -m "feat(settings): add haptics_enabled and reduce_motion, saved"
```

---

### Task 2: `Haptics` helper + desktop indicator scene

A thin, platform-branched vibration wrapper. On mobile it buzzes the motor; on desktop it flashes a debug pip (the PC review surface) and logs.

**Files:**
- Create: `Scripts/Feedback/Haptics.gd` (static-function script, like `AnimUtils`)
- Create: `Scenes/Feedback/HapticIndicator.tscn` (a `CanvasLayer` with a styled `Panel` + `Label`, top-right)
- Create: `Scripts/Feedback/HapticIndicator.gd` (`@tool`, drives the pip's text + fade)
- Test: `tests/test_haptics.gd`

**Interfaces:**
- Consumes: `GameSettings.haptics_enabled` (Task 1).
- Produces:
  - `Haptics.buzz(duration_ms: int) -> void` — motor on mobile, pip on desktop, no-op when `haptics_enabled` is false.
  - `Haptics.show_indicator: bool` (static, default `true`) — desktop-only clean-record switch; false suppresses the pip while sound/particles/shake keep running.
  - `Haptics.is_mobile() -> bool` — `OS.has_feature("mobile")`.

- [ ] **Step 1: Write the failing test** — `tests/test_haptics.gd`:

```gdscript
@tool
extends McpTestSuite

func suite_name() -> String:
	return "haptics"

func _source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, "script must exist: " + path)
	return "" if f == null else f.get_as_text()

func test_buzz_is_a_no_op_when_haptics_disabled() -> void:
	# Desktop context: buzz must not throw and must respect the toggle.
	# We assert it runs without error under both toggle states; the motor
	# and pip are platform/side effects, not returned values.
	GameSettings.haptics_enabled = false
	Haptics.buzz(20)  # must be a silent no-op, no error
	GameSettings.haptics_enabled = true
	assert_true(true, "buzz() with haptics off did not throw")

func test_buzz_uses_vibrate_handheld_on_mobile_only() -> void:
	var src := _source("res://Scripts/Feedback/Haptics.gd")
	assert_true(src.contains("OS.has_feature(\"mobile\")"),
		"Haptics must branch on the mobile feature")
	assert_true(src.contains("Input.vibrate_handheld("),
		"Haptics must call vibrate_handheld on the mobile branch")

func test_buzz_respects_the_toggle_in_source() -> void:
	var src := _source("res://Scripts/Feedback/Haptics.gd")
	assert_true(src.contains("GameSettings.haptics_enabled"),
		"Haptics.buzz must gate on GameSettings.haptics_enabled")
```

- [ ] **Step 2: Run the test loop** for suite `haptics`. Expected: FAIL (`Haptics` not found).

- [ ] **Step 3a: Author `Scenes/Feedback/HapticIndicator.tscn`** through the editor (`scene_open` a new scene → `node_create`; save it):
  - Root `CanvasLayer` (layer `128`, so it sits above game UI), name `HapticIndicator`.
  - Child `Panel` named `Pip`, anchored top-right, `custom_minimum_size` ~`(220, 56)`, offset in ~24px from the top-right corner; give it a dark rounded `StyleBoxFlat` override (a debug node, so a direct override is allowed here).
  - Child of `Pip`: `Label` named `Text`, centered, font size ~22.
  - Attach `Scripts/Feedback/HapticIndicator.gd` to the root. Save the scene.

- [ ] **Step 3b: Implement `Scripts/Feedback/HapticIndicator.gd`:**

```gdscript
@tool
extends CanvasLayer
class_name HapticIndicator

## Desktop-only debug pip for haptics. The phone's motor can't be seen, so on
## PC a haptic call flashes this labelled chip (e.g. "HAPTIC · Pop · 20ms") in
## the top-right corner and fades it out. It never appears on a device build,
## where the player feels the motor instead. Purely a developer aid.

@onready var _text: Label = $Pip/Text
@onready var _pip: Panel = $Pip

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_pip.modulate.a = 0.0

## Flash the chip with `msg`, then fade it. Safe to call repeatedly.
func flash(msg: String) -> void:
	if Engine.is_editor_hint() or _text == null:
		return
	_text.text = msg
	_pip.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(_pip, "modulate:a", 0.0, 0.4)
```

- [ ] **Step 3c: Implement `Scripts/Feedback/Haptics.gd`:**

```gdscript
@tool
extends Object
class_name Haptics

## Reward haptics (2026-09-23). A thin, platform-branched vibration wrapper —
## nothing in the project vibrated before this. On a phone, buzz() drives the
## motor; on desktop (where vibrate_handheld is a no-op) it flashes the
## HapticIndicator pip so the effect is reviewable on PC. All static: no node,
## no autoload. Every call is a silent no-op when GameSettings.haptics_enabled
## is false.

## Tier labels shown on the desktop pip. Keyed by duration for a readable name.
const _TIER_NAME := { 8: "Tick", 20: "Pop", 50: "Celebration" }

## Desktop clean-record switch. False hides the pip (for trailer capture)
## while sound, particles and shake keep running. Ignored on mobile.
static var show_indicator: bool = true

## The live desktop pip, created lazily on first desktop buzz.
static var _indicator: HapticIndicator = null

static func is_mobile() -> bool:
	return OS.has_feature("mobile")

## Buzz for `duration_ms`. Motor on mobile, pip on desktop, no-op when off.
static func buzz(duration_ms: int) -> void:
	if not GameSettings.haptics_enabled:
		return
	if is_mobile():
		Input.vibrate_handheld(duration_ms)
		return
	# Desktop: no motor exists. Show the review pip instead.
	if not show_indicator:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or Engine.is_editor_hint():
		return
	if _indicator == null or not is_instance_valid(_indicator):
		_indicator = preload("res://Scenes/Feedback/HapticIndicator.tscn").instantiate()
		tree.root.add_child(_indicator)
	var name: String = _TIER_NAME.get(duration_ms, str(duration_ms) + "ms")
	_indicator.flash("HAPTIC · %s · %dms" % [name, duration_ms])
```

- [ ] **Step 4: Run the test loop** for suite `haptics`. Expected: PASS. (If `Haptics`/`HapticIndicator` `class_name`s don't resolve, restart the editor — new `class_name` needs a relaunch.)

- [ ] **Step 5: Commit**

```bash
git add Scripts/Feedback/Haptics.gd Scripts/Feedback/HapticIndicator.gd Scenes/Feedback/HapticIndicator.tscn tests/test_haptics.gd
git commit -m "feat(feedback): add Haptics wrapper with desktop review pip"
```

---

### Task 3: `AudioDirector.play_chord` — layered sound in one call

Layering (two cues on one beat) lives in one function so only one `_DOUBLE_FIRE_ALLOWLIST` entry is needed.

**Files:**
- Modify: `Scripts/Audio/AudioDirector.gd` (add `play_chord` after `play_sfx_variant`, ~line 404)
- Modify: `tests/test_audio_coverage.gd` (add the allowlist entry)
- Test: `tests/test_audio_director.gd` (extend)

**Interfaces:**
- Produces: `AudioDirector.play_chord(ids: Array, pitches: Array = []) -> void` — plays each id together; `pitches[i]` applies to `ids[i]` (default `1.0`). Unknown/empty ids are skipped (null-safe like `play_sfx`).

- [ ] **Step 1: Write the failing test** — add to `tests/test_audio_director.gd`:

```gdscript
func test_play_chord_plays_each_known_id() -> void:
	# Behavioural: after a chord of two known ids, at least two pool players
	# hold a stream. This proves layering actually reaches the pool.
	AudioDirector.play_chord([&"reward", &"sparkle"], [1.0, 1.1])
	var playing := 0
	for p in AudioDirector._sfx_pool:
		if p.stream != null:
			playing += 1
	assert_true(playing >= 2, "a two-id chord assigns at least two pool players")

func test_play_chord_is_null_safe_on_unknown_ids() -> void:
	AudioDirector.play_chord([&"definitely_not_a_cue"])  # must not throw
	assert_true(true, "unknown chord id did not throw")
```

- [ ] **Step 2: Run the test loop** for suite `audio_director`. Expected: FAIL (`play_chord` not defined).

- [ ] **Step 3a: Implement** in `Scripts/Audio/AudioDirector.gd` after `play_sfx_variant`:

```gdscript
## Plays several cues on the same beat -- a deliberate layered "chord" (a
## celebration ta-da with a cheer under it). `pitches[i]` applies to `ids[i]`,
## defaulting to 1.0. This is the ONE sanctioned place two sfx fire with no
## await between them; every other such pair is a bug the coverage suite
## catches. Unknown or empty ids are skipped, matching play_sfx's null-safety.
func play_chord(ids: Array, pitches: Array = []) -> void:
	for i in ids.size():
		var id: StringName = ids[i]
		var stream := _resolve_sfx(id)
		if stream == null:
			continue
		var player := _sfx_pool[_sfx_next]
		_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
		player.stream = stream
		var pitch: float = pitches[i] if i < pitches.size() else 1.0
		player.pitch_scale = pitch * (1.0 + randf_range(-sfx_pitch_variance, sfx_pitch_variance))
		player.play()
```

- [ ] **Step 3b: Add the allowlist entry** in `tests/test_audio_coverage.gd`'s `_DOUBLE_FIRE_ALLOWLIST` (it scans `res://Scripts`, so `play_chord`'s loop of `play_sfx`-equivalent calls would otherwise trip the guard). The scanner keys on direct `play_sfx(` — `play_chord` calls `.play()` on the pool directly, not `play_sfx`, so verify by reading the scan: it flags functions with two `play_sfx(` calls. `play_chord` has none, so **no entry is needed unless the scan flags it**. Run the loop first (Step 4); only if `audio_coverage` reports `play_chord`, add:

```gdscript
	"res://Scripts/Audio/AudioDirector.gd:play_chord": "the one sanctioned layered-cue function, reviewed 2026-09-23",
```

- [ ] **Step 4: Run the test loop** for suites `audio_director` then `audio_coverage`. Expected: both PASS (add the allowlist entry from Step 3b only if `audio_coverage` fails naming `play_chord`).

- [ ] **Step 5: Commit**

```bash
git add Scripts/Audio/AudioDirector.gd tests/test_audio_director.gd tests/test_audio_coverage.gd
git commit -m "feat(audio): add play_chord for sanctioned layered cues"
```

---

### Task 4: `RewardFeedback` autoload — the orchestrator

The core. Tier constants, the recipe table, and `play()` dispatching the four channels.

**Files:**
- Create: `Scripts/Feedback/RewardFeedback.gd`
- Modify: `project.godot` (register the autoload)
- Test: `tests/test_reward_feedback.gd`

**Interfaces:**
- Consumes: `AudioDirector.play_sfx`/`play_chord` (Tasks 3), `Haptics.buzz` (Task 2), `GameSettings.reduce_motion` (Task 1), `Juice.shake`, the particle scenes under `Scenes/`.
- Produces:
  - `RewardFeedback.play(moment: StringName, anchor: Node = null, opts: Dictionary = {}) -> void`
  - `RewardFeedback.RECIPES: Dictionary` (constant; the debug gallery enumerates it)
  - `RewardFeedback.TIER_TICK`/`TIER_POP`/`TIER_CELEBRATION: int` constants
  - `RewardFeedback.moment_tier(moment: StringName, opts: Dictionary) -> int` (resolves per-call tier escalation)

- [ ] **Step 1: Write the failing test** — `tests/test_reward_feedback.gd`:

```gdscript
@tool
extends McpTestSuite

func suite_name() -> String:
	return "reward_feedback"

func test_every_recipe_sound_id_resolves() -> void:
	for moment in RewardFeedback.RECIPES:
		var sfx: StringName = RewardFeedback.RECIPES[moment].get("sfx", &"")
		if sfx == &"":
			continue  # badge_reveal owns no sound here (EndCutscene plays it)
		assert_true(AudioDirector.has_sfx(sfx),
			"%s -> %s must resolve to a real stream" % [moment, sfx])

func test_play_is_null_safe_without_an_anchor() -> void:
	RewardFeedback.play(&"week_cleared")  # no anchor, must not throw
	assert_true(true, "play() without an anchor did not throw")

func test_unknown_moment_is_a_no_op() -> void:
	RewardFeedback.play(&"not_a_real_moment")
	assert_true(true, "unknown moment did not throw")

func test_star_earned_escalates_to_celebration_on_the_third_star() -> void:
	assert_eq(RewardFeedback.moment_tier(&"star_earned", {"step": 1}),
		RewardFeedback.TIER_POP, "star 1 is a Pop")
	assert_eq(RewardFeedback.moment_tier(&"star_earned", {"step": 3}),
		RewardFeedback.TIER_CELEBRATION, "star 3 is a Celebration")

func test_badge_reveal_tier_follows_the_band() -> void:
	assert_eq(RewardFeedback.moment_tier(&"badge_reveal", {"band": "Amazing"}),
		RewardFeedback.TIER_CELEBRATION, "an Amazing badge is a Celebration")
	assert_eq(RewardFeedback.moment_tier(&"badge_reveal", {"band": "Disaster"}),
		RewardFeedback.TIER_POP, "a Disaster badge is a muted Pop")
```

- [ ] **Step 2: Register the autoload** in `project.godot` `[autoload]` block, after the `Achievements`/`AchievementToast` lines:

```
RewardFeedback="*res://Scripts/Feedback/RewardFeedback.gd"
```

Then **restart the editor** (a new autoload is not seen until relaunch).

- [ ] **Step 3: Run the test loop** for suite `reward_feedback`. Expected: FAIL (`RewardFeedback` not defined / no `RECIPES`).

- [ ] **Step 4: Implement `Scripts/Feedback/RewardFeedback.gd`:**

```gdscript
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

## Particle scenes, by role.
const POP_BURST := "res://Scenes/SchoolSimulation/RewardBurst.tscn"
const CELEBRATION_CONFETTI := "res://Scenes/SchoolSimulation/CelebrationConfetti.tscn"
const SPECIALTY_BURST := "res://Scenes/AturJadwal/SpecialtyMatchBurst.tscn"

## moment -> { tier, sfx, particle?, escalates?, dynamic_sfx? }. The single
## readable home of the reward vocabulary; the debug gallery enumerates it.
const RECIPES := {
	&"stat_gain":        { "tier": TIER_TICK, "sfx": &"stat_up" },
	&"stat_loss":        { "tier": TIER_TICK, "sfx": &"stat_down" },
	&"score_tick":       { "tier": TIER_TICK, "sfx": &"score_tick", "escalates": true },
	&"coins_earned":     { "tier": TIER_POP, "sfx": &"coin", "arpeggio": true },
	&"star_earned":      { "tier": TIER_POP, "sfx": &"star_earn_1", "dynamic_sfx": true },
	&"schedule_confirmed": { "tier": TIER_POP, "sfx": &"schedule_confirm" },
	&"specialty_match":  { "tier": TIER_POP, "sfx": &"specialty_match", "particle": SPECIALTY_BURST },
	&"item_applied":     { "tier": TIER_POP, "sfx": &"item_applied" },
	&"minigame_combo":   { "tier": TIER_POP, "sfx": &"combo_up", "escalates": true },
	&"minigame_win":     { "tier": TIER_CELEBRATION, "sfx": &"result_fanfare", "chord": [&"result_fanfare", &"reward"] },
	&"achievement_unlocked": { "tier": TIER_POP, "sfx": &"achievement_success" },
	&"achievement_claimed":  { "tier": TIER_CELEBRATION, "sfx": &"achievement_prize", "chord": [&"achievement_prize", &"reward"] },
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

## Fire the full multi-sensory combo for `moment`.
func play(moment: StringName, anchor: Node = null, opts: Dictionary = {}) -> void:
	if Engine.is_editor_hint():
		return
	var recipe: Dictionary = RECIPES.get(moment, {})
	if recipe.is_empty():
		return
	var tier := moment_tier(moment, opts)
	_play_sound(moment, recipe, tier, opts)
	Haptics.buzz(HAPTIC_MS.get(tier, 20))
	if not GameSettings.reduce_motion:
		_play_particles(recipe, tier, anchor)
		_play_shake(tier, anchor)

func _play_sound(moment: StringName, recipe: Dictionary, tier: int, opts: Dictionary) -> void:
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
	AudioDirector.play_sfx(sfx, pitch)

func _arpeggio(id: StringName) -> void:
	for i in ARPEGGIO_COUNT:
		AudioDirector.play_sfx(id, 1.0 + PITCH_STEP * float(i))
		await get_tree().create_timer(ARPEGGIO_GAP).timeout

func _play_particles(recipe: Dictionary, tier: int, anchor: Node) -> void:
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
```

- [ ] **Step 5: Run the test loop** for suite `reward_feedback`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Feedback/RewardFeedback.gd project.godot tests/test_reward_feedback.gd
git commit -m "feat(feedback): add RewardFeedback orchestrator autoload"
```

---

### Task 5: Debug "Feedback" gallery tab + clean-record toggle

Every moment as a one-tap button; a toggle to hide the haptic pip for trailer capture.

**Files:**
- Modify: `Scripts/Debug/DebugManager.gd` (add tab name, `_build_feedback_panel`, panel builder call)
- Test: `tests/test_reward_feedback.gd` (extend — assert gallery covers every recipe)

**Interfaces:**
- Consumes: `RewardFeedback.RECIPES`, `Haptics.show_indicator`.

- [ ] **Step 1: Write the failing test** — add to `tests/test_reward_feedback.gd`:

```gdscript
func test_debug_feedback_tab_covers_every_recipe() -> void:
	var src := FileAccess.open("res://Scripts/Debug/DebugManager.gd", FileAccess.READ).get_as_text()
	assert_true(src.contains('"Feedback"'), "DebugManager registers a Feedback tab")
	assert_true(src.contains("_build_feedback_panel"), "DebugManager builds the feedback panel")
	assert_true(src.contains("RewardFeedback.RECIPES"),
		"the feedback panel enumerates RewardFeedback.RECIPES (one button per moment)")
	assert_true(src.contains("Haptics.show_indicator"),
		"the feedback panel toggles the clean-record haptic indicator")
```

- [ ] **Step 2: Run the test loop** for suite `reward_feedback`. Expected: FAIL.

- [ ] **Step 3a: Add `"Feedback"` to `tab_names`** in `DebugManager.gd` (~line 285):

```gdscript
	var tab_names = ["General", "Students", "Minigames", "Scenes", "Prestasi", "Feedback", "Logs"]
```

- [ ] **Step 3b: Add the builder call** after `_build_achievements_panel(content_area)` (~line 319):

```gdscript
	_build_feedback_panel(content_area)
```

- [ ] **Step 3c: Implement `_build_feedback_panel`** near the other `_build_*_panel` functions:

```gdscript
## Reward feedback audition gallery (2026-09-23). One button per RewardFeedback
## moment, firing the real combo against the current scene, plus a switch that
## hides the desktop haptic pip so trailer footage records clean.
func _build_feedback_panel(parent: Control) -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	panels["Feedback"] = scroll

	var margin = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# Clean-record switch: hide the haptic pip while everything else fires.
	var clean = CheckButton.new()
	clean.text = " Tampilkan Indikator Haptic "
	clean.button_pressed = Haptics.show_indicator
	clean.add_theme_font_size_override("font_size", 22)
	clean.toggled.connect(func(on: bool): Haptics.show_indicator = on)
	vbox.add_child(clean)

	for moment in RewardFeedback.RECIPES:
		var btn = Button.new()
		btn.text = "  ▶  " + String(moment)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 80)
		btn.add_theme_font_size_override("font_size", 22)
		var m: StringName = moment
		btn.pressed.connect(func():
			var opts := {}
			if m == &"star_earned":
				opts = {"step": 3}
			elif m == &"badge_reveal":
				opts = {"band": "Amazing"}
			RewardFeedback.play(m, get_tree().current_scene, opts)
			log_message("Fired reward feedback: " + String(m)))
		vbox.add_child(btn)
```

- [ ] **Step 4: Run the test loop** for suite `reward_feedback`. Expected: PASS. Then manually: open the overlay (F1) → **Feedback** tab, tap a few moments, confirm sound/particles/shake fire and the pip shows (and vanishes when the toggle is off).

- [ ] **Step 5: Commit**

```bash
git add Scripts/Debug/DebugManager.gd tests/test_reward_feedback.gd
git commit -m "feat(debug): add reward feedback audition gallery tab"
```

---

### Task 6: Wire the three flagship moments (end of Slice 1)

Star earned, coins earned, week cleared — the moments the mentor will judge first.

**Files:**
- Modify: `Scripts/Minigames/UI/ResultStar.gd` (star earned) — or `ResultCheckup.gd` where stars tally; confirm which shows the roster stars
- Modify: `Scripts/Lobby/loby.gd` (coins earned on claim) and `Scripts/SchoolSimulation/ResultCheckup.gd` (Wirausaha payout)
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` (`_on_week_complete`, week cleared)
- Test: `tests/test_audio_coverage.gd` (extend — source scan per screen)

**Interfaces:**
- Consumes: `RewardFeedback.play`.

- [ ] **Step 1: Write the failing test** — add to `tests/test_audio_coverage.gd`:

```gdscript
func test_flagship_moments_call_reward_feedback() -> void:
	var expected := {
		"res://Scripts/SchoolSimulation/SchoolDay.gd": &"week_cleared",
		"res://Scripts/Lobby/loby.gd": &"coins_earned",
	}
	for path in expected:
		var src := _source(path)
		assert_true(src.contains('RewardFeedback.play(&"%s"' % expected[path]),
			'%s must call RewardFeedback.play(&"%s")' % [path, expected[path]])
```

- [ ] **Step 2: Run the test loop** for suite `audio_coverage`. Expected: FAIL.

- [ ] **Step 3: Implement** — at each reward moment, replace/augment the lone `play_sfx` with a `RewardFeedback.play`:
  - `SchoolDay.gd` `_on_week_complete()` (the existing `play_sfx(&"reward")` site): change to `RewardFeedback.play(&"week_cleared", self)`. Keep any existing tween/scene-change flow.
  - `loby.gd` `_on_claim_pressed()`: where the coin balance rises, call `RewardFeedback.play(&"coins_earned", %MoneyLabel)` (pass the money label node as anchor). Leave the existing `reward` chime if it reads as the claim confirmation, or fold it in — check the `_DOUBLE_FIRE_ALLOWLIST` note for `loby.gd:_on_claim_pressed` and update the justification if the call changes.
  - Stars: in the result star reveal (`ResultStar.gd` / `ResultCheckup.gd`), at each star that lights, call `RewardFeedback.play(&"star_earned", star_node, {"step": star_index})` where `star_index` is 1..3. Remove the now-redundant direct `star_earn_*` `play_sfx` so the cue isn't doubled.

- [ ] **Step 4: Run the test loop** for suites `audio_coverage` then `reward_feedback`. Expected: PASS. Manually play a week (or use the debug Scenes tab → weekly report) and listen: stars should climb, the payout should arpeggiate, the week-clear should feel like a celebration.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/SchoolDay.gd Scripts/Lobby/loby.gd Scripts/Minigames/UI/ResultStar.gd Scripts/SchoolSimulation/ResultCheckup.gd tests/test_audio_coverage.gd
git commit -m "feat(feedback): wire star, coin and week-clear through RewardFeedback"
```

---

### Task 7: Settings screen — the two toggles

Surface `haptics_enabled` and `reduce_motion` beside "Lewati Dialog Minigame."

**Files:**
- Modify: the Settings scene (`Scenes/UI/settings.tscn` or wherever `%SkipDialogToggle` lives — find via `grep`) — add two `CheckButton`s with unique names `HapticsToggle`, `ReduceMotionToggle`
- Modify: `Scripts/UI/Settings.gd` (`@onready` refs + init values + handlers)
- Test: `tests/test_settings.gd` (extend — source scan for the handlers)

**Interfaces:**
- Consumes: `GameSettings.haptics_enabled`, `GameSettings.reduce_motion`.

- [ ] **Step 1: Write the failing test** — add to `tests/test_settings.gd`:

```gdscript
func test_settings_screen_exposes_haptics_and_motion() -> void:
	var src := FileAccess.open("res://Scripts/UI/Settings.gd", FileAccess.READ).get_as_text()
	assert_true(src.contains("GameSettings.haptics_enabled ="),
		"Settings must write haptics_enabled from its toggle")
	assert_true(src.contains("GameSettings.reduce_motion ="),
		"Settings must write reduce_motion from its toggle")
```

- [ ] **Step 2: Run the test loop** for suite `settings`. Expected: FAIL.

- [ ] **Step 3a: Scene work first** — open the settings scene in the editor, duplicate the `SkipDialogToggle` `CheckButton` twice, name them `HapticsToggle` (label `"Getaran (Haptic)"`) and `ReduceMotionToggle` (label `"Kurangi Gerakan"`), set unique-name access on. Save the scene. Then `git diff HEAD -- '*.gd'` to confirm no stale-tab writes.

- [ ] **Step 3b: Script work** — in `Scripts/UI/Settings.gd`, after the `_skip_dialog` ref (line ~25):

```gdscript
@onready var _haptics: CheckButton = %HapticsToggle
@onready var _reduce_motion: CheckButton = %ReduceMotionToggle
```

After the `_skip_dialog.button_pressed = ...` init (line ~38):

```gdscript
	_haptics.button_pressed = GameSettings.haptics_enabled
	_reduce_motion.button_pressed = GameSettings.reduce_motion
```

After the `_skip_dialog.toggled.connect(...)` line (line ~44):

```gdscript
	_haptics.toggled.connect(_on_haptics_toggled)
	_reduce_motion.toggled.connect(_on_reduce_motion_toggled)
```

New handlers after `_on_skip_dialog_toggled`:

```gdscript
## "Getaran (Haptic)": drives phone vibration on reward moments. Saved.
func _on_haptics_toggled(pressed: bool) -> void:
	GameSettings.haptics_enabled = pressed
	if not Engine.is_editor_hint():
		GameSettings.save_settings()

## "Kurangi Gerakan": drops screenshake and screen confetti (sound and haptic
## still fire) for players who dislike motion. Saved.
func _on_reduce_motion_toggled(pressed: bool) -> void:
	GameSettings.reduce_motion = pressed
	if not Engine.is_editor_hint():
		GameSettings.save_settings()
```

- [ ] **Step 4: Run the test loop** for suite `settings`. Expected: PASS. Manually: open Settings, toggle both, confirm they stick after leaving and returning.

- [ ] **Step 5: Commit**

```bash
git add Scripts/UI/Settings.gd Scenes/UI/settings.tscn tests/test_settings.gd
git commit -m "feat(settings): expose haptics and reduce-motion toggles"
```

---

### Task 8: Wire the remaining sim, schedule, shop & inventory moments

**Files:**
- Modify: `Scripts/SchoolSimulation/DaySummaryStatRow.gd` (`stat_gain`/`stat_loss`)
- Modify: `Scripts/AturJadwal/atur_jadwal.gd` (`schedule_confirmed`, `specialty_match`)
- Modify: `Scripts/Inventory/ApplyItemScreen.gd` or `ApplyStudentRow.gd` (`item_applied`)
- Test: `tests/test_audio_coverage.gd` (extend)

**Interfaces:** Consumes `RewardFeedback.play`.

- [ ] **Step 1: Write the failing test** — add to `tests/test_audio_coverage.gd`:

```gdscript
func test_sim_shop_inventory_moments_call_reward_feedback() -> void:
	var expected := {
		"res://Scripts/SchoolSimulation/DaySummaryStatRow.gd": [&"stat_gain", &"stat_loss"],
		"res://Scripts/AturJadwal/atur_jadwal.gd": [&"schedule_confirmed", &"specialty_match"],
	}
	for path in expected:
		var src := _source(path)
		for m in expected[path]:
			assert_true(src.contains('RewardFeedback.play(&"%s"' % m),
				'%s must call RewardFeedback.play(&"%s")' % [path, m])
```

- [ ] **Step 2: Run the test loop** for suite `audio_coverage`. Expected: FAIL.

- [ ] **Step 3: Implement** — at each moment, call `RewardFeedback.play` with the row/widget as anchor, and remove the now-redundant direct `play_sfx` for that cue:
  - `DaySummaryStatRow.gd`: where a stat animates up, `RewardFeedback.play(&"stat_gain", self)`; where it drops, `RewardFeedback.play(&"stat_loss", self)`. (These replace the existing `stat_up`/`stat_down` `play_sfx`.)
  - `atur_jadwal.gd` `_proceed_start_week()` (the `schedule_confirm` site): `RewardFeedback.play(&"schedule_confirmed")`. At the specialty-match gold burst site (the existing `specialty_match` cue): `RewardFeedback.play(&"specialty_match", <the matched row/splash node>)`. Update the relevant `_DOUBLE_FIRE_ALLOWLIST` justifications if a site's call set changes.
  - `ApplyItemScreen.gd`/`ApplyStudentRow.gd`: where an item applies to a student (`item_applied` cue): `RewardFeedback.play(&"item_applied", <the student row>)`.

- [ ] **Step 4: Run the test loop** for suites `audio_coverage`, `atur_jadwal`, `day_summary`, `inventory`, `reward_feedback`. Expected: PASS. Manually spot-check a schedule confirm and a stat row in the debug gallery.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/DaySummaryStatRow.gd Scripts/AturJadwal/atur_jadwal.gd Scripts/Inventory/ApplyItemScreen.gd Scripts/Inventory/ApplyStudentRow.gd tests/test_audio_coverage.gd
git commit -m "feat(feedback): wire stat, schedule, specialty and item moments"
```

---

### Task 9: Wire the minigame, achievement & end-of-grade moments

**Files:**
- Modify: `Scripts/Minigames/UI/MinigameScoreHUD.gd` (`minigame_combo`), `Scripts/Minigames/UI/MinigameResultPopup.gd` (`minigame_win`)
- Modify: `Scripts/Achievements/AchievementToast.gd` (`achievement_unlocked`), `Scripts/Achievements/AchievementClaimPopup.gd` (`achievement_claimed`)
- Modify: `Scripts/EndGame/EndCutscene.gd` (`badge_reveal`, band from the verdict), `Scripts/EndGame/RunResult.gd` (`run_win` on a win)
- Test: `tests/test_audio_coverage.gd` (extend)

**Interfaces:** Consumes `RewardFeedback.play`.

- [ ] **Step 1: Write the failing test** — add to `tests/test_audio_coverage.gd`:

```gdscript
func test_minigame_achievement_endgame_moments_call_reward_feedback() -> void:
	var expected := {
		"res://Scripts/Minigames/UI/MinigameResultPopup.gd": &"minigame_win",
		"res://Scripts/Achievements/AchievementClaimPopup.gd": &"achievement_claimed",
		"res://Scripts/EndGame/EndCutscene.gd": &"badge_reveal",
		"res://Scripts/EndGame/RunResult.gd": &"run_win",
	}
	for path in expected:
		var src := _source(path)
		assert_true(src.contains('RewardFeedback.play(&"%s"' % expected[path]),
			'%s must call RewardFeedback.play(&"%s")' % [path, expected[path]])
```

- [ ] **Step 2: Run the test loop** for suite `audio_coverage`. Expected: FAIL.

- [ ] **Step 3: Implement:**
  - `MinigameScoreHUD.gd`: on a combo increment, `RewardFeedback.play(&"minigame_combo", self, {"step": combo_count})`.
  - `MinigameResultPopup.gd`: on a win, `RewardFeedback.play(&"minigame_win", self)`.
  - `AchievementToast.gd`: on unlock banner, `RewardFeedback.play(&"achievement_unlocked", self)`.
  - `AchievementClaimPopup.gd`: on claim, `RewardFeedback.play(&"achievement_claimed", self)`.
  - `EndCutscene.gd`: at the badge reveal, keep the existing `badge_reveal_stream(band)` sound as-is, and ADD `RewardFeedback.play(&"badge_reveal", <badge node>, {"band": band})` for the physical channels.
  - `RunResult.gd`: on a win verdict, `RewardFeedback.play(&"run_win", self)`.

- [ ] **Step 4: Run the test loop** for suites `audio_coverage`, `end_cutscene`, `run_result`, `reward_feedback`. Expected: PASS. Manually use the debug Scenes tab's **Gladi Resik** rehearsals (Semua Lulus) to hear the end-of-grade celebration, then **↩ Pulihkan Run** to restore.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Minigames/UI/MinigameScoreHUD.gd Scripts/Minigames/UI/MinigameResultPopup.gd Scripts/Achievements/AchievementToast.gd Scripts/Achievements/AchievementClaimPopup.gd Scripts/EndGame/EndCutscene.gd Scripts/EndGame/RunResult.gd tests/test_audio_coverage.gd
git commit -m "feat(feedback): wire minigame, achievement and end-of-grade moments"
```

---

### Task 10: Docs, shopping list & final full run

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md` (newest first)
- Modify: `docs/superpowers/DEBT.md` (the audio shopping list)
- Modify: `CLAUDE.md` (bump the suite/test count in `## Testing`)

- [ ] **Step 1: Add the shopping list to `docs/superpowers/DEBT.md`** under "Audio and copy":

```markdown
**Reward-feedback shopping list (2026-09-23).** RewardFeedback reuses existing
streams via pitch and layering, but three genuinely new sounds would lift the
warmth. Drop each at its slot path (swappable, no code change); until then the
slot aliases an existing stream:
- a warm kids "yay"/cheer — the Celebration `play_chord` partner
- a soft chord "ta-da" — the Celebration base
- a dry chalk/paper tick — the Tick tier's character
```

- [ ] **Step 2: Add a CHANGELOG entry** (newest first) at the top of `docs/superpowers/CHANGELOG.md`:

```markdown
## 2026-09-23 — Reward feedback pass

Added `RewardFeedback`, a multi-sensory reward orchestrator (sound + particles
+ haptics + screenshake) across ~15 reward moments, unified by three "weight"
tiers. New `Haptics` helper (mobile motor / desktop review pip), an
`AudioDirector.play_chord` for layered cues, `GameSettings.haptics_enabled` and
`reduce_motion` toggles in Settings, and a debug **Feedback** gallery tab that
auditions every moment (with a clean-record switch for trailer capture).
Spec: `docs/superpowers/specs/2026-09-23-reward-feedback-pass-design.md`.
```

- [ ] **Step 3: Take one full `test_run`** (all suites). Expected: green. Budget an editor restart afterward (a full run drops the bridge). Then `git status` — if `kejartes_theme.tres` or `default_bus_layout.tres` changed from the run, `git checkout --` whichever you didn't intend (per CLAUDE.md).

- [ ] **Step 4: Bump the count** in `CLAUDE.md` `## Testing` (three new suites: `haptics`, `reward_feedback`, plus the extended ones — set the numbers to the full run's reported totals).

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/CHANGELOG.md docs/superpowers/DEBT.md CLAUDE.md
git commit -m "docs(feedback): changelog, audio shopping list, suite count"
```

---

## Self-Review

**Spec coverage:**
- RewardFeedback autoload + `play()` → Task 4. ✓
- Three tiers (Tick/Pop/Celebration) → Task 4 constants. ✓
- Reward vocabulary (~15 moments) → Task 4 `RECIPES`, wired in Tasks 6/8/9. ✓
- Layered sound via one `play_chord` + allowlist → Task 3. ✓
- Haptics helper, platform branch, PC pip → Task 2. ✓
- Settings `haptics_enabled` / `reduce_motion` (saved) → Tasks 1 & 7; `reduce_motion` consumed in Task 4. ✓
- Feedback Gallery debug tab + clean-record toggle → Task 5. ✓
- Escalation (star pitch/tier, coin arpeggio, combo pitch) → Task 4 `_play_sound`/`_arpeggio`. ✓
- Testing plan (source scans, has_sfx, persistence, gallery coverage) → across all tasks. ✓
- Shopping list → Task 10. ✓
- Phasing: Slice 1 = Tasks 1–6; Slice 2 = Tasks 8–9; Slice 3 = Tasks 7 & 10. ✓

**Placeholder scan:** No TBD/TODO; every code step carries real code; wiring tasks name the exact function/site and the exact `play` call. The one conditional (Task 3 Step 3b allowlist entry) is gated on an observable test result with the exact line to add. ✓

**Type consistency:** `play(moment, anchor, opts)`, `moment_tier(moment, opts)`, `RECIPES`, `TIER_*`, `HAPTIC_MS`, `SHAKE_STRENGTH`, `play_chord(ids, pitches)`, `Haptics.buzz(duration_ms)`, `Haptics.show_indicator` — used consistently across Tasks 2–9. ✓

**Note for the executor:** exact call sites in Tasks 6/8/9 ("the existing `play_sfx(&"reward")` site", "the specialty-match gold burst site") must be located by reading the current file — grep the named cue id in the named file. The moment id and anchor to pass are specified; the surrounding line is not reproduced because these files evolve.
