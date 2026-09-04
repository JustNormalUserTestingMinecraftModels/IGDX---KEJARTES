# Minigame Reward & Feedback Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the star rating so a perfect run actually earns three stars in every
minigame, then rebuild the end-of-minigame result card and the in-game score HUD
into a consistent, icon-led, particle-and-audio-backed reward moment.

**Architecture:** Three separable layers, in dependency order. (1) A **star rubric**
on `BaseMinigame` — one overridable `get_star_ratio()` hook plus a pure
`_calculate_stars()` — replacing the `max_score`-only rule that silently caps four
of the eight games at one star. (2) A **result-card restyle**: every runtime
`StyleBoxFlat` / `theme_override_*` in `MinigameResultPopup.configure()` moves to
`ThemeFactory` type variations, every emoji glyph becomes a real SVG texture, and
`play()` gains an escalating per-star reveal with bursts, a counting score, and
confetti on a three-star finish. (3) A **shared `MinigameScoreHUD`** scene template
replacing the six ad-hoc `ScoreLabel`s, giving every in-run score an icon, a target,
a count-up and a pop.

**Tech Stack:** Godot 4.6 GDScript, `DesignTokens`/`ThemeFactory` baked theme,
`RewardParticles.gd` (`GPUParticles2D`), `AudioDirector` autoload, `Juice.gd`,
`McpTestSuite` suites run via the Godot AI MCP `test_run`.

**Spec:** No separate spec document. The brief is captured verbatim in
"Context & Findings" below; this plan doubles as the spec of record. Prior art this
plan builds on: `docs/superpowers/specs/2026-09-03-day-summary-polish-and-rewards.md`
(the `RewardParticles` / burst / confetti pattern being reused here) and
`docs/superpowers/specs/2026-09-02-atur-jadwal-warning-and-statbar-polish.md`
(nine-patch card framing, and the `self_modulate` hazard).

---

## Global Constraints

- **Godot 4.6.** Portrait 1080x1920, `mobile` renderer.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation; add a new
  variation and rebake if none fits. Only accepted exception: layout-only constants
  (`separation`, `margin_*`). This plan *removes* overrides; it must not add any.
- **No visual is built at runtime.** Static chrome is a node in the `.tscn`; repeated
  rows are a `PackedScene` template. `tests/test_viewport_editability.gd`'s `BASELINE`
  is a ratchet — it may only ever be lowered, never raised.
- **No emoji as UI iconography.** The project banned this during the 2026-09-02 pass.
  Every glyph in `MinigameResultPopup.gd` is a defect to be replaced with a
  transparent SVG in `Assets/Images/UI/Placeholders/`.
- **UI text is Indonesian.** Engine/systems code is English.
- **Every script needs a `##` file header and a `##` line on every `@export`** —
  enforced by `tests/test_script_documentation.gd`.
- **Tunable numbers go in a named `const` block or an `@export`**, never inline.
- **Test suites must be `@tool`, extend `McpTestSuite`, and contain no coroutine** —
  the runner does `suite.call(name)` without awaiting, so an `await` silently aborts
  the test and it reports "0 assertions". Never call `play()` or `fire()` from a test.
- **Scripts the runner instantiates live must be `@tool`**, with real side effects in
  `_ready()` gated behind `if Engine.is_editor_hint(): return`.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through
  `scene_open` -> `node_create` / `node_set_property` -> `scene_save`. `anchors_preset`
  is inert (set the four anchors); numbers must be unquoted.
- **Rescan after editing a `.gd`, before running tests** (`filesystem_manage(op="scan")`).
  If the edit came from outside the editor, force the reload with a no-op
  `script_patch` on that same file.
- **The Godot MCP bridge is single-client.** Implementer subagents write scripts,
  tests and assets; the controller session builds every `.tscn` and runs every
  `test_run`.
- Commits: Conventional Commits with a scope, e.g. `fix(minigames): ...`.

---

## Context & Findings

### The brief (verbatim)

> As a professional education game programmer and visual UI, could you plan the layout
> UI pop-up on ResultStar.tscn — the one after the player finally completes the
> minigame — to be more addictive with more particles, more consistent styling on its
> boxes, more fun icons generated, and more audio SFX accompanying it, so the player
> feels more rewarded?
>
> Also those stars sometimes have a bug where a perfect run on sepakbola or seni
> menari and others sometimes only produces one star. What happens?
>
> Also plan and lay out better icon scores overall on minigames, since the current
> version is just plain numbers with no icons at all. Make the player have great
> feedback, visual and audio, so each progress feels like it matters and they feel
> special / like they're winning.

### Root cause of the one-star bug — **confirmed, not a hypothesis**

`Scripts/Minigames/UI/BaseMinigame.gd:587`:

```gdscript
func _calculate_stars(score: int, max_score: int, is_win: bool) -> int:
	if not is_win:
		return 0
	if max_score <= 0:
		return 1  # Win with no score tracking = 1 star minimum
	var ratio = float(score) / float(max_score)
	if ratio >= 0.80: return 3
	elif ratio >= 0.50: return 2
	return 1
```

and `_show_result_overlay()` at line 613:

```gdscript
var mg_max_score: int = -1
if "max_score" in self:
	mg_max_score = self.max_score
```

Only the four **Akademis** games declare `max_score` (`PilihanGanda.gd:154`,
`Menjodohkan.gd:164`, `Password.gd:76`, `Variabel.gd:92`). The other four do not:

| Minigame | `score`? | `max_score`? | Stars on a perfect run today |
|---|---|---|---|
| `MainBola` (sepakbola) | yes (`:129`) | **no** — uses `target_score` (`:130`) | **1** |
| `LombaMenari` (seni menari) | yes (`:85`) | **no** — uses `target_score` (`:182`) | **1** |
| `Badminton` | **no** — uses `player_score` (`:57`) | **no** | **1** |
| `BuatBatik` | **no** | **no** | **1** |
| Akademis x4 | yes | yes | 1-3, correct |

So the bug is not intermittent and not a race: **every win in the four non-Akademis
minigames is hard-capped at one star**, because `mg_max_score` stays `-1` and the
`max_score <= 0` branch fires. It reads as "sometimes" only because the four Akademis
games in the same rotation *do* award 2-3 stars.

Two collateral defects fall out of the same line:

- `MinigameResultPopup.configure()` sets `score_row.visible = score >= 0 and max_score > 0`,
  so those same four games show **no score row at all** on the result card.
- `Badminton` has no `score` member, so `_show_result_overlay()` also passes `score = -1`.

**The fix is not "give everyone a `max_score`."** `target_score` is a *win threshold*,
and a win means `score >= target_score`, so a `score / target_score` rubric would award
three stars to every win. Each game needs a real **mastery** metric distinct from its
win condition. Task 1 introduces the hook; Tasks 2-6 supply one metric per game.

### Reusable pieces already in the project

- `Scripts/SchoolSimulation/RewardParticles.gd` (`class_name RewardParticles`) — a
  fire-and-forget one-shot `GPUParticles2D` with `fire(delay)` and an `@export`
  `plays_sfx`. Reuse the **script**; author new emitter `.tscn` files against it.
- `Assets/Images/Particles/particle_{spark,star,plus,ring,glow,confetti,coin}.png`.
- `Assets/Images/UI/Placeholders/icon_{akademis,seni,olahraga,energy,mood,poin,uang}.svg`.
- `AudioDirector.play_sfx(id)` with `tap confirm cancel success fail coin whoosh pop
  swipe stamp unstamp popup_open popup_close select error reward tally sparkle ...`.
- `Juice.count_up(label, from, to, fmt)`, `Juice.pop_in`, `Juice.stagger_in`, `Juice.shake`.
- `ThemeFactory` variations incl. `Card`, `SunkenPanel`, `TitleLabel`, `DisplayLabel`,
  `CaptionLabel`, `PrimaryButton`, `ResultHeroLabel`, `ResultBodyLabel`, `RecapPillPanel`.

### Existing test surface to keep green

`tests/test_minigame_result_popup.gd` (12 tests) — note especially
`test_star_calculation_stayed_on_base_minigame` and
`test_score_row_hides_when_no_score_data`; both are touched by this plan and must be
updated deliberately, not deleted. `tests/test_minigame_overlays.gd`,
`tests/test_viewport_editability.gd`, `tests/test_script_documentation.gd`,
`tests/test_audio_coverage.gd`, `tests/test_project_hygiene.gd`.

---

## File Structure

**Created**

| Path | Responsibility |
|---|---|
| `Scripts/Minigames/UI/MinigameScoreHUD.gd` | Shared in-run score chip: icon + value + target, count-up, pop, combo. |
| `Scenes/Minigames/UI/MinigameScoreHUD.tscn` | Its authored layout (Pattern B template). |
| `Scenes/Minigames/UI/StarBurst.tscn` | Per-star one-shot burst (`RewardParticles`). |
| `Scenes/Minigames/UI/ResultConfetti.tscn` | Card-wide three-star confetti (`RewardParticles`). |
| `Scenes/Minigames/UI/ScorePopBurst.tscn` | Tiny HUD burst on a score increment. |
| `Assets/Images/UI/Placeholders/icon_bintang.svg` | Filled star. |
| `Assets/Images/UI/Placeholders/icon_bintang_kosong.svg` | Empty star. |
| `Assets/Images/UI/Placeholders/icon_skor.svg` | Score chip glyph. |
| `Assets/Images/UI/Placeholders/icon_target.svg` | Target/threshold glyph. |
| `Assets/Images/UI/Placeholders/icon_akurasi.svg` | Accuracy/mastery glyph. |
| `Assets/Images/UI/Placeholders/icon_kombo.svg` | Combo streak glyph. |
| `Assets/Images/UI/Placeholders/icon_waktu.svg` | Timer glyph. |
| `tests/test_minigame_star_rubric.gd` | The whole star rubric, per game. |
| `tests/test_minigame_score_hud.gd` | The shared HUD template and its retrofits. |

**Modified**

| Path | Change |
|---|---|
| `Scripts/Minigames/UI/BaseMinigame.gd:563-600, 606-655` | Star rubric const block, `get_star_ratio()`, rewritten `_calculate_stars()`. |
| `Scripts/Minigames/Olahraga/MainBola.gd` | `get_star_ratio()` (shot accuracy); HUD retrofit. |
| `Scripts/Minigames/Olahraga/Badminton.gd` | `score`/`max_score` aliases, `get_star_ratio()` (margin); HUD retrofit. |
| `Scripts/Minigames/SeniBudaya/LombaMenari.gd` | Hit counters, `get_star_ratio()` (note accuracy); HUD retrofit. |
| `Scripts/Minigames/SeniBudaya/BuatBatik.gd` | `wrong_attempts` counter, `get_star_ratio()`. |
| `Scripts/Minigames/Akademis/{PilihanGanda,Menjodohkan,Password,Variabel}.gd` | HUD retrofit only (rubric already correct). |
| `Scripts/Minigames/UI/MinigameResultPopup.gd` | De-emoji, icon rows, theme variations, escalating reveal, particles, audio. |
| `Scripts/Minigames/UI/ResultStar.gd` | Default textures, burst hook, `celebrate()`. |
| `Scenes/Minigames/UI/MinigameResultPopup.tscn` | New authored nodes: icon rows, panels, particle slots. |
| `Scenes/Minigames/UI/ResultStar.tscn` | Glow layer + burst slot. |
| `Scripts/Design/ThemeFactory.gd` | New variations (Task 10). |
| `Scripts/Audio/AudioDirector.gd` | New SFX ids (Task 9). |
| `tests/test_minigame_result_popup.gd` | Updated for the new rubric, icons and nodes. |
| `tests/test_viewport_editability.gd` | Lower `BASELINE` for retrofitted minigames. |
| `CLAUDE.md` | "Current work" entry. |

---

## Task 1: The star rubric on BaseMinigame

This is the bug fix. Everything else in the plan is polish; this task alone makes a
perfect sepakbola run stop reading as one star.

**Files:**

- Modify: `Scripts/Minigames/UI/BaseMinigame.gd:587-597` (`_calculate_stars`) and
  `:606-655` (`_show_result_overlay`)
- Test: `tests/test_minigame_star_rubric.gd` (create)

**Interfaces:**

- Consumes: nothing.
- Produces:
  - `BaseMinigame.STAR_RATIO_THREE: float`, `STAR_RATIO_TWO: float`,
    `STAR_UNRATED_DEFAULT: int`, `STAR_RATIO_UNKNOWN: float`
  - `BaseMinigame._ratio_from_score(score: int, max_score: int) -> float` — **static**,
    pure. The actual "score/max_score -> ratio, or unknown when there's no real max"
    math, callable directly on the class with no instance. **Read by Tasks 2-5's own
    static helpers as the pattern to follow.**
  - `BaseMinigame.get_star_ratio() -> float` — instance glue only: reads `self.score`/
    `self.max_score` and delegates to `_ratio_from_score`. **Overridden by Tasks 2-5.**
  - `BaseMinigame._calculate_stars(ratio: float, is_win: bool) -> int` — **static**,
    signature changed from `(score, max_score, is_win)`.

