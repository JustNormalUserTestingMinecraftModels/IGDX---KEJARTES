# Save system and "Lanjutkan" — design

Approved in conversation, 2026-10-01. Plan:
`docs/superpowers/plans/2026-10-01-save-system.md`.

## The request

> if a player already plays before it will autosave the progress
> (everything, student select, items, money, stat progress), and a new
> notification after title screen will appear that says "mau melanjutkan
> permainan sebelumnya?" with two options "ya lanjutkan" dan "permainan baru"

Then, on the first design section: "it also saves from daily results".

This reverses CLAUDE.md's "only the inventory reaches disk" rule, at the
owner's request. CLAUDE.md's Persistence paragraph is rewritten to match.

## Decisions

| Question | Decision |
|---|---|
| Where does Continue resume? | **Hub screens save on every visit**, and Continue opens the Lobby. **SchoolDay also saves after each day's result**, and Continue opens SchoolDay on the next day. Nothing in the middle of a day, and nothing in the end-of-grade chain, is ever written. |
| What does Permainan baru wipe? | The whole run: roster, grade, week, money, schedules, stats, items, skins and tutorial flags. **Achievements and Settings stay.** A confirm page guards it. |
| Storage | One versioned `ConfigFile`, `user://savegame.cfg`, owned by a static `SaveGame` script. `inventory.cfg` is merged into it. |

## Architecture

### `Scripts/Save/SaveGame.gd` (`class_name SaveGame`, static, RefCounted)

- `SAVE_KEYS`: the `GameState` fields that are saved. `EXCLUDED` maps each
  field that is not saved to the reason why. A ratchet test fails when a
  `GameState` field is in neither list, as `EndGameRehearsal.SNAPSHOT_KEYS`
  already does for rehearsals.
- Saved: `approved_students`, `returned_from_student_card`, `day_schedules`,
  `minigame_gain_this_week`, the shop's week/stock/sold/promo fields,
  `minggu_ke`, `current_grade`, `lobby_tutorial_completed`,
  `tutorials_bypassed`, `seen_minigame_how_to`, `headmaster_beats_seen`,
  `grade7_student_ids`, `grade8_student_ids`, `equipped_skins`,
  `skin_unlock_overrides`, `player_money`, `inventory`, `pending_earnings`,
  `ad_debt`, `daily_login_day`, `last_claim_date`, plus `run_stats` via
  `RunStats.to_dict()` and the screens' static first-run tutorial flags
  (`SaveGame.TUTORIAL_FLAGS`; final review: a relaunch reset them, so a
  resumed run replayed AturJadwal's and StudentList's walkthroughs).
- Not saved: `next_scene`, `selected_student`, `selected_day`
  (screen-local); `run_failed` (StatCheck decides it fresh); `max_minggu`
  (derived from `current_grade`); `is_game_beaten`,
  `debug_level_select_enabled` (GameSettings persists them already);
  `pending_week_resume` (transient hand-off, see below).
- File layout: `[meta]` holds `version`, `grade`, `week`, `max_week` and
  `day`; `[state]` holds one key per `SAVE_KEYS` entry plus `run_stats` and
  `tutorial_flags`;
  `[week]` is present only while a week is in progress.
- Pure functions over a `ConfigFile` (`write_state`, `read_state`,
  `summary_for`, `resume_scene`) carry all the logic and are what the tests
  exercise. The disk functions (`save`, `load_save`, `has_save`,
  `delete_save`, `read_legacy_inventory`) are thin wrappers that no-op under
  `Engine.is_editor_hint()`.
- Writes are atomic: save to `savegame.tmp`, then rename it over
  `savegame.cfg`.
- Reading restores `current_grade` first, since its setter recomputes
  `max_minggu`. Typed arrays come back through `.assign()`, and
  `inventory_changed` is emitted at the end.
- A file that fails to parse, lacks `[meta] version`, carries a version
  newer than `SaveGame.VERSION`, or holds a value whose type does not fit its
  field (final review: checked before anything is applied) is unusable. `has_save()` returns false,
  the file is renamed to `savegame.bad.cfg`, and a warning is pushed. The
  game never crashes on a bad save.

### Checkpoints

1. **Hub screens.** `Transition.change_scene(path)` calls
   `SaveGame.checkpoint(from_path, to_path)` where it called
   `GameState.save_inventory()`. That saves when either path is in
   `SaveGame.HUB_SCENES`: Lobby, AturJadwal, ShopHub, Koperasi,
   CosmeticShop, Inventory, ReportCard. This is what makes the cases below
   save:
   - AturJadwal → SchoolDay saves the planned week.
   - SchoolDay → Lobby saves the finished week.
   - StudentCard → Lobby saves the approved roster.
2. **Pause or quit.** `GameState._notification` calls
   `SaveGame.save_if_at_hub(current_scene_path)`. In SchoolDay or the
   end-of-grade chain it writes nothing, and the last checkpoint stands.
3. **Daily results.** In `SchoolDay._run_single_day()`, right after
   `await _show_day_summary(day_name)`, it calls
   `SaveGame.save(_week_snapshot())` with `resume_day = current_day + 1`.
