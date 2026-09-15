# Event cards and slide warning — design

**Date:** 2026-09-12 · **Branch:** `feat/event-cards-slide-warning` · **Status:** approved in brainstorm, awaiting spec review

## Goal

Three changes:

1. **Event picker cards.** The student cards in `EventStudentSelectDialog` become the DaySummary card, showing each student's **current** stats.
2. **Item-screen cards.** `ApplyStudentRow` (the item "Pakai" screen) gets the same DaySummary card. It keeps its current **content** (only the stats the item boosts, the before/after preview, the LELAH state); only the look changes.
3. **Slide warning.** The mid-day warning becomes a full-screen mustard panel that slides right-to-left through the screen, carrying the megaphone art and one caption line. It replaces **both** `EventWarning` (the three minigame banners) and `EventAnnouncement` (random events).

Source art (Google Drive, owner's `icon` folder):

- `eventwarning_icon.png`: a 1080×1920 transparent canvas. The art occupies x 179–901, y 472–1190 (723×719). The outline is navy `#1D196E` and the fill white.
- `mockups/mockup_eventwarning.png`: the icon centred on a flat `#9E8830` background.
- `mockups/mockup_eventdialogue.png`: **out of scope**. It gets its own brainstorm and spec later.

## Decisions taken in the brainstorm

| Question | Decision |
|---|---|
| Event dialogue mockup | Not in this spec. |
| What the warning shows | The mockup's panel and icon, plus **one caption line**: the subject for minigames ("KEGIATAN AKADEMIS!"), the event's name for events. |
| Panel colour | Mustard `#9E8830` for every warning. The per-subject tint is dropped. |
| Slide | **Right to left, pass-through.** In from the right edge, hold, out the left edge. |
| How the cards share the look | **Reuse the real card.** Both wrappers instance `DaySummaryStudentRow.tscn`; there is one card design in the game. |
| Event card content | Current stats ("42/60"). The event's preview is layered on when the card is selected. |
| Item card content | Only the boosted stats; selecting previews the gain. The LELAH state is kept. |

## 1. The shared card

### 1.1 `DaySummaryStudentRow` gains three entry points

The existing API is **unchanged**: `setup_row`, `setup_week_row`, `play_gain`, `play_week_gain`, `gained_ground` and `format_needs_delta`. `DaySummaryPopup` and `ResultCheckup` behave exactly as today.

Additions:

| Call | Effect |
|---|---|
| `setup_current_row(student: StudentData)` | Name, avatar, both needs bars at the student's current values (with their icons and tier words), both needs chevrons hidden. Each stat row shows its standing value through `DaySummaryStatRow.set_standing` (below). |
| `preview_stat(stat_key: String, delta: float, capped := false)` | Forwards to the stat row currently showing `stat_key`. `delta == 0` returns it to the standing view. |
| `preview_need(need_key: String, delta: float)` | The energy or mood bar travels to `clamp(current + delta, 0, 100)`. Its chevron points up or down by the delta's sign (the rule `_show_needs_delta` already uses), and the delta label stays hidden. `delta == 0` returns the bar to current and hides the chevron. |
| `show_only(keys: Array)` | Shows only the listed keys (`akademis`, `seni_budaya`, `olahraga`, `energy`, `mood`); an empty array shows everything. **The visible skills fill the stat-row slots top-down in `STAT_ORDER`**, so one boosted skill sits in the top slot rather than leaving gaps; the unused rows hide. The needs bars keep their fixed slots (energy above mood) and simply hide when not listed. |

`setup_current_row` caches each key's current value and target so the previews can compute without the `StudentData` in hand. **Call order:** `setup_current_row` first, then `show_only`. Because `show_only` can move a skill into a different row, it re-writes each reassigned row's standing view (`set_standing`) from those cached values.

### 1.2 `DaySummaryStatRow` gains a standing mode

- `static func format_standing(current: float, target: float) -> String` returns `"42/60"` (both rounded, no sign).
- `set_standing(stat_key, target, current)` sets the same icon and track variation as `set_stat`. The value becomes `format_standing(current, target)`, the chevron is hidden, and the track is set to `track_ratio(current, target)`. It caches `current` and `target` for the preview.
- `show_preview(delta: float, capped := false)`:
  - `delta == 0` and not capped: restore the standing text and track.
  - `capped`: the value reads `MAKS` and the chevron is hidden.
  - Otherwise: the value reads `format_value(delta, target)` (the card's existing `+15/60` delta format), the chevron shows when `delta > 0`, and the track travels to `track_ratio(current + delta, target)` with `Juice.fill_bar`. In the editor the value is set directly.
  - **No star burst and no tally cue.** Those are the day summary's reward moment, and a preview toggled on and off must not spam them.

### 1.3 A shared wrapper base: `StudentCardButton`

A new `@tool` `class_name StudentCardButton extends Button` holds the behaviour both wrappers share:

- **Toggle.** `toggle_mode = true`, `focus_mode = none`. The whole card is the tap target (the pattern `EventStudentCard` already uses).
- **Width fit (Pattern C).** On `NOTIFICATION_RESIZED` and on entering the tree:
  - measure the wrapper's own `size.x` (never the viewport);
  - set the `Card` child to position (0, 0), size `card_design_size` and scale `s = min(max_card_scale, size.x / card_design_size.x)`;
  - set `custom_minimum_size.y = card_design_size.y * s`.
  
  This owns the instanced card's rect outright, so the "instanced root snaps to top-left, zero-size" hazard (authoring guide, Pattern C) cannot bite.
- **Taps reach the Button.** In `_ready` (ungated), set `mouse_filter = IGNORE` on `Card` and every descendant. This is done at runtime because overrides on an instance's children are not saved. `DaySummaryStudentRow.tscn` itself is not changed, so the day summary's tap-to-dismiss behaves as today.
- **Selectable state.** `set_selectable(on)` moves here from `EventStudentCard`: set `disabled`, drop any selection, set `modulate.a` to 1.0 or `unavailable_alpha`, and tint the avatar with `unavailable_avatar_tint`.
- **Select badge.** `SelectBadge` follows `button_pressed`. The badge sits **inside** the card's bounds (today's badge hangs 18 px below the card).
- **Exports** (each with a `##` line):
  - `card_design_size: Vector2 = Vector2(992, 410)`: the card art's native size.
  - `max_card_scale: float = 1.0`: never upscale past the art.
  - `unavailable_alpha: float = 0.55`.
  - `unavailable_avatar_tint: Color = Color(0.7, 0.7, 0.75, 1.0)`.

The badges are authored **under the `Card` instance**, in card-design coordinates, so they scale with it.

### 1.4 `EventStudentCard`: the event picker's wrapper

```
EventStudentCard   StudentCardButton, variation EventSelectCard
└ Card             DaySummaryStudentRow.tscn instance
   ├ SelectBadge      icon_check.svg, inside the bottom-right corner
   ├ TiredBadge       icon_tired.svg
   └ SpecialtyBadge   icon_star.svg
```

- **Same public API as today**, so `EventStudentSelectDialog.gd` needs no logic change: `selection_changed(selected)`, `setup(student, category)`, `set_preview(stat_delta, energy_delta, mood_delta)`, `student()`, `is_selected()`, `set_selectable(on)`.
- `setup` calls `Card.setup_current_row(student)` and sets the tired and specialty badges as today. A tired student is unselectable.
- `set_preview` calls `Card.preview_stat(key_for(category), stat_delta)`, `Card.preview_need("energy", energy_delta)` and `Card.preview_need("mood", mood_delta)`.
- **Fixes the drift from DaySummary** as a side effect:
  - the needs bars get their icons (today's copy never set them);
  - the NameLabel width matches the day summary;
  - the badge sits back on the card;
  - the preview animates.
- The dialog cards change from `SIZE_SHRINK_CENTER` to `SIZE_FILL`, so the fit pass can read the available width.

### 1.5 `ApplyStudentRow`: the item screen's wrapper

```
ApplyStudentRow    StudentCardButton   (was a PanelContainer with a CheckBox)
└ Card             DaySummaryStudentRow.tscn instance
   ├ SelectBadge   icon_check.svg
   └ LelahChip     DaySummaryBadge.tscn, text "LELAH", tinted state_danger, hidden unless tired
```

- **Content kept**:
  - `setup(p_student: Dictionary, boosts: Dictionary)` (same signature), the `KEY` map and the `tired_energy_threshold` export;
  - `selection_changed` (no arguments), `set_preview(active)`, `is_selected`, `can_select`, `set_selected`, `selected_student_id` and the `student` var;
  - the `select` sound on toggle.
- **Data bridge.** The row converts its roster Dictionary through a new `GameState.student_data_from_dict(dict) -> StudentData`, which is the body of `convert_to_student_data_array()`'s loop extracted verbatim. The array function then calls it. Behaviour is unchanged; one conversion rule exists instead of two.
- **`setup`:**
  - `Card.setup_current_row(sd)` and `Card.show_only(boosted keys)`;
  - a tired student (energy at or below the threshold) gets the `LelahChip` and `set_selectable(false)`.
  
  The chip is an **authored node**; today it is loaded and instanced at runtime.
- **`set_preview(active)`:** for each boosted key, `after = clamp(cur + boost, 0, 100)` and `delta = after - cur`.
  - Skills call `Card.preview_stat(key, delta, capped = cur >= 100)`, so a stat already at 100 reads `MAKS` as today.
  - Needs call `Card.preview_need(key, delta)`.
  - When inactive, every delta is 0.
  - The old 1.02 scale-up is dropped; the select badge and the pressed stylebox show selection.
- **Readout change** (a visual change, not a content change):
  - the value is the DaySummary pair, `current/target` idle and `+N/target` selected (was `cur/100` and `cur ➜ after (+N)`);
  - skill tracks read against the grade target like everywhere else on the card, not against 100.
- **`ApplyItemScreen`:**
  - its `Rows` VBox lays the rows at full width and the fit pass scales each card to it (about 944 px wide, so s ≈ 0.95);
  - Select All, the confirm count and the payoff (RewardBurst, floating text, confetti) keep working through the same row API.

## 2. The slide warning

### 2.1 Scene

The scene keeps the path `Scenes/SchoolSimulation/EventWarning.tscn`, so SchoolDay's `event_warning_scene` export and its fallback `load` path still hold. Its contents are rebuilt:

```
EventWarning   Control, full rect, mouse_filter STOP (swallows taps while it runs), @tool
└ Panel        Panel, variation EventWarningPanel, anchors full rect (layout_mode 1)
   └ Content   VBoxContainer, centred, separation 32
      ├ Icon      TextureRect, texture = icon_texture, expand ignore-size, keep-aspect-centred, min height 560
      └ Caption   Label, variation EventWarningCaptionLabel, centred, autowrap
```

- **Icon asset:** `Assets/Images/SchoolDay/eventwarning_icon.png`, the Drive file **cropped to its art** (723×719 plus a 16 px transparent pad on each side), so the TextureRect's aspect is the art's rather than the empty canvas.
- **Export:** `@export var icon_texture: Texture2D` defaults to it (art stays swappable from the Inspector).
- **Tokens** (`DesignTokens.gd`, each with a `##` line):
  - `event_warning_bg = #9E8830` (the mockup's panel);
  - `event_warning_ink = #1D196E` (the icon's outline navy).
- **Variations** (`ThemeFactory.gd`):
  - `EventWarningPanel`: a flat `StyleBoxFlat` in `event_warning_bg`, no border, no radius.
  - `EventWarningCaptionLabel`: display font (Boohong), white fill, `event_warning_ink` outline. The font size is the same token `DisplayLabel` reads, so the caption matches the game's other display headings; the outline is 16 px.
  
  `EventWarningCaptionLabel` joins `DISPLAY_ROSTER` in `tests/test_theme_factory.gd`, which pins the display-font roster in both directions.
- **Contrast.** White on `#9E8830` is about 3.5:1 and the navy outline about 4.3:1. That passes the 3:1 large-text floor for a display-size caption; a test pins it.
- **Retired:** the hazard stripes, the `KiperIdle.jpg` background, the caution emoji fallback and the runtime-built icon/background. The scene is fully authored and nothing is built at runtime.

### 2.2 Motion and API

`play_warning(caption: String) -> void` is awaitable and runs these steps in order:

1. Set the caption text and play `event_announce` once. This is the one cue for every warning; SchoolDay's extra `popup_open` goes.
2. Slide the Panel from `x = +W` to `0` over `slide_in_duration`, easing out.
3. `Juice.pop_in(Icon)` as it lands; the caption fades in with it.
4. Hold for `hold_duration`.
5. Slide from `0` to `-W` over `slide_out_duration`, easing in.
6. `queue_free()`.

- `W` is the root's own `size.x` (Pattern C: measure the root, never the viewport).
- **Exports**, each documented: `slide_in_duration = 0.35`, `hold_duration = 1.1`, `slide_out_duration = 0.35`, and `icon_texture`. Total is about 1.8 s (today: 3.75 s for the minigame banner, 2.27 s for the announcement). Easing can later be tuned through the `motion-lab` skill.
- **Test seam:** `static func panel_x(stage: StringName, width: float) -> float` returns `+width` for `&"enter"`, `0` for `&"rest"` and `-width` for `&"exit"`. `play_warning` tweens between those values, so a test pins the direction without awaiting.
- No tap-to-skip. `_ready`'s side effects are gated behind `Engine.is_editor_hint()`; the tweens only run from `play_warning`.

### 2.3 SchoolDay

- `_show_event_warning(caption: String)` drops its `accent_color` parameter and its `popup_open` call.
- The three minigame calls pass `"KEGIATAN AKADEMIS!"`, `"KEGIATAN OLAHRAGA!"` and `"KEGIATAN SENI BUDAYA!"`. Their subject-colour tokens are no longer read here.
- `_show_event_announcement` is **deleted**. Its five call sites (the Nasi Kotak and Hujan events, `_handle_interactive_event`, and `force_event`'s two) call `_show_event_warning(title)`.
- The `event_announcement_scene` export is deleted, together with `SchoolDay.tscn`'s assignment of it and the ext_resource. **This edit goes through the editor** (`scene_open` → property cleared → `scene_save`), never by hand.
- The three interactive event titles lose their trailing emoji (📚 ⚽ 🎨) in both `_trigger_random_event` and `force_event`: "Les Tambahan Akademis", "Latihan Olahraga Ekstra", "Workshop Sanggar Seni". These strings now reach the caption, and the project bans emoji as iconography.

### 2.4 Deleted

- `Scenes/SchoolSimulation/EventAnnouncement.tscn` and `Scripts/SchoolSimulation/EventAnnouncement.gd` (+ `.uid`).
- `Scenes/SchoolSimulation/AnnouncementBurst.tscn` and `Scripts/SchoolSimulation/AnnouncementBurst.gd` (+ `.uid`). Only `EventAnnouncement` uses them.
- `Assets/Images/UI/Placeholders/icon_event_warning.png`, `icon_event_announce.png` and `bg_event_announce.png` (+ `.import`), **each only if a grep at deletion time finds no other reference**.
- The hazard-stripe shader, **only if** nothing else references it after the two scenes change.
- `KiperIdle.jpg` is **kept**. It is minigame art; the warning simply stops using it.
- `tests/test_viewport_editability.gd`'s `ALLOWED` loses its `EventWarning.gd` and `EventAnnouncement.gd` entries (2 each).
- Stale comments are updated: `AudioDirector.gd` (the `event_announce` cue stays), `ThemeFactory.gd:641`, `EventStudentSelectDialog.gd`'s header, and `StudentSummaryCard.gd`'s header. `test_student_summary_card.gd:91` currently passes only because of a comment in the dialog script; **delete that assertion**. The event-card tests in `test_day_summary.gd` already pin what the dialog instantiates, and the dialog no longer uses `StudentSummaryCard` at all.

## 3. Testing

Tests are written first, one task at a time, and follow the established source-scan and live-structure patterns. Every new or changed script is `@tool` with a `##` header and a `##` line on each `@export`.

**Updated:**

- `test_day_summary.gd`: the event-card tests now expect the parts under `Card/`, and the root to be a `StudentCardButton` / `EventStudentCard` with `toggle_mode`. The "children do not swallow the tap" test adds the card to the tree before checking, because the ignore is applied in `_ready`.
- `test_event_student_card_tired.gd`: the alpha comes from `unavailable_alpha`.
- `test_apply_student_row.gd`: the rewrite keeps the same four behaviours (the key map, only boosted stats visible, the preview raises then restores, a tired student cannot be selected), asserted against the Card's rows and bars.
- `test_light_ground_text.gd:178,197`: the two contrast checks are retargeted from the old `BarRow*/DeltaLabel` to the card's preview readout, `Card/StatRow1/Value`. They measure it against the card art before, during and after the preview, the same three moments they check today.
- `test_event_polish.gd`: the announcement tests are removed; the warning tests assert the new icon path and that there is no emoji.
- `test_school_day.gd`: remove `EventAnnouncement` from the scene and script lists; the hazard-stripe test is removed with the stripes.
- `test_viewport_editability.gd`: the `ALLOWED` entries described above.
- `test_theme_factory.gd`: `DISPLAY_ROSTER` gains `EventWarningCaptionLabel`.

**New:**

- `DaySummaryStatRow.format_standing` / `set_standing` / `show_preview`, including `MAKS` and the absence of the burst and the cue.
- `DaySummaryStudentRow.setup_current_row`, `preview_stat`, `preview_need` and `show_only`, including slot order when only one skill is boosted.
- `StudentCardButton`: the loaded Card rect after the fit at 992 and at 944 wide (test the **loaded** rect, per the authoring guide), the minimum height tracks the scale, and every Card descendant ignores the mouse once in the tree.
- `GameState.student_data_from_dict` equals `convert_to_student_data_array()`'s output for the same roster entry.
- `EventWarning`:
  - the structure and variations;
  - `icon_texture` is the cropped art, with an aspect of about 1:1;
  - `panel_x` enters from `+W` and exits to `-W`;
  - `play_warning` references `event_announce` and not `popup_open`;
  - the caption's contrast on the panel is at least 3:1.
- Both tokens and both variations are present in the baked theme.
- SchoolDay: no `_show_event_announcement`, no `event_announcement_scene`, the three minigame captions present, and no emoji in the event titles.

## 4. Order and hazards

- **Scene work first, script work second** (CLAUDE.md 4b): `scene_save` flushes stale script tabs. Once a script has been patched, restart the editor before the next `scene_save`.
- **Tokens and rebake.** New `@export`s on `DesignTokens` need a **full editor restart** before the rebake picks them up. Rebake alone (not next to scene operations) and diff the bake before committing (memory notes).
- **Instanced children.** Overrides on an instance's children are dropped on save. The badges are new nodes under the `Card` instance (saved fine); nothing overrides the card's own internals.
- **Verification** is live, per CLAUDE.md: seed the playtest state, then force an event and apply an item through the debug overlay, and capture screenshots at full size.

## 5. Noticed, not fixed here

- `EventStudentSelectDialog.gd:122` looks up `Background`, but the node is `BackgroundDim`, so `bg_event_dialog.png` never shows. The ratchet's single BASELINE count for that file is this dead path.
- `test_result_checkup.gd:462` asserts a string that no longer exists in the code, so it always passes.
- `authoring-guide.md:222` still lists `EventStudentSelectDialog.gd (11)`; the baseline is now 1.

## 6. CLAUDE.md

- The placeholder list drops the event-popup icons and backgrounds this work deletes; `bg_event_dialog.png` stays.
- `eventwarning_icon.png` is real art, so it is not listed.
- The completed pass goes to `docs/superpowers/CHANGELOG.md`, not to CLAUDE.md.