> **Why static:** this project's MCP test runner runs every suite inside the live
> editor. A script without `@tool` — which `BaseMinigame.gd` and every minigame script
> deliberately is not, per CLAUDE.md's design-system carve-out for minigames — becomes
> a "placeholder instance" when instantiated live in that context, and **every instance
> method call on it fails**, even inside the scene tree ("Attempt to call a method on a
> placeholder instance"). This was confirmed empirically before writing this task: a
> transient probe suite showed a static class-level call works fine, while an instance
> method call on a `Node.new()` with the script attached fails identically whether or
> not the node is added to the tree. So every piece of real rating math in Tasks 1-6 is
> a `static func`, testable directly on the class (`BaseMinigame._calculate_stars(...)`)
> with no instantiation at all. Instance methods (`get_star_ratio()` itself,
> `sync_score_alias()` in Task 4) become thin glue verified by source-scan, matching
> this project's own documented fallback for anything that can't be instantiated
> headlessly.

- [ ] **Step 1: Write the failing test**

Create `tests/test_minigame_star_rubric.gd`:

```gdscript
@tool
extends McpTestSuite

## The end-of-minigame star rubric.
##
## Before 2026-09-04, _calculate_stars() read `max_score`, which only the four
## Akademis quizzes declare. MainBola, LombaMenari, Badminton and BuatBatik fell
## through the `max_score <= 0` branch and were hard-capped at one star on every
## win, however perfect the run. This suite pins the replacement rubric: a
## per-game mastery ratio via get_star_ratio(), and a never-one-star floor for a
## win that reports no ratio at all.
##
## Must be @tool; no test here may be a coroutine. BaseMinigame.gd is
## deliberately NOT @tool, so every method call on a live instance of it
## fails in this editor-hosted runner ("placeholder instance") even inside
## the scene tree -- confirmed empirically before this suite was written.
## Every test below therefore calls the class's static helpers directly,
## with no instantiation at all.

func suite_name() -> String:
	return "minigame_star_rubric"


const BASE_PATH := "res://Scripts/Minigames/UI/BaseMinigame.gd"


func test_a_loss_is_always_zero_stars() -> void:
	assert_eq(BaseMinigame._calculate_stars(1.0, false), 0, "a loss earns no stars")
	assert_eq(BaseMinigame._calculate_stars(-1.0, false), 0,
		"a loss with no ratio earns no stars")


func test_a_perfect_ratio_earns_three_stars() -> void:
	assert_eq(BaseMinigame._calculate_stars(1.0, true), 3, "100% mastery is three stars")
	assert_eq(BaseMinigame._calculate_stars(0.92, true), 3, "at the three-star threshold")


func test_a_middling_ratio_earns_two_stars() -> void:
	assert_eq(BaseMinigame._calculate_stars(0.7, true), 2, "70% mastery is two stars")


func test_a_bare_win_earns_one_star() -> void:
	assert_eq(BaseMinigame._calculate_stars(0.2, true), 1, "a scraped win is one star")


## The regression this whole task exists for.
func test_a_win_with_no_tracked_ratio_is_not_capped_at_one_star() -> void:
	assert_eq(BaseMinigame._calculate_stars(-1.0, true), 2,
		"a win the game cannot rate must not read as the worst possible win")


func test_ratio_from_score_uses_max_score_when_present() -> void:
	assert_true(absf(BaseMinigame._ratio_from_score(3, 4) - 0.75) < 0.001,
		"score over max_score")


func test_ratio_from_score_is_unknown_without_a_real_max_score() -> void:
	assert_true(absf(BaseMinigame._ratio_from_score(0, 0) - BaseMinigame.STAR_RATIO_UNKNOWN) < 0.001,
		"a game that tracks nothing reports no ratio rather than a fake zero")
	assert_true(absf(BaseMinigame._ratio_from_score(0, -1) - BaseMinigame.STAR_RATIO_UNKNOWN) < 0.001,
		"a negative max_score is also 'no real max'")


func test_ratio_from_score_clamps_to_one() -> void:
	assert_true(absf(BaseMinigame._ratio_from_score(9, 3) - 1.0) < 0.001,
		"a score above max_score still clamps to a perfect ratio, never over 1.0")


func test_get_star_ratio_is_thin_glue_over_the_static_helper() -> void:
	var src := FileAccess.get_file_as_string(BASE_PATH)
	assert_true(src.contains("_ratio_from_score("),
		"get_star_ratio() delegates its math to the static helper rather than "
		+ "re-deriving it, so every override can reuse the same pattern")


func test_calculate_stars_is_static_and_no_longer_takes_a_max_score() -> void:
	var src := FileAccess.get_file_as_string(BASE_PATH)
	assert_true(src.contains("static func _calculate_stars(ratio: float, is_win: bool) -> int:"),
		"the rubric takes a ratio, not a (score, max_score) pair, and is static "
		+ "so every minigame test can call it without instantiating a live node")
	assert_false(src.contains("return 1  # Win with no score tracking = 1 star minimum"),
		"the one-star cap is gone")


func test_thresholds_are_named_constants() -> void:
	var src := FileAccess.get_file_as_string(BASE_PATH)
	for name in ["STAR_RATIO_THREE", "STAR_RATIO_TWO", "STAR_UNRATED_DEFAULT"]:
		assert_true(src.contains("const %s" % name), "%s is a named const" % name)
```

- [ ] **Step 2: Run the test to verify it fails**

Controller: `filesystem_manage(op="scan")`, then `test_run(suite="minigame_star_rubric")`.

Expected: FAIL — "Invalid call. Nonexistent function '_calculate_stars' in base
'BaseMinigame'" (the 2-argument static form doesn't exist yet) and similarly for
`_ratio_from_score`.

- [ ] **Step 3: Replace the rubric in BaseMinigame.gd**

Replace `_calculate_stars` (currently `:587-597`) with this block:

```gdscript
# --- Star rubric ------------------------------------------------------------
# A minigame's win threshold and its *mastery* are different questions: a win
# means score >= target, so rating stars off the win threshold would make every
# win three stars. Each minigame answers the mastery question itself in
# get_star_ratio(); this block only turns that answer into stars.

## Mastery ratio at or above which a win earns three stars.
const STAR_RATIO_THREE: float = 0.90
## Mastery ratio at or above which a win earns two stars.
const STAR_RATIO_TWO: float = 0.60
## Stars for a win by a minigame that reports no mastery ratio at all. Two, not
## one: an unrated win must never read to the player as the worst possible win.
const STAR_UNRATED_DEFAULT: int = 2
## Sentinel get_star_ratio() returns when the minigame tracks no mastery metric.
const STAR_RATIO_UNKNOWN: float = -1.0


## Score-out-of-max-score ratio, or STAR_RATIO_UNKNOWN when max_score isn't a
## real ceiling (<= 0). Static and pure so it is callable directly on the
## class in a test, with no instance and no placeholder-instance failure --
## every per-game override in Tasks 2-5 follows this same static-helper shape.
##
## Affects: nothing. Pure.
static func _ratio_from_score(score: int, max_score: int) -> float:
	if max_score <= 0:
		return STAR_RATIO_UNKNOWN
	return clampf(float(score) / float(max_score), 0.0, 1.0)


## How well the player did, 0.0-1.0, independent of whether they won.
##
## Override this in a minigame that has a mastery metric its win threshold does
## not already express (shot accuracy, note accuracy, rally margin, mistakes
## made). The default here covers the quiz-shaped games, which score out of a
## real `max_score`. Thin instance glue over _ratio_from_score() -- keep any
## new math in a static helper of its own, not here, so it stays testable.
##
## Affects: nothing. Pure.
func get_star_ratio() -> float:
	var s: int = int(self.score) if "score" in self else 0
	var m: int = int(self.max_score) if "max_score" in self else 0
	return _ratio_from_score(s, m)


## Stars from a mastery ratio. A loss is always zero stars; a win is never
## zero. Static: called from a test with no instance, and from
## _show_result_overlay() as `BaseMinigame._calculate_stars(...)` would also
## work, though the instance call `_calculate_stars(...)` still resolves fine
## from inside an instance method since Godot looks up statics through self.
##
## Affects: nothing. Pure.
static func _calculate_stars(ratio: float, is_win: bool) -> int:
	if not is_win:
		return 0
	if ratio < 0.0:
		return STAR_UNRATED_DEFAULT
	if ratio >= STAR_RATIO_THREE:
		return 3
	if ratio >= STAR_RATIO_TWO:
		return 2
	return 1
```

Then update the one call site (`:631`):

```gdscript
	var stars := _calculate_stars(get_star_ratio(), is_win)
```

This call site is inside `_show_result_overlay()`, an *instance* method — calling a
static function from there (`_calculate_stars(...)`, unqualified) works exactly like
today, because Godot resolves an unqualified static call through the class. Only
*test code calling in from outside*, with no instance to begin with, needs the
`BaseMinigame.` qualifier, as the test file above does.

- [ ] **Step 4: Run the test to verify it passes**

Controller: `filesystem_manage(op="scan")`, then `test_run(suite="minigame_star_rubric")`.

Expected: PASS, 10/10.

If it still fails with "function not found" while the source on disk is correct, the
editor is serving stale bytecode — force a reload with a no-op `script_patch` on
`BaseMinigame.gd` (add a blank line, remove it). It logs a benign
`GDScript reload failed with error code 43` and then works.

- [ ] **Step 5: Fix the existing popup suite's stale assertion**

`tests/test_minigame_result_popup.gd:153`'s `test_star_calculation_stayed_on_base_minigame`
asserts the old signature. Replace its body with:

```gdscript
func test_star_calculation_stayed_on_base_minigame() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/BaseMinigame.gd")
	assert_true(src.contains("static func _calculate_stars(ratio: float, is_win: bool) -> int:"),
		"the rubric still lives on BaseMinigame, not in the popup")
	var popup_src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameResultPopup.gd")
	assert_false(popup_src.contains("_calculate_stars"),
		"the popup renders stars, it does not decide them")
```

- [ ] **Step 6: Run the full suite**

Controller: `test_run()`. Expected: every suite green.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Minigames/UI/BaseMinigame.gd tests/test_minigame_star_rubric.gd tests/test_minigame_result_popup.gd && git commit -m "fix(minigames): stop capping unrated wins at one star" -m "_calculate_stars() read max_score, which only the four Akademis quizzes declare, so every win in MainBola, LombaMenari, Badminton and BuatBatik fell through the max_score <= 0 branch and scored exactly one star no matter how perfect the run. Stars now come from an overridable per-game get_star_ratio(), and an unrated win reads as two stars, never one." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 2: MainBola (sepakbola) mastery — shot accuracy

**Files:**

- Modify: `Scripts/Minigames/Olahraga/MainBola.gd` (override placed above `lose_game()`, `:689`)
- Test: `tests/test_minigame_star_rubric.gd` (append)

**Interfaces:**

- Consumes: `BaseMinigame.STAR_RATIO_UNKNOWN`, `_calculate_stars` (Task 1).
- Produces: `MainBolaScript._shot_accuracy_ratio(score: int, shots_taken: int) -> float`
  — **static**, pure — and `MainBola.get_star_ratio() -> float`, the thin instance
  override that calls it.

MainBola already has everything needed: `score` (goals, `:129`), `MAX_ATTEMPTS = 8`
(`:124`) and `attempts_left` (`:131`). Mastery = goals divided by shots taken. A player
who scores 5 from 5 shots is perfect; one who scores 5 from 8 is not.

Per Task 1's finding, `MainBola.gd` is not `@tool`, so its tests call the static
helper directly rather than instantiating the script — an instance method call on it
fails with "placeholder instance" in this editor-hosted runner.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_minigame_star_rubric.gd`:

```gdscript
const MAINBOLA_PATH := "res://Scripts/Minigames/Olahraga/MainBola.gd"
## MainBola.gd declares no class_name, so its static helper is reached
## through this preloaded Script reference rather than a bare identifier --
## `MainBola.foo()` fails to parse ("Identifier not declared"); a preloaded
## Script const resolves statics fine with no class_name required. Confirmed
## empirically before this was written.
const MainBolaScript := preload("res://Scripts/Minigames/Olahraga/MainBola.gd")


func test_mainbola_rates_a_flawless_striker_at_three_stars() -> void:
	# 5 goals from 5 shots is perfect.
	assert_true(absf(MainBolaScript._shot_accuracy_ratio(5, 5) - 1.0) < 0.001,
		"5 goals from 5 shots is perfect")
	assert_eq(BaseMinigame._calculate_stars(MainBolaScript._shot_accuracy_ratio(5, 5), true), 3,
		"and earns three stars")


func test_mainbola_rates_a_wasteful_striker_lower() -> void:
	# 4 goals from 8 shots.
	assert_true(absf(MainBolaScript._shot_accuracy_ratio(4, 8) - 0.5) < 0.001,
		"4 goals from 8 shots")
	assert_eq(BaseMinigame._calculate_stars(MainBolaScript._shot_accuracy_ratio(4, 8), true), 1,
		"a scraped win is one star")


func test_mainbola_reports_unknown_before_any_shot() -> void:
	assert_true(absf(MainBolaScript._shot_accuracy_ratio(0, 0) - BaseMinigame.STAR_RATIO_UNKNOWN) < 0.001,
		"no shots taken means no accuracy to divide by")


func test_mainbola_get_star_ratio_delegates_to_the_static_helper() -> void:
	var src := FileAccess.get_file_as_string(MAINBOLA_PATH)
	assert_true(src.contains("_shot_accuracy_ratio("),
		"get_star_ratio() calls the static helper rather than re-deriving the math")
```

- [ ] **Step 2: Run to verify it fails**

`filesystem_manage(op="scan")`, `test_run(suite="minigame_star_rubric")`.

Expected: FAIL — `MainBolaScript._shot_accuracy_ratio` doesn't exist yet.

- [ ] **Step 3: Implement the override**

Add to `Scripts/Minigames/Olahraga/MainBola.gd`, just above `func lose_game()` (`:689`):

```gdscript
## Shot accuracy: goals scored per shot taken. Reaching the goal target with
## every shot on target is a three-star run; grinding it out over all eight
## attempts is not. Returns STAR_RATIO_UNKNOWN before the first shot, so a win
## that somehow took no shots is not rated a zero.
##
## Affects: nothing. Pure. Static so a test can call it with no instance.
static func _shot_accuracy_ratio(score: int, shots_taken: int) -> float:
	if shots_taken <= 0:
		return STAR_RATIO_UNKNOWN
	return clampf(float(score) / float(shots_taken), 0.0, 1.0)


## How well the player did this run, delegated to the static helper above.
##
## Affects: nothing. Pure. Read by BaseMinigame._show_result_overlay().
func get_star_ratio() -> float:
	return _shot_accuracy_ratio(score, MAX_ATTEMPTS - attempts_left)
```

- [ ] **Step 4: Run to verify it passes**

`filesystem_manage(op="scan")`, `test_run(suite="minigame_star_rubric")`. Expected: PASS, 14/14.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Minigames/Olahraga/MainBola.gd tests/test_minigame_star_rubric.gd && git commit -m "feat(minigames): rate sepakbola stars on shot accuracy" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: LombaMenari (seni menari) mastery — note accuracy

**Files:**

- Modify: `Scripts/Minigames/SeniBudaya/LombaMenari.gd:85` (counters), `:182` (reset),
  `:264-268` (miss), `:453-462` (hits), override near `win_game()`
- Test: `tests/test_minigame_star_rubric.gd` (append)

**Interfaces:**

- Consumes: `BaseMinigame.STAR_RATIO_UNKNOWN` (Task 1).
- Produces: `LombaMenari.POINTS_PERFECT: int`, `POINTS_GOOD: int`, `perfect_hits: int`,
  `good_hits: int`, `missed_notes: int`,
  `MenariScript._note_accuracy_ratio(perfect_hits: int, good_hits: int, missed_notes: int) -> float`
  — **static**, pure — and `LombaMenari.get_star_ratio() -> float`, the thin instance
  override that calls it.

The game scores `+100` for a PERFECT hit (`:457`) and `+50` for a good one (`:461`),
with misses culled at `:264-268`. Mastery = points earned divided by points that were
on the table: `(100*perfect + 50*good) / (100 * notes_presented)`. This weights an
all-PERFECT run at 1.0 and a sloppy-but-winning run well below it.

Per Task 1's finding, `LombaMenari.gd` is not `@tool`; the test calls the static
helper directly rather than instantiating the script.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_minigame_star_rubric.gd`:

```gdscript
const MENARI_PATH := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"
## LombaMenari.gd declares no class_name -- see MainBolaScript's comment in
## this same suite for why a preloaded Script const is used instead of the
## bare class name.
const MenariScript := preload("res://Scripts/Minigames/SeniBudaya/LombaMenari.gd")


func test_menari_rates_an_all_perfect_routine_at_three_stars() -> void:
	var ratio := MenariScript._note_accuracy_ratio(20, 0, 0)
	assert_true(absf(ratio - 1.0) < 0.001, "every note PERFECT")
	assert_eq(BaseMinigame._calculate_stars(ratio, true), 3, "and earns three stars")


func test_menari_rates_a_half_good_half_missed_routine_lower() -> void:
	# 10 good hits = 500 points of a possible 2000
	var ratio := MenariScript._note_accuracy_ratio(0, 10, 10)
	assert_true(absf(ratio - 0.25) < 0.001, "half the notes at half credit")
	assert_eq(BaseMinigame._calculate_stars(ratio, true), 1, "a sloppy win is one star")


func test_menari_reports_unknown_before_a_single_note() -> void:
	var ratio := MenariScript._note_accuracy_ratio(0, 0, 0)
	assert_true(absf(ratio - BaseMinigame.STAR_RATIO_UNKNOWN) < 0.001,
		"no notes presented means nothing to rate")


func test_menari_get_star_ratio_delegates_to_the_static_helper() -> void:
	var src := FileAccess.get_file_as_string(MENARI_PATH)
	assert_true(src.contains("_note_accuracy_ratio("),
		"get_star_ratio() calls the static helper rather than re-deriving the math")
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `MenariScript._note_accuracy_ratio` doesn't exist yet.

- [ ] **Step 3: Add the counters and the override**

Beside `var score: int = 0` (`:85`):

```gdscript
## Points a PERFECT hit is worth. The star rubric divides by this, so it is a
## const rather than an inline literal at the two award sites.
const POINTS_PERFECT: int = 100
## Points a merely-good (matched but outside the tight window) hit is worth.
const POINTS_GOOD: int = 50

## Notes swiped inside the PERFECT window this run. Read by get_star_ratio().
var perfect_hits: int = 0
## Notes swiped correctly but outside the PERFECT window this run.
var good_hits: int = 0
## Notes that reached the hit zone unanswered this run.
var missed_notes: int = 0
```

Reset all three where `score = 0` is reset (`:182`):

```gdscript
	score = 0
	perfect_hits = 0
	good_hits = 0
	missed_notes = 0
```

Replace the two award sites (`:456-462`):

```gdscript
			if min_dist < 45.0:
				score += POINTS_PERFECT
				perfect_hits += 1
				_show_hit_feedback("PERFECT!", Color(1.0, 0.84, 0.0))
				_pulse_hit_zone(Color(1.0, 0.9, 0.2)) # Glowing gold/yellow pulse
			else:
				score += POINTS_GOOD
				good_hits += 1
```

Count the miss inside the existing block that appends to `notes_to_remove` (`:264-268`):

```gdscript
			missed_notes += 1
			notes_to_remove.append(note)
```

Add the override near `func win_game()`:

```gdscript
## Note accuracy: points earned as a fraction of the points that were actually
## on the table. An all-PERFECT routine rates 1.0; a routine that only ever
## grazes the window tops out at 0.5 even if it clears the score target.
##
## Affects: nothing. Pure. Static so a test can call it with no instance.
static func _note_accuracy_ratio(perfect_hits: int, good_hits: int, missed_notes: int) -> float:
	var notes_presented: int = perfect_hits + good_hits + missed_notes
	if notes_presented <= 0:
		return STAR_RATIO_UNKNOWN
	var earned: int = perfect_hits * POINTS_PERFECT + good_hits * POINTS_GOOD
	var possible: int = notes_presented * POINTS_PERFECT
	return clampf(float(earned) / float(possible), 0.0, 1.0)


## How well the player did this run, delegated to the static helper above.
##
## Affects: nothing. Pure. Read by BaseMinigame._show_result_overlay().
func get_star_ratio() -> float:
	return _note_accuracy_ratio(perfect_hits, good_hits, missed_notes)
```

- [ ] **Step 4: Run to verify it passes**

`filesystem_manage(op="scan")`, `test_run(suite="minigame_star_rubric")`. Expected: PASS, 18/18.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Minigames/SeniBudaya/LombaMenari.gd tests/test_minigame_star_rubric.gd && git commit -m "feat(minigames): rate seni menari stars on note accuracy" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: Badminton mastery — rally margin, and a visible score row

**Files:**

- Modify: `Scripts/Minigames/Olahraga/Badminton.gd:57` (mirrors), `:105-106` (reset),
  `:423`/`:432` (score sites), `:591-603` (win/lose overrides)
- Test: `tests/test_minigame_star_rubric.gd` (append)

**Interfaces:**

- Consumes: `BaseMinigame.STAR_RATIO_UNKNOWN` (Task 1).
- Produces: `BadmintonScript._rally_margin_ratio(player_score: int, enemy_score: int) -> float`
  — **static**, pure — `Badminton.score: int`, `Badminton.max_score: int`,
  `Badminton.sync_score_alias() -> void`, `Badminton.get_star_ratio() -> float`.

Badminton is the only game with **no `score` member at all** — it tracks
`player_score` / `enemy_score`. So `_show_result_overlay()` passes `score = -1` and
the result card hides its score row entirely. Mirroring `player_score` into `score`
fixes that for free. Mastery = rally dominance: `player / (player + enemy)`.

Per Task 1's finding, `Badminton.gd` is not `@tool`, so its rating math is tested via
the static helper directly. `sync_score_alias()`'s mirror assignment mutates instance
state and has no pure-static equivalent worth the awkwardness, so it is verified by a
source-text scan instead — this project's own documented fallback for anything that
can't be instantiated headlessly in this runner.

- [ ] **Step 1: Write the failing test**

```gdscript
const BADMINTON_PATH := "res://Scripts/Minigames/Olahraga/Badminton.gd"
## Badminton.gd declares no class_name -- see MainBolaScript's comment in
## Task 2's test additions for why a preloaded Script const is used instead
## of the bare class name.
const BadmintonScript := preload("res://Scripts/Minigames/Olahraga/Badminton.gd")


func test_badminton_rates_a_shutout_at_three_stars() -> void:
	var ratio := BadmintonScript._rally_margin_ratio(7, 0)
	assert_true(absf(ratio - 1.0) < 0.001, "a shutout is perfect")
	assert_eq(BaseMinigame._calculate_stars(ratio, true), 3, "and earns three stars")


func test_badminton_rates_a_narrow_win_lower() -> void:
	var ratio := BadmintonScript._rally_margin_ratio(7, 6)
	assert_true(absf(ratio - (7.0 / 13.0)) < 0.001, "a 7-6 grind")
	assert_eq(BaseMinigame._calculate_stars(ratio, true), 1, "and is one star")


func test_badminton_reports_unknown_before_any_rally() -> void:
	var ratio := BadmintonScript._rally_margin_ratio(0, 0)
	assert_true(absf(ratio - BaseMinigame.STAR_RATIO_UNKNOWN) < 0.001,
		"no rallies played means nothing to rate")


func test_badminton_get_star_ratio_delegates_to_the_static_helper() -> void:
	var src := FileAccess.get_file_as_string(BADMINTON_PATH)
	assert_true(src.contains("_rally_margin_ratio("),
		"get_star_ratio() calls the static helper rather than re-deriving the math")


func test_badminton_declares_score_and_max_score_mirrors() -> void:
	var src := FileAccess.get_file_as_string(BADMINTON_PATH)
	assert_true(src.contains("var score: int = 0"),
		"score mirrors player_score so the result card can show a score row")
	assert_true(src.contains("var max_score: int = 0"),
		"max_score mirrors the rally target")


func test_badminton_sync_score_alias_assigns_both_mirrors() -> void:
	var src := FileAccess.get_file_as_string(BADMINTON_PATH)
	assert_true(src.contains("func sync_score_alias() -> void:"),
		"the mirror-sync method exists")
	var body: String = src.split("func sync_score_alias() -> void:")[1].split("\nfunc ")[0]
	assert_true(body.contains("score = player_score"), "score mirrors player_score")
	assert_true(body.contains("max_score = target_score"), "max_score mirrors target_score")


func test_badminton_calls_sync_score_alias_on_every_rally_point_and_at_game_end() -> void:
	var src := FileAccess.get_file_as_string(BADMINTON_PATH)
	var call_count: int = src.count("sync_score_alias()") - 1   # subtract the func's own declaration line
	assert_gt(call_count, 3,
		"sync_score_alias() should be called at both score sites, in both "
		+ "win_game() and lose_game(), and once on reset -- five call sites beyond "
		+ "the declaration, so more than 3")
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `BadmintonScript._rally_margin_ratio` doesn't exist yet, and the source
scans find no `sync_score_alias`.

- [ ] **Step 3: Implement**

Beside `var player_score: int = 0` (`:57`):

```gdscript
## Mirror of player_score under the name BaseMinigame's result card reads.
## Badminton is the only minigame that names its own score `player_score`; the
## card would otherwise hide its score row entirely. Kept in step by
## sync_score_alias() -- never assigned directly.
var score: int = 0
## Mirror of target_score under the name the result card reads.
var max_score: int = 0
```

Next to `win_game()` (`:591`):

```gdscript
## Republish player_score / target_score under the names BaseMinigame's result
## card reads. Called after every rally point and once before the card shows.
##
## Affects: this node's own `score` and `max_score` mirrors.
func sync_score_alias() -> void:
	score = player_score
	max_score = target_score


## Rally dominance: the share of all points played that the player took. A
## shutout rates 1.0; scraping past the target in a long rally does not.
##
## Affects: nothing. Pure. Static so a test can call it with no instance.
static func _rally_margin_ratio(player_score: int, enemy_score: int) -> float:
	var rallies: int = player_score + enemy_score
	if rallies <= 0:
		return STAR_RATIO_UNKNOWN
	return clampf(float(player_score) / float(rallies), 0.0, 1.0)


## How well the player did this run, delegated to the static helper above.
##
## Affects: nothing. Pure. Read by BaseMinigame._show_result_overlay().
func get_star_ratio() -> float:
	return _rally_margin_ratio(player_score, enemy_score)
```

Call `sync_score_alias()` after each `+= 1` at `:423` and `:432`, and at the top of
both the `win_game()` and `lose_game()` overrides before their `super` calls. Reset
alongside `player_score = 0` (`:105-106`):

```gdscript
	player_score = 0
	enemy_score = 0
	sync_score_alias()
```

> **Note on the base `get_star_ratio()`:** now that Badminton declares `max_score`,
> the base implementation would return `player_score / target_score` — which is at
> least 1.0 on every win. The override above takes precedence, so this is correct as
> written; do not remove the override on the grounds that "Badminton has a max_score now."

- [ ] **Step 4: Run to verify it passes**

Expected: PASS, 25/25.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Minigames/Olahraga/Badminton.gd tests/test_minigame_star_rubric.gd && git commit -m "feat(minigames): rate badminton stars on rally margin and show its score" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: BuatBatik mastery — mistakes made

**Files:**

- Modify: `Scripts/Minigames/SeniBudaya/BuatBatik.gd:114` (counter), `:454-459`
  (bookkeeping), override above `_on_all_steps_done` (`:705`)
- Test: `tests/test_minigame_star_rubric.gd` (append)

**Interfaces:**

- Consumes: `BaseMinigame.STAR_RATIO_UNKNOWN` (Task 1).
- Produces: `BatikScript._mistake_free_ratio(wrong_attempts: int, required_steps: int) -> float`
  — **static**, pure — `BuatBatik.wrong_attempts: int`, `BuatBatik.get_star_ratio() -> float`.

BuatBatik is a four-step ordered-sequence game (`correct_sequence`, `:114`) with no
score at all. Its natural mastery metric is a clean run: mistakes made against steps
required. Zero wrong tool placements is 1.0.

Per Task 1's finding, `BuatBatik.gd` is not `@tool`, so the test calls the static
helper directly rather than instantiating the script.

- [ ] **Step 1: Write the failing test**

```gdscript
const BATIK_PATH := "res://Scripts/Minigames/SeniBudaya/BuatBatik.gd"
## BuatBatik.gd declares no class_name -- see MainBolaScript's comment in
## Task 2's test additions for why a preloaded Script const is used instead
## of the bare class name.
const BatikScript := preload("res://Scripts/Minigames/SeniBudaya/BuatBatik.gd")


func test_batik_rates_a_flawless_sequence_at_three_stars() -> void:
	var ratio := BatikScript._mistake_free_ratio(0, 4)
	assert_true(absf(ratio - 1.0) < 0.001, "no wrong tools placed")
	assert_eq(BaseMinigame._calculate_stars(ratio, true), 3, "and earns three stars")


func test_batik_rates_a_run_with_mistakes_lower() -> void:
	# two mistakes against four required steps
	var ratio := BatikScript._mistake_free_ratio(2, 4)
	assert_true(absf(ratio - 0.5) < 0.001, "two mistakes halves the rating")
	assert_eq(BaseMinigame._calculate_stars(ratio, true), 1, "and is one star")


func test_batik_never_reports_a_negative_ratio() -> void:
	var ratio := BatikScript._mistake_free_ratio(99, 4)
	assert_true(absf(ratio - 0.0) < 0.001, "mistakes clamp at zero, not below")


func test_batik_get_star_ratio_delegates_to_the_static_helper() -> void:
	var src := FileAccess.get_file_as_string(BATIK_PATH)
	assert_true(src.contains("_mistake_free_ratio("),
		"get_star_ratio() calls the static helper rather than re-deriving the math")
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `BatikScript._mistake_free_ratio` doesn't exist yet.

- [ ] **Step 3: Implement**

Beside `var correct_sequence: Array = [...]` (`:114`):

```gdscript
## Wrong tool placements this run. The star rubric's only input -- BuatBatik
## has no score, so a clean sequence is what mastery means here.
var wrong_attempts: int = 0
```

Increment it in the mismatch branch at `:454-459` (the `else` opposite
`_add_correct_layer(step)`):

```gdscript
		else:
			wrong_attempts += 1
```

Reset it wherever the run is set up — the same function that assigns
`player_sequence = []`.

Add above `func _on_all_steps_done(all_correct: bool) -> void:` (`:705`):

```gdscript
## Cleanliness of the batik sequence: every wrong tool placement costs one
## step's worth of the rating. A four-step pattern laid down without a single
## mistake rates 1.0.
##
## Affects: nothing. Pure. Static so a test can call it with no instance.
static func _mistake_free_ratio(wrong_attempts: int, required_steps: int) -> float:
	if required_steps <= 0:
		return STAR_RATIO_UNKNOWN
	return clampf(1.0 - float(wrong_attempts) / float(required_steps), 0.0, 1.0)


## How well the player did this run, delegated to the static helper above.
##
## Affects: nothing. Pure. Read by BaseMinigame._show_result_overlay().
func get_star_ratio() -> float:
	return _mistake_free_ratio(wrong_attempts, correct_sequence.size())
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS, 29/29.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Minigames/SeniBudaya/BuatBatik.gd tests/test_minigame_star_rubric.gd && git commit -m "feat(minigames): rate buat batik stars on a mistake-free sequence" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 6: Pin the four Akademis quizzes against regression

The quizzes were never broken — they are the only games the old rubric served. This
task adds no production code; it locks in that Task 1's default path still rates them,
and that all eight games are now rateable. It is a separate task because it is the
gate that says "the bug class is closed", not just "these four games are fixed".

**Files:**

- Test: `tests/test_minigame_star_rubric.gd` (append)

**Interfaces:**

- Consumes: everything from Tasks 1-5. Produces: nothing.

- [ ] **Step 1: Write the test**

```gdscript
## Every minigame script in the project, so a ninth one cannot quietly ship
## without a mastery metric.
const ALL_MINIGAMES := [
	"res://Scripts/Minigames/Akademis/PilihanGanda.gd",
	"res://Scripts/Minigames/Akademis/Menjodohkan.gd",
	"res://Scripts/Minigames/Akademis/Password.gd",
	"res://Scripts/Minigames/Akademis/Variabel.gd",
	"res://Scripts/Minigames/Olahraga/MainBola.gd",
	"res://Scripts/Minigames/Olahraga/Badminton.gd",
	"res://Scripts/Minigames/SeniBudaya/LombaMenari.gd",
	"res://Scripts/Minigames/SeniBudaya/BuatBatik.gd",
]

## The four games that ride the base implementation because they score out of a
## real max_score. The other four override it -- see Tasks 2-5.
const QUIZ_MINIGAMES := [
	"res://Scripts/Minigames/Akademis/PilihanGanda.gd",
	"res://Scripts/Minigames/Akademis/Menjodohkan.gd",
	"res://Scripts/Minigames/Akademis/Password.gd",
	"res://Scripts/Minigames/Akademis/Variabel.gd",
]


func test_every_quiz_declares_a_real_max_score() -> void:
	for path in QUIZ_MINIGAMES:
		var src := FileAccess.get_file_as_string(path)
		assert_true(src.contains("var max_score: int"),
			"%s scores out of a max_score, so the base rubric rates it" % path)


func test_every_minigame_can_be_rated() -> void:
	for path in ALL_MINIGAMES:
		var src := FileAccess.get_file_as_string(path)
		var overrides := src.contains("func get_star_ratio() -> float:")
		var has_max := src.contains("var max_score: int")
		assert_true(overrides or has_max,
			"%s must either declare max_score or override get_star_ratio()" % path)


func test_a_perfect_quiz_run_is_three_stars() -> void:
	var ratio := BaseMinigame._ratio_from_score(3, 3)
	assert_eq(BaseMinigame._calculate_stars(ratio, true), 3,
		"3 of 3 correct is a three-star run")


func test_every_minigame_that_overrides_get_star_ratio_uses_a_static_helper() -> void:
	# The pattern this whole test suite depends on: any override must expose
	# its math as a static func, or its own tests (and any later caller) hit
	# the same "placeholder instance" wall Task 1 found and worked around.
	for path in ALL_MINIGAMES:
		var src := FileAccess.get_file_as_string(path)
		if not src.contains("func get_star_ratio() -> float:"):
			continue   # quiz-shaped games ride the base implementation, nothing to check
		assert_true(src.contains("static func "),
			("%s overrides get_star_ratio() and must expose its math as a static "
			+ "helper, per the pattern Task 1 established") % path)
```

- [ ] **Step 2: Run it**

`test_run(suite="minigame_star_rubric")`. Expected: PASS, 33/33. If
`test_every_minigame_can_be_rated` fails, a game from Tasks 2-5 was missed — go back
to it rather than weakening this test.

- [ ] **Step 3: Run the full suite**

`test_run()`. Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add tests/test_minigame_star_rubric.gd && git commit -m "test(minigames): pin every minigame to a rateable mastery metric" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 7: The icon set

**Files:**

- Create: `Assets/Images/UI/Placeholders/icon_bintang.svg`, `icon_bintang_kosong.svg`,
  `icon_skor.svg`, `icon_target.svg`, `icon_akurasi.svg`, `icon_kombo.svg`,
  `icon_waktu.svg`
- Test: `tests/test_minigame_result_popup.gd` (append)

**Interfaces:**

- Consumes: nothing.
- Produces: seven `res://Assets/Images/UI/Placeholders/icon_*.svg` paths, consumed by
  Tasks 11, 12 and 14.

Match the existing house style: flat single-colour geometry on a transparent ground,
`96x96` viewBox, no gradients — read `Assets/Images/UI/Placeholders/icon_akademis.svg`
first and follow it. White fill (`#FFFFFF`) so the consuming node can tint via
`self_modulate`; **never** bake an accent colour into the file.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_minigame_result_popup.gd`:

```gdscript
## Every icon this screen now uses instead of an emoji glyph. The project
## banned emoji as UI iconography during the 2026-09-02 pass; these are the
## replacements.
const RESULT_ICONS := [
	"res://Assets/Images/UI/Placeholders/icon_bintang.svg",
	"res://Assets/Images/UI/Placeholders/icon_bintang_kosong.svg",
	"res://Assets/Images/UI/Placeholders/icon_skor.svg",
	"res://Assets/Images/UI/Placeholders/icon_target.svg",
	"res://Assets/Images/UI/Placeholders/icon_akurasi.svg",
	"res://Assets/Images/UI/Placeholders/icon_kombo.svg",
	"res://Assets/Images/UI/Placeholders/icon_waktu.svg",
]


func test_every_result_icon_exists_and_loads_as_a_texture() -> void:
	for path in RESULT_ICONS:
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		assert_true(load(path) is Texture2D, "%s loads as a Texture2D" % path)
```

- [ ] **Step 2: Run to verify it fails**

`test_run(suite="minigame_result_popup")`. Expected: FAIL on the first missing path.

- [ ] **Step 3: Author the seven SVGs**

Each 96x96, transparent, white fill. `icon_bintang.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" width="96" height="96">
  <path fill="#FFFFFF" d="M48 6 L60.4 33.6 L90 37.2 L68 57.4 L73.9 86.6 L48 72.2 L22.1 86.6 L28 57.4 L6 37.2 L35.6 33.6 Z"/>
</svg>
```

`icon_bintang_kosong.svg` — the same path with `fill="none" stroke="#FFFFFF"
stroke-width="7" stroke-linejoin="round"`.

The remaining five, same wrapper, one shape each:

- `icon_skor.svg` — a tally plaque: a `rect` x=10 y=18 w=76 h=60 rx=12 filled white,
  plus three punched bars in a second path with `fill-rule="evenodd"` at y=34/48/62,
  x=26, width=44, height=6, rx=3.
- `icon_target.svg` — three concentric circles cx=48 cy=48 r=40/26/12, alternating
  `fill="none" stroke="#FFFFFF" stroke-width="9"` and `fill="#FFFFFF"`.
- `icon_akurasi.svg` — a check: path `M18 50 L38 70 L78 26`, `fill="none"`,
  `stroke="#FFFFFF" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"`.
- `icon_kombo.svg` — a flame: path `M48 6 C64 28 78 38 78 58 a30 30 0 0 1 -60 0 C18 42 30 38 34 24 C40 34 44 32 48 6 Z`, filled white.
- `icon_waktu.svg` — a clock: `circle` cx=48 cy=48 r=38 `fill="none" stroke="#FFFFFF"
  stroke-width="9"`, plus hands path `M48 24 L48 50 L68 60` with the same stroke and
  `stroke-linecap="round"`.

- [ ] **Step 4: Import them**

Controller: `filesystem_manage(op="scan")` so Godot generates each `.import` sidecar.
Then confirm seven sidecars exist:

```bash
ls Assets/Images/UI/Placeholders/ | grep -cE 'icon_(bintang|bintang_kosong|skor|target|akurasi|kombo|waktu)[.]svg[.]import'
```

Expected output: `7`

- [ ] **Step 5: Run to verify it passes**

`test_run(suite="minigame_result_popup")`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Assets/Images/UI/Placeholders tests/test_minigame_result_popup.gd && git commit -m "feat(minigames): add the result-card and score-HUD icon set" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 8: Particle scenes for the result card and the HUD

**Files:**

- Create: `Scenes/Minigames/UI/StarBurst.tscn`, `Scenes/Minigames/UI/ResultConfetti.tscn`,
  `Scenes/Minigames/UI/ScorePopBurst.tscn`
- Test: `tests/test_minigame_result_popup.gd` (append)

**Interfaces:**

- Consumes: `RewardParticles` (`res://Scripts/SchoolSimulation/RewardParticles.gd`),
  `Assets/Images/Particles/particle_{star,spark,confetti,ring}.png`.
- Produces: three scene paths whose roots are `GPUParticles2D` carrying
  `RewardParticles`, i.e. exposing `fire(delay: float) -> void` and `plays_sfx: bool`.
  Consumed by Tasks 11, 13 and 14.

**No new script.** `RewardParticles.gd` already does exactly this job, and the two
existing emitters (`RewardBurst.tscn`, `CelebrationConfetti.tscn`) differ from each
other only in authored emitter settings. Follow that precedent.

- [ ] **Step 1: Write the failing test**

```gdscript
const PARTICLE_SCENES := [
	"res://Scenes/Minigames/UI/StarBurst.tscn",
	"res://Scenes/Minigames/UI/ResultConfetti.tscn",
	"res://Scenes/Minigames/UI/ScorePopBurst.tscn",
]


func test_every_particle_scene_is_a_one_shot_reward_particles_emitter() -> void:
	for path in PARTICLE_SCENES:
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		var node: Node = load(path).instantiate()
		track(node)
		assert_true(node is GPUParticles2D, "%s roots at a GPUParticles2D" % path)
		assert_true(node is RewardParticles,
			"%s reuses RewardParticles rather than a new script" % path)
		assert_true(node.one_shot, "%s is one-shot" % path)
		assert_false(node.emitting, "%s does not emit until fired" % path)
		assert_true(node.texture != null, "%s has an authored texture" % path)
		assert_true(node.process_material != null, "%s has an authored material" % path)
```

- [ ] **Step 2: Run to verify it fails**

`test_run(suite="minigame_result_popup")`. Expected: FAIL — scenes do not exist.

- [ ] **Step 3: Author the three scenes (controller, via MCP)**

Build each through `scene_manage` / `node_create` / `node_set_property` / `scene_save`
— **never** by writing `.tscn` text while the editor is attached.

`StarBurst.tscn` — root `GPUParticles2D` named `StarBurst`, script
`res://Scripts/SchoolSimulation/RewardParticles.gd`, texture
`res://Assets/Images/Particles/particle_star.png`:

| Property | Value |
|---|---|
| `emitting` | `false` |
| `amount` | `18` |
| `lifetime` | `0.8` |
| `one_shot` | `true` |
| `explosiveness` | `0.95` |

`process_material` — a new `ParticleProcessMaterial`: `emission_shape = 1`,
`emission_sphere_radius = 20.0`, `direction = Vector3(0, -1, 0)`, `spread = 180.0`,
`initial_velocity_min = 140.0`, `initial_velocity_max = 320.0`,
`angular_velocity_min = -260.0`, `angular_velocity_max = 260.0`,
`gravity = Vector3(0, 380, 0)`, `scale_min = 0.20`, `scale_max = 0.40`,
`color = Color(1, 0.86, 0.32, 1)`.

Add a child `GPUParticles2D` named `GlowRing`, same script, `plays_sfx = false`,
texture `particle_ring.png`, `amount = 1`, `lifetime = 0.5`, `one_shot = true`,
`explosiveness = 1.0`; its material with `initial_velocity_min = 0.0`,
`initial_velocity_max = 0.0`, `gravity = Vector3(0, 0, 0)`, `scale_min = 0.4`,
`scale_max = 0.4`. The parent's `fire()` already restarts every `GPUParticles2D`
child, so no code is needed for this.

`ResultConfetti.tscn` — root `GPUParticles2D` named `ResultConfetti`, same script,
texture `particle_confetti.png`: `emitting = false`, `amount = 120`, `lifetime = 2.6`,
`one_shot = true`, `explosiveness = 0.2`. Material: `emission_shape = 3`,
`emission_box_extents = Vector3(540, 8, 1)`, `direction = Vector3(0, 1, 0)`,
`spread = 28.0`, `initial_velocity_min = 100.0`, `initial_velocity_max = 260.0`,
`angular_velocity_min = -340.0`, `angular_velocity_max = 340.0`,
`gravity = Vector3(0, 320, 0)`, `scale_min = 0.22`, `scale_max = 0.48`.

`ScorePopBurst.tscn` — root `GPUParticles2D` named `ScorePopBurst`, same script,
texture `particle_spark.png`, `plays_sfx = false` (the HUD plays its own tick):
`emitting = false`, `amount = 8`, `lifetime = 0.45`, `one_shot = true`,
`explosiveness = 1.0`. Material: `emission_shape = 1`, `emission_sphere_radius = 10.0`,
`direction = Vector3(0, -1, 0)`, `spread = 55.0`, `initial_velocity_min = 70.0`,
`initial_velocity_max = 150.0`, `gravity = Vector3(0, 300, 0)`, `scale_min = 0.12`,
`scale_max = 0.22`.

- [ ] **Step 4: Run to verify it passes**

`test_run(suite="minigame_result_popup")`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Scenes/Minigames/UI tests/test_minigame_result_popup.gd && git commit -m "feat(minigames): add star, confetti and score-pop reward emitters" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 9: The new audio cues

**Files:**

- Modify: `Scripts/Audio/AudioDirector.gd:26-66` (the `@export` block), `:203-224`
  (the sfx-id match)
- Test: `tests/test_audio_coverage.gd` (append)

**Interfaces:**

- Consumes: nothing.
- Produces: six new `AudioDirector.play_sfx()` ids — `star_earn_1`, `star_earn_2`,
  `star_earn_3`, `result_fanfare`, `score_tick`, `combo_up`. Consumed by Tasks 11,
  13 and 14.

Three ascending star cues are what makes the reveal escalate: the same sound three
times reads as a list, three rising sounds read as a climb. All six alias existing
streams as placeholders — the established practice for new cue ids here (see the
2026-09-02 and 2026-09-03 passes) — so nothing blocks on new audio assets.

- [ ] **Step 1: Write the failing test**

```gdscript
## The six cues the 2026-09-04 minigame reward pass added. Each currently
## aliases an existing stream; the ids are the contract, the files are not.
const REWARD_SFX_IDS := [
	&"star_earn_1", &"star_earn_2", &"star_earn_3",
	&"result_fanfare", &"score_tick", &"combo_up",
]


func test_every_reward_cue_resolves_to_a_real_stream() -> void:
	for id in REWARD_SFX_IDS:
		assert_true(AudioDirector.has_sfx(id), "%s resolves to a stream" % id)
```

> Use the existing public `has_sfx(id: StringName) -> bool` wrapper, not the
> private accessor it delegates to (`_resolve_sfx` as of this writing) — the
> wrapper's own doc comment says it exists exactly for this: "tests and the
> audio-coverage suite use it to prove a slot got filled." If a future reader
> finds `has_sfx` gone, read the accessor's actual current name and use it
> directly, but prefer the public wrapper when one exists.
>
> **Also update the pre-existing id allowlist.** `tests/test_audio_coverage.gd`
> already has a `test_every_play_sfx_id_in_the_project_is_known` test that scans
> all of `Scripts/` for `play_sfx(&"...")` calls (including inside doc comments,
> since it's a raw regex text scan) against a hardcoded `known` array. Every
> `##`-documented `@export` in `AudioDirector.gd` carries a
> `` `play_sfx(&"id")`: ... `` usage comment (the file's own established
> convention), so the six new exports' doc comments alone will trip this test
> unless their ids are added to `known` too. Add `"star_earn_1"`, `"star_earn_2"`,
> `"star_earn_3"`, `"result_fanfare"`, `"score_tick"`, `"combo_up"` to that
> array in the same edit — easy to miss since it's a second, separate test
> function from the one above.

- [ ] **Step 2: Run to verify it fails**

`test_run(suite="audio_coverage")`. Expected: FAIL — the match falls through to null.

- [ ] **Step 3: Add the exports and the match arms**

In the `@export` block:

```gdscript
## First star of the result card's reveal. Placeholder: aliases pop.ogg. The
## three star_earn_* cues are meant to rise in pitch; swap in real assets
## before ship.
@export var sfx_star_earn_1: AudioStream = preload("res://Assets/Audio/SFX/pop.ogg")
## Second star of the reveal. Placeholder: aliases pop.ogg.
@export var sfx_star_earn_2: AudioStream = preload("res://Assets/Audio/SFX/pop.ogg")
## Third star of the reveal. Placeholder: aliases reward.ogg.
@export var sfx_star_earn_3: AudioStream = preload("res://Assets/Audio/SFX/reward.ogg")
## The result card's arrival sting. Placeholder: aliases reward.ogg.
@export var sfx_result_fanfare: AudioStream = preload("res://Assets/Audio/SFX/reward.ogg")
## One increment of a counting score readout. Placeholder: aliases pop.ogg.
@export var sfx_score_tick: AudioStream = preload("res://Assets/Audio/SFX/pop.ogg")
## An in-run combo stepping up. Placeholder: aliases pop.ogg.
@export var sfx_combo_up: AudioStream = preload("res://Assets/Audio/SFX/pop.ogg")
```

> `sfx_tally` (`:63`) and `sfx_sparkle` (`:66`) already preload exactly those two
> paths, so both exist. Confirm before writing anyway.

And in the match at `:203-224`:

```gdscript
		&"star_earn_1": return sfx_star_earn_1
		&"star_earn_2": return sfx_star_earn_2
		&"star_earn_3": return sfx_star_earn_3
		&"result_fanfare": return sfx_result_fanfare
		&"score_tick": return sfx_score_tick
		&"combo_up": return sfx_combo_up
```

- [ ] **Step 4: Run to verify it passes**

`filesystem_manage(op="scan")`, `test_run(suite="audio_coverage")`. Expected: PASS.

- [ ] **Step 5: Check the audio bus layout did not get dirtied**

```bash
git status --short Assets/Audio/default_bus_layout.tres
```

Expected: no output. If that file shows as modified, a suite leaked global AudioServer
state — that is a *new* leak (the old one was fixed on 2026-08-30), so investigate
before continuing, then restore it:

```bash
git checkout -- Assets/Audio/default_bus_layout.tres
```

- [ ] **Step 6: Commit**

```bash
git add Scripts/Audio/AudioDirector.gd tests/test_audio_coverage.gd && git commit -m "feat(audio): add the minigame reward cue ids" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 10: Theme variations for the result card and HUD

**Files:**

- Modify: `Scripts/Design/ThemeFactory.gd`
- Modify: `Assets/Theme/kejartes_theme.tres` (regenerated, not hand-edited)
- Test: `tests/test_minigame_result_popup.gd` (append)

**Interfaces:**

- Consumes: `DesignTokens` (`Assets/Theme/design_tokens.tres`) — **existing tokens
  only.** Adding a new `@export` to `DesignTokens` is invisible to a running editor
  and would strand this task the way the `ShelfEdge` variation was stranded on
  2026-09-01. Derive any new colour from an existing token (`.lightened()`,
  `.darkened()`, alpha) instead.
- Produces: seven theme type variations, consumed by Tasks 11, 12 and 14:
  `ResultCardPanel`, `ResultStatPanel`, `ResultBadgePanel`, `ResultStarSlot`,
  `ResultDeltaLabel`, `ScoreHudPanel`, `ScoreHudValueLabel`.

This is what "more consistent styling on its boxes" means concretely: today
`MinigameResultPopup.configure()` builds **six** `StyleBox` objects and applies
**twenty-odd** `theme_override_*` calls at runtime, so the card's boxes are styled by
whichever `BaseMinigame` `@export` values the individual minigame happened to set —
which is exactly why they do not match each other across the eight games. Moving them
into the theme is what makes them consistent, and it is also the project's hard rule.

- [ ] **Step 1: Write the failing test**

```gdscript
## The variations the result card and score HUD are styled by. Their existence
## in the baked theme is what lets Tasks 12 and 14 delete every runtime
## StyleBox and theme_override_* from MinigameResultPopup.configure().
const RESULT_VARIATIONS := [
	"ResultCardPanel", "ResultStatPanel", "ResultBadgePanel", "ResultStarSlot",
	"ResultDeltaLabel", "ScoreHudPanel", "ScoreHudValueLabel",
]


func test_every_result_variation_is_in_the_baked_theme() -> void:
	var theme: Theme = load("res://Assets/Theme/kejartes_theme.tres")
	# Base type "Panel", not "PanelContainer" -- every existing panel-style
	# variation in ThemeFactory.gd (Card, SunkenPanel, RecapPillPanel, ...)
	# is registered with set_type_variation(name, "Panel") even though the
	# nodes that use them are PanelContainer in the .tscn (PanelContainer
	# extends Panel, and Godot resolves theme_type_variation lookups through
	# that ancestry at draw time -- but get_type_variation_list() itself
	# only returns exact base-type matches, so the query has to name the
	# type variations were actually registered under).
	var types := theme.get_type_variation_list("Panel") \
		+ theme.get_type_variation_list("Label") \
		+ theme.get_type_variation_list("Control")
	for variation in RESULT_VARIATIONS:
		assert_true(variation in types,
			"%s is a baked type variation -- rebake ThemeFactory if not" % variation)
```

- [ ] **Step 2: Run to verify it fails**

`test_run(suite="minigame_result_popup")`. Expected: FAIL — none are in the theme.

- [ ] **Step 3: Add the variations to ThemeFactory.gd**

Read the existing `Card` (`:241`), `SunkenPanel` (`:254`) and `RecapPillPanel` (`:772`)
builders first and follow their exact shape — same helper calls, same token reads,
same comment density. Then add, in that same style:

- `ResultCardPanel` — base `PanelContainer`. A `StyleBoxTexture` over
  `res://Assets/Images/UI/Placeholders/popup_bg.svg` in nine-patch mode (the framing
  the 2026-09-02 PERINGATAN dialog established), content margins 32/28/32/28.
- `ResultStatPanel` — base `PanelContainer`. Derived from `SunkenPanel`: the same
  token background darkened, the tokens' medium corner radius, content margins
  20/12/20/12. This is the box the score row and the delta rows sit in.
- `ResultBadgePanel` — base `PanelContainer`. The category chip's ground: token
  surface colour, full-pill corner radius, content margins 18/8/18/8. The category
  accent is applied to the badge's icon `TextureRect`, never to the panel — see the
  hazard note in Task 12.
- `ResultStarSlot` — base `Control`. 96x96, no drawing of its own; exists so
  `ResultStar.tscn` gets its footprint from the theme rather than from
  `popup_star_size` being passed down at runtime.
- `ResultDeltaLabel` — base `Label`. Body font, the tokens' stat font size, centred,
  4px outline in the tokens' outline colour.
- `ScoreHudPanel` — base `PanelContainer`. A translucent dark pill for the in-run HUD:
  token surface at about 0.55 alpha, full-pill radius, content margins 18/8/18/8.
- `ScoreHudValueLabel` — base `Label`. Display font, large size, 8px outline — the HUD
  score has to stay legible over a football pitch and a batik cloth.

- [ ] **Step 4: Rebake the theme**

`Scripts/Design/BakeTheme.gd` is an `EditorScript` and has no MCP entry point. Two
routes.

*Preferred (by hand):* in the editor, File > Run (Ctrl+Shift+X) on
`Scripts/Design/BakeTheme.gd`.

*Headless:* write a transient `@tool` `McpTestSuite` into `res://tests/` whose single
test does the bake, run it, then delete it:

```gdscript
@tool
extends McpTestSuite

## TRANSIENT -- delete after running. Drives the ThemeFactory rebake headlessly
## because Scripts/Design/BakeTheme.gd is an EditorScript with no MCP entry
## point. Not a real test suite; do not commit.

func suite_name() -> String:
	return "transient_rebake"

func test_rebake() -> void:
	var theme: Theme = ThemeFactory.build()
	var err := ResourceSaver.save(theme, "res://Assets/Theme/kejartes_theme.tres")
	assert_eq(err, OK, "theme saved")
```

Run `test_run(suite="transient_rebake")`, confirm PASS, then delete the file and
`filesystem_manage(op="scan")`.

- [ ] **Step 5: Run to verify it passes**

`test_run(suite="minigame_result_popup")`. Expected: PASS.

- [ ] **Step 6: Confirm nothing else regressed**

`test_run()`. Expected: all green — in particular any suite that asserts on baked
variation counts.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_minigame_result_popup.gd && git commit -m "feat(design): add result-card and score-HUD theme variations" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 11: ResultStar — real star art, a glow, and its own burst

**Files:**

- Modify: `Scripts/Minigames/UI/ResultStar.gd`
- Modify: `Scenes/Minigames/UI/ResultStar.tscn`
- Test: `tests/test_minigame_result_popup.gd` (append)

**Interfaces:**

- Consumes: `icon_bintang.svg` / `icon_bintang_kosong.svg` (Task 7),
  `StarBurst.tscn` (Task 8), `star_earn_1/2/3` (Task 9), `ResultStarSlot` (Task 10).
- Produces:
  - `ResultStar.DEFAULT_FILLED_TEXTURE: String`, `DEFAULT_EMPTY_TEXTURE: String`,
    `BURST_SCENE: String`
  - `ResultStar.set_filled(filled, filled_tex, empty_tex, filled_color, empty_color) -> void`
    — **signature unchanged**, so Task 12 keeps calling it exactly as today
  - `ResultStar.celebrate(index: int) -> void` — **not** a coroutine; fires the burst,
    plays `star_earn_<index+1>`, blooms the glow. Called by `play()` in Task 13.

Today both texture slots default to `null`, so every star falls through to `_draw()`'s
procedural polygon in every game — the "consistent styling" gap in the star row
specifically. Give the scene real art by default while leaving the `@export` override
path intact.

- [ ] **Step 1: Write the failing test**

```gdscript
func test_a_star_defaults_to_real_art_not_the_procedural_polygon() -> void:
	var star: Control = load(STAR_PATH).instantiate()
	Engine.get_main_loop().root.add_child(star)
	track(star)
	star.set_filled(true, null, null, Color.WHITE, Color.GRAY)
	assert_true(star.icon.texture != null,
		"a null texture argument falls back to the shipped star art, not to _draw()")
	assert_true(star.is_filled, "and the star reads as earned")


func test_an_unearned_star_uses_the_hollow_art() -> void:
	var star: Control = load(STAR_PATH).instantiate()
	Engine.get_main_loop().root.add_child(star)
	track(star)
	star.set_filled(false, null, null, Color.WHITE, Color.GRAY)
	assert_true(star.icon.texture != null, "the empty star has art too")
	assert_false(star.is_filled, "and reads as unearned")


func test_the_star_scene_carries_a_glow_and_a_burst_slot() -> void:
	var star: Control = load(STAR_PATH).instantiate()
	track(star)
	assert_true(star.has_node("Glow"), "an authored Glow layer, not a runtime one")
	assert_true(star.has_node("BurstSlot"), "an authored slot the burst mounts into")


func test_celebrate_is_not_a_coroutine() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/ResultStar.gd")
	var body: String = src.split("func celebrate(")[1].split("\nfunc ")[0]
	assert_false(body.contains("await "),
		"celebrate() must be callable from a test and from the reveal loop")
```

- [ ] **Step 2: Run to verify it fails**

`test_run(suite="minigame_result_popup")`. Expected: FAIL — `icon.texture` is null,
no `Glow`, no `celebrate`.

- [ ] **Step 3: Update the scene (controller, via MCP)**

`scene_open` `res://Scenes/Minigames/UI/ResultStar.tscn`, then:

- Set the root's `theme_type_variation` to `ResultStarSlot` and its
  `custom_minimum_size` to `Vector2(96, 96)`.
- Add a `TextureRect` named `Glow`, then `move_node` it to index 0 so it draws behind
  `Icon` (`node_create` appends last). Texture
  `res://Assets/Images/Particles/particle_glow.png`, four anchors 0/0/1/1,
  `expand_mode = 1`, `stretch_mode = 5`, `modulate = Color(1, 0.86, 0.32, 0)` — it is
  invisible until `celebrate()`.
- Add a `Control` named `BurstSlot` as the last child, four anchors 0.5/0.5/0.5/0.5 so
  it sits at the star's centre.
- `scene_save`.

- [ ] **Step 4: Update ResultStar.gd**

Add above `set_filled`:

```gdscript
## Shipped art for an earned star, used when the caller passes no texture.
## Before 2026-09-04 both slots defaulted to null, so every minigame fell
## through to _draw()'s procedural polygon and the star row was the one part
## of the result card that never matched the rest of the game's art.
const DEFAULT_FILLED_TEXTURE := "res://Assets/Images/UI/Placeholders/icon_bintang.svg"
## Shipped art for an unearned star.
const DEFAULT_EMPTY_TEXTURE := "res://Assets/Images/UI/Placeholders/icon_bintang_kosong.svg"
## Scene fired at this star's centre when it lands earned.
const BURST_SCENE := "res://Scenes/Minigames/UI/StarBurst.tscn"
## Peak alpha the glow layer reaches on celebrate().
const GLOW_PEAK_ALPHA: float = 0.85
## Seconds the glow takes to bloom before settling back.
const GLOW_BLOOM_TIME: float = 0.18

@onready var glow: TextureRect = $Glow
@onready var burst_slot: Control = $BurstSlot
```

Inside `set_filled`, replace

```gdscript
	var tex := filled_tex if filled else empty_tex
```

with

```gdscript
	var tex: Texture2D = filled_tex if filled else empty_tex
	if tex == null:
		tex = load(DEFAULT_FILLED_TEXTURE if filled else DEFAULT_EMPTY_TEXTURE)
```

Then add:

```gdscript
## Land this star: bloom the glow, fire a burst, play the matching rung of the
## three-cue ladder. `index` is 0-based, so the third star gets star_earn_3 --
## three rising cues read as a climb where three identical ones read as a list.
##
## Not a coroutine: play() drives it from its reveal loop, and a test must be
## able to call it. Fire-and-forget -- the burst frees itself.
##
## Affects: this star's Glow layer, and adds a self-freeing burst under
## BurstSlot.
func celebrate(index: int) -> void:
	if Engine.is_editor_hint() or not is_filled:
		return
	AudioDirector.play_sfx(StringName("star_earn_%d" % clampi(index + 1, 1, 3)))
	var burst: Node = load(BURST_SCENE).instantiate()
	burst_slot.add_child(burst)
	burst.plays_sfx = false
	burst.fire()
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(glow, "modulate:a", GLOW_PEAK_ALPHA, GLOW_BLOOM_TIME)
	tw.tween_property(glow, "modulate:a", 0.35, GLOW_BLOOM_TIME * 2.0)
```

> `burst.fire()` is a coroutine and is **called, not awaited** — deliberate, and it
> matches `DaySummaryStatRow`'s existing use. Do not add an `await` here; it would make
> `celebrate()` a coroutine and break both the reveal loop and the test.

- [ ] **Step 5: Run to verify it passes**

`filesystem_manage(op="scan")`, `test_run(suite="minigame_result_popup")`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Minigames/UI/ResultStar.gd Scenes/Minigames/UI/ResultStar.tscn tests/test_minigame_result_popup.gd && git commit -m "feat(minigames): give result stars real art, a glow and a landing burst" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 12: Result card layout and configure() — icons in, emoji and overrides out

**Files:**

- Modify: `Scenes/Minigames/UI/MinigameResultPopup.tscn`
- Modify: `Scripts/Minigames/UI/MinigameResultPopup.gd:31-58` (consts and `@onready`s),
  `:88-250` (`configure`, `_stat_delta_suffix`, `_configure_delta_label`)
- Test: `tests/test_minigame_result_popup.gd` (replace the badge test, append the rest)

**Interfaces:**

- Consumes: Task 7's icons, Task 10's variations, `BaseMinigame`'s existing `style`
  dictionary (keys unchanged).
- Produces: `MinigameResultPopup._CATEGORY_ICON_PATHS: Dictionary`,
  `_CATEGORY_ICON_FALLBACK: String`, `_ENERGY_ICON: String`, `_MOOD_ICON: String`,
  and the node bindings `score_panel`, `score_icon`, `category_badge`,
  `category_badge_label`, `badge_icon`, `delta_panel`, `stat_delta_icon`,
  `energy_delta_icon`, `mood_delta_icon`, `confetti`. Consumed by Task 13.

- [ ] **Step 1: Write the failing test**

Replace `test_category_badge_shows_the_right_icon_and_colour` (`:126`) with the second
test below, and append the rest:

```gdscript
func test_the_popup_uses_no_emoji_as_iconography() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameResultPopup.gd")
	# Scanned by codepoint rather than by literal, so this test file stays
	# GDScript takes \U plus eight hex digits for the astral planes; the three
	# BMP glyphs below are safe as literals. Note \u{...} is NOT valid syntax.
	var banned: Array[String] = [
		"\U0001F4DA", "\U0001F3A8", "⚽", "⚡", "\U0001F60A",
		"\U0001F389", "\U0001F525", "✨", "\U0001F680", "\U0001F3AE",
	]
	for glyph in banned:
		assert_false(src.contains(glyph),
			"emoji-as-iconography has been banned since the 2026-09-02 pass")


func test_the_category_badge_shows_a_texture_not_a_glyph() -> void:
	var popup := _make()
	popup.configure(true, 3, 3, 3, "Pilihan Ganda", "Akademis", 5.0, -2.0, 1.0, STYLE)
	assert_true(popup.badge_icon.texture != null, "the badge carries an icon texture")
	assert_eq(popup.category_badge_label.text, "Akademis", "and just the name as text")


func test_each_delta_row_carries_its_own_icon() -> void:
	var popup := _make()
	popup.configure(true, 3, 3, 3, "Pilihan Ganda", "Olahraga", 5.0, -2.0, 1.0, STYLE)
	assert_true(popup.stat_delta_icon.texture != null, "the stat delta has an icon")
	assert_true(popup.energy_delta_icon.texture != null, "energy has icon_energy")
	assert_true(popup.mood_delta_icon.texture != null, "mood has icon_mood")


func test_configure_builds_no_styleboxes_or_overrides_at_runtime() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameResultPopup.gd")
	assert_false(src.contains("StyleBoxFlat.new()"),
		"card, badge and button chrome come from theme variations now")
	assert_false(src.contains("StyleBoxTexture.new()"), "same for the textured card")
	assert_false(src.contains("add_theme_stylebox_override"), "no stylebox overrides")
	assert_false(src.contains("add_theme_color_override"), "no colour overrides")
	assert_false(src.contains("add_theme_font_size_override"), "no font-size overrides")


func test_the_score_row_shows_for_a_game_with_only_a_target() -> void:
	var popup := _make()
	# Badminton's shape after Task 4: a real score, a real target.
	popup.configure(true, 3, 7, 7, "Badminton", "Olahraga", 5.0, -2.0, 1.0, STYLE)
	assert_true(popup.score_panel.visible,
		"a target-based game gets a score row, not a blank card")
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — no `badge_icon`, and `StyleBoxFlat.new()` is all over `configure()`.

- [ ] **Step 3: Rebuild the scene (controller, via MCP)**

`scene_open` `res://Scenes/Minigames/UI/MinigameResultPopup.tscn`, then, keeping every
existing node name the `@onready`s and the passing tests already bind:

- `Dim/Center/Card` — set `theme_type_variation = "ResultCardPanel"`.
- Add `ResultConfetti` (an instance of `res://Scenes/Minigames/UI/ResultConfetti.tscn`)
  as a child of `Dim` at `position = Vector2(540, -20)`, then `move_node` it after
  `Center` so it draws over the card.
- Wrap `ScoreRow` in a new `PanelContainer` named `ScorePanel`
  (`theme_type_variation = "ResultStatPanel"`) inserted at `ScoreRow`'s old index, and
  `move_node` `ScoreRow` under it.
- Inside `ScoreRow`, insert a `TextureRect` named `ScoreIcon` at index 0: texture
  `icon_skor.svg`, `custom_minimum_size = Vector2(44, 44)`, `expand_mode = 1`,
  `stretch_mode = 5`.
- `CategoryBadge` becomes a `PanelContainer` (`ResultBadgePanel`). A node's **type
  cannot be changed in place**, so delete the `Label` and recreate it at the same
  index. Give it a child `HBoxContainer` named `BadgeRow`
  (`theme_override_constants/separation = 10`, `alignment = 1`) holding a
  `TextureRect` named `BadgeIcon` (44x44, `expand_mode = 1`, `stretch_mode = 5`) and a
  `Label` named `BadgeLabel` (`theme_type_variation = "ResultDeltaLabel"`).
- Wrap the three delta labels in a `PanelContainer` named `DeltaPanel`
  (`ResultStatPanel`) containing a `VBoxContainer` named `DeltaList`
  (`theme_override_constants/separation = 8`). Inside it, put each original `Label`
  into an `HBoxContainer` — `StatDeltaRow` / `EnergyDeltaRow` / `MoodDeltaRow`,
  `alignment = 1`, separation 10 — each also holding a `TextureRect` named
  `StatDeltaIcon` / `EnergyDeltaIcon` / `MoodDeltaIcon` (40x40, `expand_mode = 1`,
  `stretch_mode = 5`). Keep the `Label` node names unchanged and set
  `theme_type_variation = "ResultDeltaLabel"` on each.
- `TitleLabel` -> `ResultHeroLabel`; `NameLabel` -> `ResultBodyLabel`;
  `ScorePrefixLabel` -> `ResultBodyLabel`; `ScoreValueLabel` -> `DisplayLabel`;
  `ContinueButton` -> `PrimaryButton`.
- Delete every `theme_override_colors/*` and `theme_override_constants/outline_size`
  left on these nodes — the variations carry them now. Keep `separation` and
  `alignment`.
- `scene_save`.

- [ ] **Step 4: Rewrite the icon consts and configure()**

Replace `_CATEGORY_ICONS` (`:44`) with:

```gdscript
## Category -> icon texture. Replaces the emoji glyph map the shipped card
## used; the project banned emoji as UI iconography during the 2026-09-02 pass.
const _CATEGORY_ICON_PATHS := {
	"Akademis": "res://Assets/Images/UI/Placeholders/icon_akademis.svg",
	"SeniBudaya": "res://Assets/Images/UI/Placeholders/icon_seni.svg",
	"Olahraga": "res://Assets/Images/UI/Placeholders/icon_olahraga.svg",
}
## Icon for a category the map above does not know.
const _CATEGORY_ICON_FALLBACK := "res://Assets/Images/UI/Placeholders/icon_poin.svg"
## The two need-delta rows' icons.
const _ENERGY_ICON := "res://Assets/Images/UI/Placeholders/icon_energy.svg"
const _MOOD_ICON := "res://Assets/Images/UI/Placeholders/icon_mood.svg"
```

Strip the emoji from `_FAIL_TITLES` (`:33-38`) so they read as plain Indonesian:

```gdscript
const _FAIL_TITLES: Array[String] = [
	"Belum Tepat, Coba Lagi Lain Kali!",
	"Jangan Menyerah, Coba Lagi Lain Kali!",
	"Yuk! Terus Berlatih agar Berhasil!",
	"Ingat dan Kamu Pasti Bisa!",
]
```

Rewrite `_stat_delta_suffix` to return the plain Indonesian name only — `"Akademis"`,
`"Seni Budaya"`, `"Olahraga"` — with the icon supplied separately. Do the same to
`win_title_text`'s default on `BaseMinigame` if it still carries a glyph.

In `configure()`, delete every `StyleBoxFlat.new()`, `StyleBoxTexture.new()`,
`add_theme_stylebox_override`, `add_theme_color_override`,
`add_theme_font_size_override` and `add_theme_font_override` call. Each becomes either
nothing (the variation already covers it) or, for the two genuinely dynamic cases:

- **Win/lose title colour** — `title_label.self_modulate = style["popup_title_win_color"]
  if is_win else style["popup_title_lose_color"]`
- **Delta sign colour** — `label.self_modulate = Color(0.3, 0.95, 0.5) if delta > 0
  else Color(0.95, 0.35, 0.35)`

> **Hazard, from the 2026-09-02 StatBar lesson:** `self_modulate` multiplies the whole
> node. It is safe on a `Label` (which draws only glyphs) and safe on a `TextureRect`
> carrying a white-fill icon — which is exactly why Task 7 requires white fills. It is
> **not** safe on a `PanelContainer` whose background you want left alone. Tint the
> `BadgeIcon`, never the `ResultBadgePanel`.

Set the icons and the panel visibility:

```gdscript
	badge_icon.texture = load(_CATEGORY_ICON_PATHS.get(category, _CATEGORY_ICON_FALLBACK))
	badge_icon.self_modulate = _CATEGORY_COLORS.get(category, Color(0.7, 0.7, 0.8))
	category_badge_label.text = category
	category_badge.visible = category != ""
	stat_delta_icon.texture = load(_CATEGORY_ICON_PATHS.get(category, _CATEGORY_ICON_FALLBACK))
	energy_delta_icon.texture = load(_ENERGY_ICON)
	mood_delta_icon.texture = load(_MOOD_ICON)
	score_icon.texture = load("res://Assets/Images/UI/Placeholders/icon_skor.svg")
```

Swap `score_row.visible` for `score_panel.visible`, keeping the same rule
(`score >= 0 and max_score > 0` — which now passes for Badminton too, thanks to
Task 4's mirrors), and hide `delta_panel` when all three delta rows are hidden. Add
the matching `@onready` bindings for every new node, and make `_configure_delta_label`
toggle the enclosing `HBoxContainer` rather than the bare `Label`, so a hidden row
takes its icon with it.

- [ ] **Step 5: Run to verify it passes**

`filesystem_manage(op="scan")`, `test_run(suite="minigame_result_popup")`.
Expected: PASS. Watch `test_popup_scene_carries_every_node_the_script_binds` (`:58`) —
it walks the `@onready` list, so any node named differently in Step 3 than in Step 4
fails there first.

- [ ] **Step 6: Commit**

```bash
git add Scenes/Minigames/UI/MinigameResultPopup.tscn Scripts/Minigames/UI/MinigameResultPopup.gd tests/test_minigame_result_popup.gd && git commit -m "feat(minigames): restyle the result card onto theme variations and real icons" -m "Every box on the card was styled by a runtime StyleBox built from whichever BaseMinigame exports the individual minigame happened to set, so the card looked different across the eight games. Chrome now comes from the theme, and every emoji glyph is a real transparent SVG." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 13: The reveal sequence — escalation, counting, confetti

**Files:**

- Modify: `Scripts/Minigames/UI/MinigameResultPopup.gd` (`play()`, currently `:252-330`)
- Test: `tests/test_minigame_result_popup.gd` (append — **source scans only**)

**Interfaces:**

- Consumes: `ResultStar.celebrate(index)` (Task 11), the `confetti` node (Task 12),
  `result_fanfare` / `score_tick` (Task 9), `Juice.count_up`.
- Produces: `MinigameResultPopup._star_count: int`, `_score_target: int`,
  `STAR_POP_SCALES`, `STAR_HOLD_TIMES`, `CONFETTI_STAR_THRESHOLD`, `SCORE_COUNT_TIME`.
  `play()` keeps its signature and stays a coroutine.

`play()` is a coroutine and **cannot be called from any test** — the runner does not
await. So this task's tests are source scans, the established pattern here
(`test_base_minigame_no_longer_builds_the_result_card` at `:146` does exactly this).
Behavioural confirmation is a manual pass, Step 5.

The current reveal treats all three stars identically: same pop, same settle, no sound.
That is the "not addictive" complaint in mechanical terms — nothing escalates, so the
third star feels like the first. Four changes:

1. **Fanfare on arrival.** `result_fanfare` as the card bounces in.
2. **Escalating stars.** Each star pops a little further than the last (1.14 -> 1.22 ->
   1.34), holds a beat longer, and calls `celebrate(i)` for the rising cue and the
   burst. An *unearned* star still appears, silently and without a burst — the contrast
   is what makes an earned one land.
3. **A counting score.** The score tallies up from zero with a tick, rather than
   appearing already finished.
4. **Confetti at three stars only.** Fired after the third star lands, gated exactly
   the way the 2026-09-03 pass gated its bursts. A two-star finish stays quiet, or the
   celebration means nothing.

- [ ] **Step 1: Write the failing test**

```gdscript
func test_the_reveal_escalates_across_the_three_stars() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameResultPopup.gd")
	assert_true(src.contains("const STAR_POP_SCALES"),
		"per-star pop scales are a named const, not inline literals")
	assert_true(src.contains("celebrate("),
		"each earned star gets its landing burst and rising cue")


func test_confetti_is_gated_on_a_three_star_finish() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameResultPopup.gd")
	assert_true(src.contains("const CONFETTI_STAR_THRESHOLD"),
		"the confetti gate is a named const")
	assert_true(src.contains("_star_count >= CONFETTI_STAR_THRESHOLD"),
		"a two-star finish stays quiet")


func test_the_score_counts_up_rather_than_appearing_finished() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameResultPopup.gd")
	assert_true(src.contains("Juice.count_up"), "the score tallies")
	assert_true(src.contains("result_fanfare"), "the card arrives with a sting")


func test_configure_remembers_the_star_count_for_play() -> void:
	var popup := _make()
	popup.configure(true, 3, 3, 3, "Pilihan Ganda", "Akademis", 5.0, -2.0, 1.0, STYLE)
	assert_eq(popup._star_count, 3, "play() reads the count configure() was given")
	popup.configure(true, 1, 1, 3, "Pilihan Ganda", "Akademis", 5.0, -2.0, 1.0, STYLE)
	assert_eq(popup._star_count, 1, "and it updates on reconfigure")
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — no `STAR_POP_SCALES`, no `_star_count`.

- [ ] **Step 3: Implement**

Add to the const block:

```gdscript
## Per-star pop scale, ascending. The shipped reveal popped all three to the
## same 1.18, so the third star landed no harder than the first and the whole
## sequence read flat. Index is the star's 0-based position.
const STAR_POP_SCALES: Array[float] = [1.14, 1.22, 1.34]
## Seconds each star holds at its pop scale before settling. Ascending for the
## same reason.
const STAR_HOLD_TIMES: Array[float] = [0.06, 0.10, 0.18]
## Stars at or above which the card fires its screen-wide confetti. Three: a
## two-star finish staying quiet is what makes three mean something.
const CONFETTI_STAR_THRESHOLD: int = 3
## Seconds the score readout takes to tally up from zero.
const SCORE_COUNT_TIME: float = 0.6
```

Add `var _star_count: int = 0` and `var _score_target: int = 0` beside `_is_win`, and
set both at the top of `configure()`:

```gdscript
	_star_count = stars
	_score_target = score
```

Bind the emitter: `@onready var confetti: RewardParticles = $Dim/ResultConfetti`.

In `configure()`'s score section, seed the label at zero so `play()` has something to
count from:

```gdscript
	score_value_label.text = "0 / %d" % max_score
```

In `play()`, after the card's bounce-in tween (step 2):

```gdscript
	AudioDirector.play_sfx(&"result_fanfare")
```

Replace the star loop (step 4) with:

```gdscript
	# 4. Stars pop in one by one, escalating. An unearned star still appears --
	# silently, and without a burst -- so the contrast makes an earned one land.
	var star_index := 0
	for star in star_row.get_children():
		var pop_scale: float = STAR_POP_SCALES[mini(star_index, STAR_POP_SCALES.size() - 1)]
		var tw_star := get_tree().create_tween().set_parallel(true)
		tw_star.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_star.tween_property(star, "modulate:a", 1.0, 0.15)
		tw_star.tween_property(star, "scale", Vector2(pop_scale, pop_scale), 0.18)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw_star.finished
		star.celebrate(star_index)
		await get_tree().create_timer(
			STAR_HOLD_TIMES[mini(star_index, STAR_HOLD_TIMES.size() - 1)]).timeout
		var tw_settle := get_tree().create_tween()
		tw_settle.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_settle.tween_property(star, "scale", Vector2(1.0, 1.0), 0.1)\
			.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		await tw_settle.finished
		star_index += 1

	# 4b. A full house, and only a full house, gets the confetti.
	if _star_count >= CONFETTI_STAR_THRESHOLD:
		confetti.fire()
```

In the step-5 fade loop, replace `score_row` with `score_panel` in the
`fade_nodes` list, and special-case it so the number tallies as it arrives:

```gdscript
		if fn == score_panel and _score_target > 0:
			AudioDirector.play_sfx(&"score_tick")
			Juice.count_up(score_value_label, 0.0, float(_score_target))
```

> Read `Juice.count_up`'s signature at `Scripts/Design/Juice.gd:93` before wiring this
> — it takes a `fmt` you can use to append the `/ max` half, and
> `Juice.count_up_formatted` (`:117`) exists if the simple one cannot express it. Use
> whichever fits; do not invent a third counting helper.

- [ ] **Step 4: Run to verify it passes**

`filesystem_manage(op="scan")`, `test_run(suite="minigame_result_popup")`. Expected: PASS.

- [ ] **Step 5: Confirm it behaviourally, once, by hand**

`play()` cannot be tested, so verify it in the running game — but **do not play a
minigame to get there.** The debug overlay (`F1`, or five taps in the top-right
corner) has a minigame launcher that starts any of the eight directly. Launch
`MainBola`, score every shot, and confirm on the card that (a) three stars fill,
(b) each lands louder than the last, (c) confetti falls, (d) the score tallies. Then
launch it again and lose deliberately: confirm zero stars, no bursts, no confetti.

`editor_screenshot` once at the three-star card. One screenshot costs more than the
whole 568-test run, so take exactly one.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Minigames/UI/MinigameResultPopup.gd tests/test_minigame_result_popup.gd && git commit -m "feat(minigames): make the result reveal escalate, tally and celebrate" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 14: The shared in-run score HUD

**Files:**

- Create: `Scripts/Minigames/UI/MinigameScoreHUD.gd`,
  `Scenes/Minigames/UI/MinigameScoreHUD.tscn`
- Test: `tests/test_minigame_score_hud.gd` (create)

**Interfaces:**

- Consumes: Task 7's icons, Task 8's `ScorePopBurst.tscn`, Task 9's `score_tick` /
  `combo_up`, Task 10's `ScoreHudPanel` / `ScoreHudValueLabel`.
- Produces:
  - `MinigameScoreHUD.setup(hud_icon: Texture2D, target: int) -> void`
  - `MinigameScoreHUD.set_score(value: int) -> void` — pops, bursts, ticks
  - `MinigameScoreHUD.set_combo(value: int) -> void` — shows/hides the combo chip
  - `MinigameScoreHUD.set_label_text(text: String) -> void` — the escape hatch for
    Badminton's `"7 - 6"`
  Consumed by Task 15.

This is the "plain numbers, no icons" half of the brief. Today each of the games with
a score builds its own `ScoreLabel` styling at runtime — `MainBola.gd:427-434`,
`Badminton.gd:576-583`, `LombaMenari.gd:163-167`, `Menjodohkan.gd:505-506` — with five
`theme_override_*` calls apiece, all slightly different. One template replaces them.

- [ ] **Step 1: Write the failing test**

Create `tests/test_minigame_score_hud.gd`:

```gdscript
@tool
extends McpTestSuite

## The shared in-run score readout.
##
## Before 2026-09-04 each minigame styled its own bare ScoreLabel at runtime
## with five theme_override_* calls, so the score looked different in every
## game and carried no icon at all. This is the one template they all mount.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "minigame_score_hud"


const HUD_PATH := "res://Scenes/Minigames/UI/MinigameScoreHUD.tscn"
const ICON_SKOR := "res://Assets/Images/UI/Placeholders/icon_skor.svg"


func _make() -> Node:
	var node: Node = load(HUD_PATH).instantiate()
	Engine.get_main_loop().root.add_child(node)
	track(node)
	return node


func test_the_scene_carries_every_node_the_script_binds() -> void:
	var hud := _make()
	for path in ["Panel/Row/Icon", "Panel/Row/ValueLabel", "Panel/Row/TargetLabel",
			"Panel/Row/ComboChip", "BurstSlot"]:
		assert_true(hud.has_node(path), "%s is an authored node" % path)


func test_setup_installs_the_icon_and_the_target() -> void:
	var hud := _make()
	hud.setup(load(ICON_SKOR), 5)
	assert_true(hud.icon.texture != null, "the icon is set")
	assert_true(hud.target_label.text.contains("5"), "the target reads out")


func test_set_score_updates_the_value() -> void:
	var hud := _make()
	hud.setup(load(ICON_SKOR), 5)
	hud.set_score(3)
	assert_eq(hud.value_label.text, "3", "the value tracks the score")


func test_the_combo_chip_hides_below_the_display_threshold() -> void:
	var hud := _make()
	hud.set_combo(1)
	assert_false(hud.combo_chip.visible, "a combo of one is not a combo")
	hud.set_combo(3)
	assert_true(hud.combo_chip.visible, "three in a row is worth showing")
	assert_true(hud.combo_chip_label.text.contains("3"), "and reads out the count")


func test_the_escape_hatch_leaves_the_target_alone() -> void:
	var hud := _make()
	hud.setup(load(ICON_SKOR), 7)
	hud.set_label_text("7 - 6")
	assert_eq(hud.value_label.text, "7 - 6",
		"Badminton's two-sided score goes through verbatim")
	assert_true(hud.target_label.text.contains("7"), "and the target is untouched")


func test_the_hud_adds_no_theme_overrides() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameScoreHUD.gd")
	assert_false(src.contains("add_theme_"), "chrome comes from the theme variations")


func test_no_public_method_is_a_coroutine() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameScoreHUD.gd")
	for fn in ["setup", "set_score", "set_combo", "set_label_text"]:
		var body: String = src.split("func %s(" % fn)[1].split("\nfunc ")[0]
		assert_false(body.contains("await "), "%s() must be callable from _process" % fn)
```

- [ ] **Step 2: Run to verify it fails**

`test_run(suite="minigame_score_hud")`. Expected: FAIL — the scene does not exist.

- [ ] **Step 3: Author the scene (controller, via MCP)**

Root `Control` named `MinigameScoreHUD`, `mouse_filter = 2` (ignore). Children:

- `PanelContainer` named `Panel`, `theme_type_variation = "ScoreHudPanel"`.
  - `HBoxContainer` named `Row`, `theme_override_constants/separation = 12`,
    `alignment = 1`.
    - `TextureRect` named `Icon`, `custom_minimum_size = Vector2(48, 48)`,
      `expand_mode = 1`, `stretch_mode = 5`.
    - `Label` named `ValueLabel`, `theme_type_variation = "ScoreHudValueLabel"`.
    - `Label` named `TargetLabel`, `theme_type_variation = "ResultBodyLabel"`.
    - `PanelContainer` named `ComboChip`, `theme_type_variation = "ResultBadgePanel"`,
      `visible = false`.
      - `HBoxContainer` named `ComboRow`, separation 6.
        - `TextureRect` named `ComboIcon`, texture `icon_kombo.svg`, 32x32,
          `expand_mode = 1`, `stretch_mode = 5`.
        - `Label` named `ComboLabel`, `theme_type_variation = "ResultBodyLabel"`.
- `Control` named `BurstSlot`, anchors 0.5/0.5/0.5/0.5.

Attach the Step 4 script to the root, then `scene_save`.

- [ ] **Step 4: Write MinigameScoreHUD.gd**

```gdscript
@tool
class_name MinigameScoreHUD
extends Control

## The shared in-run score readout, mounted by every minigame that keeps score.
##
## Before this template, MainBola, Badminton, LombaMenari and Menjodohkan each
## styled a bare ScoreLabel at runtime with five theme_override_* calls apiece,
## all slightly different and none carrying an icon. Chrome now comes from the
## ScoreHudPanel / ScoreHudValueLabel theme variations; the only thing this
## script sets is content.
##
## Affects: nothing outside itself. Every method is synchronous so a minigame
## can call it from _process or a signal handler.
##
## @tool so the scene previews in the editor.

## Combo length at or above which the combo chip appears. Two-in-a-row is
## noise; three is a streak worth telling the player about.
const COMBO_DISPLAY_MIN: int = 3
## Peak scale of the value label's pop on a score increase.
const POP_SCALE: float = 1.28
## Seconds the pop takes to swell, and again to settle.
const POP_TIME: float = 0.12
## Burst fired at the readout when the score goes up.
const BURST_SCENE := "res://Scenes/Minigames/UI/ScorePopBurst.tscn"

@onready var icon: TextureRect = $Panel/Row/Icon
@onready var value_label: Label = $Panel/Row/ValueLabel
@onready var target_label: Label = $Panel/Row/TargetLabel
@onready var combo_chip: PanelContainer = $Panel/Row/ComboChip
@onready var combo_chip_label: Label = $Panel/Row/ComboChip/ComboRow/ComboLabel
@onready var burst_slot: Control = $BurstSlot

## Last value set_score() saw, so a re-set of the same score does not re-pop.
var _last_score: int = 0


## Install the readout's icon and its target. A `target` of 0 or less hides the
## target half, for a game that scores without a ceiling.
##
## Affects: this HUD's own icon, value and target labels.
func setup(hud_icon: Texture2D, target: int) -> void:
	icon.texture = hud_icon
	target_label.visible = target > 0
	if target > 0:
		target_label.text = "/ %d" % target
	value_label.text = "0"
	_last_score = 0


## Set the score. A genuine increase pops the label, fires a burst and ticks; a
## re-set of the same number does none of those, so a minigame is free to call
## this every frame.
##
## Affects: this HUD's value label, and adds a self-freeing burst under
## BurstSlot on an increase.
func set_score(value: int) -> void:
	value_label.text = str(value)
	if value <= _last_score:
		_last_score = value
		return
	_last_score = value
	if Engine.is_editor_hint():
		return
	AudioDirector.play_sfx(&"score_tick")
	var burst: Node = load(BURST_SCENE).instantiate()
	burst_slot.add_child(burst)
	burst.fire()
	Juice.set_pivot_center(value_label)
	var tw := create_tween()
	tw.tween_property(value_label, "scale", Vector2(POP_SCALE, POP_SCALE), POP_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(value_label, "scale", Vector2.ONE, POP_TIME)\
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


## Show or hide the combo chip. Below COMBO_DISPLAY_MIN it stays hidden, and
## the cue fires only on the transition into visibility, never every hit.
##
## Affects: this HUD's combo chip.
func set_combo(value: int) -> void:
	var show_chip: bool = value >= COMBO_DISPLAY_MIN
	if show_chip and not combo_chip.visible and not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"combo_up")
	combo_chip.visible = show_chip
	combo_chip_label.text = "x%d" % value


## Write the value half verbatim, for a game whose score is not a single number
## -- Badminton's "7 - 6", say. Leaves the target half untouched.
##
## Affects: this HUD's value label.
func set_label_text(text: String) -> void:
	value_label.text = text
```

- [ ] **Step 5: Run to verify it passes**

`filesystem_manage(op="scan")`, `test_run(suite="minigame_score_hud")`. Expected: PASS, 7/7.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Minigames/UI/MinigameScoreHUD.gd Scenes/Minigames/UI/MinigameScoreHUD.tscn tests/test_minigame_score_hud.gd && git commit -m "feat(minigames): add the shared score HUD template" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 15: Retrofit the scoring minigames onto the HUD

**Files:**

- Modify: `Scenes/Minigames/Olahraga/{MainBola,Badminton}.tscn`,
  `Scenes/Minigames/SeniBudaya/LombaMenari.tscn`,
  `Scenes/Minigames/Akademis/{Menjodohkan,PilihanGanda,Password,Variabel}.tscn`
- Modify: the matching `.gd` for each
- Test: `tests/test_minigame_score_hud.gd` (append)

**Interfaces:**

- Consumes: everything from Task 14.
- Produces: `LombaMenari.current_combo: int`, `best_combo: int`. Nothing else new.

Replace each game's bare `ScoreLabel` with a `MinigameScoreHUD` instance at the same
position, and delete the runtime styling block that went with it. This is a pure
substitution — **no scoring logic changes in this task**, beyond LombaMenari's combo
counters.

Per-game mapping:

| Game | Icon | `setup()` target | Per-update call |
|---|---|---|---|
| `MainBola` | `icon_olahraga.svg` | `target_score` | `set_score(score)` |
| `Badminton` | `icon_olahraga.svg` | `target_score` | `set_label_text("%d - %d" % [enemy_score, player_score])` |
| `LombaMenari` | `icon_seni.svg` | `target_score` | `set_score(score)` + `set_combo(current_combo)` |
| `Menjodohkan` | `icon_akademis.svg` | `max_score` | `set_score(locked_matches.size())` |
| `PilihanGanda` / `Password` / `Variabel` | `icon_akademis.svg` | `max_score` | `set_score(score)` |

- [ ] **Step 1: Write the failing test**

```gdscript
## Every minigame scene that keeps a score, and must therefore mount the shared
## HUD rather than styling a bare ScoreLabel of its own.
const SCORING_MINIGAME_SCENES := [
	"res://Scenes/Minigames/Olahraga/MainBola.tscn",
	"res://Scenes/Minigames/Olahraga/Badminton.tscn",
	"res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn",
	"res://Scenes/Minigames/Akademis/Menjodohkan.tscn",
	"res://Scenes/Minigames/Akademis/PilihanGanda.tscn",
	"res://Scenes/Minigames/Akademis/Password.tscn",
	"res://Scenes/Minigames/Akademis/Variabel.tscn",
]

const SCORING_MINIGAME_SCRIPTS := [
	"res://Scripts/Minigames/Olahraga/MainBola.gd",
	"res://Scripts/Minigames/Olahraga/Badminton.gd",
	"res://Scripts/Minigames/SeniBudaya/LombaMenari.gd",
	"res://Scripts/Minigames/Akademis/Menjodohkan.gd",
	"res://Scripts/Minigames/Akademis/PilihanGanda.gd",
	"res://Scripts/Minigames/Akademis/Password.gd",
	"res://Scripts/Minigames/Akademis/Variabel.gd",
]


func test_every_scoring_minigame_mounts_the_shared_hud() -> void:
	for path in SCORING_MINIGAME_SCENES:
		var src := FileAccess.get_file_as_string(path)
		assert_true(src.contains("MinigameScoreHUD.tscn"),
			"%s instances the shared HUD" % path)


func test_no_scoring_minigame_still_styles_a_score_label_at_runtime() -> void:
	for path in SCORING_MINIGAME_SCRIPTS:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("score_label.add_theme_"),
			"%s no longer styles its score at runtime" % path)
```

- [ ] **Step 2: Run to verify it fails**

`test_run(suite="minigame_score_hud")`. Expected: FAIL on all seven scenes.

- [ ] **Step 3: Retrofit each scene (controller, via MCP), one at a time**

For each: `scene_open`; read the existing `ScoreLabel`'s anchors and offsets with
`node_get_properties`; `node_create` a `MinigameScoreHUD.tscn` instance named
`ScoreHUD` as a sibling at those same anchors and offsets; delete `ScoreLabel`;
`scene_save`. Run `test_run()` after **each** scene rather than all seven — a broken
`.tscn` is far cheaper to localise one at a time.

Note that some of these games have no `ScoreLabel` in the scene at all (check
`PilihanGanda`, `Password`, `Variabel` first — they may print their score only into
`result_subtitle`). For those, add `ScoreHUD` at the top centre of the existing header
container rather than replacing anything.

- [ ] **Step 4: Retrofit each script**

For each: change the `@onready` from
`@onready var score_label: Label = $.../ScoreLabel` to
`@onready var score_hud: MinigameScoreHUD = $.../ScoreHUD`; call
`score_hud.setup(load("res://Assets/Images/UI/Placeholders/icon_<category>.svg"), <target>)`
where the old styling block ran once; and replace the whole
`if score_label: ... add_theme_*` block with the single per-update call from the table
above. Delete the now-unused `score_font_size` / `score_color` `@export`s **only if
nothing else reads them** — grep first.

For `LombaMenari`, additionally add beside the Task 3 counters:

```gdscript
## Consecutive hits without a miss, for the HUD's combo chip. Reset by a miss.
var current_combo: int = 0
## Longest combo this run. Not yet read by the star rubric -- reserved for a
## balance pass once real playtest numbers exist.
var best_combo: int = 0
```

Increment `current_combo` at both hit sites and set it to 0 at the miss site, keep
`best_combo = maxi(best_combo, current_combo)`, and call
`score_hud.set_combo(current_combo)` after each.

- [ ] **Step 5: Run to verify it passes**

`filesystem_manage(op="scan")`, `test_run()`. Expected: every suite green, including
`test_minigame_overlays` and `test_project_hygiene` — the latter catches a stale
`ext_resource` UID if a scene edit went sideways.

- [ ] **Step 6: Confirm one game by hand**

Debug overlay -> minigame launcher -> `LombaMenari`. Confirm the HUD shows an icon,
the score pops and bursts on a hit, and the combo chip appears at three in a row and
vanishes on a miss. One `editor_screenshot`.

- [ ] **Step 7: Commit**

```bash
git add Scenes/Minigames Scripts/Minigames tests/test_minigame_score_hud.gd && git commit -m "feat(minigames): mount the shared score HUD in every scoring game" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 16: Lower the ratchet and record the work

**Files:**

- Modify: `tests/test_viewport_editability.gd:70-78` (`BASELINE`)
- Modify: `CLAUDE.md` ("Current work")
- Modify: `docs/superpowers/design/authoring-guide.md` ("Known gaps")

**Interfaces:**

- Consumes: everything. Produces: nothing.

Tasks 12 and 15 deleted real runtime visual construction from six minigame scripts and
from the result popup. The `BASELINE` dict is a ratchet that may **only ever be
lowered** — leaving it high after a conversion is how the debt silently creeps back.

- [ ] **Step 1: Measure the real remaining counts**

`test_run(suite="viewport_editability")`. The failure message for an over-budget file
names its actual count. Run it, read the numbers, and lower each entry to what the
suite actually reports — do not guess, and never raise one.

- [ ] **Step 2: Update BASELINE**

Edit the entries for `MainBola.gd`, `Badminton.gd`, `LombaMenari.gd`, `BuatBatik.gd`,
`Menjodohkan.gd`, `PilihanGanda.gd` and `BaseMinigame.gd` to their measured values. If
a file reaches 0, remove its entry entirely rather than leaving a `: 0`.

- [ ] **Step 3: Run to verify**

`test_run(suite="viewport_editability")`. Expected: PASS.

- [ ] **Step 4: Update the docs**

In `CLAUDE.md`, add to "Current work":

> The 2026-09-04 minigame reward pass is complete. Plan:
> `docs/superpowers/plans/2026-09-04-minigame-reward-feedback.md`. It fixed the
> one-star bug — `_calculate_stars()` read `max_score`, which only the four Akademis
> quizzes declare, so every win in MainBola, LombaMenari, Badminton and BuatBatik was
> hard-capped at one star — by replacing it with an overridable per-game
> `get_star_ratio()` mastery metric (shot accuracy, note accuracy, rally margin,
> mistake-free sequence) and a two-star floor for an unrated win. It then moved the
> result card's chrome off runtime `StyleBox`es onto seven new `ThemeFactory`
> variations, replaced every emoji glyph with a transparent SVG, gave the star reveal
> an escalating pop with per-star bursts and three rising audio cues, gated confetti on
> a three-star finish, and replaced the ad-hoc `ScoreLabel`s with the shared
> `MinigameScoreHUD` template. Placeholders outstanding: the six new `AudioDirector`
> cue ids (`star_earn_1/2/3`, `result_fanfare`, `score_tick`, `combo_up`) all alias
> `pop.ogg` / `reward.ogg`, the seven new icon SVGs are flat white placeholder
> geometry, and `LombaMenari.best_combo` is tracked but not yet fed into the rubric,
> pending a real balance pass.

In `docs/superpowers/design/authoring-guide.md`'s "Known gaps", strike the minigame
entries this pass converted and note the new `MinigameScoreHUD` template.

- [ ] **Step 5: Full verification**

```bash
git status --short Assets/Audio/default_bus_layout.tres
```

Expected: no output.

Then `test_run()` — every suite, every test. Read the actual summary before claiming
anything is done; do not report completion from a partial run.

- [ ] **Step 6: Commit**

```bash
git add tests/test_viewport_editability.gd CLAUDE.md docs/superpowers/design/authoring-guide.md && git commit -m "docs(minigames): record the reward pass and lower the editability ratchet" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Open questions for the user

None of these block execution — each has a stated default the plan already implements —
but they are the judgment calls worth confirming.

1. **Three-star difficulty.** `STAR_RATIO_THREE = 0.90` means near-flawless. On grade 9
   (16 weeks, the harshest tuning) that may be too punishing to feel rewarding.
   Default: 0.90, tunable as one const.
2. **The unrated-win floor.** `STAR_UNRATED_DEFAULT = 2` is a safety net so a future
   ninth minigame cannot silently reintroduce this bug. Task 6's
   `test_every_minigame_can_be_rated` should mean it never fires. Keeping both is
   belt-and-braces; say so if you would rather the test alone carry it.
3. **Confetti threshold.** Three stars only. Firing at two would make it common and
   therefore meaningless — but it is one const if you want it looser.
4. **`best_combo` in the rubric.** `LombaMenari` will track it from Task 15 but not use
   it. Folding it into `get_star_ratio()` is a balance decision that wants real
   playtest numbers, so this plan deliberately leaves it out.
