# Shorten — design

2026-09-14. Approved through the `/gamecode` Brief; every decision took its
bold default. Builds on EventDialogue (PR #31, merged into `Textures`).

## What the player gets

A tiny **Shorten** button in the Lobby opens a panel with two options,
**Jangan Skip Dialog** and **Skip Dialog**. With Skip Dialog on, the eight
minigames go straight from the sliding EventWarning into play. There is no
character line in between.

```
Lobby ── [Shorten] → panel: Jangan Skip Dialog | Skip Dialog
SchoolDay, midday roll
 ├ Minigame                 → EventWarning → (dialogue unless skipping) → minigame
 ├ Nasi Kotak / Hujan       → EventWarning → dialogue, always
 └ Les / Latihan / Workshop → EventWarning → Tolak | Terima dialogue, always
```

## Rules

1. **What Skip Dialog skips.** It skips every dialogue that offers no choice,
   meaning every `MODE_TAP` catalog entry, except *Kejutan Nasi Kotak Orang
   Tua* (`nasi_kotak`) and *Hujan Deras & Jalanan Licin* (`hujan`). Today that
   is exactly the eight minigame entries. The three `MODE_CHOICE` events keep
   their dialogue, because the Tolak / Terima choice lives there.
2. **Where it applies.** `SchoolDay._show_event_dialogue()` returns `true`
   before it instantiates anything, so the flow carries on exactly as if the
   player had tapped through. The EventWarning still plays.
3. **The panel.**
   - It shows which mode is on now.
   - Tapping an option sets it, saves it and closes the panel.
   - Tapping the dim background closes it without changing anything.
   - The options are an ordinary, non-destructive pair: **Skip Dialog** is a
     PrimaryButton, **Jangan Skip Dialog** a SecondaryButton.
   - Per the popup-dismiss rule, the scrim starts at `MOUSE_FILTER_IGNORE`
     and only starts catching taps after the panel has opened, so the opening
     tap cannot also close it.
4. **The button.**
   - "Tiny" is the game's smallest button step: 96 px tall, which is both
     `btn_h_s` and `touch_target_min`. It is a SecondaryButton labelled
     "Shorten".
   - It sits on the money row (y 1392–1488), between the daily-login icon
     (x ≤ 144) and the money chip (x ≥ 700). That keeps it out of the debug
     gesture's top-right 200×200 px and away from the dev-only DBG button at
     the top left.
   - The lobby tutorial's overlay covers it while the tutorial runs.
5. **The setting.** `GameSettings.skip_event_dialogue` is a bool, default
   `false`. It is saved and loaded next to the minigame-tutorial switch, as
   `[pengaturan] skip_dialog` in `user://settings.cfg`. The owner approved
   this persistence in the Brief.
6. **Grades.** Same in every grade.
7. **Labels.** "Shorten", "Jangan Skip Dialog" and "Skip Dialog", exactly as
   the owner wrote them. The status line reads "Sekarang: dialog minigame
   ditampilkan." or "Sekarang: dialog minigame dilewati."

## Units

| Unit | Change |
|---|---|
| `Scripts/GameSettings.gd` | `skip_event_dialogue` var; one `set_value` and one `get_value` line |
| `Scripts/SchoolSimulation/EventDialogueCatalog.gd` | `SHORTEN_KEEPS := ["nasi_kotak", "hujan"]`; `static shorten_skips(key) -> bool` (TAP entry, not kept) |
| `Scripts/SchoolSimulation/SchoolDay.gd` | early return in `_show_event_dialogue()` |
| `Scenes/Lobby/ShortenPanel.tscn` + `Scripts/Lobby/ShortenPanel.gd` | new popup: Scrim, a centred Card, title, status line, the two buttons; `signal closed`, `open()`, `pick(skip)`; `@tool` with editor-hint gating, like `Settings.gd` |
| `Scenes/Lobby/loby.tscn` + `Scripts/Lobby/loby.gd` | `ShortenButton`; pressing it instances the panel |

`ShortenPanel.pick()` saves only outside the editor (`Engine.is_editor_hint()`
gates `save_settings()`), so tests that exercise it never write the real
settings file.

## Tests

- **`tests/test_shorten.gd`** — new suite, `suite_name()` = `"shorten"`,
  `@tool`, no coroutines:
  - the setting defaults to off, and is saved and loaded under `skip_dialog`
  - `shorten_skips()` is true exactly for the eight minigame keys
  - `_show_event_dialogue` checks the setting before it instantiates anything
  - the Lobby button: its node, variation, label, row and neighbours, and its
    wiring
  - the panel: its buttons, variations and labels; that `pick()` writes the
    setting and emits `closed`; that the status line follows the setting; and
    that the scrim starts ignoring input
- **Existing suites extended:**
  - `confirm_pair_semantics` lists the panel as non-destructive
  - `lobby` checks the button's touch target
  - `lobby_layout` checks it clears the front-row faces
- Must stay green: `button_geometry`, `event_dialogue`, `school_day`,
  `settings`, `viewport_editability`, `script_documentation`. The last task
  runs the full suite.

## Not doing

- A Settings-screen entry.
- A per-event list of what to skip.
- Changing the week's Skip button, which already shows no dialogue.
