# Audio

- `SFX/` — short one-shot sounds (16 slots, all filled)
- `BGM/` — looping music (4 slots, currently empty)

**Every file in `SFX/` right now is a placeholder.** All of it is free
for commercial use (see `SFX/LICENSES.md` and `Kenney_License.txt`), and
all of it is meant to be replaced. `BGM/` has no files in it yet — the
four slots are wired up and ready, waiting for tracks.

## How to swap a sound — the whole procedure

1. Drop your `.ogg` into `SFX/` or `BGM/`. Keep any filename you like;
   the slot name is what matters, not the filename.
2. Open `Scenes/Audio/audio_director.tscn` in the Godot editor.
3. Drag your file from the FileSystem dock onto the matching slot in the
   Inspector.
4. Save the scene. Done — no code changes, ever.

For BGM only, one extra step: select your file in the FileSystem dock,
open the **Import** tab, tick **Loop**, and click **Reimport**. Without
this the track plays once and stops.

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

## BGM slots

The four `bgm_*` slots on `audio_director.tscn` are wired into the game
already — every screen calls `AudioDirector.play_bgm(&"...")` at the
right moment — but the slots themselves are empty until the audio team
drops files in. Until then, those screens simply play no music.

| Slot | Plays on | Character to aim for |
|---|---|---|
| `bgm_menu` | MainMenu, Settings | warm, welcoming, unhurried |
| `bgm_lobby` | Lobby, StudentCard, StudentList, AturJadwal | cheerful, curious, mid-tempo |
| `bgm_simulation` | SchoolDay and its minigames | gently busy, low-distraction — this one plays longest |
| `bgm_result` | SemesterEnd | reflective, proud, softer |

The four lobby-family screens share one track deliberately, and
`AudioDirector.play_bgm` no-ops when the requested id is already
playing — so moving between them never restarts the music.

Tracks crossfade automatically (0.8 s by default, tunable on the
`default_bgm_fade` slot in the same inspector).

To fill a slot: drop the `.ogg` into `BGM/`, drag it onto the matching
slot in `audio_director.tscn`'s Inspector, then select the file in the
FileSystem dock, open the **Import** tab, tick **Loop**, and click
**Reimport**. Save the scene when done.

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
