# RunResult (Badge Rank Scene) polish — design & handoff

> **Revised 2026-09-27 for the clean-code standard.** The design decisions
> below are the collaborator's and are unchanged: layout Option C, the reveal
> order, the contextual button, the caption pools and the scope. The revision
> adds what `docs/superpowers/design/clean-code.md` and the post-clean-code
> `Textures` require, and corrects the path and API references that no longer
> hold. Revised passages carry a **Rev:** tag; §7 (Clean-code requirements) is
> new; the list of changes and the open questions are at the end.

**Branch:** `badgerankscenepolish` (off `Textures`, which must already contain
the clean-code pass (PR1–PR3) before this is built)
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
- Persistence. No new `user://` writes.

---

## 3. Layout — Option C

Portrait 1080-wide. Keep `WinStage` + `BlurLayer` as the first two children,
unchanged. **Rev:** the report UI moves out of the bare full-rect
`MarginContainer` and into the project's tall-phone shell, `Safe`
(`SafeAreaMargin`, Full Rect, `mouse_filter` IGNORE) → `UI` (plain `Control`)
→ `Column` (authoring guide, "Tall phones", rule 3). Every node the script
touches gets a **unique name (`%`)** so the script never spells a path
(clean-code §6):

```
RunResult (Control, script RunResult.gd)
├─ WinStage              (unchanged)
├─ BlurLayer             (unchanged)
├─ Safe (SafeAreaMargin) → UI (Control)
│   └─ Column (VBox)
│       ├─ %TitleLabel       "Hasil Kelas 7" — masthead, ResultHeroLabel (unchanged variation)
│       ├─ %MedallionStack (VBox, centered)
│       │   ├─ %GradeBadge   TextureRect, the rank medallion (unchanged art)
│       │   └─ %GradeCaption one line, from the rank's caption pool (§6)
│       ├─ %MedalStrips (VBox, separation ~12)
│       │   ├─ %StripTop     HBox of 3 StatCounter instances
│       │   └─ %StripBottom  HBox of 3 StatCounter instances
│       └─ %BtnSelesai       contextual label + icon (§5)
└─ %StarBurst            authored one-shot burst (§4, step 5)
```

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
**Rev:** RunResult is `RunResultRow`'s only caller (re-checked 2026-09-27:
only `RunResult.gd`, `tests/test_run_result.gd`, `tests/test_viewport_editability.gd`
and the changelog name it), so delete `RunResultRow.tscn` + `.gd` in the
same PR. Keeping it would also leave two count-up bodies side by side, which
the duplicate-body ratchet flags.

**Rev — the six cells are authored, not built.** The test plan (§8) already
asks for "six `StatCounter` instances" in the scene, so the cells are placed in
`RunResult.tscn`, not instanced by code. The authoring guide's "no visual is
built at runtime" rule prefers that. Each cell's fixed facts are `@export`s on
the StatCounter **root** (overrides on an instance's children are dropped on
save; CLAUDE.md 4b), each with a `##` line:

```gdscript
## The figure's picture: a transparent SVG, never a text glyph.
@export var icon_texture: Texture2D
## The word under the number, e.g. "Menang".
@export var caption_text: String = ""
## Appended to the counted number, e.g. "G" for the wirausaha cell.
@export var value_suffix: String = ""
```

