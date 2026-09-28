# Reward feedback pass — multi-sensory "juice" for the game's rewards

**Date:** 2026-09-23
**Status:** design, awaiting review
**Scope:** architectural — a new feedback-orchestration subsystem plus
haptics/screenshake helpers, wired through the game's reward moments, with a
debug audition tool.

## Problem

The mentor's note: the game's rewards feel **bland, mundane and unpolished** —
it should feel *fun and warm, school-like*. Investigation shows the audio
*plumbing* is already mature (344 `play_sfx` call sites, a coverage suite
pinning SFX at nearly every screen, the 2026-09-21 Drive pack filling real
streams). The gap is not missing sound — it is that **every reward fires a
single flat cue with nothing layered on it**:

- Three stars play the same ping three times (or once); no escalation.
- A coin payout is one plink, not a climbing count-up.
- A week-clear is a lone `reward` cue — no crescendo that says "you did great."
- Sound never stacks with the visual pop, haptic beat, or shake that would
  give a reward *weight*.

Good game feel is **multi-sensory, layered, and consistent**. The game today is
single-shot, thin, and ad-hoc. Fixing the orchestration moves all four of the
mentor's complaints (flat moments, generic feel, quiet stretches, uncelebrated
wins) at once.

## Goals

1. Make every reward moment feel deliberate and satisfying, in one consistent
   visual/audio/tactile language.
2. Reuse the pieces that already exist (`AudioDirector`, `RewardParticles`,
   `Juice.shake`) rather than reinventing them.
3. Keep review **cheap and manual** — a debug gallery that fires every moment
   on demand, so the developer (and the mentor) audition the whole vocabulary
   in seconds without playing a week or spending model tokens.
4. Respect the player: haptics and motion are toggleable and saved.

## Non-goals

- **Not** C's "juice on every interaction." This pass targets *reward moments*
  only, not every button tap (taps already have `UIPolish` press/release).
- No new audio *engine* — `AudioDirector` stays the single audio authority.
- No new persistence beyond two saved settings booleans.
- Minigame internals stay out of the design system (per CLAUDE.md), but their
  *reward* beats (combo, win) may call `RewardFeedback`.

## Architecture

### The `RewardFeedback` autoload

A new autoload — a peer to `AudioDirector`, but for reward *moments*. Screens
make **one call**:

```gdscript
RewardFeedback.play(&"star_earned", anchor, { "step": 2 })
```

- `moment: StringName` — a key into the recipe table (§ Vocabulary).
- `anchor: Node` — where a particle burst spawns and what a Pop-tier shake
  jitters (usually the widget that just changed). May be null (sound + haptic
  only).
- `opts: Dictionary` — per-call escalation data: `step` (which star / combo
  index, drives pitch), `from`/`to` (count-up range for the coin arpeggio).

`RewardFeedback` owns **no visuals of its own**. It delegates:

- **sound** → `AudioDirector.play_sfx` / `play_sfx_variant` / new `play_chord`
- **particles** → instantiates the existing `RewardBurst` / `CelebrationConfetti`
  PackedScenes and calls `RewardParticles.fire()` (already fire-and-forget)
- **screenshake** → `Juice.shake(node, strength)` (already exists)
- **haptics** → new `Haptics` helper (§ Haptics)

Being an autoload, it needs the scene tree for particles and timers; it resolves
the screen root from the current scene when `anchor` is null.

### Why an autoload, not static funcs or methods on AudioDirector

- Static functions (like `AnimUtils`) can't hold a burst-scene pool or run the
  fire-and-forget timers cleanly.
- Bolting particles/shake/haptics onto `AudioDirector` mixes concerns — it is
  the audio authority and should stay that.
- An autoload is globally callable from any screen with no wiring, matching how
  `AudioDirector` is already used.

## The unifier: three reward "weights"

The root of the ad-hoc feel is that every moment is hand-tuned. Instead, **three
tiers**, each a fixed bundle of the four channels, so the whole game speaks one
language. A moment maps to a tier and supplies its own sound id.

| Tier | Sound | Particles | Haptic | Shake | Feel |
|---|---|---|---|---|---|
| **Tick** | 1 subtle cue | none | ~8 ms light | none | a small thing registered |
| **Pop** | 1 cue, pitch by `step` | small burst at anchor | ~20 ms | tiny, anchor-only | a reward landed |
| **Celebration** | layered chord + fanfare | screen confetti | ~50 ms | screen-root shake | you did great |

Tier constants (durations, shake strengths, pitch steps) live in a documented
`const` block on `RewardFeedback` — a new tunable of ours, per CLAUDE.md's rule
(never inline, never in `Balance.gd`).

## The reward vocabulary

The recipe table (`moment → { tier, sound, particle_scene?, notes }`), the
single readable home of the reward language and the source the debug gallery
enumerates:

| Moment | Tier | Escalation |
|---|---|---|
| `stat_gain` | Tick | — |
| `stat_loss` | Tick | down-pitched cue |
| `score_tick` | Tick | pitch nudges up with score |
| `coins_earned` | Pop | arpeggio: pitch climbs across the count-up |
| `star_earned` | Pop→Celebration | pitch rises per star; 3rd star is Celebration |
| `schedule_confirmed` | Pop | — |
| `specialty_match` | Pop | gold-burst particle |
| `item_applied` | Pop | — |
| `minigame_combo` | Pop | pitch climbs with combo count |
| `minigame_win` | Celebration | — |
| `achievement_unlocked` | Pop | — |
| `achievement_claimed` | Celebration | — |
| `week_cleared` | Celebration | — |
| `badge_reveal` | tier by band | amazing/good = Celebration; bad/disaster = muted Pop |
| `run_win` | Celebration | — |

