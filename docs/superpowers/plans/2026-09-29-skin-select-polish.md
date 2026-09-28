# Skin Select Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The skin picker shows only *your class* (the approved roster, 2/3/4 by grade), centred under a "Kelasmu · N murid" header, in the scrapbook look: a ruled paper tray with washi tape, taped photo-card tiles with name captions, a lipped mint TERAPKAN with a "PAKAI!" sticker, and SFX on select, snap and apply.

**Spec:** `docs/superpowers/specs/2026-09-28-skin-select-polish-design.md` (the collaborator's handoff; its "Scope decisions" bind, its own task list is superseded by this plan). **Look:** `docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md` (merged as #112).

## Revision (2026-09-29, maintainer)

The handoff was written before the UI depth pass merged. This plan keeps every
locked scope decision and changes only *how*:

- **Buttons are the depth pass's lipped faces, not hand-built shadows.**
  TERAPKAN goes through `_add_button_variation` in `accent_mint` (the main
  action colour; the spec's "success-green"). Its sink-onto-the-lip press and
  the main-action haptic tick come from `UIPolish`/`PressFeel` for free — no
  `Juice` wiring. The flat red `SKIN_APPLY_*` block is deleted.
- **The back button keeps the shared red back arrow** (`TextureButton`) that
  every screen uses, instead of the spec's one-off round cream button: a back
  control that looks different on one screen reads as a different action.
  Recorded as a departure in the PR.
- **Tiles are lipped photo cards.** Rest: `button_cream` on `button_cream_lip`.
  Open: `accent_sunflower` on `accent_sunflower_lip` (the palette's highlight,
  "never an action"). Each tile gets a washi-tape tab and a name caption,
  authored in `StudentTile.tscn`.
- **The paper tray reuses the depth pass's notebook art**
  (`Assets/Images/UI/Notebook/paper_rule.png`, tiled) and the existing
  `Assets/Images/AturJadwal/washi_tape.svg`, as authored nodes. No new art.
- **Calls down, not a GameState read.** `Lobby.gd` hands the roster's names to
  `SkinSelect.open(names)`; `SkinSelect` never reads `GameState.approved_students`
  itself, so tests drive it with plain arrays. An empty array falls back to
  `StudentSkins.NAMES`.
- **SFX use existing cues** from `AudioDirector`'s registry: `&"select"` on a
  tile, `&"pop"` when the carousel settles on a new skin, `&"apply"` on
  TERAPKAN. No registry additions.
- **Stretch features stay out** (the spec's "Baru!" badge, peek-on-select,
  turntable idle, locked-skin treatment): the owner has not signed them off.

## Global Constraints

- **Godot 4.6**, portrait. UI text Indonesian; systems code English.
- **Tests run only inside the editor** via `test_run`; every suite `@tool extends McpTestSuite`; no `await` in a test. `McpTestSuite` has only `assert_true/false/eq/ne/gt/has_key/contains/is_error`.
- **Scenes:** never hand-edit a `.tscn` while the editor is attached. Subagents hand-edit only while the controller has this worktree's editor **closed**; the controller then re-saves each touched scene through the editor (`scene_open` + `scene_save`) and drops any unrelated `@tool` bake from the diff. New nodes get a random 9–10 digit `unique_id` not already in the file.
- **No `theme_override_*`** except layout-only constants. New looks are `ThemeFactory` variations; after editing `ThemeFactory.gd` the controller restarts, rebakes alone (`test_run(suite="theme_rebake")`), restarts, and checks `theme_factory`'s bake-matches test.
- **No runtime-built visuals.** Static chrome is authored; per-call **text** (names, "N murid") is fine.
- **Tall phones:** the tray stays re-anchored to the bottom inside its existing layout; check at 1080×2400.
- **Clean code** (`docs/superpowers/design/clean-code.md`): `##` header and `##` on every `@export`; typed everything (typed loop variables too); no `var x := <Autoload>.…`; named constants; `%` unique names for nodes a script touches; `push_error` on a missing node the scene must have. Run `test_run(suite="clean_code")` per task and lock in any shrink with `ci/clean_code_dump.gd`.
- **Persistence:** unchanged (`GameState.equipped_skins`, per name, session-scoped).
- **Keep as-is:** carousel physics (`_scroll`, `card_pose`, drag, `_slide_to`, `SkinCard.settle_index`), the pending/commit model, the overlay-over-Lobby model, `StudentSkins` resolution.
- **Commits:** Conventional Commits with a scope; message via `git commit -F`, ending with the session's attribution trailer.

## File Structure

- `Scripts/Skins/SkinSelect.gd` — `open(names: Array[String] = [])`, `_names`, roster header text, tile hiding, SFX.
- `Scripts/Lobby/Lobby.gd` — passes the roster's names (a pure static `SkinSelect.roster_names(students: Array) -> Array[String]`).
- `Scripts/Skins/StudentTile.gd` + `Scenes/Skins/StudentTile.tscn` — caption + tape tab.
- `Scenes/Skins/SkinSelect.tscn` — centred rail, header + hint, paper tray chrome, name dividers, PAKAI! sticker.
- `Scripts/Design/ThemeFactory.gd` — lipped `SkinApplyButton`, `SkinStudentTile(Active)`, paper `SkinTray`, new label variations; drop `SKIN_APPLY_*`.
- Tests: `test_skin_select.gd`, `test_student_tile.gd`, `test_lobby_skins.gd`, `test_theme_factory.gd`, `test_button_geometry.gd` (only if a new radius exemption is needed).

---

## Task 1: The rail shows your class

**Files:** `Scripts/Skins/SkinSelect.gd`, `Scripts/Lobby/Lobby.gd` (~line 795–804), `Scripts/Skins/StudentTile.gd` (header comment only), `tests/test_skin_select.gd`, `tests/test_lobby_skins.gd` (the comment near line 74 and any pin on `open()` taking no argument).

**Produces:** `SkinSelect.open(names: Array[String] = []) -> void`; `static SkinSelect.roster_names(students: Array) -> Array[String]` (each dict's `"name"`, in roster order, skipping non-dicts and empty names); `SkinSelect.visible_names() -> Array[String]`.

- [ ] **Step 1: Failing tests** in `tests/test_skin_select.gd` (reuse the suite's existing way of instancing SkinSelect):
  - `open(["Andi", "Sari"])` (use two real names from `StudentSkins.NAMES`) shows exactly 2 visible tiles, in that order, and hides the rest; `current_student()` is the first.
  - 3 and 4 names show 3 and 4 tiles.
  - `open([])` falls back to all of `StudentSkins.NAMES`.
  - `select_student(1)` with 2 names opens the second name; `select_student(2)` is ignored (out of range).
  - `roster_names([{"name": "A"}, {"name": ""}, 5, {"name": "B"}])` is `["A", "B"]`.
  - Update the existing tests that assume six tiles (lines ~57–59) to call `open()` with no names (the fallback), so they keep testing the six-name path.
- [ ] **Step 2: Implement.** Add `var _names: Array[String] = []` (doc it). `open(names)` sets `_names = names.duplicate() if not names.is_empty() else StudentSkins.NAMES.duplicate()` and replaces every `StudentSkins.NAMES` read in `open`, `play_rail_entrance`, `current_student`, `select_student`, `apply_without_closing` with `_names`. Tiles beyond `_names.size()` are hidden (the authored `Tile1–6` stay; same idea as `Dots` hiding extras). Update the header comments in `SkinSelect.gd`, `StudentTile.gd` and at the Lobby call site that say "all six, never the roster" — the roster now drives it, and persistence stays per name.
- [ ] **Step 3: Lobby calls down.** `screen.open(SkinSelect.roster_names(GameState.approved_students))`. Type the local (`var names: Array[String] = …`), no autoload inference. Lobby.gd is near the 1,000-line ceiling: keep the change to a line or two.
- [ ] **Step 4:** Controller runs `skin_select`, `lobby_skins`, `student_tile`, `lobby`, `clean_code`.
- [ ] **Step 5: Commit** `feat(skins): the skin picker shows your class, not all six`.

## Task 2: Theme variations in the depth look

**Files:** `Scripts/Design/ThemeFactory.gd` (`_build_skin_select`, ~line 600–720), `tests/test_theme_factory.gd`, `tests/test_skin_select.gd` (the theme pins near lines 386–404), `tests/test_button_geometry.gd` only if needed.

- [ ] **Step 1: Failing tests.** In `test_skin_select.gd` replace the flat-red pins: `SkinApplyButton`'s normal stylebox `LippedBox.is_lipped` and `bg_color == tokens.accent_mint`; `SkinStudentTile` lipped on `button_cream`; `SkinStudentTileActive` lipped on `accent_sunflower`; `SkinTray` is a panel whose `bg_color` is the paper token chosen below and has no black top rim. In `test_theme_factory.gd`, add the new display labels to `DISPLAY_ROSTER`.
- [ ] **Step 2: Implement.**
  - `SkinApplyButton` → `_add_button_variation(theme, tokens, "SkinApplyButton", tokens.accent_mint, tokens.accent_mint_lip)`, then keep its large font size (today 73: move that number to a named `SKIN_APPLY_FONT` const if it is not one). Delete `SKIN_APPLY_FILL`, `SKIN_APPLY_TEXT` and the three `SKIN_APPLY_*` tint consts if nothing else reads them.
  - `SkinStudentTile` / `SkinStudentTileActive` → `_add_button_variation` with the cream / sunflower trios. If `test_button_geometry` or `test_student_tile`'s size pin objects (the lip changes the content rect), keep the tile's `custom_minimum_size` and adjust padding, not the size.
  - `SkinTray` → a paper sheet: `surface_page` (or `surface_card`; pick the lighter so the rules read) with no border. It stays a `StyleBoxFlat` panel.
  - New Label variations: `SkinRosterHeaderLabel` (display font, `font_title`, `brand_primary`), `SkinRosterHintLabel` (body font, `font_caption`, `text_secondary`), `SkinTileCaptionLabel` (display, `font_micro`, `text_primary`), `SkinApplyTag` (Label with a small lipped `accent_sunflower` stylebox on `accent_sunflower_lip`, `text_primary`, display, `font_caption` — the "PAKAI!" sticker).
  - Tokens only; no colour literals.
- [ ] **Step 3:** Controller restarts, rebakes alone, restarts; runs `theme_factory`, `button_geometry`, `skin_select`, `student_tile`, `clean_code`; commits the bake separately.
- [ ] **Step 4: Commit** `feat(skins): lipped mint TERAPKAN, taped photo tiles and a paper tray`.

## Task 3: The scrapbook scene

**Files (editor CLOSED):** `Scenes/Skins/SkinSelect.tscn`, `Scenes/Skins/StudentTile.tscn`, `Scripts/Skins/StudentTile.gd`, `Scripts/Skins/SkinSelect.gd`, `tests/test_skin_select.gd`, `tests/test_student_tile.gd`.

- [ ] **Step 1: Failing tests** (source scans where live instancing is not possible):
  - `Tray/Rail` has `alignment = 1`.
  - `SkinSelect.tscn` has a `RosterHeader` Label (`SkinRosterHeaderLabel`, unique name) and a `RosterHint` Label (`SkinRosterHintLabel`, text "ketuk untuk pilih") above the rail; a `Rules` TextureRect using `paper_rule.png` with tiling; two `Tape` TextureRects using `washi_tape.svg` at the tray's top corners; two divider `Panel`s (`SkinDotOn`) either side of `SkinName`; a `PakaiTag` Label (`SkinApplyTag`, "PAKAI!") on TERAPKAN's corner.
  - `open(["A","B"])` (real names) sets `RosterHeader` to "Kelasmu · 2 murid".
  - `StudentTile.tscn` has a `Caption` Label (`SkinTileCaptionLabel`, unique) and a `Tape` TextureRect; `show_student(who, …)` sets `Caption.text` to `who`.
- [ ] **Step 2: Author the nodes** (hand-edit, editor closed). Tray chrome sits behind the rail and buttons (earlier siblings); everything decorative has `mouse_filter = 2`; `Rules` fills the tray (anchors) with `texture_repeat` enabled and `stretch_mode` tile; tape pieces rotated a few degrees (not in a Container). Header + hint sit above the rail inside the tray; nudge the rail down only as much as needed and keep the tray's own rect (tall-phone pins). The PAKAI! sticker is a child of `Terapkan`, top-right, tilted.
- [ ] **Step 3: Scripts.** `StudentTile.gd`: `@onready var _caption: Label = %Caption` (resolve lazily for tests the way the file already reaches `Frame`), `push_error` if missing; `show_student` sets the caption. `SkinSelect.gd`: `@onready var _roster_header: Label = %RosterHeader`; `open()` sets `"Kelasmu · %d murid" % _names.size()` (a named format const).
- [ ] **Step 4:** Controller relaunches the editor, re-saves both scenes through it, runs `skin_select`, `student_tile`, `skin_card`, `skin_frame`, `tall_screen_layout`, `viewport_editability`, `script_documentation`, `clean_code`, and screenshots the open picker at grade 7/8/9.
- [ ] **Step 5: Commit** `feat(skins): the picker's paper tray, taped tiles and class header`.

## Task 4: SFX

**Files:** `Scripts/Skins/SkinSelect.gd`, `tests/test_skin_select.gd`.

- [ ] **Step 1: Failing source-scan tests:** `select_student` body plays `&"select"`; the settle path plays `&"pop"` only when `_skin_index` changes; `apply()` plays `&"apply"`. Confirm each cue exists in `Scripts/Audio/AudioDirector.gd`'s registry (it does today) and that its comment there fits the use.
- [ ] **Step 2: Implement.** Fire from the index-change point (compare old and new `_skin_index` where `select_skin` / the settle lands), never per drag frame. Go through `AudioDirector.play_sfx` only.
- [ ] **Step 3:** Controller runs `skin_select`, `audio_coverage`, `audio_director`, `clean_code`.
- [ ] **Step 4: Commit** `feat(skins): the picker taps, snaps and chimes`.

## Task 5: Verify, docs, ship

- [ ] Live screenshots at full size, 1080×1920, grade 7/8/9 (2/3/4 tiles, centred, no benched student), plus a 1080×2400 SubViewport capture. Check TERAPKAN's held (sunk) state does not clip the PAKAI! sticker.
- [ ] `docs/superpowers/CHANGELOG.md` entry; `DEBT.md` if anything is deferred (the four stretch features, the back-button departure if the owner wants the round one later); CLAUDE.md suite/test counts after the full run.
- [ ] Full suite, then the `ship-pr` skill.
