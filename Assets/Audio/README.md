# Audio

- `SFX/` — short one-shot sounds (16 slots, all filled)
- `BGM/` — music, single tracks and playlists (all slots filled, 15 files total)

**Every file in `SFX/` right now is a placeholder.** All of it is free
for commercial use (see `SFX/LICENSES.md` and `Kenney_License.txt`), and
all of it is meant to be replaced. `BGM/` holds real user-supplied tracks
(see `BGM/CREDITS.md`) — swap any of them out the same way.

Note: `introcutscene.mp3` and `schoolsimulation.mp3` are currently the
same placeholder track. That's deliberate for now, not a bug — one of
them is slated to be replaced with a distinct OST later.

## How to swap a sound — the whole procedure

1. Drop your `.ogg`/`.mp3`/`.wav` into `SFX/` or `BGM/`. Keep any
   filename you like; the slot name is what matters, not the filename.
2. Open `Scenes/Audio/audio_director.tscn` in the Godot editor.
3. Drag your file from the FileSystem dock onto the matching slot in the
   Inspector (see "Adding or swapping BGM" below for array slots).
4. Save the scene. Done — no code changes, ever.

For BGM, the Loop import setting matters and differs by slot type — see
"Adding or swapping BGM" below.

A slot you leave empty simply plays nothing. Nothing crashes.

## SFX slots

| Slot | Fires when | Where |
|---|---|---|
| `sfx_tap` | any button is pressed | auto-wired for every button by `Scripts/UI/UIPolish.gd`; also main menu buttons, cutscene skip |
| `sfx_confirm` | a positive/accept action | main menu play button, atur jadwal (assign activity / save schedule), event student-select dialog accept, result checkup accept |
| `sfx_cancel` | back, close, decline | main menu back, settings back, event student-select dialog decline, school day back-out |
| `sfx_success` | a target is met | day summary pass, semester result pass |
| `sfx_fail` | a target is missed | day summary fail, atur jadwal validation failures, semester result fail |
| `sfx_coin` | money increases | Lobby `_update_money_display` (daily login payout, any money gain) |
| `sfx_whoosh` | scene transitions | `Scripts/Transition/transition.gd`, cutscene grade selection |
| `sfx_pop` | Musik slider preview | Settings (dragging the BGM slider) |
| `sfx_swipe` | student card swiped | StudentCard |
| `sfx_stamp` | APPROVE stamp lands | StudentCard |
| `sfx_unstamp` | BATAL erases the stamp | StudentCard |
| `sfx_popup_open` | a popup/overlay/dialog opens | AturJadwal, Lobby, EventStudentSelectDialog, SchoolDay, StudentCard, ResultCheckup |
| `sfx_popup_close` | a popup/overlay/dialog closes | AturJadwal, Lobby, DailyDecayOverview, StudentCard |
| `sfx_select` | a list card, day, or activity is picked | AturJadwal, CutScene, EventStudentSelectDialog, StudentList |
| `sfx_error` | a blocked action | atur jadwal validation error, Lobby (already-claimed reward), StudentCard (approve limit reached) |
| `sfx_reward` | daily login claim, week complete | Lobby, SchoolDay |

Note on `sfx_tap`: it fires automatically for *every* `BaseButton` in the
game. Keep whatever you put there short and unobtrusive — it is by far
the most-heard sound in the project. A button opts out with
`button.set_meta(Juice.NO_AUTO_JUICE, true)`.

Two corrections worth calling out explicitly, since they differ from
what you might expect from the names: the StudentCard's APPROVE stamp
plays `stamp` (not `confirm`), and its BATAL/eraser action plays
`unstamp` (not `cancel`). These are their own distinct sounds — treat
them as a matched pair (stamp landing / stamp being scraped off), not
as a synonym for confirm/cancel.

## BGM system

Four kinds of BGM behavior exist, chosen automatically per scene — nothing
here requires a settings toggle.

### Single looping track

Plain background music: one file, loops forever, crossfades to the next when
a new one starts.

