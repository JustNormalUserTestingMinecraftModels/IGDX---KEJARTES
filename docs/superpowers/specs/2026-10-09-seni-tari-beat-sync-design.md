# Seni Tari (Lomba Menari) beat-sync — design

**Date:** 2026-10-09
**Branch:** `feat/tutorial-visual-overhaul` (spec only; implementation should be
cut onto its own branch, e.g. `feat/seni-tari-beat-sync`)
**Status:** Approved by the owner in brainstorming (2026-10-09). This is a
**handoff spec** for the team on the other side of GitHub — one step (the beat
chart) must be produced on a machine with audio tooling; see §7.
**Scope:** `Scripts/Minigames/SeniBudaya/LombaMenari.gd`, a new `DanceChart`
resource + its `.tres`, a dev-only chart-generation tool, the
`minigame_senibudaya_menari` BGM slot in `Scenes/Audio/AudioDirector.tscn`, a
small addition to `Scripts/Audio/AudioDirector.gd`, and the related tests.

---

## 1. Problem

The dance minigame's arrows have **nothing to do with the music**. Notes spawn
on arbitrary second-intervals from a randomised list of hand-written patterns
(`LombaMenari.gd` `rhythm_patterns`, `next_spawn_time`, `time_elapsed`), while
the BGM plays independently on its own `AudioStreamPlayer`. The two never line
up, and the pattern order is random on every run.

The owner supplied a revised track (`seniTariRevisi.mpeg`, which is actually an
MP3 — ID3v2 header, year 2026) and wants:

1. The arrow patterns **synced to this song's beat** — arrows land on the beat.
2. The new track swapped in as the minigame's music.
3. Fade-in / fade-out on that track.

## 2. Goals / non-goals

**Goals**
- Arrows arrive at the hit-zone centre **on the beat** of the new track.
- The choreography follows the **song's own structure** (busier chorus, sparser
  verse), not a mechanical loop.
- The track fades in and out cleanly.
- The run's grade difficulty (Kelas 7/8/9) comes from the **score target only**.

**Non-goals**
- No change to the swipe/grade/hit-window model (`grade_for_distance`,
  `bagus_window_px`, `sempurna_window_px` stay as tuned on 2026-09-15).
- No change to the dancer rig, the FNF note camera, or the idle-breathing
  motion — all of that rides on top unchanged.
- No runtime beat-detection. The game must not depend on any external audio
  tool at play time; detection is an **offline, dev-only** step (§7).
- No new persistence. The chart is a static committed resource.

## 3. Approaches considered (and the decisions made)

| Decision | Options weighed | Chosen |
|---|---|---|
| How arrows lock to the song | BPM+offset grid · hand-authored chart · **offline auto-detection → chart** | Offline auto-detection → chart, then hand-tune |
| Chart storage | repeating bar-pattern · **explicit event list** | Explicit event list (only format that can follow song structure; it is also what the detector emits) |
| Per-grade difficulty | density on a shared grid · tighter windows · separate charts · **score only** | **Score only** — all grades play the identical chart |
| End condition | song-end = win · **keep score target** | Keep `target_score`; the song loops if it ends first |

## 4. The sync model (the core change)

A note travels from off-screen to the hit-zone centre. To make it **land on a
beat**, it must *spawn* ahead of that beat by its travel time.

```
travel_time = spawn_distance / note_speed          # seconds in flight
spawn an event targeting song-time t_beat when:
    song_pos >= t_beat - travel_time
```

- **`song_pos`** is the live playback position of the menari track, read from a
  new `AudioDirector.get_minigame_bgm_position()` (see §6). It is corrected for
  output latency so visuals and audio agree:
  `pos = player.get_playback_position()
         + AudioServer.get_time_since_last_mix()
         - AudioServer.get_output_latency()`.
- **Lead expressed in beats.** Per the owner's "speed derived from beat timing",
  the on-screen lead is a fixed number of **beats** (`lead_beats`, an `@export`,
  default 2.0), so note speed is computed from the song, not hand-set:
  `beat_period = 60.0 / chart.bpm`
  `note_speed  = spawn_distance / (lead_beats * beat_period)`.
  A faster song moves notes faster; they still land on the beat.
