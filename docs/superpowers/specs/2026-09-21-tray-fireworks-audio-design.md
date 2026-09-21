# Tray gestures, confetti fireworks, and the real soundtrack — design

2026-09-21 · branch `feat/tray-fireworks-audio`

Four player-facing changes and one audit, from one `/gamecode` request:

1. The koperasi basket tray answers a drag, and a tap on a tray item returns it.
2. The minigame result card uses the shipped `star.png`, and its celebration
   becomes three confetti fireworks placed on the screen by an authored scene.
3. Lobby students blink on a 5–10 s idle timer from the Eyelid layer.
4. The 49 sounds in the collaborator's Drive folder replace the placeholder
   aliases, across every screen in the user's coverage table.
5. A UI-consistency audit of the screens this branch touches, plus a written
   inventory of the rest.

---

## 0. What the code already does — read this first

Two of the five asks are already partly or wholly built. Rebuilding them would
be churn, so this spec records what exists and scopes the work to the gap.

### Lobby blinking is shipped

`Scripts/Lobby/StudentFace.gd` (commit `27ae2cc`, *"feat(lobby): students blink
every 5-10 s with a faded lid"*) already carries exactly the requested
behaviour:

```gdscript
@export var idle_blink_enabled: bool = true
@export var blink_hold_range: Vector2 = Vector2(5.0, 10.0)
```

`_advance_blink()` counts down `blink_hold_range` from the rig's own RNG, then
fades the **Eyelid** layer in over `blink_fade_seconds`, holds
`blink_close_seconds`, and fades out. `motion_seed = 0` randomises per rig, so
the four seats never blink in step. All six rigs (`AndiFace.tscn` …
`TheaFace.tscn`) are instanced in `Scenes/Lobby/loby.tscn`.

**Gap:** none in the mechanism. The work is verification only — a test that
pins the 5–10 s window and the Eyelid-layer coupling so a later edit cannot
silently drop it, plus confirming every rig actually carries an `Eyelid` node
with art. `tests/test_student_face.gd` and `tests/test_face_rig_roster.gd`
already exist; this branch extends rather than replaces them.

### The star art is shipped; the particles are not

`Scripts/Minigames/UI/ResultStar.gd` already defaults both slots to
`res://Assets/Images/UI/star.png` (commit `ed7bcf9`). The file in the repo is
360×360; the one in the user's Downloads is 345×357 — the same glossy design,
re-cropped. The user asked for the Downloads file by name, so this branch drops
it in at the same path (the project's documented asset-replacement contract)
and checks the result card still reads right at its authored box.

**Gap:** the celebration. `Scenes/Minigames/UI/StarBurst.tscn` fires
`particle_star.png` from each star's own `BurstSlot`. The ask is three
**confetti fireworks on the screen**, not a star spray behind each star — a
different effect in a different place.

---

## 1. Koperasi: drag the tray, tap to return

### Today

`Scripts/Koperasi/BasketTray.gd` has `ViewState.EXPANDED / COLLAPSED`,
`toggle()` and `set_state(state, animate)`. The only way to move it is a
**press** — `Body/Emblem/HeaderButton` while expanded, `Stage/CrateHandle`
(owned by `koprasi.gd`) while collapsed. `tray_offset_collapsed = 190.0` is how
far it slides.

`Scripts/Koperasi/TraySlot.gd` classifies a release through the pure
`classify_release(held_seconds, drift, hold_threshold, slop)`:

| release | today |
|---|---|
| drift ≥ `hold_slop` (30 px) | `&"none"` |
| held ≥ `hold_seconds` (0.35 s) | `&"hold"` → `remove_requested` |
| held < `hold_seconds` | `&"tap"` → `tapped` → the shop nudges the slot |

### Change A — the tray follows a finger

A new drag gesture on the tray's own body, in `BasketTray.gd`:

- `_gui_input` on `Body` handles `InputEventScreenDrag` / `InputEventMouseMotion`
  while a press is down, moving `position.y` between `_base_y` (expanded) and
  `_base_y + tray_offset_collapsed` (collapsed), clamped to that range so the
  tray can never be flung off its dock.
- On release, a pure static `classify_drag(travel, velocity, span)` decides the
  resting state, so the rule is testable without a frame:
  - `velocity` past `FLICK_VELOCITY` (900 px/s) wins outright and picks the
    state the flick points at — a fast short flick must not be read as "barely
    moved, snap back".
  - otherwise the tray settles to whichever end is nearer: past `span * 0.5`
    it commits, below it returns.
- The settle re-enters `set_state(state, true)` so the existing tween, the
  emblem fade, the badge rule and the `state_changed` signal all keep working
  unchanged — `koprasi.gd`'s CrateHandle mirror needs no edit.
- A drag that ends where it started emits no `state_changed` (set_state already
  no-ops on a repeat), so a stray touch costs nothing.

The press buttons stay. Drag is added alongside them, not instead of them.

**Conflict to respect:** `TraySlot` already claims presses for its
hold-to-return gesture, and slots sit inside `Body`. A drag that starts on a
slot must move the tray, not swell the item. `TraySlot._begin_press` therefore
learns to cancel itself once drift passes `hold_slop` — it already measures
that drift at release; this moves the check to motion so the slot yields to the
tray mid-gesture instead of fighting it to the end.

### Change B — a tap returns one

`classify_release`'s `&"tap"` currently nudges. It becomes a return: the tap
path emits `remove_requested` like the hold does.

The `tapped` signal itself stays on `TraySlot` and `BasketTray` (it is public
API that `koprasi.gd` connects to) but the shop's handler stops nudging and the
tap now reaches `Cart.remove_item` through the existing
`remove_requested` → `koprasi.gd` path. Keeping the hold as well means no
player who learned the old gesture loses it.

**State touched:** `Cart` only (the autoload). `GameState.inventory` is
untouched until Beli, exactly as now.

`tests/test_koperasi_tap_spam.gd` asserts the old tap behaviour and is updated
in the same task that changes it.

---

## 2. Three confetti fireworks

### The scene

A new `Scenes/Minigames/UI/ConfettiFireworks.tscn` with
`Scripts/Minigames/UI/ConfettiFireworks.gd` (`@tool`), sized to the 1080×1920
canvas, holding **three authored `GPUParticles2D` bursts** as real nodes — not
built at runtime, per the project's second rule.

The user asked for "an interactable scene so you know where is the firework
placed". That is the `@tool` half: each burst is a child node the designer can
drag in the editor viewport, and the script draws a labelled ring at each
burst's origin while `Engine.is_editor_hint()` is true so the three positions
are visible without pressing play. The rings never draw at runtime.

Knobs, all `@export` and documented:

| knob | default | why |
|---|---|---|
| `burst_delay` | 0.14 s | the three fireworks go off in sequence, not together — a volley reads as a celebration, a single flash reads as a glitch |
| `confetti_per_burst` | 26 | dense enough to read on a 1080-wide phone, cheap enough for the mobile renderer |
| `burst_speed` | `Vector2(260, 520)` | min/max launch speed |
| `gravity` | 620 px/s² | confetti falls; the old star burst used 380 |
| `spin_range` | ±320 °/s | flat paper tumbles |
| `fade_seconds` | 1.1 s | lifetime |

Art is the existing `Assets/Images/Particles/particle_confetti.png` — already
in the repo, already the right thing, no new asset needed.

### Where it fires — and what it does *not* replace

The card already has **two** celebration effects, and they are not the same
thing:

- `Dim/ResultConfetti` (`Scenes/Minigames/UI/ResultConfetti.tscn`) at
  `position = Vector2(540, -20)` — one emitter above the top edge raining
  confetti down the whole screen, gated at `CONFETTI_STAR_THRESHOLD = 3`.
  **This stays exactly as it is.** It is the full-house rain, not a firework.
- `ResultStar.celebrate()` instancing `StarBurst.tscn` into each star's own
  `BurstSlot` — a star-shaped spray behind each star as it lands. **This is
  the "3 star particle" the user asked to replace.**

So `ConfettiFireworks` takes over the second one: `MinigameResultPopup.gd`
holds one instance above the card, and the reveal loop fires burst *i* as star
*i* lands, at the burst's own authored screen position rather than at the
star's. `ResultStar.celebrate()` keeps its glow bloom and its `star_earn_N`
cue and stops instancing `StarBurst`.

`StarBurst.tscn` is left in the tree: `RewardParticles.gd` and other callers
may still use it, and deleting it is out of scope for this branch.

**Win vs lose.** The fireworks fire only on a win. A loss shows the same
`star.png` art darkened by `popup_star_empty_color` (already the behaviour) and
no volley — a celebration on a loss is the kind of tonal miss the design system
exists to prevent.

---

## 3. The sounds

49 files in the collaborator's Drive folder
(`1n_bK9LMW5sj3bhhb4brX6j7ko-c3M7dG`), downloaded through the Drive connector
into `Assets/Audio/`:

- `SFX/` — 32 files (25 at the top level, 7 under `minigame/`)
- `Ambient/` — 8 files
- `credits.txt` → merged into `Assets/Audio/SFX/LICENSES.md`

### The architecture already fits

`tests/test_audio_coverage.gd` pins the rule: **no screen loads an audio file
directly.** Streams reach the game only through `AudioDirector`'s `@export`
slots. So this work is (a) drop the files in, (b) re-point the placeholder
`preload()`s, (c) add slots for the cues that have no id yet, (d) add the call
sites the user's coverage table asks for.

### Slots that stop being placeholders

| id | was | becomes |
|---|---|---|
| `sfx_star_earn_1/2/3` | `pop.ogg` ×2, `reward.ogg` | `oneStar` / `twoStar` / `threeStar` |
| `sfx_result_fanfare` | `reward.ogg` | `winSuccessful` |
| `sfx_sparkle` | `reward.ogg` | `threeStarredPoints` |
| `sfx_event_announce` | copy of `reward.ogg` | `eventAlert` |
| `sfx_coin` | Kenney | `earnMoney` |

### New slots

`sfx_school_bell` (`Schoolring`), `sfx_stat_up` (`stats-upDing`),
`sfx_stat_down` (`stats-downDing`), `sfx_card_flip` (`cardFlip`),
`sfx_schedule_confirm` (`scheduleConfirmChime`), `sfx_timer_tick`
(`timeTicking`), `sfx_times_up` (`timesUp`), `sfx_back_tap` (`BackButtonTap`),
`sfx_shop_browse` (`shopBrowseTap`), `sfx_transaction` (`transactionShop`),
`sfx_item_applied` (`itemAfterAppliedEachCharacter`), `sfx_apply` (`apply`),
`sfx_tutorial_popup` (`tutorialPopUp`), `sfx_result_checkup`
(`ResultCheckup`), `sfx_daily_claim` (`dailyLoginClaim`).

Randomised families, as `Array[AudioStream]` so a repeat never sounds
identical: `sfx_transition_sweep` (3), `sfx_ball_kick` (4), `sfx_racket_hit`
(3), `sfx_achievement` (3 + `achievementNotificationPrize` +
`notificationAchievementSuccess`).

Badge reveal is a **tier**, not one cue — `badgeReveal{Amazing,Good,Normal,Bad,
Disaster}` map to a `sfx_badge_reveal` dictionary keyed by the EndCutscene
grade band it already computes.

### Ambience

`Assets/Audio/Ambient/` holds loops, not one-shots: `classroomAmbient1/2/3`,
`writing`, `thunderstorm1`, `schoolsimulation1/2`.

AudioDirector today has two buses, `BGM` and `SFX`, and rewrites
`default_bus_layout.tres` on boot. **This branch does not add a third bus** —
that file is already a known cause of spurious dirty trees, and a new bus would
need a new settings slider to be honest about. Instead ambience gets its own
looping `AudioStreamPlayer` on the existing `SFX` bus, with
`play_ambience(id)` / `stop_ambience()`. Ambience then follows the SFX slider,
which is the behaviour a player would expect from a "sound effects" control.

`thunderstorm1` is wired to the Hujan random event; `classroomAmbient*` to
SchoolDay; `writing` to the academic activity beat.

### Where each cue is called

From the user's own table:

| Screen | cue |
|---|---|
| StudentCard | `card_flip`, `stamp` (kept), `unstamp` (kept) |
| AturJadwal | `schedule_confirm` |
| SchoolDay | `school_bell`, classroom ambience, `stat_up`, `stat_down` |
| Minigames | `result_fanfare` / `fail`, `timer_tick`, `times_up`, `ball_kick`, `racket_hit` |
| EventWarning | `event_announce` |
| ResultCheckup | `result_checkup`, `star_earn_*` |
| End sequence | `badge_reveal` tier |
| Shop | `coin`, `transaction`, `shop_browse` |
| UI global | `transition_sweep`, `popup_open/close`, `back_tap` |

### Import settings

Godot imports `.ogg` as `AudioStreamOggVorbis`. Loops need `loop = true` in the
`.import`; one-shots must not loop. The ambience files and only those get the
loop flag — a looping one-shot is the classic way a UI click becomes a drone.

---

## 4. UI consistency

`/design-audit-ui` critiques a screen from a picture. "Throughout the game" is
~20 screens and is not one branch's work, so this splits:

**Done here.** The project's own hard rule — *never add a `theme_override_*`* —
is mechanically checkable. The tree currently has 66 non-layout overrides
(29 `font_sizes`, 23 `styles`, 14 `colors`) plus 233 `constants`, most of which
are the allowed layout-only exception. This branch fixes the overrides on the
screens it already touches (Koperasi, the minigame result popup, the Lobby) by
moving them to `ThemeFactory` variations, and runs `/design-audit-ui` on those
three screens' captures.

**Written down, not done.** Every remaining override is inventoried by screen
in `docs/superpowers/DEBT.md`, so the next pass has a work list instead of a
grep. Fixing all 66 would mean touching a dozen screens this branch has no
other reason to open, and a rebake per screen — the kind of wide, shallow diff
that hides the real changes above.

---

## 5. Files

| File | Change |
|---|---|
| `Scripts/Koperasi/BasketTray.gd` | drag gesture, `classify_drag()` |
| `Scripts/Koperasi/TraySlot.gd` | drift cancels a press; tap returns |
| `Scripts/Koperasi/koprasi.gd` | tap handler stops nudging |
| `Assets/Images/UI/star.png` | replaced from Downloads |
| `Scenes/Minigames/UI/ConfettiFireworks.tscn` | **new** — three placed bursts |
| `Scripts/Minigames/UI/ConfettiFireworks.gd` | **new**, `@tool` |
| `Scripts/Minigames/UI/ResultStar.gd` | drops the per-star burst |
| `Scripts/Minigames/UI/MinigameResultPopup.gd` | fires the volley on a win |
| `Scripts/Audio/AudioDirector.gd` | new slots, ambience player, real streams |
| `Assets/Audio/SFX/**`, `Assets/Audio/Ambient/**` | **new** — 49 files |
| `Scripts/Lobby/StudentFace.gd` | unchanged — verified only |
| `docs/superpowers/DEBT.md` | the override inventory |

## 6. Grades 7/8/9

Nothing here is grade-scaled. The tray, the fireworks, the blink and every cue
behave identically in Kelas 7, 8 and 9 — they are presentation, and the
grade ladder lives in `Balance.gd` and `RunGrade.gd`, neither of which this
branch touches.

## 7. State across the bridge

Only §1 touches state, and only `Cart` (the autoload holding the pending
purchase). Nothing here reads or writes `GameState.approved_students`, so the
`akademis2` (seni_budaya) / `kepribadian1` (mood) naming trap does not apply to
this branch. `GameState.inventory` — the one persisted thing — changes only
through the existing Beli path, unchanged.
