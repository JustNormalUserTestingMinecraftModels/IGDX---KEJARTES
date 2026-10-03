# RunResult (Badge Rank Scene) polish — design & handoff

> **Revision (2026-09-28): re-checked against Textures `b2890588`.** The
> design is unchanged (layout Option C, reveal order, contextual button,
> caption pools, scope). This pass fits the plan to what landed after the
> 2026-09-27 revision: the ambient kit (PR #88), the StudentList-walkthrough
> reset (PR #85), the clean-code legacy-key rule, the settings pass (which added
> `GameSettings.reduce_motion`) and the particle-spin fix. Passages changed
> here carry **Rev 09-28**. What changed:
>
> 1. **Ambient kit.** RunResult's root now has `AmbientPass` / `AmbientFail`
>    between `BlurLayer` and the report UI, `_dress_ambience()`, `_passed`,
>    and a glint material on `GradeBadge`, all pinned by `test_ambient_kit`.
>    The tree (§3) keeps them in place, `Safe` takes `MarginContainer`'s slot,
>    the moved `GradeBadge` keeps its glint, and the `Warm` light pool is
>    re-aimed at the new medallion. `test_ambient_kit`'s `GradeBadge` path pin
>    joins the list of pins to update (§8).
> 2. **PR #85.** The beat-the-game branch now resets tutorial flags through
>    `TUTORIAL_FLAGS` + `static func _reset_static_flag()`. Open question 4 is
>    resolved, and the two untyped `load()`s are gone, so RunResult.gd's
>    `UNTYPED` entry is **already 0** (§7). `_finish_game()` (§5) keeps the
>    loop and its order after `is_game_beaten = true`, which
>    `test_run_result` pins.
> 3. **Pins the 09-27 list missed.** `test_run_result` scans
>    `GameState.current_grade == 7` (named away by `FIRST_GRADE`), and
>    `test_shop_weekly_stock` scans `_apply_progression()`'s own body up to
>    `if GameState.current_grade < 9:` (gone after the split). Both are
>    updated in the same PR (§8).
> 4. **Baseline corrections.** Juice.gd has no `UNTYPED` entry; its 5 is
>    `BARE_NUMBERS`. RunResult.gd is 336 lines. `return_button.png` has eleven
>    other users now (Settings, SkinSelect). The rest of §7's table was
>    re-read and holds.
> 5. **New project behaviour.** `GameSettings.reduce_motion` (Kurangi Gerakan)
>    exists now, and screens land at rest under it (DailyLoginPanel). The
>    reveal honours it through `skip_reveal()`, and the idle pulse stays off
>    (§4).
> 6. **Robustness gaps closed.** A `_has_landed` guard means a skip after the
>    slam cannot fire the one-shot `StarBurst` twice. The caption is drawn once
>    per visit, so the skip and the slam show the same line. `StarBurst` sits
>    under `GradeBadge` so it rides the medallion on a tall phone (§3, §4).
> 7. **Snippets added** for StatCounter, the reveal's skip and the
>    progression split, all typed, with named numbers, `%` refs and functions
>    ≤ 50 lines.
> 8. **§9 is now a tagged task list.** Each step is **[editor]** (controller,
>    godot-ai bridge) or **[code]** (subagent, no bridge). Scene work comes
>    before script work, and the rebake runs alone after all scene saves.
>    Every code task ends with `test_run(suite="clean_code")` and the named
>    suites. A final task covers CHANGELOG, DEBT, the CLAUDE.md count, the full
>    run and `ship-pr`.
>
> **Not implemented anywhere yet.** Textures has no `StatCounter`,
> `outcome_for`, `grade_name_for`, `caption_pool_for`, new variations or
> `icon_retry`/`icon_trophy` art.

> **Revised 2026-09-27 for the clean-code standard.** The design decisions
> below are the collaborator's and are unchanged: layout Option C, the reveal
> order, the contextual button, the caption pools and the scope. The revision
> adds what `docs/superpowers/design/clean-code.md` and the post-clean-code
> `Textures` require, and corrects the path and API references that no longer
> hold. Revised passages carry a **Rev:** tag; §7 (Clean-code requirements) is
> new; the list of changes and the open questions are at the end.

**Branch:** `badgerankscenepolish` (PR #86, docs only). **Rev 09-28:** it forks
from `521fe24a`, before the ambient kit. `Textures` now contains the whole
clean-code pass. Build on a fresh branch from current `origin/Textures`, or
merge `Textures` into this one first (open question 5).
**Screen:** `Scenes/EndGame/RunResult.tscn` / `Scripts/EndGame/RunResult.gd`
**Status:** design approved (layout, motion, button, captions). Ready for a
build pass by another session.

This is a **handoff spec**: the design was settled with the mentor. The
implementing session builds against the numbers, call sites and tests below.
Nothing here changes `RunGrade.gd` or how the rank badge is chosen. The
medallion art and `_badge_for()` stay exactly as they are.

---

## 1. Why

The current screen reads as six identical white pill rows stacked under a badge
card, with small type. Mentor's notes: too many boxes, too flat/boring, text
too small on a phone. The rank-badge mechanic is fine and must not change; only
the *layout, motion, the menu button's wording, and the grade caption* change.

Four layout directions were mocked; **Option C ("panggung juara")** was chosen:
a large celebratory medallion up top, the six figures compressed into **two
horizontal "medal strips" of three counters each**.

---

## 2. Scope

In scope:
- Re-layout RunResult to Option C (medallion hero + two medal strips).
- New reveal choreography (cute, rewarding), reusing existing `Juice` /
  `AnimUtils` calls.
- Contextual `BtnSelesai` label + icon that follows the real progression
  branch.
- A caption **pool per rank** (random pick) instead of one fixed line.
- Bigger type throughout (see §3).
- **Rev:** the clean-code obligations for every file this touches (§7): named
  numbers, full typing, short single-job functions, and locking the resulting
  debt reduction into `ci/clean_code_baseline.gd`.

Out of scope / must not change:
- `RunGrade.gd` scoring and rank letters.
- `_badge_for()` and the five `rank_badge_*` textures. The medallion draws its
  own letter + RANK ribbon.
- `_apply_progression()`'s destinations and side effects. The button's *label*
  is derived from the same inputs; its *routing* is untouched. **Rev:** the
  function is split into one function per branch (§5, §7), but each branch
  keeps its exact statements. `tests/test_run_result.gd`,
  `tests/test_achievements.gd` and `tests/test_end_game_rehearsal.gd` scan for
  those statements verbatim (e.g.
  `Achievements.record_grade_passed(GameState.current_grade)`,
  `GameState.current_grade += 1`, `reset_roster_for_new_grade`).
  **Rev 09-28:** this includes PR #85's tutorial reset: `TUTORIAL_FLAGS`, the
  `for path: String in TUTORIAL_FLAGS` loop calling
  `_reset_static_flag(path, flag)` after `GameState.is_game_beaten = true`,
  and the static helper itself (`test_run_result` calls it on the script).
  Two scans *do* change with the split, and they are updated, not worked
  around (§8): `GameState.current_grade == 7` and `test_shop_weekly_stock`'s
  `_apply_progression()` body scan.
- **Rev 09-28 — the ambient kit (PR #88).** `AmbientPass` / `AmbientFail`,
  their children, `_dress_ambience()` and its statements, `_passed`, and
  `GradeBadge`'s `glint_material.tres` are unchanged. `test_ambient_kit`
  scans `ambient_pass.visible = _passed`,
  `ambient_fail.visible = not _passed`, `grade_badge.material = null`,
  `shown.modulate.a = 0.0` and the `dur_slow` fade, so keep those variable
  names. The mood fade is not part of the reveal, and the skip leaves it
  alone.
- Persistence. No new `user://` writes.

---

## 3. Layout — Option C

Portrait 1080-wide. Keep `WinStage` + `BlurLayer` as the first two children,
unchanged. **Rev 09-28:** `AmbientPass` and `AmbientFail` stay third and
fourth, unchanged. `test_ambient_kit` pins the first four children in that
order, so the report UI goes **after** them, in `MarginContainer`'s old slot.
**Rev:** the report UI moves out of the bare full-rect
`MarginContainer` and into the project's tall-phone shell, `Safe`
(`SafeAreaMargin`, Full Rect, `mouse_filter` IGNORE) → `UI` (plain `Control`)
→ `Column` (authoring guide, "Tall phones", rule 3). Every node the script
touches gets a **unique name (`%`)** so the script never spells a path
(clean-code §6):

```
RunResult (Control, script RunResult.gd)
├─ %WinStage             (unchanged; Rev 09-28: made unique, path unchanged)
├─ %BlurLayer            (unchanged; made unique)
├─ %AmbientPass          (ambient kit, unchanged; made unique)
├─ %AmbientFail          (ambient kit, unchanged; made unique)
├─ Safe (SafeAreaMargin) → UI (Control)
│   └─ Column (VBox)
│       ├─ %TitleLabel       "Hasil Kelas 7" — masthead, ResultHeroLabel (unchanged variation)
│       ├─ %MedallionStack (VBox, centered)
│       │   ├─ %GradeBadge   TextureRect, the rank medallion (unchanged art,
│       │   │   │            keeps material = glint_material.tres)
│       │   │   └─ %StarBurst  authored one-shot burst (§4, step 5), at the
│       │   │                  badge's centre
│       │   └─ %GradeCaption one line, from the rank's caption pool (§6)
│       ├─ %MedalStrips (VBox, separation ~12)
│       │   ├─ %StripTop     HBox of 3 StatCounter instances
│       │   └─ %StripBottom  HBox of 3 StatCounter instances
│       └─ %BtnSelesai       contextual label + icon (§5)
```

**Rev 09-28 — placement notes.**
- `%StarBurst` moves from the root to under `%GradeBadge`. It is a
  `GPUParticles2D`, so the container ignores it and it keeps its authored
  position inside the badge. Parented there, it rides the medallion on a tall
  phone (tall-phone rule 4, "a picture and its items move as one piece"),
  where a root-level position would stay put. The badge's glint does not
  spread to it: `use_parent_material` is off by default.
- `GradeBadge` is **moved**, not recreated. If it has to be recreated,
  re-set `material` to `res://Scripts/Shaders/glint_material.tres`, because
  `test_ambient_kit` asserts it.
- `AmbientPass/Warm` (a `LightPool`) sits at `center = (0.5, 0.33)`, "light
  behind the grade". The bigger medallion moves, so re-aim `center` on the
  medallion's new centre at 1080×1920 and check it at 1080×2400.
  `test_ambient_kit` does not pin `center`.

**Rev — sizes are in the 1080 project scale.** The mock's "~150–170 px"
medallion reads as mockup pixels at 360 wide: today's `GradeBadge` is already
300×290, so 150 px would shrink the hero. In project pixels the Option C
medallion is **~450–510 px**. It is a layout number, so it lives in the
`.tscn` as `custom_minimum_size`, never in code. The type sizes below are
converted the same way (see open question 1).

**StatCounter cell** (new `PackedScene`, `Scenes/EndGame/StatCounter.tscn` +
`Scripts/EndGame/StatCounter.gd`, `@tool`, `class_name StatCounter`; PascalCase
names, clean-code §1): a `Sheet` Panel with the `Card` variation, containing
icon (top), value `Label` (big), caption `Label` (small). Three per strip,
divided by a thin separator (a 1px `ColorRect` or a panel border, no
`theme_override`). This **replaces** `RunResultRow.tscn` for this screen.
**Rev:** RunResult is `RunResultRow`'s only caller (re-checked 2026-09-28:
only `RunResult.gd`, `tests/test_run_result.gd`, `tests/test_viewport_editability.gd`
and old docs name it), so delete `RunResultRow.tscn` + `.gd` in the
same PR. Keeping it would also leave two count-up bodies side by side, which
the duplicate-body ratchet flags.

**Rev — the six cells are authored, not built.** The test plan (§8) already
asks for "six `StatCounter` instances" in the scene, so the cells are placed in
`RunResult.tscn`, not instanced by code. The authoring guide's "no visual is
built at runtime" rule prefers that. Each cell's fixed facts are `@export`s on
the StatCounter **root** (overrides on an instance's children are dropped on
save; CLAUDE.md 4b), each with a `##` line. **Rev 09-28:** the whole script,
modelled on `ShopHubTile.gd` (the same root-export pattern). The children are
`%Icon`, `%Value` and `%Caption` inside StatCounter.tscn:

```gdscript
@tool
class_name StatCounter
extends PanelContainer

## One figure of RunResult's report: an icon over a number that counts up,
## over the word that names it. Authored six times in RunResult.tscn; the
## fixed facts are @exports on this root because Godot drops overrides set
## on an instance's children (CLAUDE.md 4b). RunResult calls down into it
## and it reports nothing back, so it has no signal.
##
## @tool so each cell shows its real icon and caption in the editor. The
## value reads "0" + suffix at rest, so the screen never shows its punchline
## before the reveal reaches it.

## The figure's picture: a transparent SVG, never a text glyph.
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_apply_exports()
## The word under the number, e.g. "Menang".
@export var caption_text: String = "":
	set(value):
		caption_text = value
		_apply_exports()
## Appended to the counted number, e.g. "G" for the wirausaha cell.
@export var value_suffix: String = ""

@onready var icon_rect: TextureRect = %Icon
@onready var value_label: Label = %Value
@onready var caption_label: Label = %Caption

## The number this cell counts up to. Set through set_value().
var target_value: float = 0.0


func _ready() -> void:
	_apply_exports()
	value_label.text = format_value(0.0, value_suffix)


## The label text for `value`: rounded to a whole number, then the suffix.
## Pure, so tests call it without the scene (like MinigameWinStat.format_delta).
static func format_value(value: float, suffix: String) -> String:
	return "%d%s" % [roundi(value), suffix]


## Arms the cell for the reveal: remembers the figure, shows "0" + suffix.
func set_value(value: float) -> void:
	target_value = value
	value_label.text = format_value(0.0, value_suffix)


## Counts 0 -> target_value. Returns the tween so RunResult's skip can kill it.
func count_up(delay: float, duration: float) -> Tween:
	return Juice.count_up_formatted(value_label, 0.0, target_value,
		func(v: float) -> String: return format_value(v, value_suffix),
		delay, duration)


## Lands the cell on its final figure, for a skipped reveal.
func show_final() -> void:
	value_label.text = format_value(target_value, value_suffix)


## Mirrors the exports onto the children. The setters also run while the
## scene loads, before the @onready refs exist, which is expected and
## skipped. Once ready, a missing child is a broken scene and errors on load.
func _apply_exports() -> void:
	if icon_rect == null or caption_label == null:
		return
	icon_rect.texture = icon_texture
	caption_label.text = caption_text
```

(The `null` guard, not `is_node_ready()`: `test_run_result`'s template tests
call `_ready()` directly on an out-of-tree instance, as they do for
`RunResultRow` today, and `is_node_ready()` stays false there.)

Name the six by what they count, not by position (clean-code §1, "no numbered
stand-ins"): `%MenangCounter`, `%KalahCounter`, `%PoinCounter`,
`%BarangCounter`, `%WirausahaCounter`, `%EventCounter`.

The six cells, in order (icon → value → caption), values from
`GameState.run_stats` (a `RunStats`; **Rev:** field names re-checked
2026-09-28, and the stat-key rename does not touch them):

| Strip | Cell | Icon | Value source | Caption |
|---|---|---|---|---|
| Top | 1 | `icon_minigame_menang.svg` | `minigames_won` (int) | "Menang" |
| Top | 2 | `icon_minigame_kalah.svg` | `minigames_lost` (int) | "Kalah" |
| Top | 3 | `icon_poin.svg` | `minigame_points` (float) | "Poin" |
| Bottom | 1 | `icon_barang.svg` | `items_used` (int) | "Barang" |
| Bottom | 2 | `icon_uang.svg` | `wirausaha_money` (int, + "G") | "Wirausaha" |
| Bottom | 3 | `icon_event.svg` | `event_student_count()` | "Event" |

Reuse the six existing SVGs, all in `Assets/Images/UI/Placeholders/`. **Rev:**
they become `ext_resource`s of the `.tscn` (the counters' `icon_texture`), so
the six `ICON_*` preloads leave `RunResult.gd`.

**Type sizes**: the mentor's "too small" note. Use `ThemeFactory` variations,
not overrides. **Rev:** converted to project pixels and landed on tokens. The
project already rules `CaptionLabel` (`font_caption`, 22 px) unreadable on a
phone: `EventBodyLabel`, `CatatanLabel` and `RunResultNameLabel` were each
raised off it. So:
- Counter value: display face (`font_display`), new `ResultStatValueLabel`,
  sized from a token: **`tokens.font_h1` (64)** as the starting point. The mock's
  28–34 × 3 would be 84–102, and "24000G" at 96 px will not fit a third of a
  952 px column. Measure the widest realistic value live before raising it.
- Counter caption: at least the body phone step, **`font_body_size + 8`
  (36)**, dark ink on the Card. Reuse the existing `RunResultNameLabel`, which
  is exactly that (body face, `text_primary`, "the name beside each figure in
  RunResult's report", `style-guide.md`) and already clears AA on `Card` (DRY:
  no new variation). Update its style-guide line to say "caption under each
  figure".
- GradeCaption: **≥ 42 px** equivalent (today it wears `CaptionLabel`).
  Option C takes it **off the Card**, onto the
  blurred painting, so the old dark ink will not read there. Add
  `ResultCaptionLabel`: body face, light ink with the dark outline
  `ResultHeroLabel` uses (`tokens.text_outline_size`, outline `text_primary`),
  size `tokens.font_h2` (48) or `font_body_size + 8`. Pick by measurement.
- Any new variation goes in `ThemeFactory.gd` and needs a **rebake**, and an
  entry in `DISPLAY_ROSTER` in `tests/test_theme_factory.gd` if it's a display
  face (`ResultStatValueLabel` is; `ResultCaptionLabel` is not). Sizes come
  from token expressions, not literals. `ThemeFactory.gd` is exempt from the
  bare-number count (`ci/clean_code_allowed.gd`), but tokens remain the style
  guide's rule. **Rev 09-28 — the pins and the bake.**
  - `DISPLAY_ROSTER` is checked both ways: `ResultStatValueLabel` and the
    green M button go in, with a dated comment like the roster's others.
  - `ResultCaptionLabel` sets no `font`, so it inherits the body face. Add it
    to the list in `test_body_labels_do_not_take_the_display_font` (beside
    `ResultBodyLabel`), which pins that.
  - Add all three names to a declared-variation list
    (`test_every_declared_variation_exists`'s `expected`) so a typo cannot
    silently fall back to the base type.
  - Rebake **alone**, after every scene save of the pass (§9 Task 4): restart
    the editor, run `test_run(suite="theme_rebake")` by itself, restart again,
    then `git diff Assets/Theme/kejartes_theme.tres`. It should add only the
    three variations' lines. Id churn anywhere else means the bake picked up
    stale in-memory state: `git checkout --` it and redo. Never run a
    `scene_save` between a rebake and a restart.

Category colours for the counter accents come from `DesignTokens.gd`
(`cat_akademis` #1F6FBA, `cat_senibudaya` #3D7F12, `cat_olahraga` #E03A18,
`currency_gold` #ffc93c, `brand_primary` #7A4A2B). No new tokens. **Rev:** the
hexes are today's values for reference only. A counter that wears an accent
reads it from the tokens by name (e.g. `@export var accent_token: StringName`
resolved through `Juice.tokens()`), never from a copied `Color`, so a token
edit cannot leave the counters behind.

**Tall phones:** re-anchor per the authoring guide's "Tall phones": backdrop
Full Rect + Keep Aspect Covered, UI inside `SafeAreaMargin`. **Rev:**
`test_tall_screen_layout.gd` does **not** cover RunResult today (re-checked
2026-09-28: it covers Lobby, Koperasi, StudentCard, StudentList, LevelSelect,
ReportCard and Settings). Add RunResult's contract test there (`Safe` → `UI`,
`Column` under the safe area, `%GradeBadge` and `%BtnSelesai` under a
`SafeAreaMargin` via `_assert_under_safe_area`). **Rev 09-28: contract only.**
RunResult is not `@tool`, so standing it up at 1080×2400 with `_stood_up`
would run its live `_ready()` (BGM, GameState reads, tweens). The memory
note on data-less screens in `game_eval` records an editor hang from exactly
that. Check the tall layout by screenshot instead (§9 Task 7).

---

## 4. Reveal choreography

Keep the game's dramatic order: **numbers build the case, the medallion is the
verdict.** Retune `_play_reveal()` / `_slam_grade()` and do not invent new
easing: reuse the vocabulary in `Juice.gd` and `AnimUtils.gd`. **Rev:** every
tween the reveal starts is kept in one typed list so the skip (below) can stop
it: `var _reveal_tweens: Array[Tween] = []`, filled through a
`_track(tween: Tween) -> Tween` helper that ignores `null` (the `Juice`/
`AnimUtils` calls return `null` for a freed node).

1. `Juice.pop_in(title_label)` (returns its `Tween`: track it).
2. Strips arrive staggered: `AnimUtils.staggered_entrance(strip_top, 0.0)` then
   `staggered_entrance(strip_bottom, strip_stagger)` (0 → 1.1 → 1.0
   overshoot; returns its `Tween`). **Rev:** the collaborator's `0.18` becomes
   `@export var strip_stagger: float = 0.18` in the existing "Reveal Timing"
   group, replacing `row_stagger` (a designer tunes it: clean-code §2).
3. Each counter rolls up as its strip lands. **Rev:** use
   **`Juice.count_up_formatted`** for all six cells, through
   `StatCounter.count_up(delay, duration)`, not `Juice.count_up`.
   `count_up` returns `void`, so a skip could never stop it, and it ignores the
   screen's `count_up_seconds`. `count_up_formatted(label, from, to, formatter,
   delay, duration) -> Tween` (re-checked 2026-09-28) takes a delay (pass the
   strip's delay) and a duration (pass `count_up_seconds`). One formatter,
   `StatCounter.format_value`, covers the "G" cell too.
   Keep the existing SFX split: coin cell → `AudioDirector.play_sfx(&"coin")`,
   others → `&"pop"`. **Rev:** decide "is this the coin cell" by node
   (`counter == wirausaha_counter`), not by comparing caption strings as
   `_build_rows()` does today.
4. Drumroll pause (`grade_delay`), then the medallion slams in: the existing
   `_slam_grade()` tween (scale 3.0 → 1.0, `TRANS_BACK`), unchanged in
   behaviour. **Rev:** the literal becomes
   `const GRADE_SLAM_FROM_SCALE := 3.0`; track the tween.
5. On land: `play_sfx(&"stamp")` + `Juice.shake(medallion_stack, 8.0)` +
   **star confetti** + `RewardFeedback.play(&"run_win", self)` for S/A (keep the
   existing `RunGrade.is_top_grade` gate; keep `&"fail"` for D).
   **Rev:**
   - `8.0` becomes `const GRADE_LAND_SHAKE := 8.0`. **Rev 09-28:** shake the
     `%MedallionStack` ref, not `grade_badge.get_parent()`, so the script
     never assumes the tree.
   - `RewardFeedback` (autoload, `Scripts/Feedback/RewardFeedback.gd`) plays
     `run_win` at the Celebration tier, which **throws no particles of its
     own** (its header: celebrating screens author their own) and already
     shakes the screen root. So the star confetti is the screen's: an
     **authored** `%StarBurst` node in `RunResult.tscn`, an instance of the
     existing `Scenes/Minigames/UI/StarBurst.tscn` (a `RewardParticles` burst
     of `particle_star.png`, which spins since 2026-09-28's disable-z fix;
     `PaperConfetti.tscn` is the paper alternative),
     fired with `star_burst.fire()`. `AchievementClaimPopup` does the same.
     `fire()` frees the node once spent, so fire it exactly once per visit.
     **Rev 09-28:** `_on_grade_landed()` begins with a `_has_landed` guard.
     The skip calls it too, and a skip after the slam has already landed
     must not fire a freed burst or stamp twice.
   - Put the landing in its own function (`_on_grade_landed()`) rather than
     the inline lambda it is today, so each piece stays short and named.
6. Caption + button fade in last. (The RANK ribbon is part of the medallion
   art, so it arrives with the slam.) **Rev:** `Juice.fade_in` still returns
   `void` (re-checked 2026-09-28), so a skip cannot stop it. Make it return
   its `Tween`, the same
   backward-compatible change `pop_in` already documents ("a skipped reveal
   must not let a half-faded node keep fading"): `-> Tween`, `return null` on
   the dead-node guard. Its one existing caller (`EventWarning.gd`) ignores the
   result. Keep `BtnSelesai` non-interactive (`disabled`) until this step or a
   skip lands it, so an invisible button cannot be pressed.

Cutey extras (optional, but requested feel):
- `AnimUtils.idle_pulse(medallion)` after it settles: a heartbeat, not a
  freeze. **Rev:** keep the returned looping `Tween` in
  `var _idle_pulse: Tween`. **Rev 09-28:** not under `GameSettings.reduce_motion`.
- Tap the medallion → `AnimUtils.wobble(medallion)` (easter egg). **Rev:**
  `GradeBadge` is `mouse_filter = IGNORE` today, so it needs STOP/PASS and a
  `gui_input` handler connected in `_ready()`. `wobble` and `idle_pulse` both
  drive `scale`, and `wobble` only kills tweens it registered itself
  (`AnimUtils._safe_tween`), never the pulse. So: kill `_idle_pulse`, wobble,
  and restart the pulse on the wobble tween's `finished`. Otherwise two tweens
  fight over the medallion's scale.
- Button press → `AnimUtils.back_bounce` (it's the ← action button). **Rev:**
  `UIPolish` already gives every Button press/release scale juice. Stacking
  `back_bounce` on it double-animates `scale`, so set
  `btn_selesai.set_meta(Juice.NO_AUTO_JUICE, true)` if `back_bounce` stays. See
  open question 3: with a contextual label the button is no longer a "←"
  control.
- **Skip-to-end:** a tap during the reveal jumps to the final state. `pop_in` /
  `count_up_formatted` / `staggered_entrance` return their tweens precisely so
  a skip can `.kill()` them and land on the final values. Keep this: replay
  and late taps must never strand a half-counted number. **Rev:** the reveal
  also awaits timers (`create_timer(...).timeout`), which cannot be killed.
  After each `await`, check a `_is_revealing: bool` (cleared by the skip) the
  same way today's code re-checks `is_instance_valid(self)`, and return when
  it is false. The skip is one short function: kill every tracked tween, call
  each counter's `show_final()`, land the grade without the tween, run the
  finale at once. While `_is_revealing`, a screen tap skips; afterwards, a
  medallion tap wobbles. **Rev 09-28:** `UI`, `Column` and the strips are
  `mouse_filter` IGNORE, so a tap on empty screen reaches the root's
  `_gui_input`. `GradeBadge` is STOP, so it eats taps on itself: its handler
  calls `skip_reveal()` while `_is_revealing` and wobbles afterwards.

**Rev 09-28 — reduce motion.** Since the settings pass, `GameSettings.reduce_motion`
(Kurangi Gerakan) exists and screens honour it by placing things at rest
(`DailyLoginPanel._on_reveal_burst_started`). Here that is one guard at the
top of `_play_reveal()`: under `reduce_motion`, call `skip_reveal()` and
return. The medallion still lands, with its sound, fanfare and burst, just
without tweens. `RewardFeedback` already drops its own shake under the
setting. The skip and its helpers:

```gdscript
## Every tween the reveal starts, so skip_reveal() can stop them all.
var _reveal_tweens: Array[Tween] = []
## True from _ready until the finale lands or a tap skips. Each await in the
## reveal re-checks it, because a timer cannot be killed.
var _is_revealing: bool = false
## Set by the first landing, so a skip after the slam cannot stamp twice or
## fire the one-shot StarBurst after it has freed itself.
var _has_landed: bool = false


## Keeps `tween` for skip_reveal(). Juice and AnimUtils return null for a
## freed node, so null is passed through and not stored.
func _track(tween: Tween) -> Tween:
	if tween != null:
		_reveal_tweens.append(tween)
	return tween


## A tap during the reveal (or reduce_motion) lands the final state at once.
func skip_reveal() -> void:
	if not _is_revealing:
		return
	_is_revealing = false
	for tween: Tween in _reveal_tweens:
		if tween.is_valid():
			tween.kill()
	_reveal_tweens.clear()
	var chrome: Array[Control] = [title_label, strip_top, strip_bottom]
	_land_at_rest(chrome)
	for counter: StatCounter in _counters():
		counter.show_final()
	_show_grade()
	_on_grade_landed()
	_reveal_finale()


## pop_in and staggered_entrance start their nodes shrunk and transparent,
## so a killed tween would strand them invisible; put them back at rest.
func _land_at_rest(nodes: Array[Control]) -> void:
	for node: Control in nodes:
		node.scale = Vector2.ONE
		node.modulate.a = 1.0
```

`_counters() -> Array[StatCounter]` returns the six `@onready` refs.
`_show_grade()` writes the badge texture and the caption drawn once in
`_ready()` (§6) at rest (scale `Vector2.ONE`, alpha 1). `_slam_grade()` calls
it and then tweens from `GRADE_SLAM_FROM_SCALE`.

**Rev — the editability ratchet.** The original note says confetti and
tap-to-wobble "will trip `tests/test_viewport_editability.gd`". They will not.
That suite counts only `.new(` calls on visual node types. `wobble` is a tween
on an existing node, and an authored `%StarBurst` builds nothing. Do **not**
use `AnimUtils.create_floating_text` with a ★ glyph: it builds a `Label` at
runtime with `add_theme_*_override` calls, and a text star is glyph
iconography. Expected result: `ALLOWED` gains nothing and `BASELINE` is
unchanged. With the six cells authored, `RunResult.gd` constructs nothing:
delete its `ALLOWED` entry (value `0`, whose comment describes the retired
`_build_rows()`; still there 2026-09-28), or rewrite that comment if the suite
needs the key. The `StatCheck.gd` entry's comment says "the same shape as
RunResult's rows"; reword it when the rows go.

---

## 5. Contextual menu button

`BtnSelesai` currently reads "Kembali ke Menu" with `return_button.png`. Make
its label + icon follow the same branch `_apply_progression()` already takes,
computed once in `_ready()` after `_compute_grade()`. **Routing is unchanged.**
Only text and icon are derived. Keep the label branch adjacent to (or derived
from the same match as) the destination branch so they can never drift.

| Condition | Destination (unchanged) | Label | Icon |
|---|---|---|---|
| Pass, grade 7 | StudentCard (grade 8) | `Lanjut ke Kelas 8` | forward arrow |
| Pass, grade 8 | StudentCard (grade 9) | `Lanjut ke Kelas 9` | forward arrow |
| Pass, grade 9 (game beaten) | MainMenu | `Selesaikan Permainan` | trophy |
| Fail, grade 7 | MainMenu (full restart) | `Mulai Ulang` | refresh |
| Fail, grade 8/9 | StudentCard (retry same grade) | `Ulangi Kelas N` | refresh |

**Rev — one decision, read twice.** "Derived from the same match" becomes a
typed enum and a pure static function that both the button and
`_apply_progression()` read. Add `class_name RunResult` to the script (the
file is already `RunResult.gd`, so the class-name rule holds) so tests can call
the helpers without the live scene:

```gdscript
## Where a finished run goes next. The button's face and _apply_progression()
## both read this one decision, so the label can never promise a different
## destination from the one the tap takes.
enum Outcome { ADVANCE, BEAT_GAME, RESTART, RETRY }

## The first and last grades a run passes through.
const FIRST_GRADE := 7
const FINAL_GRADE := 9

static func outcome_for(run_failed: bool, grade: int) -> Outcome:
	if run_failed:
		return Outcome.RESTART if grade == FIRST_GRADE else Outcome.RETRY
	return Outcome.BEAT_GAME if grade >= FINAL_GRADE else Outcome.ADVANCE

static func button_label_for(outcome: Outcome, grade: int) -> String:
	match outcome:
		Outcome.ADVANCE: return "Lanjut ke %s" % GameState.grade_name_for(grade + 1)
		Outcome.BEAT_GAME: return "Selesaikan Permainan"
		Outcome.RESTART: return "Mulai Ulang"
		Outcome.RETRY: return "Ulangi %s" % GameState.grade_name_for(grade)
	push_error("RunResult: no button label for outcome %d" % outcome)
	return ""
```

`_apply_progression()` becomes a `match outcome_for(...)` that calls one
function per branch (`_advance_grade()`, `_finish_game()`, `_restart_run()`,
`_retry_grade()`, each returning its destination path). The shared failure
reset (schedules, week, shop week, run stats, `run_failed`) is written once, in
the failure path, not copied into two branches. Every statement keeps its
current wording (see §2). **Rev 09-28 — the split, against today's code**
(including PR #85's flag reset):

```gdscript
## Where each branch lands. Named once; tests scan for these paths.
const MAIN_MENU_SCENE := "res://Scenes/MainMenu/MainMenu.tscn"
const STUDENT_CARD_SCENE := "res://Scenes/StudentCard/StudentCard.tscn"


func _apply_progression() -> String:
	match outcome_for(GameState.run_failed, GameState.current_grade):
		Outcome.ADVANCE: return _advance_grade()
		Outcome.BEAT_GAME: return _finish_game()
		Outcome.RESTART: return _restart_run()
		Outcome.RETRY: return _retry_grade()
	push_error("RunResult: no progression for this outcome")
	return MAIN_MENU_SCENE


## What every lost run clears, whichever grade it retries from.
func _reset_failed_run() -> void:
	GameState.day_schedules.clear()
	GameState.minggu_ke = 1
	# The retry's week 1 is a new week: without this it would reuse the
	# lost attempt's Koperasi shelf and sold list (same grade, week 1).
	GameState.reset_shop_week()
	GameState.run_stats.reset()
	GameState.run_failed = false


## Grade-7 loss: full restart; the MainMenu -> CutScene bootstrap takes over.
func _restart_run() -> String:
	_reset_failed_run()
	GameState.approved_students.clear()
	GameState.grade7_student_ids.clear()
	GameState.grade8_student_ids.clear()
	GameState.returned_from_student_card = false
	return MAIN_MENU_SCENE


## Grade 8/9 loss: retry at StudentCard, roster kept so locked students stay.
func _retry_grade() -> String:
	_reset_failed_run()
	GameState.returned_from_student_card = false
	return STUDENT_CARD_SCENE
```

`_advance_grade()` and `_finish_game()` each open with
`Achievements.record_grade_passed(GameState.current_grade)`, which today runs
once before the `< 9` branch and must still run before `current_grade`
changes. Then each takes its branch's existing statements verbatim.
`_finish_game()` uses `GameState.set_grade(FIRST_GRADE)` and keeps the
`TUTORIAL_FLAGS` loop after `GameState.is_game_beaten = true`. Its old
explanatory comment about `set_grade()` not clearing `day_schedules` moves
with it, shortened to the why. Every piece is well under 50 lines.

- Interpolate the grade number with `GameState.get_grade_name()` rather than
  hardcoding, so "Kelas 8/9/N" stays correct. **Rev:** `get_grade_name()` only
  names the **current** grade ("Kelas " + `current_grade`), and "Lanjut ke
  Kelas 8" needs the *next* one. Add `static func grade_name_for(grade: int) ->
  String` to `GameState` and make `get_grade_name()` return
  `grade_name_for(current_grade)`, so the "Kelas %d" wording lives in one
  place. `GameState.shop_week_key_for()` is the precedent for a static
  helper on that autoload. (Re-checked 2026-09-28: neither exists yet.)
- The **beat-the-game** state gets a distinct celebratory treatment: swap
  `PrimaryButtonM` → a success-green button variation for that one state (no
  `theme_override`). **Rev:** there is **no `SuccessButtonM`**, and plain
  `SuccessButton` is **not green** any more. Since the 2026-09-14
  lobby-style-buttons pass, `ThemeFactory._build_buttons` gives Primary,
  Secondary, Danger *and* Success the same Lobby brown look, so a
  `SuccessButtonM` would look identical to `PrimaryButtonM`. Add a genuinely
  green M-step variation instead (working name `CelebrateButtonM`), built the
  way `RosterStatusSudah` gets its green (`_add_button_variation` from
  `tokens.state_success`) with the M padding (`tokens.btn_pad_v_m`,
  `tokens.font_h2`, as `_add_size_step` gives `PrimaryButtonM`).
  `_add_size_step` sets `base_type` to `Button`, so the new variation also
  needs its own `icon_max_width` (`tokens.btn_icon_s`) and `h_separation`
  (`tokens.space_sm`) like `PrimaryButtonM`, or the trophy renders at its
  native size. Register it in `tests/test_button_geometry.gd`'s `SIZE_STEPS`
  and `test_natural_height_matches_the_size_step` tables and in
  `DISPLAY_ROSTER` (both helpers set the display font). Switching
  `theme_type_variation` at runtime is not an override. Green = "earned",
  which fits `tests/test_confirm_pair_semantics.gd`'s rule.
- **Icons must be real transparent SVG textures, not glyphs** (project bans
  emoji/text iconography). **Rev:** they are `@export`s on the RunResult root,
  assigned in the Inspector like the five `rank_badge_*` (drop-replaceable,
  no preloads in code), each with a `##` line: `icon_advance`,
  `icon_finish_game`, `icon_retry`. The forward arrow can reuse the existing
  `Assets/Images/UI/Nav/icon_chevron_right.png` (no new asset). Two new
  placeholders are needed, a refresh/repeat and a trophy, named in the
  folders' `icon_*` snake_case convention: `icon_retry.svg` and
  `icon_trophy.svg` in `Assets/Images/UI/Placeholders/` (§10). Add a grouped
  entry to `docs/superpowers/DEBT.md`.
- **Rev:** `return_button.png` stays. **Rev 09-28:** eleven other scenes use it
  (AturJadwal, Inventory, Koperasi, ShopHub, CosmeticShop, ReportCard,
  SchoolDay, both Achievements screens, Settings and SkinSelect). But
  `BtnSelesai` stops being a back control, so
  remove RunResult's entry from `tests/test_back_controls.gd`'s `ROSTER`
  (it pins `MarginContainer/Column/BtnSelesai` to the canonical back texture)
  with a one-line comment saying why.

---

## 6. Caption pool per rank

Replace the single-string `GRADE_CAPTIONS` with a **pool per rank** and pick
one at random (`pick_random()`). **Rev 09-28:** draw it **once per visit**, in
`_ready()` after `_compute_grade()`, into `var _caption_text: String`, and
have `_show_grade()` write it (§4). Drawing in `_slam_grade()` would let a
skip before the slam show a different line from the one the slam would. This
keeps the screen from saying the same sentence every run. Wording (Indonesian,
mentor-approved starting set; tune freely):

```gdscript
## A pool of captions per rank; one is drawn at random each run so the
## grade says something rather than just scoring something. Keys are
## RunGrade.letter()'s outputs.
const GRADE_CAPTIONS: Dictionary = {
	"S": [
		"Sempurna. Tidak ada yang tertinggal.",
		"Satu kelas, nol yang tertinggal. Luar biasa.",
		"Kamu hafal nama mereka, dan mereka takkan lupa namamu.",
		"Tidak ada yang bisa ditambah lagi. Sempurna.",
	],
	"A": [
		"Luar biasa. Kelas ini beruntung punya kamu.",
		"Hampir sempurna. Mereka tumbuh di tanganmu.",
		"Guru seperti kamu yang mereka ceritakan nanti.",
		"Nyaris tanpa cela. Kerja yang bagus.",
	],
	"B": [
		"Baik. Targetnya tercapai.",
		"Cukup solid. Mereka naik kelas dengan tenang.",
		"Kerja yang rapi. Masih ada ruang untuk lebih.",
		"Targetnya aman. Lain kali coba lebih tinggi.",
	],
	"C": [
		"Lulus tipis. Lain kali lebih awal.",
		"Selamat, walau napasnya sampai habis.",
		"Lolos di detik terakhir. Untung terkejar.",
		"Berhasil, nyaris saja tidak.",
	],
	"D": [
		"Belum berhasil. Mereka masih menunggumu.",
		"Kali ini belum. Mereka percaya kamu bisa.",
		"Bel berbunyi terlalu cepat. Coba sekali lagi.",
		"Belum sampai. Tapi belum berakhir.",
	],
}
```

**Rev — typed, pure, and loud.** Keep the `const GRADE_CAPTIONS` name and the
`"S": [` key spelling: `tests/test_run_grade_ranks.gd`'s
`test_every_rank_has_a_caption` scans for exactly that (the text from
`const GRADE_CAPTIONS` to the first `}`, so no caption may contain a brace).
The pool is read through
a pure static helper that returns a typed array. An unmapped rank is a
programmer mistake (`RunGrade.letter()` only returns these five), so it is
reported, not papered over (clean-code §9). The original `.get(..., [""])`
fallback would hide it:

```gdscript
## The caption pool for `rank`. Pure, so tests read it without the scene.
static func caption_pool_for(rank: String) -> Array[String]:
	var pool: Array[String] = []
	if not GRADE_CAPTIONS.has(rank):
		push_error("RunResult: no caption pool for rank '%s'" % rank)
		return pool
	pool.assign(GRADE_CAPTIONS[rank])
	return pool
```

**Rev 09-28:** the draw, called once from `_ready()`:
```gdscript
## One caption for this visit, so the slam and a skip show the same line.
func _draw_caption() -> String:
	var pool := caption_pool_for(_grade_text)
	return "" if pool.is_empty() else String(pool.pick_random())
```
The screen still never crashes on a bad rank: the caption is blank, as it was
before, but the error now reaches the log. (`_badge_for()`'s silent fall-back
to D is out of scope, §2, and stays as it is.)

---

## 7. Clean-code requirements (new)

The rulebook is `docs/superpowers/design/clean-code.md` (⚙ = enforced by the
ratchet, `ci/clean_code_scan.gd`, run by `tests/test_clean_code.gd` (suite
`clean_code`) and by CI's `ci/project_check.gd`). What it means for this pass:

**Today's debt for the files this touches** (`ci/clean_code_baseline.gd`,
**Rev 09-28:** re-read at `b2890588`):

| Entry | Now | After this pass |
|---|---|---|
| `UNTYPED` `Scripts/EndGame/RunResult.gd` | **not listed (0)**. PR #85 replaced the two untyped `load()`s with `_reset_static_flag()`'s `load(path) as GDScript` | stays 0. Every new `var`, loop variable and parameter is typed |
| `BARE_NUMBERS` `Scripts/EndGame/RunResult.gd` | 8 | **0**: re-counted 2026-09-28, still `Vector2(3.0, 3.0)` (2), `shake(..., 8.0)`, the exit fade `0.4`, `== 7`, `< 9`, `set_grade(7)`, and `entry[3]` in `_build_rows()`. The ambient kit's `0.0`/`1.0` are trivial (`TRIVIAL_NUMBERS`) |
| `LONG_FUNCTIONS` for RunResult.gd | none | **none**: every function stays ≤ 50 code lines (`_apply_progression` is under 50 today but the longest; split it, §5) |
| `LARGE_SCRIPTS` | not listed (336 lines) | stays far under 1,000 (expect ~450–500) |
| `DUPLICATE_GROUPS` | none for EndGame | none: no copied count-up body (delete `RunResultRow`) |
| `BARE_NUMBERS` `Scripts/Design/Juice.gd` (**Rev 09-28:** was mislabelled `UNTYPED`; Juice has no `UNTYPED` entry) | 5 | ≤ 5 (the `fade_in` return change adds none), and no `UNTYPED` entry appears |
| `Scripts/GameState.gd` | `UNTYPED` 9, `BARE_NUMBERS` 21 | no growth (`grade_name_for` is typed and number-free) |
| `RunResultRow.gd`, new `StatCounter.gd` | no entries | new scripts start clean, so they must be clean from the first commit |

`ThemeFactory.gd` is in `ci/clean_code_allowed.gd` for long functions, size and
bare numbers, so new variations there add no debt. `ALLOWED` gains nothing
from this pass.

**Rules, applied:**
- **Names (§1):** `StatCounter.tscn`/`.gd`, `class_name StatCounter`,
  `class_name RunResult`; counters named by what they count; new art
  `icon_retry.svg`, `icon_trophy.svg` (snake_case, `A–Z a–z 0–9 _ - .` only);
  booleans read as questions (`_is_revealing`, `_has_landed`, `_is_exiting`:
  rename `_exiting` while touching it). **Rev 09-28:** `_passed` keeps its
  name. `test_ambient_kit` scans `ambient_pass.visible = _passed`, and this is
  review guidance, not a ratchet. **Rev 09-28 ⚙:** no legacy stat key
  (`akademis[123]`, `kepribadian[12]`) anywhere in a new or touched file,
  comments included. Every new `res://` literal matches the file's exact case.
  No misspelled stem in a new file name.
- **No magic numbers ⚙ (§2):** logic constants in a `const` block at the top of
  `RunResult.gd`: `GRADE_SLAM_FROM_SCALE`, `GRADE_LAND_SHAKE`,
  `EXIT_FADE_SECONDS` (the `0.4` in `_on_selesai_pressed`), `FIRST_GRADE`,
  `FINAL_GRADE`, each with a `##` line. Timing a designer tunes is an
  `@export` in "Reveal Timing" (`strip_stagger`, `count_up_seconds`,
  `grade_delay`). Medallion size, strip separation and cell padding are
  `.tscn` layout. Font sizes are `ThemeFactory` variations from tokens.
- **One job per function ⚙ (§3):** `_ready()` reads as a table of contents
  (bind signals, play BGM, dress backdrop, reset for reveal, fill counters,
  compute grade, **dress ambience** (Rev 09-28: unchanged, still after
  `_compute_grade()`, which sets `_passed`), draw caption, set button face,
  play reveal). `_build_rows()` becomes
  `_fill_counters()` (six `set_value` calls, no building). `_play_reveal()`
  splits into `_reveal_title()`, `_reveal_strip(strip, delay)`,
  `_slam_grade()`, `_show_grade()`, `_on_grade_landed()`, `_reveal_finale()`,
  plus `skip_reveal()`. `_apply_progression()` splits per branch (§5). None
  over 50.
- **Flat (§4):** guard clauses; `match` on `Outcome`; the reveal is a straight
  sequence of awaits, never a self-calling coroutine.
- **DRY ⚙ (§5):** `Juice.count_up_formatted` instead of a hand-rolled
  count-up; one `format_value` for every cell; the existing `StarBurst.tscn`
  and `RewardFeedback`; `RunResultNameLabel` reused for captions;
  `GameState.grade_name_for` as the one "Kelas N" wording; `UIPolish` owns
  button press juice (don't add a second one without opting out);
  `_reset_failed_run()` written once for both loss branches.
- **Signals up, calls down (§6):** RunResult calls down into its counters
  (`set_value()`, `count_up(delay, duration) -> Tween`, `show_final()`).
  StatCounter never reaches up and needs no signal (it reports nothing). Every
  node the script touches is `@onready var x: T = %Name`: no `$A/B/C` paths,
  which is what let today's layout change break five tests at once.
  **Rev 09-28:** that includes today's `$WinStage`, `$BlurLayer`,
  `$AmbientPass` and `$AmbientFail`; their paths stay the same, so the
  path-based pins still hold.
- **No type inference from an autoload** (`tests/test_project_hygiene.gd`, PRs #97/#98, 2026-09-28): never `var x := GameState.…` or `:=` on any autoload call (ItemDatabase, GameSettings, …); declare the type, e.g. `var money: int = GameState.player_money`. A cold editor restart once left such results untyped, which makes `:=` a parse error.
- **Type everything ⚙ (§7):** `->` on every function, typed parameters, typed
  `@onready`s (`var menang_counter: StatCounter = %MenangCounter`),
  `Array[Tween]`, `Array[String]`, `Array[StatCounter]`, `Outcome`, typed loop
  variables (`for tween: Tween in ...`, as the file's `TUTORIAL_FLAGS` loop
  already does). `:=` only where the right side is obvious. Type a `Variant`
  read explicitly (the `String(...)` around `pick_random()`).
- **Comments say why (§8):** `##` file header on `StatCounter.gd` and a `##`
  line on every `@export` (`tests/test_script_documentation.gd`); update
  RunResult's header (it still says "six counted-up figures" rows). No
  commented-out code.
- **Fail loudly (§9):** unmapped rank → `push_error` (§6); unmapped outcome →
  `push_error` (§5); a missing `%` node is a load error, not a silent
  `get_node_or_null` skip. `_reset_static_flag()` already reports a missing
  flag (PR #85).
- **Boy Scout (§10):** every function touched ends shorter or equal and no
  less typed. `_slam_grade`, `_on_selesai_pressed` and `_apply_progression`
  lose their bare numbers here. The two stale "Corrected from the brief"
  comments leave with the code they described.

**Locking in the reduction.** The shrink above makes `test_clean_code` fail
("shrank -- lock it in") until the baseline is regenerated **in the same
commit**, in plain mode (it only ever lowers):

    <Godot console exe> --headless --path . --script res://ci/clean_code_dump.gd

Then check `git diff ci/clean_code_baseline.gd` shows only RunResult.gd's
`BARE_NUMBERS` line removed (**Rev 09-28:** there is no `UNTYPED` line left
to remove) and nothing raised. No
`-- --rekey` is needed: RunResult.gd has no function-keyed entries, and
`RunResultRow.gd` has none to move. If the dump prints any `RAISED (review):`
line it writes nothing. Fix the code, never the baseline. An open editor keeps
serving the old baseline until a no-op `script_patch` of it. **Rev 09-28:**
if a merge from `Textures` conflicts in the baseline, never hand-merge it:
take one side whole (`git checkout --ours|--theirs`), run the dump
(`-- --rekey` if the other side moved anything), and review the diff.

---

## 8. Tests

`tests/test_run_result.gd` is source-text scans plus structural checks on a bare
`instantiate()` (the scene is deliberately **not** `@tool`; live property reads
are off-limits). Follow that pattern. **Rev:** static helpers on
`class_name RunResult` can be called directly without an instance.

- **Layout:** assert the scene has `%MedalStrips` with `%StripTop` /
  `%StripBottom`, each holding three `StatCounter` instances (six in all);
  assert `%GradeBadge` still exists as a `TextureRect` and the root still
  binds the five `rank_badge_*` exports. **Rev:** assert the report UI sits
  under `Safe` → `UI`. **Rev 09-28:** and that `Safe` comes after
  `AmbientFail` in the root's child order.
- **Captions:** assert `GRADE_CAPTIONS` has an entry for each rank. **Rev:**
  take the ranks from `RunGrade.LETTER_BANDS` + `RunGrade.LETTER_FLOOR`
  instead of a hand list, so a new rank fails the test. Call
  `RunResult.caption_pool_for(rank)` and assert each pool is non-empty and
  every member a non-empty `String`. Assert the helper's source contains
  `push_error`. **Rev 09-28:** assert `_draw_caption(` is called in `_ready`'s
  body and not in `_slam_grade`'s.
- **Button:** **Rev:** assert `RunResult.outcome_for()` maps the five
  (`run_failed`, `current_grade`) combinations to the four outcomes, and
  `RunResult.button_label_for()` returns the five strings of §5. Pure, no
  scene. Source-scan that `_apply_progression` matches on `outcome_for(` and
  that the three icon exports are assigned in the scene.
- **Motion:** scan for the reused call names (`staggered_entrance(`,
  `count_up_formatted(`, `pop_in(`, `idle_pulse(`, `wobble(`,
  `star_burst.fire(`), scoped to function bodies the way
  `test_the_backdrop_is_dressed_from_the_same_verdict_flag` scopes its scan.
  Assert `skip_reveal()`'s body calls `.kill()` on the tracked tweens.
  **Rev 09-28:** assert `_play_reveal()`'s body checks
  `GameSettings.reduce_motion` before any tween. Assert `_on_grade_landed()`
  starts with the `_has_landed` guard.
- **StatCounter:** port the row-template tests to it: loads, has a
  `TextureRect` icon (never a Label) with a stand-in texture, `set_value`
  writes "0" + suffix at rest, `format_value` rounds and appends the suffix,
  and the caption contrasts with its Card and is at least body size (reuse
  `_resolve_row_name`'s baked-theme method).
- **Editability:** **Rev:** expect **no** new `ALLOWED` entry. Delete or
  rewrite RunResult.gd's stale entry in `tests/test_viewport_editability.gd`.
  Confirm `BASELINE` is unchanged.
- **Theme:** if a new display variation was added, update `DISPLAY_ROSTER` in
  `tests/test_theme_factory.gd` and rebake. **Rev:** plus
  `tests/test_button_geometry.gd`'s tables for the green M button. **Rev
  09-28:** plus `ResultCaptionLabel` in the body-face list and all three in
  `test_every_declared_variation_exists` (§3).

**Rev — existing tests this layout breaks (update them in the same PR):**
- `test_run_result.gd`: the three `MarginContainer/...` path tests;
  `test_the_script_actually_compiles` (checks `has_method("_build_rows")`:
  use `_fill_counters`); `test_it_reports_all_six_figures` (the six old labels;
  scan the `.tscn` for the new captions instead);
  `test_the_report_uses_texture_icons_not_emoji` (the icon path moves from the
  script to the `.tscn`); the backdrop order test
  (`order.find("MarginContainer")` → `Safe`); `test_the_title_reads_over_the_letterbox_bar`
  (reads `MarginContainer/Column/TitleLabel`); the six RunResultRow tests
  (port to StatCounter). **Rev 09-28:**
  `test_grade7_loss_goes_to_main_menu_grade8_9_restarts_same_grade` scans
  `GameState.current_grade == 7`. Pin `outcome_for`'s mapping instead (the
  Button test above) and scan `grade == FIRST_GRADE`.
  `test_every_tutorial_flag_to_reset_exists_on_its_script` and
  `test_the_flag_reset_clears_the_student_list_walkthrough` must pass
  **unchanged**.
- `test_run_grade_ranks.gd`: `test_the_grade_is_a_badge_not_a_letter_label`
  pins `MarginContainer/Column/GradeCard/GradeStack`.
- **Rev 09-28:** `test_ambient_kit.gd`:
  `test_run_result_carries_both_moods_over_the_blur` reads the badge's
  material at `MarginContainer/Column/GradeCard/GradeStack/GradeBadge`. Point
  it at the new path (`Safe/UI/Column/MedallionStack/GradeBadge`). The
  first-four-children assertion must pass unchanged.
- **Rev 09-28:** `test_shop_weekly_stock.gd`:
  `test_every_run_restart_clears_the_shop` takes `_apply_progression()`'s own
  body up to `if GameState.current_grade < 9:` and expects
  `GameState.reset_shop_week()` in it. After the split, scan
  `_reset_failed_run()`'s body for it, and assert `_restart_run` and
  `_retry_grade` both call `_reset_failed_run()`.
- `test_back_controls.gd`: RunResult's `ROSTER` entry (§5).
- `test_tall_screen_layout.gd`: add RunResult (§3), contract only.
- `style-guide.md`'s `RunResultNameLabel` line; `test_light_ground_text.gd`'s
  header comment mentions RunResult's row names. Keep it accurate.
  `test_end_game_rehearsal.gd`'s comments cite `RunResult.gd` line numbers
  (`:109-114`, `:197-210`). Refresh them or drop the numbers (comments only).

**Rev — clean-code checklist (run before `ship-pr`):**
- [ ] `test_run(suite="clean_code")` green: no "grew", no un-locked "shrank".
- [ ] `ci/clean_code_dump.gd` run in plain mode after the shrink; the baseline
      diff only removes RunResult.gd's `BARE_NUMBERS` line.
- [ ] `script_documentation`, `viewport_editability`, `theme_factory`,
      `button_geometry`, `back_controls`, `tall_screen_layout`, `run_result`,
      `run_grade_ranks`, `ambient_kit`, `shop_weekly_stock`, `achievements`,
      `end_game_rehearsal`, `audio_coverage`, `end_cutscene`, `win_stage`,
      `light_ground_text`, `confirm_pair_semantics`, `project_hygiene` green
      as targeted runs (`theme_rebake` only alone, §3).
- [ ] `grep -n "theme_override" Scenes/EndGame/StatCounter.tscn
      Scenes/EndGame/RunResult.tscn` shows only layout constants
      (`separation`, `margin_*`).
- [ ] No bare number, untyped `var` or `->`-less function in `RunResult.gd` or
      `StatCounter.gd`; no function over 50 code lines.

Run with the Godot AI MCP `test_run` (targeted per suite; a full run rebakes the
theme and drops the bridge; see project guide). Check `git status` after any
full run and revert an unintended `kejartes_theme.tres` / `default_bus_layout.tres`.

---

## 9. Build plan (Rev 09-28: tagged tasks)

**[editor]** = the controller, through the godot-ai bridge (single-client:
no subagent touches it). **[code]** = a subagent writing files with plain
edits, never the bridge; it hands back, and the controller verifies. Scene
work comes before script work (CLAUDE.md 4b). The only script edits made
before a `scene_save` go through the editor itself (`script_create` /
`script_patch`), so no tab is stale. After a **[code]** step touches any
`.gd`, the controller does a no-op `script_patch` on each changed file (or
restarts) before `test_run`. After every `scene_save`:
`git diff HEAD -- '*.gd'` for files not being edited, and a diff of every
saved scene for baked `@tool` state.

**Task 0 — Preflight [editor]**
1. `git status`, `git reflog -1` and `git branch --show-current` in one
   command (the checkout is shared). Branch per open question 5, from current
   `origin/Textures`, and bring this spec in. Close Godot without saving
   before any checkout or merge, then restart it.
2. Open `Scenes/MainMenu/MainMenu.tscn`. Baseline:
   `test_run(suite="clean_code")`, `run_result`, `run_grade_ranks`,
   `ambient_kit`, `shop_weekly_stock` all green before anything changes.

**Task 1 — StatCounter scene [editor]**
1. `script_create` `Scripts/EndGame/StatCounter.gd` with §3's script (it is
   self-contained, so the scene can carry its exports).
2. `scene_manage` create `Scenes/EndGame/StatCounter.tscn`: `PanelContainer`
   root with `theme_type_variation = &"Card"` and the script, then a VBox with
   `%Icon` (TextureRect, stand-in texture), `%Value` (`ResultStatValueLabel`;
   the name is set now and the variation lands in Task 4) and `%Caption`
   (`RunResultNameLabel`). No `theme_override_*` beyond `separation` /
   `margin_*`. `scene_save`, then diff the scene.
3. Verify: `test_run(suite="clean_code")`, `script_documentation`. Commit.

**Task 2 — RunResult re-layout [editor]**
1. `script_patch` `RunResult.gd` with **only** the three `icon_*` `@export`s
   (with `##` lines, in a "Button icons" group), so the scene can assign them.
2. In `RunResult.tscn`: add `Safe` (`MarginContainer` + `SafeAreaMargin`
   script, Full Rect, IGNORE) → `UI` → `Column` right after `AmbientFail`.
   Reparent `TitleLabel`, `GradeBadge`, `GradeCaption` and `BtnSelesai` into
   the §3 tree. Use a real reparent: `move_node` only reorders siblings, and
   a missing `index` rolls back a whole batch. `GradeBadge` keeps its glint
   `material`. Set it to ~450–510 px and `mouse_filter` STOP. Set `UI`,
   `Column` and the strips to IGNORE (§4, skip-to-end). Add
   `MedallionStack`, `MedalStrips`, `StripTop`/`StripBottom` and the six named
   `StatCounter` instances (icon/caption/suffix on each **root**), plus
   `StarBurst.tscn` under `GradeBadge` at its centre. Set `%` on every node
   the script touches, including `WinStage`, `BlurLayer`, `AmbientPass` and
   `AmbientFail`. Assign `icon_advance` (`icon_chevron_right.png`); the other
   two wait for Task 3's art. Set `GradeCaption` to `ResultCaptionLabel`.
   Delete `MarginContainer`, `GradeCard` and `RowsBox`.
3. Re-aim `AmbientPass/Warm.center` on the medallion.
4. `scene_save`; diff the scene; `git diff HEAD -- '*.gd'`.
5. Verify: `test_run(suite="ambient_kit")` (only the badge-path assertion may
   fail; it is fixed in Task 6) and `clean_code`. Commit, noting the
   expected red path pins.

**Task 3 — Button art [code] then [editor]** (the last planned scene save,
so the rebake can follow)
1. [code] Author `icon_retry.svg` and `icon_trophy.svg` in
   `Assets/Images/UI/Placeholders/` (transparent, drop-replaceable,
   snake_case). No `.gd` is touched here, so no editor tab can go stale.
2. [editor] `filesystem_manage(op="scan")` so both import. Assign
   `icon_finish_game` / `icon_retry` on RunResult's root, `scene_save`, diff
   the scene and `git diff HEAD -- '*.gd'`. `test_run(suite="clean_code")`,
   `project_hygiene`. Commit.

**Task 4 — Theme variations and rebake [code] then [editor]**
1. [code] `ThemeFactory.gd`: `ResultStatValueLabel`, `ResultCaptionLabel` and
   `CelebrateButtonM` (§3, §5), token expressions only. Tests:
   `DISPLAY_ROSTER`, the body-face list, `test_every_declared_variation_exists`,
   and `test_button_geometry.gd`'s two tables. `style-guide.md` lines for the
   three, and `RunResultNameLabel`'s line reworded.
2. [editor] Restart the editor. Run `test_run(suite="theme_rebake")` **alone**,
   then restart again. `git diff` the bake: only the three variations' lines.
   Then `test_run(suite="clean_code")`, `theme_factory`, `button_geometry`,
   `confirm_pair_semantics`. No `scene_save` between the rebake and the
   restart. Commit the factory, tests and bake together.

**Task 5 — RunResult.gd, Juice, GameState, RunResultRow removal [code] then [editor]**
1. [code] `Juice.fade_in -> Tween`. `GameState.grade_name_for` with
   `get_grade_name()` delegating to it. `RunResult.gd` rewritten to §4–§7:
   `class_name RunResult`, the const block, `Outcome`/`outcome_for`/
   `button_label_for`, the progression split, `%` onreadys, `_fill_counters`,
   the reveal functions, `_track`/`skip_reveal`/`_has_landed`,
   `reduce_motion`, the caption pool and draw, the button face, and the
   header. `_dress_ambience()` and `_reset_static_flag()` stay byte-for-byte.
   With `ROW_SCENE` gone, delete `RunResultRow.tscn`/`.gd` (+ `.uid`). In the
   same hand-off, replace the six RunResultRow tests in `test_run_result.gd`
   with their StatCounter ports (§8), so the suite never loads a deleted
   scene.
2. [editor] No-op `script_patch` on every changed `.gd`, then
   `project_manage(op="stop")` and `filesystem_manage(op="scan")` (a new
   `class_name`). Then `test_run(suite="clean_code")`: expect "shrank" on
   RunResult.gd. Run the dump in plain mode; its diff removes only
   RunResult.gd's `BARE_NUMBERS` line. No-op `script_patch` the baseline and
   re-run `clean_code` green, then `script_documentation`, `achievements`,
   `audio_coverage`, `end_cutscene`, `win_stage`. Commit code and baseline
   together. (`run_result` and friends stay red on the old path pins until
   Task 6.)

**Task 6 — Tests [code] then [editor]**
1. [code] Everything in §8: new tests, the pins (`test_run_result`,
   `test_run_grade_ranks`, `test_ambient_kit`, `test_shop_weekly_stock`,
   `test_back_controls`, `test_viewport_editability`), the
   `test_tall_screen_layout` contract, and the stale comments. No coroutine
   tests; every suite stays `@tool`.
2. [editor] No-op `script_patch` each changed test. Run
   `test_run(suite="clean_code")`, then each suite in §8's checklist, one by
   one. Commit.

**Task 7 — Look check [editor]**
Seed (Debug → General → Seed Playtest State), then use Scenes → **Gladi Resik
Akhir Kelas** to reach RunResult on a pass (S/A) and a fail (D). Screenshot
at full size at 1080×1920 and 1080×2400, freezing time as the memory notes
describe. Check:
- the widest value (`24000G`) fits a cell; if not, lower `ResultStatValueLabel`;
- the caption reads on the painting;
- the warm pool sits behind the medallion;
- the StarBurst centres on the badge;
- a tap skips cleanly, and Kurangi Gerakan lands at rest.
Fix layout numbers in the `.tscn` only (scene op, then save, then diff).

**Task 8 — Close out [code] then [editor]**
1. [code] `docs/superpowers/CHANGELOG.md` entry (newest first). DEBT: delete
   "Deferred: Plan C's RunResult redesign", now superseded and stale ("no
   RunResult commit since 2026-09-11" has been false since PR #85/#88). Add
   one grouped placeholder entry for `icon_retry.svg` / `icon_trophy.svg`,
   and refresh the `icon_event.svg` note (RunResult's counters, not rows).
2. [editor] Full `test_run` (budget one editor restart; the bridge drops).
   `git status`, and `git checkout --` an unintended bake /
   `default_bus_layout.tres`. Update CLAUDE.md's "N suites, M tests (date)"
   line from that run.
3. Finish with the `ship-pr` skill (it binds the PR and stamps the tested
   commit).

---

## 10. Assets to create (placeholders, drop-replaceable)

- ~~`nav_arrow_forward`~~ **Rev:** reuse `Assets/Images/UI/Nav/icon_chevron_right.png`
  (button "Lanjut"); no new asset
- `icon_retry.svg` (button "Ulangi" / "Mulai Ulang"), was `nav_refresh`
- `icon_trophy.svg` (button "Selesaikan Permainan"), was `nav_trophy`
- ~~optional `fx_star`~~ **Rev:** not needed: the existing `StarBurst.tscn`
  already carries `Assets/Images/Particles/particle_star.png`

All transparent SVG, authored beside the existing UI icons in
`Assets/Images/UI/Placeholders/` (where the other placeholder `icon_*.svg`
live; `UI/Nav/` holds the finished PNG nav art), same-path drop-replaceable,
names in snake_case from the safe character set (clean-code §1), logged in
`docs/superpowers/DEBT.md` as one grouped entry. (Re-checked 2026-09-28: no
retry/trophy art exists in the repo yet.)

---

## Summary of the 2026-09-27 revision

What changed and why (design decisions untouched):

1. **Stale API fixes.** `Juice.count_up` returns `void` → use
   `count_up_formatted` (returns a `Tween`, takes delay + duration);
   `Juice.fade_in` returns `void` → make it return its `Tween` for the skip;
   `GameState.get_grade_name()` names only the current grade → add
   `grade_name_for(grade)`; `SuccessButtonM` does not exist and `SuccessButton`
   is Lobby brown since 2026-09-14 → a real green M variation;
   `RewardFeedback`'s `run_win` throws no particles → an authored `StarBurst`.
2. **Stale claims fixed.** `test_tall_screen_layout.gd` does not cover
   RunResult (add it); confetti/wobble do not trip the editability scan
   (it counts `.new(` only), and `create_floating_text` is avoided because it
   builds a themed Label with overrides and a glyph; `return_button.png` has
   other callers (keep it); `BtnSelesai` leaves `test_back_controls`.
3. **Units.** Sizes restated in 1080 project pixels on tokens; the medallion
   grows to ~450–510 px, not 150.
4. **Clean code.** New §7: named consts / `@export`s for every number,
   `class_name RunResult`, `Outcome` enum + pure static helpers, typed caption
   pool with `push_error` on an unmapped rank, functions ≤ 50 lines,
   `%` unique names, authored counters instead of runtime rows, delete
   `RunResultRow`, RunResult.gd's `BARE_NUMBERS` 8→0 locked
   in with the plain-mode dump (its `UNTYPED` 2 was cleared by PR #85 since).
5. **Tests.** Lists the existing pins the new tree breaks, and a
   clean-code checklist.
6. **Assets.** Names moved to the folders' `icon_*` snake_case convention;
   the forward arrow and star reuse existing art.

(The 2026-09-28 changes are listed in the note at the top.)

## Open questions

1. **Size scale.** Were the mock's px figures (medallion 150–170, value 28–34,
   caption ≥13/14) meant at a 360-wide mockup scale? This revision assumes so
   (×3). If they were meant literally at 1080, the medallion and captions
   would *shrink*, against the mentor's note.
2. **Beat-the-game colour.** A new green button variation (not
   `SuccessButtonM`, which would be brown) is proposed. Confirm green is still
   wanted now that every framed button is Lobby brown, or pick another
   celebratory look (e.g. gold).
3. **`back_bounce` on a forward button.** It tilts counter-clockwise, a "back"
   gesture, while the button now mostly says "Lanjut". Keep it (with
   `NO_AUTO_JUICE`), or let `UIPolish`'s standard press juice stand?
4. ~~**Found in passing:** the beat-the-game Lobby reset of `tutorial_shown` is
   a silent no-op.~~ **Rev 09-28: resolved by PR #85**
   (`7b682dd1`): `TUTORIAL_FLAGS` now points the flag at `StudentList.gd` and
   `_reset_static_flag()` errors on a missing one. This pass keeps it as is.
5. **Rev 09-28 — which branch builds it?** PR #86 is docs-only and forks from
   before the ambient kit. Either merge `Textures` into
   `badgerankscenepolish` and build there (the PR then grows from spec to
   feature), or merge #86 as the spec and build on a new branch from
   `Textures`.
6. **Rev 09-28 — reduce motion.** This plan lands the reveal at rest under
   Kurangi Gerakan (still with the stamp, fanfare and one burst) and drops the
   idle pulse. Should the tap-wobble easter egg also be off under it, and
   should the burst be skipped too?
7. **Rev 09-28 — StarBurst's own sparkle cue.** `RewardParticles.fire()` plays
   `&"sparkle"` unless `plays_sfx` is off, on top of the stamp and, for S/A,
   `run_win`'s fanfare. Set `plays_sfx = false` on the instance (a root
   property, so it serialises), or keep the extra cue?