- **This replaces** `rhythm_patterns`, `active_pattern_index`,
  `pattern_step_index`, `next_spawn_time`, `time_elapsed`, and
  `_spawn_rhythm_beat()` entirely. `_process()` drives a **chart cursor**
  against `song_pos` instead of a seconds timer.

### Alignment with the countdown

`SchoolDay` starts the music (fading in) *before* the 3-2-1 countdown, and
`is_game_active` only flips true when the countdown ends. We keep that. On the
frame gameplay unlocks, the spawner **advances its cursor past every event
whose target time has already gone by** (i.e. to the first event with
`t_beat - travel_time >= song_pos`). Beats that elapsed under the countdown are
skipped rather than dumped on screen as instant misses. From then on the cursor
walks forward with the music.

### Looping

The track loops (§5). When `song_pos` **drops** between frames (wrap detected),
the cursor resets to the chart's start and continues. Nothing else resets.

## 5. Audio asset swap + fades

- Copy `seniTariRevisi.mpeg` into `Assets/Audio/BGM/` as an `.mp3`. Simplest:
  replace the existing `minigame_senibudaya_menari.mp3` (keep the filename so
  the slot's drag is trivial); otherwise add a new file and repoint the slot.
- In `Scenes/Audio/AudioDirector.tscn`, drag it onto the
  `bgm_minigame_senibudaya_menari` slot. **Loop = on** (single-track slot rule,
  `Assets/Audio/README.md`).
- Set the `.import` `bpm` / `bar_beats` / `loop_offset` from detection (§7) so
  Godot's native beat fields agree with the chart. (The spawner reads the chart,
  not the import, so this is for correctness/tools, not a hard runtime dep.)

**Fades.** The plumbing already exists: `play_minigame_bgm` fades up from
−60 dB over `minigame_bgm_fade` (0.4 s) and `stop_minigame_bgm` fades down the
same way (`AudioDirector.gd`). Deliverable:

- Give the menari launch a **tunable, slightly longer** fade so the revised
  track doesn't start/stop abruptly, **without** changing the 0.4 s other
  minigames use. Implement as an optional `fade` argument on
  `play_minigame_bgm(id, fade := -1.0)` / `stop_minigame_bgm(fade := -1.0)`
  (−1 = keep `minigame_bgm_fade`), passed from `SchoolDay` only for the menari
  id. No new exported slot unless the owner wants the number inspector-visible.

## 6. `AudioDirector` addition

One small, documented method (the only change to the audio autoload):

```gdscript
## The live playback position of the minigame BGM player, in seconds,
## corrected for output latency so on-beat spawns line up with what the
## player hears. 0.0 when nothing is playing. Read every frame by LombaMenari.
func get_minigame_bgm_position() -> float
```

Plus the optional `fade` parameters on `play_minigame_bgm` / `stop_minigame_bgm`
from §5. Both go in `tests/test_audio_director.gd`'s slot/API coverage.

## 7. The chart & the offline tool (the team's step)

### `DanceChart` resource

A new `Resource` (`Scripts/Minigames/SeniBudaya/DanceChart.gd`, `@tool`,
`class_name DanceChart`) with documented `@export`s:

| Field | Type | Meaning |
|---|---|---|
| `bpm` | `float` | Song tempo; drives `note_speed` and the beat→time map. |
| `first_beat_offset` | `float` | Seconds from song start to beat 0. |
| `song_length` | `float` | Seconds; sanity/validation only (loop is engine-driven). |
| `events` | `Array[Dictionary]` | Explicit list, each `{ "beat": float, "type": int }`, sorted ascending by `beat`; `beat` is fractional for off-beat subdivisions; `type` is a `LombaMenari.NoteType` value. |

Committed as `Resources/Minigames/Charts/SeniTari.tres` and referenced by
`LombaMenari` via an `@export var chart: DanceChart` (so the owner/artist can
swap it in the Inspector, same philosophy as every other slot). Beat→time:
`t = first_beat_offset + beat * 60.0 / bpm`.

### Offline generation (dev-only, not shipped)

1. A Python script (`tools/dance_chart/detect_beats.py`, using `librosa` or
   `aubio`) runs on the mp3 → JSON `{ bpm, first_beat_offset, beats: [...] }`.