Name the six by what they count, not by position (clean-code §1, "no numbered
stand-ins"): `%MenangCounter`, `%KalahCounter`, `%PoinCounter`,
`%BarangCounter`, `%WirausahaCounter`, `%EventCounter`.

The six cells, in order (icon → value → caption), values from
`GameState.run_stats` (a `RunStats`; **Rev:** field names re-checked, and
PR3's stat-key rename does not touch them):

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
- GradeCaption: **≥ 42 px** equivalent. Option C takes it **off the Card**, onto the
  blurred painting, so the old dark ink will not read there. Add
  `ResultCaptionLabel`: body face, light ink with the dark outline
  `ResultHeroLabel` uses (`tokens.text_outline_size`, outline `text_primary`),
  size `tokens.font_h2` (48) or `font_body_size + 8`. Pick by measurement.
- Any new variation goes in `ThemeFactory.gd` and needs a **rebake**
  (`Scripts/Design/BakeTheme.gd` via File > Run), and an entry in
  `DISPLAY_ROSTER` in `tests/test_theme_factory.gd` if it's a display face
  (`ResultStatValueLabel` is; `ResultCaptionLabel` is not). Sizes come from
  token expressions, not literals. `ThemeFactory.gd` is exempt from the
  bare-number count (`ci/clean_code_allowed.gd`), but tokens remain the style
  guide's rule.

Category colours for the counter accents come from `DesignTokens.gd`
(`cat_akademis` #1F6FBA, `cat_senibudaya` #3D7F12, `cat_olahraga` #E03A18,
`currency_gold` #ffc93c, `brand_primary` #7A4A2B). No new tokens. **Rev:** the
hexes are today's values for reference only. A counter that wears an accent
reads it from the tokens by name (e.g. `@export var accent_token: StringName`
resolved through `Juice.tokens()`), never from a copied `Color`, so a token
edit cannot leave the counters behind.

**Tall phones:** re-anchor per the authoring guide's "Tall phones": backdrop
Full Rect + Keep Aspect Covered, UI inside `SafeAreaMargin`. **Rev:**
`test_tall_screen_layout.gd` does **not** cover RunResult today. No EndGame
scene is in it, and RunResult is not in DEBT's Phase 2/3 list either. Add
RunResult's contract test there (`Safe` → `UI`, `Column` under the safe area)
as part of this pass.

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
   **`Juice.count_up_formatted`** for all six cells, not `Juice.count_up`.
   `count_up` returns `void`, so a skip could never stop it, and it ignores the
   screen's `count_up_seconds`. `count_up_formatted(label, from, to, formatter,
   delay, duration) -> Tween` takes a delay (pass the strip's delay) and a
   duration (pass `count_up_seconds`), and one formatter covers the "G" cell
   too. The formatter is a pure static on StatCounter, modelled on
   `MinigameWinStat.format_delta`:
   `static func format_value(value: float, suffix: String) -> String`.
   Keep the existing SFX split: coin cell → `AudioDirector.play_sfx(&"coin")`,
   others → `&"pop"`. **Rev:** decide "is this the coin cell" by node
   (`counter == wirausaha_counter`), not by comparing caption strings as
   `_build_rows()` does today.
4. Drumroll pause (`grade_delay`), then the medallion slams in: the existing
   `_slam_grade()` tween (scale 3.0 → 1.0, `TRANS_BACK`), unchanged in
   behaviour. **Rev:** the literal becomes
   `const GRADE_SLAM_FROM_SCALE := 3.0`; track the tween.
5. On land: `play_sfx(&"stamp")` + `Juice.shake(medallion.get_parent(), 8.0)` +
   **star confetti** + `RewardFeedback.play(&"run_win", self)` for S/A (keep the
   existing `RunGrade.is_top_grade` gate; keep `&"fail"` for D).
   **Rev:**
   - `8.0` becomes `const GRADE_LAND_SHAKE := 8.0`.
   - `RewardFeedback` (autoload, `Scripts/Feedback/RewardFeedback.gd`) plays
     `run_win` at the Celebration tier, which **throws no particles of its
     own** (its header: celebrating screens author their own) and already
     shakes the screen root. So the star confetti is the screen's: an
     **authored** `%StarBurst` node in `RunResult.tscn`, an instance of the
     existing `Scenes/Minigames/UI/StarBurst.tscn` (a `RewardParticles` burst
     of `particle_star.png`; `PaperConfetti.tscn` is the paper alternative),
     fired with `star_burst.fire()`. `AchievementClaimPopup` does the same.
     `fire()` frees the node once spent, so fire it exactly once per visit.
   - Put the landing in its own function (`_on_grade_landed()`) rather than
     the inline lambda it is today, so each piece stays short and named.
6. Caption + button fade in last. (The RANK ribbon is part of the medallion
   art, so it arrives with the slam.) **Rev:** `Juice.fade_in` returns `void`
   today, so a skip cannot stop it. Make it return its `Tween`, the same
   backward-compatible change `pop_in` already documents ("a skipped reveal
   must not let a half-faded node keep fading"): `-> Tween`, `return null` on
   the dead-node guard. Its one existing caller ignores the result. Keep
   `BtnSelesai` non-interactive (`disabled`) until this step or a skip lands
   it, so an invisible button cannot be pressed.

Cutey extras (optional, but requested feel):
- `AnimUtils.idle_pulse(medallion)` after it settles: a heartbeat, not a
  freeze. **Rev:** keep the returned looping `Tween` in
  `var _idle_pulse: Tween`.
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
  medallion tap wobbles.

**Rev — the editability ratchet.** The original note says confetti and
tap-to-wobble "will trip `tests/test_viewport_editability.gd`". They will not.
That suite counts only `.new(` calls on visual node types. `wobble` is a tween
on an existing node, and an authored `%StarBurst` builds nothing. Do **not**
use `AnimUtils.create_floating_text` with a ★ glyph: it builds a `Label` at
runtime with `add_theme_*_override` calls, and a text star is glyph
iconography. Expected result: `ALLOWED` gains nothing and `BASELINE` is
unchanged. With the six cells authored, `RunResult.gd` constructs nothing:
delete its `ALLOWED` entry (value `0`, whose comment describes the retired
`_build_rows()`), or rewrite that comment if the suite needs the key.

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
current wording (see §2).

- Interpolate the grade number with `GameState.get_grade_name()` rather than
  hardcoding, so "Kelas 8/9/N" stays correct. **Rev:** `get_grade_name()` only
  names the **current** grade ("Kelas " + `current_grade`), and "Lanjut ke
  Kelas 8" needs the *next* one. Add `static func grade_name_for(grade: int) ->
  String` to `GameState` and make `get_grade_name()` return
  `grade_name_for(current_grade)`, so the "Kelas %d" wording lives in one
  place. `GameState.shop_week_key_for()` is the precedent for a static
  helper on that autoload.
- The **beat-the-game** state gets a distinct celebratory treatment: swap
  `PrimaryButtonM` → a success-green button variation for that one state (no
  `theme_override`). **Rev:** there is **no `SuccessButtonM`**, and plain
  `SuccessButton` is **not green** any more. Since the 2026-09-14
  lobby-style-buttons pass, `ThemeFactory._build_buttons` gives Primary,
  Secondary, Danger *and* Success the same Lobby brown look, so a
  `SuccessButtonM` would look identical to `PrimaryButtonM`. Add a genuinely
  green M-step variation instead (working name `CelebrateButtonM`), built the
  way `RosterStatusSudah` gets its green (`_add_button_variation` from
  `tokens.state_success`) with the M padding. `_add_size_step` sets
  `base_type` to `Button`, so the new variation also needs its own
  `icon_max_width` (`tokens.btn_icon_s`) and `h_separation`
  (`tokens.space_sm`) like `PrimaryButtonM`, or the trophy renders at its
  native size. Register it in `tests/test_button_geometry.gd`'s step and
  height tables and in `DISPLAY_ROSTER`. Switching `theme_type_variation` at
  runtime is not an override. Green = "earned", which fits
  `tests/test_confirm_pair_semantics.gd`'s rule.
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
- **Rev:** `return_button.png` stays. Nine other scenes use it (AturJadwal,
  Inventory, Koperasi, ShopHub, CosmeticShop, ReportCard, SchoolDay and both
  Achievements screens). But `BtnSelesai` stops being a back control, so
  remove RunResult's entry from `tests/test_back_controls.gd`'s `ROSTER`
  (it pins `MarginContainer/Column/BtnSelesai` to the canonical back texture)
  with a one-line comment saying why.

---

## 6. Caption pool per rank

Replace the single-string `GRADE_CAPTIONS` with a **pool per rank**; pick one at
random in `_slam_grade()` (`pick_random()`). This keeps the screen from
saying the same sentence every run. Wording (Indonesian, mentor-approved
starting set; tune freely):

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
`test_every_rank_has_a_caption` scans for exactly that. The pool is read through
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

`_slam_grade()` becomes:
```gdscript
var pool := caption_pool_for(_grade_text)
grade_caption.text = "" if pool.is_empty() else String(pool.pick_random())
```
The screen still never crashes on a bad rank: the caption is blank, as it was
before, but the error now reaches the log. (`_badge_for()`'s silent fall-back
to D is out of scope, §2, and stays as it is.)

---

## 7. Clean-code requirements (new)

The rulebook is `docs/superpowers/design/clean-code.md` (⚙ = enforced by the
ratchet in `tests/test_clean_code.gd` and CI's `ci/project_check.gd`). What it
means for this pass:

**Today's debt for the files this touches** (`ci/clean_code_baseline.gd`):

| Entry | Now | After this pass |
|---|---|---|
| `UNTYPED` `Scripts/EndGame/RunResult.gd` | 2 | **0**: type the two `load()` results in the beat-the-game branch (`var atur_jadwal_script: GDScript = load(...)`, same for the Lobby one) |
| `BARE_NUMBERS` `Scripts/EndGame/RunResult.gd` | 8 | **0**: by our reading the 8 are `Vector2(3.0, 3.0)` (2), `shake(..., 8.0)`, the exit fade `0.4`, `== 7`, `< 9`, `set_grade(7)`, and `entry[3]` in `_build_rows()` |
| `LONG_FUNCTIONS` for RunResult.gd | none | **none**: every function stays ≤ 50 code lines (`_apply_progression` is 42 today; split it, §5) |
| `LARGE_SCRIPTS` | not listed (299 lines) | stays far under 1,000 |
| `DUPLICATE_GROUPS` | none for EndGame | none: no copied count-up body (delete `RunResultRow`) |
| `UNTYPED` `Scripts/Design/Juice.gd` | 5 | ≤ 5 (the `fade_in` return change adds none) |
| `Scripts/GameState.gd` | `UNTYPED` 9 (and bare numbers) | no growth (`grade_name_for` is typed and number-free) |
| `RunResultRow.gd`, new `StatCounter.gd` | no entries | new scripts start clean, so they must be clean from the first commit |

`ThemeFactory.gd` is in `ci/clean_code_allowed.gd` for long functions, size and
bare numbers, so new variations there add no debt. `ALLOWED` gains nothing
from this pass.

**Rules, applied:**
- **Names (§1):** `StatCounter.tscn`/`.gd`, `class_name StatCounter`,
  `class_name RunResult`; counters named by what they count; new art
  `icon_retry.svg`, `icon_trophy.svg` (snake_case, `A–Z a–z 0–9 _ - .` only);
  booleans read as questions (`_is_revealing`, `_is_exiting`: rename
  `_exiting` while touching it).
- **No magic numbers ⚙ (§2):** logic constants in a `const` block at the top of
  `RunResult.gd`: `GRADE_SLAM_FROM_SCALE`, `GRADE_LAND_SHAKE`,
  `EXIT_FADE_SECONDS` (the `0.4` in `_on_selesai_pressed`), `FIRST_GRADE`,
  `FINAL_GRADE`, each with a `##` line. Timing a designer tunes is an
  `@export` in "Reveal Timing" (`strip_stagger`, `count_up_seconds`,
  `grade_delay`). Medallion size, strip separation and cell padding are
  `.tscn` layout. Font sizes are `ThemeFactory` variations from tokens.
- **One job per function ⚙ (§3):** `_ready()` reads as a table of contents
  (bind signals, play BGM, dress backdrop, reset for reveal, fill counters,
  compute grade, set button face, play reveal). `_build_rows()` becomes
  `_fill_counters()` (six `set_value` calls, no building). `_play_reveal()`
  splits into `_reveal_title()`, `_reveal_strip(strip, delay)`,
  `_slam_grade()`, `_on_grade_landed()`, `_reveal_finale()`, plus
  `skip_reveal()`. `_apply_progression()` splits per branch (§5). None over 50.
- **Flat (§4):** guard clauses; `match` on `Outcome`; the reveal is a straight
  sequence of awaits, never a self-calling coroutine.
- **DRY ⚙ (§5):** `Juice.count_up_formatted` instead of a hand-rolled
  count-up; one `format_value` for every cell; the existing `StarBurst.tscn`
  and `RewardFeedback`; `RunResultNameLabel` reused for captions;
  `GameState.grade_name_for` as the one "Kelas N" wording; `UIPolish` owns
  button press juice (don't add a second one without opting out).
- **Signals up, calls down (§6):** RunResult calls down into its counters
  (`set_value()`, `count_up(delay, duration) -> Tween`, `show_final()`).
  StatCounter never reaches up and needs no signal (it reports nothing). Every
  node the script touches is `@onready var x: T = %Name`: no `$A/B/C` paths,
  which is what let today's layout change break five tests at once.
- **Type everything ⚙ (§7):** `->` on every function, typed parameters, typed
  `@onready`s (`var menang_counter: StatCounter = %MenangCounter`),
  `Array[Tween]`, `Array[String]`, `Outcome`. `:=` only where the right side
  is obvious. Type a `Variant` read explicitly (the `String(...)` around
  `pick_random()`).
- **Comments say why (§8):** `##` file header on `StatCounter.gd` and a `##`
  line on every `@export` (`tests/test_script_documentation.gd`); update
  RunResult's header (it still says "six counted-up figures" rows). No
  commented-out code.
- **Fail loudly (§9):** unmapped rank → `push_error` (§6); unmapped outcome →
  `push_error` (§5); a missing `%` node is a load error, not a silent
  `get_node_or_null` skip.
- **Boy Scout (§10):** every function touched ends shorter or equal and no
  less typed. `_slam_grade`, `_on_selesai_pressed` and `_apply_progression`
  lose their bare numbers here. The two stale "Corrected from the brief"
  comments leave with the code they described.

**Locking in the reduction.** The shrink above makes `test_clean_code` fail
("shrank -- lock it in") until the baseline is regenerated **in the same
commit**, in plain mode (it only ever lowers):

    <Godot console exe> --headless --path . --script res://ci/clean_code_dump.gd

Then check `git diff ci/clean_code_baseline.gd` shows only RunResult.gd's
`UNTYPED` and `BARE_NUMBERS` lines removed (and nothing raised). No
`-- --rekey` is needed: RunResult.gd has no function-keyed entries, and
`RunResultRow.gd` has none to move. If the dump prints any `RAISED (review):`
line it writes nothing. Fix the code, never the baseline. An open editor keeps
serving the old baseline until a no-op `script_patch` of it.

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
  under `Safe` → `UI`.
- **Captions:** assert `GRADE_CAPTIONS` has an entry for each rank. **Rev:**
  take the ranks from `RunGrade.LETTER_BANDS` + `RunGrade.LETTER_FLOOR`
  instead of a hand list, so a new rank fails the test. Call
  `RunResult.caption_pool_for(rank)` and assert each pool is non-empty and
  every member a non-empty `String`. Assert the helper's source contains
  `push_error`.
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
  `tests/test_button_geometry.gd`'s tables for the green M button.

**Rev — existing tests this layout breaks (update them in the same PR):**
- `test_run_result.gd`: the three `MarginContainer/...` path tests;
  `test_the_script_actually_compiles` (checks `has_method("_build_rows")`);
  `test_it_reports_all_six_figures` (the six old labels; scan the `.tscn`
  for the new captions instead); `test_the_report_uses_texture_icons_not_emoji`
  (the icon path moves from the script to the `.tscn`); the backdrop order
  test (`order.find("MarginContainer")` → `Safe`); the six RunResultRow tests
  (port to StatCounter).
- `test_run_grade_ranks.gd`: `test_the_grade_is_a_badge_not_a_letter_label`
  pins `MarginContainer/Column/GradeCard/GradeStack`.
- `test_back_controls.gd`: RunResult's `ROSTER` entry (§5).
- `test_tall_screen_layout.gd`: add RunResult (§3).
- `style-guide.md`'s `RunResultNameLabel` line; `test_light_ground_text.gd`'s
  header comment mentions RunResult's row names. Keep it accurate.

**Rev — clean-code checklist (run before `ship-pr`):**
- [ ] `test_run(suite="clean_code")` green: no "grew", no un-locked "shrank".
- [ ] `ci/clean_code_dump.gd` run in plain mode after the shrink; the baseline
      diff only removes RunResult.gd's `UNTYPED` and `BARE_NUMBERS` lines.
- [ ] `script_documentation`, `viewport_editability`, `theme_factory`,
      `button_geometry`, `back_controls`, `tall_screen_layout`, `run_result`,
      `run_grade_ranks`, `achievements`, `end_game_rehearsal`,
      `project_hygiene` green as targeted runs.
- [ ] `grep -n "theme_override" Scenes/EndGame/StatCounter.tscn
      Scenes/EndGame/RunResult.tscn` shows only layout constants
      (`separation`, `margin_*`).
- [ ] No bare number, untyped `var` or `->`-less function in `RunResult.gd` or
      `StatCounter.gd`; no function over 50 code lines.

Run with the Godot AI MCP `test_run` (targeted per suite; a full run rebakes the
theme and drops the bridge; see project guide). Check `git status` after any
full run and revert an unintended `kejartes_theme.tres` / `default_bus_layout.tres`.

---

## 9. Build order (suggested)

1. New `StatCounter` scene + script (`@tool`, documented `@export`s on the
   root, `class_name StatCounter`), and the Option C node tree in
   `RunResult.tscn` via the editor (never hand-edit the `.tscn` while
   attached). **Rev:** the tree includes `Safe` → `UI`, the six named
   counters with their icon/caption/suffix set, `%StarBurst`, and `%` unique
   names. Do **scene work first, script work second** (CLAUDE.md 4b), and
   diff every scene after each save.
2. Add ThemeFactory variations (`ResultStatValueLabel`, `ResultCaptionLabel`,
   the green M button with its icon constants) + rebake. Restart before the
   next scene save (memory: "Rebake, then restart before saving").
3. Rework `_build_rows` → `_fill_counters` (the cells are authored, so nothing
   is built); retune `_play_reveal` / `_slam_grade` for the new choreography
   as the short functions of §7, with tween tracking and `skip_reveal()`.
   **Rev:** make `Juice.fade_in` return its `Tween`.
4. Caption pool + `caption_pool_for` + random pick.
5. `Outcome` / `outcome_for` / `button_label_for`, the per-branch
   `_apply_progression` split, `GameState.grade_name_for`, the icon exports,
   the two SVG placeholders + DEBT entry.
6. Tests: extend `test_run_result.gd`, update the broken pins listed in §8,
   the `viewport_editability` entry, the theme roster and button geometry.
   Delete `RunResultRow.tscn` / `.gd`.
7. **Rev:** clean-code lock-in: `test_run(suite="clean_code")`, then
   `ci/clean_code_dump.gd` (plain mode), review the baseline diff, commit it
   with the code. Delete DEBT's "Deferred: Plan C's RunResult redesign" entry
   if this pass is judged to supersede it (re-read the plan first), and add a
   `CHANGELOG.md` entry.
8. Finish with the `ship-pr` skill.

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
`docs/superpowers/DEBT.md` as one grouped entry.

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
   nine other callers (keep it); `BtnSelesai` leaves `test_back_controls`.
3. **Units.** Sizes restated in 1080 project pixels on tokens; the medallion
   grows to ~450–510 px, not 150.
4. **Clean code.** New §7: named consts / `@export`s for every number,
   `class_name RunResult`, `Outcome` enum + pure static helpers, typed caption
   pool with `push_error` on an unmapped rank, functions ≤ 50 lines,
   `%` unique names, authored counters instead of runtime rows, delete
   `RunResultRow`, RunResult.gd's `UNTYPED` 2→0 and `BARE_NUMBERS` 8→0 locked
   in with the plain-mode dump.
5. **Tests.** Lists the existing pins the new tree breaks, and a
   clean-code checklist.
6. **Assets.** Names moved to the folders' `icon_*` snake_case convention;
   the forward arrow and star reuse existing art.

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
4. **Found in passing, not changed:** the beat-the-game branch's Lobby reset
   (`"tutorial_shown" in LobbyScript`) is a silent no-op. `Lobby.gd` declares
   no `tutorial_shown` (it lives in `StudentList.gd`), so that flag is never
   reset. It is out of this spec's scope (§2); it deserves its own fix.