4. **RunResult.** After `_apply_progression()`, `SaveGame.save()` runs when
   the destination is StudentCard. When it is MainMenu (a Kelas 7 loss, or
   the game beaten), `SaveGame.delete_save()` runs instead.
5. A plain `SaveGame.save()` (no week) drops any `[week]` section, so
   leaving the week clears it.

### Week in progress

- `[week]` holds:
  - `resume_day`, the next day index (0–5; 5 means the week's days are
    done)
  - `minigames_played`, `events_triggered`, `max_events`,
    `max_minigames`
  - `manager`, from `StudentManager.to_save_dict()`: each student's live
    and initial stats by id, plus `minigame_history` and `daily_stat_log`
- On Continue, `SaveGame.load_save()` puts `[week]` into
  `GameState.pending_week_resume`.
- `SchoolDay._ready()` calls `resume_simulation(week)` instead of
  `start_simulation()` when that dict is non-empty, and empties it.
  - `StudentManager.restore_from_save(d)` rebuilds from GameState
    (portraits, targets, quirks), then overlays the saved stats by id.
  - `resume_day == 5` goes straight to `_on_week_complete()`, the weekly
    report. In the final week, that leads on to TesNotice as usual.

### Title screen

- `MainMenu._start_game()` opens the `ContinuePopup` (an instanced,
  hidden child of `MainMenu.tscn`) when `SaveGame.has_save()`. Otherwise
  it runs today's path.
- `Scenes/MainMenu/ContinuePopup.tscn` is a NotebookFrame **dialog** in
  `Scrim/Safe/Center/Frame`, with two pages:
  - **Ask page:**
    - the title "Mau melanjutkan permainan sebelumnya?"
    - a summary line from `SaveGame.summary_for()`: "Kelas 8 · Minggu 3/6",
      plus " · Kamis" while a week is in progress
    - `PrimaryButton` "Ya, lanjutkan" and `SecondaryButton` "Permainan baru"
  - **Confirm page:**
    - "Yakin? Progres lama akan hilang."
    - `PrimaryButton` "Ya, mulai baru" and `SecondaryButton` "Batal"
- Android back and Batal step back a page, and from the Ask page close the
  popup.
- **Continue** runs `SaveGame.load_save()`, then
  `Transition.change_scene(SaveGame.resume_scene(...))`:
  - with a week in progress → SchoolDay
  - with `returned_from_student_card` set → Lobby
  - otherwise → StudentCard
- **Ya, mulai baru**:
  - `GameState.reset_run()` (today's `forget_session()` minus
    `Achievements.reset()`; `forget_session()` becomes `reset_run()` plus
    the achievement wipe)
  - `SaveGame.delete_save()`
  - the legacy carry-over below
  - today's new-game path (LevelSelect or CutScene)

### Legacy inventory

- `GameState.load_inventory()` and `save_inventory()` and their boot and
  notification calls are removed. The pure `_write_inventory_to` and
  `_read_inventory_from` helpers go too.
- `SaveGame.read_legacy_inventory()` reads `user://inventory.cfg` and
  returns its items. The first `save()` that carries them deletes the file
  (final review: deleting it on read lost the items to a quit before the
  first save).
- Starting a new game (from the popup, or a first tap with no save) merges
  those items into `GameState.inventory` once. Nobody loses pre-update
  purchases.

## Known trade-offs

- Quitting mid-day replays that day from its morning, so that one day's
  minigame and event rolls can be rerolled. Mid-day saves were not asked
  for.
- The debug overlay's Seed Playtest State, followed by any hub visit, saves
  the seeded run over the real one. It is debug-only, and Forget Session
  wipes it.
- `achievements.cfg` and `settings.cfg` are untouched.

## Testing

- **New suite `tests/test_save_game.gd`:**
  - a round trip of every `SAVE_KEYS` field through `write_state` →
    `read_state` on a `ConfigFile` (int dictionary keys and typed arrays
    included)
  - the completeness ratchet
  - `RunStats.to_dict`/`from_dict` round trip
  - the week section round trip
  - `resume_scene` table
  - summary text
  - rejecting a newer version
  - a scan that the disk functions gate on `is_editor_hint`
- **`StudentManager`:** a `to_save_dict` → `restore_from_save` round trip
  on a seeded roster.
- **Popup:** structure tests, plus a row in `test_popup_frames`.
- **Source scans:**
  - MainMenu's branch
  - Transition's `SaveGame.checkpoint` call
  - SchoolDay's daily save sitting after the day summary
  - RunResult's save/delete
- **`test_end_game_rehearsal`:** `pending_week_resume` joins
  `_DELIBERATELY_UNSNAPSHOTTED`.
- **Live check in the game:**
  1. Seed, plan a week, and play to Rabu's result.
  2. Stop the project, then relaunch.
  3. Tap the title. The popup should show "Kelas 7 · Minggu 1/4 · Kamis".
  4. Choose Lanjutkan. SchoolDay should open on Kamis, and the weekly
     report at the end should list Senin–Jumat.
  5. Relaunch, choose Permainan baru, then Ya. LevelSelect or CutScene
     should open with an empty inventory and achievements intact.