2. A Godot `@tool` importer (`Scripts/Design/BuildDanceChart.gd`, run via
   File > Run) reads that JSON and writes `SeniTari.tres`, defaulting arrow
   `type`s to a round-robin.
3. A human **hand-tunes** directions and thins/thickens events so the
   choreography matches the song — this is the authored pass the owner wants.

**Manual fallback:** if the team has no detection tooling, fill `bpm` +
`first_beat_offset` by ear and author `events` directly; the game code is
identical either way.

> ⚠️ **This step cannot be done in the spec author's environment** — no
> ffmpeg/Python/audio playback, and the track can't be heard here. The
> implementer can build the resource format, the importer, the tool script, and
> all game code, but the **actual beat numbers** must be generated and verified
> on a machine with the tooling (or authored by ear). Treat `SeniTari.tres` as
> the team's deliverable; ship a small placeholder chart so the game runs and
> tests pass until the real one lands.

### Tempo-change caveat

The model assumes a roughly constant tempo (one `bpm`). The explicit event list
still works if tempo drifts — events carry absolute `beat`s — but the `.import`
`bpm` and the `note_speed` derivation would be approximate. If the revised song
has hard tempo changes, raise it with the owner; a per-section bpm is out of
scope here.

## 8. Grade difficulty = score only

All three grades play the **identical chart** — same arrows, same beats, same
`note_speed` (from the song's bpm), same hit windows. The only per-grade lever
is `target_score`, kept as today:

| Grade | `target_score` |
|---|---|
| 7 | 1500 |
| 8 | 2000 |
| 9 | 2500 |

- **Retire** the per-grade `note_speed` block (220 / 270 / 320) in
  `start_minigame()` — speed now derives from the chart's bpm and `lead_beats`.
- `miss_limit_for()` / `MISS_LIMIT_BY_DIFFICULTY` (10 / 8 / 6) stays as the
  existing fail tolerance — it is a loss condition, not chart difficulty, and
  its tests stay green. (Flagged for the owner: if "fully on scores" is meant to
  flatten this too, say so and we make the miss limit constant.)
- End condition unchanged: reaching `target_score` wins inline; the miss limit
  loses; the looping song just keeps feeding beats until one happens.

## 9. Testing

Follow the project's static/pure-helper + source-scan pattern (the minigame
can't be instanced headlessly).

**Pure/static (behavioral):**
- `beat_to_time(beat, bpm, offset)` — exact conversion.
- `note_speed_for(spawn_distance, bpm, lead_beats)` — the derivation.
- `events_due(events, cursor, song_pos, travel_time)` → the slice to spawn this
  frame and the new cursor; covers normal advance, the countdown skip-ahead, and
  nothing-due.
- loop-wrap: `song_pos` dropping resets the cursor to 0.
- `DanceChart` validity: `bpm > 0`, events sorted, every `type` in
  `NoteType`.

**Source scans:**
- `rhythm_patterns`, `next_spawn_time`, `_spawn_rhythm_beat`, the per-grade
  `note_speed` literals are **gone** from `LombaMenari.gd`.
- `LombaMenari` reads `AudioDirector.get_minigame_bgm_position()` and spawns off
  the chart cursor.
- `AudioDirector` exposes `get_minigame_bgm_position` and the optional `fade`
  args.

**Kept:** `tests/test_lomba_menari_timing.gd`,
`tests/test_lomba_menari_misses.gd`, `tests/test_lomba_menari_arrow.gd`,
`tests/test_minigame_star_rubric.gd`, `tests/test_dance_camera.gd` — none of
their invariants change.

## 10. Risks / open questions for the owner

1. **Chart is the team's to produce** (§7). Everything else can be built and
   tested without it, behind a placeholder chart.
2. **Miss-limit scaling** — keep per-grade 10/8/6, or flatten it too? (§8)
3. **Constant tempo?** — if the revised track changes tempo, §7's caveat applies.
4. **Replace vs. add the mp3** — replacing the existing filename is the least
   work; confirm the old track isn't wanted elsewhere (it isn't referenced
   outside the menari slot).
