# Reset Progress in Settings — design + implementation handoff

**Date:** 2026-10-01 · **Branch:** `feat/reset-progress-setting` ·
**Status:** approved in chat (owner's pick "A", tomato) — **built 2026-10-01**
(what changed against this handoff: CHANGELOG, "Reset Progres in Settings")

A player-facing "Reset Progres" entry in Settings that wipes all progress and
restarts the game from the Splashscreen. The debug-only **Forget Session**
(`DebugManager._forget_session`) is the existing developer equivalent; this is
its proper in-game counterpart.

## The decision (owner-approved)

- **Button colour: Option A — tomato `DangerButton`.** The design system's
  rule is "tomato is danger" (`ThemeFactory.gd` adds `DangerButton` from
  `tokens.accent_tomato`). A full progress wipe is the most destructive action
  in the game, so it earns the strongest signal.
  - Note the tension we chose *against*: the existing destructive confirm,
    `ContinuePopup`'s "Ya, mulai baru", uses `PrimaryButton` (mint). That popup
    is the exception; tomato is the rule. Do **not** "make it consistent" by
    switching this to mint.
- **Reset wipes everything** — session state *and* on-disk saves (the #179
  save system, inventory, achievements). One call already does all of it:
  `GameState.forget_session()` (`Scripts/GameState.gd:486`):

      func forget_session() -> void:
          reset_run()            # in-memory roster, week, grade, money, schedules
          SaveGame.delete_save() # #179 save file
          Achievements.reset()   # achievement progress

- **After the wipe: a longer fade, then restart from the Splashscreen.**
  `Transition.change_scene("res://Scenes/Splashscreen/Splashscreen.tscn",
  Transition.Style.FADE, 1.3)` — a FADE (not the default WIPE) at ~1.3s, longer
  than a normal scene change, so it reads as a deliberate "resetting…" beat.
  The game does not normally boot through the Splashscreen (it boots straight to
  MainMenu), so this is intentionally a *fuller* fresh start than a cold launch.
  Splashscreen auto-routes onward to MainMenu (`Scripts/Splashscreen/Splashscreen.gd:48`),
  so it does not dead-end.

## Files to touch

### 1. New popup scene — `Scenes/UI/ResetProgressPopup.tscn` (+ `Scripts/UI/ResetProgressPopup.gd`)

Clone the structure of `Scenes/MainMenu/ContinuePopup.tscn` — it is the exact
Scrim → NotebookFrame → confirm-page pattern — but as a **single page**. Fastest
path: `scene_open` ContinuePopup, `scene_manage(save_as,
res://Scenes/UI/ResetProgressPopup.tscn)`, then in the editor:

- Delete the `Layout/Ask` page (keep only `Layout/Confirm`).
- `Frame` is the `NotebookFrame` instance — set its `title_text = "RESET PROGRES"`.
- `Layout/Confirm/Warning` (`H2Label`): text `"Apakah Anda yakin?"`.
- Add a `CaptionLabel` under Warning: `"Semua progres akan dihapus dan tidak bisa
  dikembalikan."` (KBBI-natural; keep it one calm sentence).
- `Layout/Confirm/Buttons/CancelButton` stays `SecondaryButton`, text `"Batal"`.
- `Layout/Confirm/Buttons/ConfirmButton`: change variation to **`DangerButton`**,
  text `"Ya, Reset"`.
- Rename the root node to `ResetProgressPopup` and attach the new script
  (replace the inherited `ContinuePopup.gd`).

`Scripts/UI/ResetProgressPopup.gd` — mirror `Scripts/MainMenu/ContinuePopup.gd`
(it is `@tool`, `class_name`, `extends CanvasLayer`, pure signal wiring in
`_ready()` ungated so the suite can press the buttons; the pop-in is gated behind
`Engine.is_editor_hint()`). Shape:

- `signal reset_confirmed` (emitted by ConfirmButton), `signal dismissed`
  (Batal / Android back).
- `func open() -> void` — show the Scrim, pop the frame in about its centre
  (reuse ContinuePopup's `_center_pivot` / `LAYOUT_PASSES` handling).
- `func close() -> void` — hide.
- Decides nothing itself: Settings listens and routes (same division of labour
  as ContinuePopup ↔ MainMenu).

Every `##` doc rule applies (file header, a `##` on every `@export`) —
`tests/test_script_documentation.gd` enforces it. No `theme_override_*`; use the
variations above. Popup lives in `NotebookFrame` per the popup rule
(`tests/test_popup_frames.gd` is the roster — add this popup to it).

### 2. Settings — `Scenes/UI/Settings.tscn`

Add a new card section at the end of
`SafeArea/Frame/Scroll/Pad/Sections` (after `DisplayCard`), following the
existing card pattern (a `VBoxContainer` → `Margin` → `VBox` → a
`CardSectionLabel` + content):

- `SectionLabel` (`CardSectionLabel`): `"DATA"`.
- A `Button` with variation **`DangerButton`**, text `"Reset Progres"`, unique
  name `%ResetProgressButton`.
- Instance `ResetProgressPopup.tscn` into the scene (hidden by default) — static
  chrome belongs in the `.tscn`, never built at runtime (second visual rule).

### 3. Settings wiring — `Scripts/UI/Settings.gd`

- `@onready var _reset_button: Button = %ResetProgressButton`
- `@onready var _reset_popup := %ResetProgressPopup`
- In `_ready()` (ungated wiring): `_reset_button.pressed.connect(_reset_popup.open)`;
  `_reset_popup.reset_confirmed.connect(_on_reset_confirmed)`.
- `func _on_reset_confirmed() -> void:` → `GameState.forget_session()` then
  `Transition.change_scene("res://Scenes/Splashscreen/Splashscreen.tscn",
  Transition.Style.FADE, 1.3)`.

## Tests

Follow the project's source-scan pattern (most UI can't instantiate headless).

- Extend the Settings suite (`tests/test_*settings*` / `test_pengaturan`):
  assert the `%ResetProgressButton` exists with `DangerButton`, and that
  `Scripts/UI/Settings.gd` source wires `forget_session`, `Style.FADE`, and the
  Splashscreen path.
- New `tests/test_reset_progress_popup.gd` modelled on the ContinuePopup suite:
  instance the popup, assert the title/question/caption copy, the two button
  variations (`SecondaryButton` + `DangerButton`), and that pressing
  ConfirmButton emits `reset_confirmed`.
- Add the popup to `tests/test_popup_frames.gd`'s roster.

## Build order + hazards (read `CLAUDE.md` "Working efficiently here")

1. **Start from a freshly restarted editor** — do not build on an editor left
   open across pulls (it writes stale tabs back on `scene_save`).
2. Scene work first, script work second. After any `scene_save`, check
   `git diff HEAD -- '*.gd'` for files you weren't editing.
3. After patching a script, restart the editor before the next `scene_save`.
4. The editor churns `Resources/Minigames/HowTo/*.tres` and
   `Scripts/Shaders/illustration_grade_*.tres` on boot/play — `git checkout --`
   those; they are not part of this change.
5. Finish with `ship-pr`.