Escalation uses the `pitch` argument `play_sfx` already accepts; the coin
arpeggio steps pitch as `Juice.count_up` advances the number.

## Layered sound without tripping the double-fire guard

`test_audio_coverage.gd` flags any function that plays two `play_sfx` cues on
one path with no `await` between them. A layered Celebration is exactly that —
deliberately. Rather than scatter allowlist entries across screens, layering
lives inside **one** new function:

```gdscript
AudioDirector.play_chord(ids: Array[StringName], pitches: Array[float] = []) -> void
```

Screens (and `RewardFeedback`) still make a single call. Only `play_chord`
needs one justified `_DOUBLE_FIRE_ALLOWLIST` entry, documented as a sanctioned
combo. This keeps the guard meaningful everywhere else.

## Haptics

New helper — a thin wrapper, since nothing in the project vibrates today.

```gdscript
Haptics.buzz(duration_ms: int) -> void
```

Platform-branched (`OS.has_feature("mobile")`, i.e. Android/iOS vs desktop):

- **On a real phone:** calls `Input.vibrate_handheld(duration_ms)`. No debug
  pip — the player feels it, and a pip would only clutter recorded footage.
- **On desktop (PC):** no motor call (it is a no-op there anyway). Instead, if
  the debug indicator is enabled, flashes a small labeled pip
  (`HAPTIC · Pop · 20ms`) in a screen corner and logs the call. This is the
  **PC review surface**: you verify the right moment fires the right tier and
  that the toggle silences it — you just cannot feel the motor until a device
  pass.

`buzz` is a silent no-op when `GameSettings.haptics_enabled` is false, on every
platform.

## Settings & respect

Two new saved booleans on `GameSettings` (same pattern as the existing
`skip_event_dialogue`, persisted to `user://`), surfaced in the Settings screen
the Lobby gear opens, beside "Lewati Dialog Minigame":

- **`haptics_enabled`** — default **on**. Off → `Haptics.buzz` no-ops.
- **`reduce_motion`** — default **off**. On → `RewardFeedback` skips screenshake
  and screen confetti (sound + haptic still fire), for players who dislike
  motion.

## Debug: the Feedback Gallery tab

A new **"Feedback"** tab in `DebugManager`, following the existing
`tab_names` / `panels` / `_switch_tab` pattern (as "Prestasi" and "Scenes" do):

- A scrollable list — **one button per moment** in the recipe table. Tapping
  fires the *real* combo against the current scene (particles at screen centre,
  shake on the screen root, sound, and — on PC — the haptic pip). This is the
  developer's and mentor's audition surface: the whole reward language in ~30
  seconds, no week played, no model tokens spent.
- A **"Tampilkan Indikator Haptic"** toggle (default on). Off → the haptic pip
  is suppressed while sound, particles and shake keep running, so trailer
  footage records clean straight from the editor.

## Testing

Following the source-scan convention of `test_audio_coverage.gd` (behavioural
where cheap):

1. **Every wired moment reaches `RewardFeedback.play`** — source scan per
   screen, id known to the recipe table.
2. **Every recipe sound id resolves** — `AudioDirector.has_sfx` for each
   moment's cue (behavioural, like `test_every_reward_cue_resolves_to_a_real_stream`).
3. **`play_chord` is the only allowlisted layered call** — its
   `_DOUBLE_FIRE_ALLOWLIST` entry exists and is justified.
4. **Settings persist** — `haptics_enabled` / `reduce_motion` round-trip through
   save/load; `haptics_enabled=false` suppresses `Haptics.buzz`.
5. **`reduce_motion=true` suppresses shake/confetti** but not sound/haptic.
6. **The Feedback tab enumerates every recipe** — the gallery button count
   equals the recipe table size (no moment silently missing from review).
7. **Docs** — `##` header on every new script and `##` on every `@export`
   (`test_script_documentation.gd`).

## Shopping list (developer-provided audio)

I cannot generate `.ogg`/`.wav` files. Most moments reuse current streams via
pitch and layering. A short list of *genuinely new* sounds would lift the warmth
where pitch-shifting an existing cue falls short — dropped in at their slot path,
no code change (per the swappability rule):

- a warm kids-**"yay"/cheer** — the Celebration layer (`play_chord` partner)
- a soft **chord "ta-da"** — Celebration base
- optionally a dry **chalk/paper tick** — the Tick tier's character

Exact filenames, lengths and levels are specified in the implementation plan;
until the files land, these slots alias existing streams (as the Drive pack's
placeholders already do), so nothing is silent.

## Phasing (reviewable slices)

1. **Core + gallery + flagships.** `RewardFeedback` autoload, tier constants,
   recipe table, `Haptics` helper, `AudioDirector.play_chord`, the Feedback
   debug tab, and three flagship moments wired (`star_earned`, `coins_earned`,
   `week_cleared`). Reviewable in the gallery immediately.
2. **Remaining moments.** Wire the other ~8 moments through their screens.
3. **Settings & polish.** The two Settings toggles + `reduce_motion` handling,
   haptic tuning, the shopping-list sounds once provided, the full test suite,
   changelog entry.

## Open questions

None outstanding. Screenshake scope (Celebration screen-root + tiny Pop
anchor-nudge) and haptics default (**on**, toggleable) are settled; the PC
haptic stand-in and the clean-record toggle are in the design above.
