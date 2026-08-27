# Adaptive BGM System — Design

**Status:** approved 2026-08-27, pending user review of this document
**Supersedes:** Task 3 of `docs/superpowers/plans/2026-08-27-audio-pass.md`, which
originally scoped BGM as "four static looping tracks, one per screen group."
That scope is obsolete — the shape of the BGM system itself changes here.
**Depends on:** the audio infrastructure landed in
`docs/superpowers/design/audio-pass-spec.md` (buses, `AudioDirector`
autoload, the SFX system) — unaffected by this design, reused as-is.

## Problem

`AudioDirector`'s current BGM model is "one `StringName` id → one looping
`AudioStream`, crossfade between ids." That model can express four static
mood tracks, but not what the user actually wants:

- A menu-and-title bed that spans three separate scenes.
- A four-track playlist that shuffles with no immediate repeat.
- A three-track suite that loops in a fixed sequence.
- Music that must **pause in place and resume from the same position**
  around an interruption (a minigame) that isn't a scene change.
- Two tracks (win/lose) selected by game outcome instead of screen identity.
- Minigame-category-specific tracks, one of which (SeniBudaya) further
  branches by which specific minigame launched.

The user has supplied the actual audio files (not placeholders — final or
near-final assets) at `C:\Users\Legion\Downloads\audio\`, organized by
intent (`titlescreen/`, `introcutscene/`, `loby/`, `result/`,
`schoolsimulation/`, `minigames/{akademis,olahraga,senibudaya}/`).

## Goal

Every scene/moment listed in the table below plays the right music, with
smooth crossfades (no abrupt stops or sudden starts anywhere), and the
minigame interruption case resumes school-day music from where it paused
rather than restarting it.

## Scene → music mapping

| Screen / moment | Plays | New mechanism required |
|---|---|---|
| Splashscreen, MainMenu, cutscene's level-select modal (shown only if the game was already beaten, or in debug mode) | `bgm_titlescreen` | none — simple `play_bgm`, id renamed from `&"menu"` |
| Cutscene's narrative reveal, normal path (fresh game or after level select) | `bgm_introcutscene` | none — simple `play_bgm`, new id |
| Cutscene's narrative reveal, loss-retry path (`GameState.is_game_over_cutscene == true`) | `bgm_result_lose` | none — reuses the lose track; same reveal system as the normal intro, different text |
| Lobby, StudentCard, StudentList, AturJadwal (already share one id so switching between them doesn't restart music) | 4-track shuffle, never repeats the immediately-previous track | **new: playlist mode** |
| SchoolDay (day loop) | `bgm_simulation` | none — unchanged from the existing pass |
| A minigame launches (Akademis / Olahraga / SeniBudaya) | `bgm_simulation` pauses in place (silent, position held); the matched minigame track fades in | **new: pause/resume + dedicated 3rd player** |
| Akademis specifically | 3-track fixed sequence, loops 1→2→3→1... | **new: sequence mode** |
| Olahraga specifically | single looping track | none — simple play on the minigame player |
| SeniBudaya specifically | one of two tracks, chosen by which minigame scene launched (`BuatBatik` → batik track, `LombaMenari` → dance track) | none beyond a lookup by scene name |
| An in-day **event** (announcement/warning that doesn't spawn a minigame) | nothing changes; `bgm_simulation` plays straight through | **none — falls out naturally**, since events never touch the minigame player |
| Minigame ends | minigame track fades out and stops; `bgm_simulation` fades back in from its paused position | **new: resume_bgm()** |
| SemesterEnd | `bgm_result_win` or `bgm_result_lose`, chosen by `GameState.check_semester_passed()` | none — existing call site, now picks between two ids |

## AudioDirector changes

### Slots (all still `@export`, still inspector-assignable, still safe when empty)

Renamed:
- `bgm_menu` → `bgm_titlescreen` (id `&"menu"` → `&"titlescreen"`; 2 existing
  call sites — `Scripts/UI/Settings.gd`, `Scripts/MainMenu/main_menu.gd` —
  updated to match)

New, single-track (existing `play_bgm` mechanism, no change to that method):
- `bgm_introcutscene: AudioStream`
- `bgm_result_win: AudioStream`, `bgm_result_lose: AudioStream`
  (replaces the single `bgm_result` slot; `&"result"` id retired, replaced
  by `&"result_win"` / `&"result_lose"`)
- `bgm_minigame_olahraga: AudioStream`
- `bgm_minigame_senibudaya_batik: AudioStream`
- `bgm_minigame_senibudaya_menari: AudioStream`

New, multi-track:
- `bgm_lobby_playlist: Array[AudioStream]` (4 elements expected, sized by
  what's assigned — not hardcoded to exactly 4, so a 5th can be added later
  by just appending to the array)
- `bgm_minigame_akademis: Array[AudioStream]` (3 elements expected, same
  flexibility)

New tuning knob:
- `@export var minigame_bgm_fade: float = 0.4` — separate from
  `default_bgm_fade` (0.8) so the minigame duck/return doesn't feel
  sluggish; independently adjustable in the inspector.

### New playback modes

**Playlist mode** (`play_bgm_playlist(id: StringName)`, used for `&"lobby"`):
plays a random element from the array. When that track's `finished` signal
fires, picks a new random element from the array *excluding the index that
just played* (uniform over the rest), and plays it. Continues indefinitely
until a different `play_bgm*` call takes over. Starting the same playlist id
while it's already playing is a no-op, matching existing `play_bgm` semantics.

**Sequence mode** (`play_bgm_sequence(id: StringName)`, used for
`&"minigame_akademis"`): plays array element 0. On `finished`, plays index+1,
wrapping to 0 after the last element. Same "already playing → no-op" guard.

Both modes require the underlying `.ogg` files to have **`loop = false`** in
their import settings — unlike every other BGM track in the project, which
loops forever via the import flag and never fires `finished`. This is
the one asset-prep detail that differs from the rest of the audio pass and
needs to be called out in the implementation plan explicitly, since getting
it wrong (leaving `loop=true`) means `finished` never fires and the
playlist/sequence never advances.

### Pause/resume around a minigame

A **third `AudioStreamPlayer`**, `_bgm_minigame`, added alongside the
existing `_bgm_a`/`_bgm_b` pair, routed to the `BGM` bus identically. It is
NOT part of the A/B crossfade swap — it exists solely for minigame-specific
music, and is always started fresh (no crossfade *within* itself; a new
minigame always fades in from silence, since minigames don't chain into each
other).

`pause_bgm(fade: float = -1.0)`: fades the currently-active A/B player's
volume down to -60dB over `minigame_bgm_fade` (or the given override), then
sets `stream_paused = true` on it. **Does not call `.stop()`** — this is the
critical difference from the existing crossfade chain, which always calls
`.stop()` after a fade-out and would reset playback position to 0 if reused
here. Playback position is preserved by construction.

`resume_bgm(fade: float = -1.0)`: unsets `stream_paused` on the same player,
then fades its volume back up to 0dB. Playback continues from exactly where
`stream_paused` was set.

Both are no-ops if called when there's no active BGM (empty slot / boot
edge case) — same defensive posture as the rest of `AudioDirector`.

### SeniBudaya track selection

`_play_minigame` in `SchoolDay.gd` already knows the instantiated scene
(`current_minigame`) and has a `_scene_name()` helper. The minigame-launch
call site maps:
- category `"Akademis"` → `play_bgm_sequence(&"minigame_akademis")`
- category `"Olahraga"` → `play_bgm(&"minigame_olahraga")` (on the 3rd player)
- category `"SeniBudaya"`, scene name `"BuatBatik"` →
  `play_bgm(&"minigame_senibudaya_batik")`
- category `"SeniBudaya"`, scene name `"LombaMenari"` →
  `play_bgm(&"minigame_senibudaya_menari")`

All three variants play on `_bgm_minigame`, not the A/B pair — a new method,
`play_minigame_bgm(id: StringName)`, wraps whichever of the above applies and
targets that player specifically.

### Edge cases

- **Debug cheat that skips a minigame's UI entirely**
  (`cheat_force_outcome` branch in `_play_minigame`): that branch returns
  before the minigame is ever instantiated or shown, so `pause_bgm`/
  `play_minigame_bgm`/`resume_bgm` must only be called from the normal path,
  after the cheat-branch's early return. No music interruption for a
  minigame the player never visually sees.
- **Leaving the lobby mid-track**: no state is persisted across a scene
  change away from the lobby group. Returning to it later starts a fresh
  random pick from the playlist, not a resume of the interrupted track.
- **Bus routing**: `_bgm_minigame` routes to `&"BGM"` exactly like the other
  two players, so the existing Musik slider controls it identically. No new
  bus.
- **Boot ordering**: unchanged — `_load_volumes()` still runs in `_ready()`
  before any playback.

## Asset intake

Source: `C:\Users\Legion\Downloads\audio\` (already user-supplied, real
tracks — not CC0 placeholders, no `LICENSES.md` entry needed the way the SFX
placeholders got one, since these are the user's own assets, not
attribution-tracked stock).

| Source file | Target slot |
|---|---|
| `titlescreen/titlescreen.mp3` | `bgm_titlescreen` |
| `introcutscene/intro.mp3` | `bgm_introcutscene` |
| `loby/song1.mp3` … `song4.mp3` | `bgm_lobby_playlist[0..3]` |
| `schoolsimulation/schoolday.mp3` | `bgm_simulation` (existing slot, was empty) |
| `result/gamewin.mp3` | `bgm_result_win` |
| `result/gameover.wav` | `bgm_result_lose` |
| `minigames/akademis/level1-step1.wav` … `step3.wav` | `bgm_minigame_akademis[0..2]` |
| `minigames/olahraga/olahraga.mp3` | `bgm_minigame_olahraga` |
| `minigames/senibudaya/batik.mp3` | `bgm_minigame_senibudaya_batik` |
| `minigames/senibudaya/nariDangdut.mp3` | `bgm_minigame_senibudaya_menari` |

`credit.txt`'s source attributions get folded into
`Assets/Audio/BGM/CREDITS.md` for reference, distinct in name from the SFX
pass's `LICENSES.md` since these aren't CC0-verified stock with a license
grant to record — just a record of where each track came from.

Import settings: **every file above loops (`loop=true`) except the 4 lobby
tracks and the 3 Akademis tracks**, which need `loop=false` so their
`finished` signal fires and the playlist/sequence logic can advance them.

## Testing approach

Same in-editor `McpTestSuite` pattern as the rest of the audio pass — no
external test runner exists for this project.

- Slot-existence tests for every new/renamed export (mirrors the existing
  `test_sfx_and_bgm_slots_are_exported` pattern).
- Playlist picker: called many times, statistically assert it never repeats
  the immediately-previous index twice in a row.
- Sequence picker: deterministic — assert the exact 1→2→3→1 order.
- `pause_bgm()` → `resume_bgm()`: assert playback **position is preserved**
  (not reset to 0). This is the test that would have caught the crossfade-
  reuse bug this design deliberately avoids.
- Source-level coverage (same `_source()`-based style already established in
  `tests/test_audio_coverage.gd`) confirming each scene calls the right
  `play_bgm*` / `pause_bgm` / `resume_bgm` / `play_minigame_bgm`.
- **Out of scope for any automated test**: whether a fade sounds smooth, or
  whether a track suits its scene. Structural correctness only; a listening
  pass from the user covers the rest, same caveat as the rest of this
  project.

## Non-goals

- Crossfading *between two of the minigame player's own tracks* (e.g. a
  smooth transition between Akademis sequence entries) — each entry starts
  fresh from silence on `finished`, no overlap. Not requested, and the
  dedicated single minigame player doesn't support it without becoming an
  A/B pair itself.
- Remembering lobby playlist position across a scene exit/return.
- Any new volume/settings UI — the existing three sliders are unaffected.
- Repositioning or replacing existing SFX work from the prior pass.

## Constraints

- Godot 4.6, Mobile renderer, GDScript only, no new addons — same as the
  rest of the project.
- Every stream still reaches the game through an `@export` slot on
  `AudioDirector`. No `preload()`/`load()` of a BGM path in a screen script.
- Tests are `McpTestSuite` subclasses in `tests/`, run in-editor via the
  godot-ai MCP `test_run` tool — there is no CLI test runner.
- Downloading is not applicable here; all assets are already supplied
  locally by the user and merely need copying into the repo.
