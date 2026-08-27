# Audio Pass — Spec

**Status:** approved 2026-08-27
**Implements plan:** `docs/superpowers/plans/2026-08-27-audio-pass.md`

## Problem

The audio system exists but is barely used.

- `Scripts/Audio/AudioDirector.gd` already provides: `Master`/`BGM`/`SFX`
  buses, a 12-voice pooled SFX player with pitch variance, an A/B
  crossfading BGM pair, and `set_bus_volume`/`get_bus_volume` persisted
  to `user://audio.cfg`.
- `Scenes/UI/Settings.tscn` already has three working sliders
  (Suara Utama / Musik / Efek Suara) bound to those buses.
- **But:** all four `bgm_*` slots are empty — the game is silent of music
  from splash to semester end.
- **And:** only ~11 `play_sfx` call sites exist in the entire project.
  `Scripts/SchoolSimulation/SchoolDay.gd` (1457 lines, the core loop)
  has zero. Card swiping, page turns, stamp approve/erase, popup
  open/close, day selection, schedule assignment, money changes and
  reward claims are all silent or share one generic click.

## Goal

Every player interaction and every piece of game feedback has a sound.
All sounds are free-for-commercial placeholders that the audio team can
swap for final assets by dropping a file in a folder and dragging it
onto one inspector slot — no code changes, ever.

## Requirements

### R1 — Music

- Four loopable instrumental tracks, one per existing `bgm_*` slot:
  `menu`, `lobby`, `simulation`, `result`.
- Tone: cute, warm, bright school life — the Umamusume / slice-of-life
  school-anime register the user named. Instrumental only, no vocals.
- Seamlessly loopable (`loop=true` in the `.import` sidecar).
- License: free for commercial use, no attribution *required*
  (CC0 preferred; CC-BY acceptable only if attribution is recorded in
  `Assets/Audio/BGM/LICENSES.md`).

### R2 — SFX coverage

Eight new slots on top of the existing eight:

| New slot | Fires when |
|---|---|
| `sfx_swipe` | student card swiped left/right, page turn |
| `sfx_stamp` | APPROVE stamp lands |
| `sfx_unstamp` | BATAL erases the stamp |
| `sfx_popup_open` | any popup/overlay/dialog opens |
| `sfx_popup_close` | any popup/overlay/dialog closes |
| `sfx_select` | a list card / day / activity is picked |
| `sfx_error` | a blocked action (limit reached, incomplete schedule) |
| `sfx_reward` | daily login claim, level/stat gain, day complete |

Every interactive control and every feedback moment in these screens
must fire an appropriate slot: MainMenu, Settings, Lobby, StudentCard,
StudentList, AturJadwal, SchoolDay, DaySummaryPopup,
DailyDecayOverview, EventStudentSelectDialog, ResultCheckup,
SemesterEnd, CutScene, Transition.

### R3 — Volume control

- The three existing sliders keep working and remain the only audio UI.
- Volumes persist across launches and are applied **before the first
  sound plays** on boot.
- A slider at 0 fully mutes its bus (already handled; must stay tested).
- Dragging the Musik slider gives audible feedback the same way the
  Efek Suara slider already does.

### R4 — Swappability

- No new hard-coded `preload()` of an audio file anywhere. Every stream
  reaches the game through an `@export` slot on `AudioDirector`.
- `Assets/Audio/README.md` documents every slot, what fires it, its
  current placeholder source and license, and the exact swap procedure.

## Non-goals

- Positional / 3D audio.
- Per-minigame custom music (minigames inherit `bgm_simulation`).
- A mute button separate from the sliders.
- Final mixed audio — everything here is explicitly a placeholder.

## Constraints

- Godot **4.6**, Mobile renderer, GDScript only. No new addons.
- Scripts instantiated by the in-editor test runner need `@tool` plus
  the `Engine.is_editor_hint()` guard already established in
  `AudioDirector.gd` and `Scripts/UI/Settings.gd`.
- Tests are `McpTestSuite` subclasses in `tests/`, run in-editor.
- Audio files: `.ogg` only. SFX under 1 s and under ~40 KB each.
- Downloads require explicit user approval per file.