| Slot | Plays on | Method |
|---|---|---|
| `bgm_titlescreen` | Splashscreen, MainMenu, Settings, cutscene's level-select modal | `AudioDirector.play_bgm(&"titlescreen")` |
| `bgm_introcutscene` | the narrative intro reveal (normal path) | `AudioDirector.play_bgm(&"introcutscene")` |
| `bgm_simulation` | SchoolDay | `AudioDirector.play_bgm(&"simulation")` |
| `bgm_result_win` | SemesterEnd, on a pass | `AudioDirector.play_bgm(&"result_win")` |
| `bgm_result_lose` | SemesterEnd on a fail; also the loss-retry cutscene reveal | `AudioDirector.play_bgm(&"result_lose")` |
| `bgm_minigame_olahraga` | any Olahraga minigame | `AudioDirector.play_minigame_bgm(&"minigame_olahraga")` |
| `bgm_minigame_senibudaya_batik` | the Batik minigame specifically | `AudioDirector.play_minigame_bgm(&"minigame_senibudaya_batik")` |
| `bgm_minigame_senibudaya_menari` | the dance minigame specifically | `AudioDirector.play_minigame_bgm(&"minigame_senibudaya_menari")` |

### Shuffle playlist (no immediate repeat)

| Slot | Plays on | Method |
|---|---|---|
| `bgm_lobby_playlist` (4 tracks) | Lobby, StudentCard, StudentList, AturJadwal | `AudioDirector.play_bgm_playlist(&"lobby")` |

Each track plays once, then a new one is picked at random from the
remaining three — never the one that just played. The four screens above
share this one playlist so switching between them doesn't restart the music.

### Fixed sequence, looping

| Slot | Plays on | Method |
|---|---|---|
| `bgm_minigame_akademis` (3 tracks) | any Akademis minigame | `AudioDirector.play_minigame_bgm(&"minigame_akademis")` |

Always plays in order — 1, 2, 3, 1, 2, 3... A fresh Akademis minigame launch
always restarts at track 1.

### Pause / resume around a minigame

`bgm_simulation` doesn't stop when a minigame starts — it pauses in place
(silent, position held) and resumes from exactly where it left off once the
minigame ends. This is why minigame music plays on its own dedicated player
rather than sharing the two used for everything else: `AudioDirector.pause_bgm()`
right before a minigame's music starts, `AudioDirector.resume_bgm()` right
after it stops. An in-day **event** (an announcement that doesn't launch a
minigame) never touches this — `bgm_simulation` just keeps playing straight
through it.

## Adding or swapping BGM

Single-track slots: drag a file onto the slot in `audio_director.tscn`'s
Inspector, same as any SFX slot. Array slots (`bgm_lobby_playlist`,
`bgm_minigame_akademis`): expand the array in the Inspector and drag a file
onto each element.

**One thing that matters for array slots specifically:** the files must
have their **Loop** import setting turned **off** (Import dock → uncheck/set
to Disabled → Reimport). These tracks are chained together by code — each
one plays once, and `AudioDirector` picks the next when it naturally ends.
If a file loops on its own, it never reaches that ending and the
chain/shuffle stalls on that one track forever. Every single-track slot
above is the opposite: **Loop must stay on**, or the music stops dead the
moment the file ends once.

## Volume

Players adjust three buses in-game under PENGATURAN:

| Slider | Bus |
|---|---|
| Suara Utama | `Master` |
| Musik | `BGM` |
| Efek Suara | `SFX` |

Dragging the Efek Suara (SFX) slider previews with `tap`. Dragging the
Musik (BGM) slider previews with `pop` — deliberately routed through
the SFX bus rather than the BGM bus, so a player dragging Musik toward
zero still hears the drag respond instead of fading itself into
silence.

Volume changes are debounced: a slider fires `value_changed` on every
pixel of drag, so writes to `user://audio.cfg` are coalesced into one
write roughly 0.4 s after the dragging stops, rather than one write per
pixel. Any pending change is also flushed immediately on quit
(`NOTIFICATION_WM_CLOSE_REQUEST`) and on app pause
(`NOTIFICATION_APPLICATION_PAUSED`), so backgrounding the app on mobile
doesn't lose an in-progress adjustment. Settings are restored on
launch. A slider at 0 fully mutes its bus.

## Adding a brand new sound (code change required)

Only needed if you want a sound at a moment that has no slot yet:

1. Add `@export var sfx_yourname: AudioStream` to the `SFX` group in
   `Scripts/Audio/AudioDirector.gd`.
2. Add `&"yourname": return sfx_yourname` to `_resolve_sfx` in the same
   file.
3. Add `"yourname"` to the known-id list in
   `tests/test_audio_coverage.gd::test_every_play_sfx_id_in_the_project_is_known`
   and to the slot list in
   `tests/test_audio_director.gd::test_sfx_and_bgm_slots_are_exported`.
4. Call `AudioDirector.play_sfx(&"yourname")` where you want it.
5. Add a row to the table above.
