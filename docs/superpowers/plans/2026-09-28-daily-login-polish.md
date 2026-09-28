# Daily Login Polish — Implementation Plan

Date: 2026-09-28
Branch: `daily-login-polish` (off `Textures`)
Spec: `docs/superpowers/specs/2026-09-28-daily-login-polish-design.md`
Status: **Handoff — not built.** Execute tasks in order; each ends green and
is its own commit.

## Revision (2026-09-28): clean-code pass

Checked against `docs/superpowers/design/clean-code.md` and the code on
`daily-login-polish` (current `Textures` merged in). What changed:

- **Lobby.gd cannot take this feature.** It sits in `LARGE_SCRIPTS` at exactly
  its 1073-line cap, so a single new line fails the ratchet. The daily-login
  code moves out into a new component, `DailyLoginPanel`
  (`Scripts/Lobby/DailyLoginPanel.gd`, `@tool`, `class_name`), attached to the
  existing `DailyReward` node. That is Task 1, a pure refactor that shrinks
  Lobby.gd by about 80 lines. Every later task writes into the component or
  into a second new component, `DailyRewardReveal`, and never into Lobby.gd.
- Added **Global Constraints** with a **Clean code** block, and tagged every
  step **[editor]** or **[code]**. Scene work comes before script work in
  every task.
- The phases are now Tasks 1–8. The old Phases 1–6 are Tasks 2–7, and the old
  Phase 7 is Task 8.
- Every snippet is typed and has no bare numbers. The spec's values are kept:
  `REWARD_CURVE = [80, 120, 160, 200, 240, 300, 400]` (sum 1500), ~14 coins,
  ~6 stars.
- Every task now carries a test step with the real suite names, plus
  `test_run(suite="clean_code")`.
- Where the old plan disagreed with the code, it was corrected:
  1. `test_run(suite="test_lobby")` → `suite="lobby"`. The runner takes
     `suite_name()`, not the file name. The other suites named here are
     `lobby_layout`, `tall_screen_layout`, `audio_coverage`,
     `viewport_editability`, `script_documentation`, `theme_factory`,
     `theme_rebake` and `clean_code`.
  2. `Juice.count_up` returns `void`. Use `count_up_formatted` wherever a
     tween or delay is needed.
  3. **`AnimUtils.create_floating_text` is banned here.** It builds a Label
     at runtime with five `add_theme_*_override` calls, which breaks both
     visual rules. The "+NG" is the existing `RewardAmount` node.
  4. **`AnimUtils.wobble` cannot loop.** It snaps the node to scale 0.7 on
     every call. The idle invite loops `AnimUtils.squash_bounce` instead.
  5. `ConfettiFireworks` has no `play()`. Its API is `burst_count()`,
     `fire_burst(i)` and `burst_delay`, and SchoolDay's
     `_celebrate_day_end` shows the volley pattern.
  6. Old Phase 3 put `ButtonClaim` in an HBox. That conflicts with the code:
     the button is a `GhostButton` over the gold pill baked into the art, and
     three `lobby` tests pin its centred, lower-third, clamped-height rect.
     Only `RewardCoin` + `RewardAmount` go in the container now.
  7. The spec says "strictly non-decreasing", which is self-contradictory.
     The curve is strictly increasing, and the test asserts that.
  8. The spec writes "+Xg" but the game's currency suffix is `G` (`"%dG"` in
     `_update_money_display`). The plan uses `G`.
  9. `test_audio_coverage.gd`'s `_DOUBLE_FIRE_ALLOWLIST` has the key
     `Lobby.gd:_on_claim_pressed`. That function leaves Lobby, so Task 1
     deletes the stale key.
  10. `GameSettings.reduce_motion` exists (SchoolDay honours it). The idle
      invite, flicker, burst and shine now honour it too.
  11. `DEBT.md` lists `daily_claim` under "Unused pack cues". Task 8 removes
      it once Task 3 wires the cue.
- Old line anchors re-verified: all correct (L92, L104, L721, L745, L766,
  L828; `Lobby.tscn` L1058; `AudioDirector.gd` L137-138, L379).

## Global Constraints

**House rules (CLAUDE.md).**
- No `theme_override_*`; use a `ThemeFactory` variation. The only exception
  is layout constants (`separation`, `margin_*`).
- No visual is built at runtime. Static chrome is a node in a `.tscn`, and a
  repeated sprite is a `PackedScene` template, instanced. Never call
  `Label.new()` / `TextureRect.new()`: `viewport_editability` counts them.
- Every script needs a `##` file header and a `##` line on every `@export`
  (`script_documentation`).
- UI text is Indonesian. No emoji as icons; icons are transparent SVG/PNG.
- `Balance.gd` is read-only. The daily-login numbers are ours and stay out
  of it.
- No new persistence. `daily_login_day` / `last_claim_date` stay
  session-scoped.
- Suites are `@tool`, and no test may `await`. A `@tool` script that the
  runner instances gates its real side effects behind
  `if Engine.is_editor_hint(): return`. For this feature that is doubly
  important: a `@tool` node that moves or recolours itself in the editor gets
  that state baked into `Lobby.tscn` on the next save.
- The strip art `day1..7.png` is fixed. Every new visual layers on top of it.

**Editor discipline.**
- **[editor]** steps need the live editor through the godot-ai bridge
  (`scene_open`, `node_*`, `batch_execute`, `script_attach`, `scene_save`,
  `test_run`, screenshots, rebake). Only the controller does these.
- **[code]** steps are plain file edits a subagent can do. Subagents never
  touch the bridge.
- In each task, do scene work first and script work second. After every
  `scene_save`, run `git diff HEAD -- '*.gd'` and revert stray tab flushes.
- If any `.gd` was patched since the editor last started, restart the editor
  before that task's first `scene_save`.
- After a [code] edit, run a no-op `script_patch` on each touched `.gd`
  before `test_run`, or the editor serves the stale script.
- After creating or editing a `class_name` script: `project_manage(op="stop")`,
  then `filesystem_manage(op="scan")`, before any `project_run`.
- Never hand-edit `Lobby.tscn` while the editor is attached.
- **Reparenting:** `move_node` only reorders siblings. To move a node under a
  new parent, use `node_manage`'s reparent op if it has one. Otherwise
  recreate the node under the new parent with the same properties and delete
  the original. The `%` refs survive either way.
- **Instance overrides:** they serialise only on an instanced scene's ROOT.
  Every knob Lobby needs on `DailyRewardReveal` is an `@export` on its root.
  Never set properties on its children through the instance.

**Clean code** (`docs/superpowers/design/clean-code.md`; ⚙ = ratchet):
- **Type everything ⚙.** This covers every `var` (`:=` only when the right
  side is obvious), every parameter, and every `-> ReturnType`, including
  `-> void`. Loop variables over mixed arrays are typed
  (`for node: CanvasItem in …`). New scripts start at zero debt, so any
  untyped declaration in them fails.
- **No magic numbers ⚙.** Inline, only `0`, `1`, `2`, `-1` and `0.5` are
  allowed. Anything else goes by what it is:
  - Logic → a named const block at the top of the owning script, with a
    `##` line (`STREAK_DAYS`, `SECONDS_PER_DAY`, `REWARD_CURVE`).
  - Designer-tuned (timings, counts, scales, tints) → an `@export` with a
    `##` line.
  - Layout (positions, sizes, separations, burst placement) → the `.tscn`.
  - Colours come from `DesignTokens` (`Juice.tokens().currency_gold`),
    never `Color(...)`.
- **Functions ≤ 50 code lines ⚙, with one job.** Engine callbacks read like
  a table of contents. The reveal is a sequence of small named steps, never
  one long tween builder.
- **Flat code.** Guard clauses and early `return`. A repeated awaiting step
  is a loop, never recursion.
- **No duplicated 5+-line bodies ⚙.** Reuse `AnimUtils` / `Juice` /
  `RewardFeedback`. Never copy Lobby's `_animate_button_click_bounce` or
  `_setup_button_juice` into the new component.
- **Signals up, calls down.** The panel never touches Lobby's `money_label`,
  `blur_overlay` or `reward_popup_open`. It announces `claimed(amount,
  previous_money)`, and Lobby calls `open()` / `close()` / `refresh()` down.
  The reveal announces `burst_started` / `coin_landed`, and the panel calls
  `play()` / `skip()` down.
- **Node refs** are `@onready var x: Type = %UniqueName`. Every node a
  script touches gets `unique_name_in_owner`. New names are prefixed
  (`DailyGreeting`, `StreakLabel`, …) because the panel shares Lobby's
  unique-name namespace.
- **Fail loudly.** A missing required node is a typed `@onready` failing at
  once, or a `push_error`, never a silent `if node:` skip. Task 1 removes the
  old `if daily_reward:` / `if claim_button and …` guards.
- **No commented-out code, and Boy Scout.** A Lobby function you touch ends
  typed and with its bare numbers named (`_setup_daily_login`,
  `_show_daily_reward`, `_hide_daily_reward`).
- **Ratchet stays green.** Every [code] task ends with [editor]
  `test_run(suite="clean_code")`. If it reports **shrank**, run in the same
  commit:
  `"C:/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://ci/clean_code_dump.gd`
  `git diff ci/clean_code_baseline.gd` must only lower or remove entries.
  Then run a no-op `script_patch` of the baseline so the editor re-reads it.
  If the dump prints `RAISED (review):`, that is new debt. Fix the code; a
  re-key never hides it.

## Orientation (do this first)

- Read the spec's **Constraints** and **Existing helpers**, and this plan's
  revision note. Several helpers the spec lists are corrected above.
- Open `Scenes/MainMenu/MainMenu.tscn` before trusting any test result.
- Key anchors (verified on `daily-login-polish` @ `feb87314`):
  - `Scripts/Lobby/Lobby.gd` (1073 lines = its `LARGE_SCRIPTS` cap):
    - Header ## L8-9.
    - Untyped `@onready` `daily_reward` / `claim_button` / `reward_coin` /
      `reward_amount` at L71-74.
    - `DAILY_REWARD := 10` L92, `CLAIMED_CUE_DIM_ALPHA` L99, `DAY_PANELS`
      L104-112.
    - `_create_blur_overlay` L662 (keeps `move_child(blur_overlay,
      daily_reward.get_index())`).
    - `_setup_daily_login` L684, `_update_money_display` L702 (stays),
      `_check_daily_login_reset` L711, `_update_daily_login_visual` L721.
    - `_on_daily_login_pressed` L740, `_show_daily_reward` L745,
      `_hide_daily_reward` L766, `_on_blur_overlay_input` L777.
    - `_animate_button_click_bounce` L818 (stays; the other nav buttons use
      it), `_on_claim_pressed` L828, `_chatter_allowed` L901 (stays; pinned
      by `student_chatter`).
    - The claim button is in `_ready`'s juice loop at L189.
  - Baseline for Lobby.gd:
    - `LARGE_SCRIPTS` 1073.
    - `UNTYPED` 128.
    - `BARE_NUMBERS` 58.
    - `LONG_FUNCTIONS` `_ready` 95 and `_show_step` 56. Neither is touched
      except for one token on L189.
    - Six `DUPLICATE_GROUPS`, none of them daily-login functions.
  - `Scenes/Lobby/Lobby.tscn`: `DailyReward` (TextureRect, L1058) with
    children `Label` (H1Label "Daily Login"), `ButtonClaim` (GhostButton),
    `RewardCoin`, `RewardAmount` (CoinLabel, static "10G"). None of them has
    a unique name today.
  - `Scripts/Audio/AudioDirector.gd`: `&"daily_claim"` registered (L137-138,
    L379), **never played**.
  - `Scripts/Feedback/RewardFeedback.gd` (autoload):
    `play(moment, anchor, opts)`; `coins_earned` is Pop tier.
  - Helpers:
    - `AnimUtils.squash_bounce(node, tilt)`, `spring_pop_in(node,
      from_scale)`, `popup_spring_in(node)` (all `_safe_tween`: a new call
      kills the node's previous one).
    - `Juice.pop_in(node, delay) -> Tween`, `count_up(label, from, to, fmt)
      -> void`, `count_up_formatted(label, from, to, formatter, delay,
      duration) -> Tween`, `set_pivot_center(node)`.
    - `Scenes/Minigames/UI/ConfettiFireworks.tscn` (`@tool`, three authored
      GPUParticles2D bursts).
    - Particle art in `Assets/Images/Particles/` (`particle_coin.png`,
      `particle_star.png`, `particle_glow.png`).
  - Tests that touch this code today:
    - `tests/test_lobby.gd` (suite `lobby`): `test_daily_login_uses_pop_in`,
      `test_the_panel_swaps_art_per_day`, the claim-button geometry tests,
      and touch targets on `DailyReward/ButtonClaim`.
    - `tests/test_tall_screen_layout.gd`: the `DailyReward` rect at both
      aspects.
    - `tests/test_audio_coverage.gd`: popup_open, the RewardFeedback
      flagship and the double-fire allowlist.
    - `tests/test_student_chatter.gd`: the `_chatter_allowed` expression.

---

## Task 1 — Extract `DailyLoginPanel` (pure refactor, Lobby.gd shrinks)

No behaviour change. The flat 10G reward stays until Task 2. This task makes
room: after it, Lobby.gd is ~990 lines and every later task writes into the
component.

**Why a script on the existing node, not a new sub-scene.** "Save Branch as
Scene" would move `DailyReward` and its children into
`DailyLoginPanel.tscn`. The script-on-node choice is safer for five reasons:

- **Nothing moves.** Every path the suites pin keeps resolving:
  `DailyReward/ButtonClaim`, `DailyReward/Label`, the `DailyReward` rects in
  `tall_screen_layout`, and the touch-target list.
- **No reference churn.** No ext_resource/UID churn in `Lobby.tscn`, where a
  stale UID has bitten before.
- **No override trap.** Instance-override serialisation only works on an
  instance's root. The Tasks 4–7 children would otherwise all be authored
  inside the sub-scene, and a mistake silently drops properties on save.
- **No reuse to gain.** `DailyReward` appears in exactly one scene.
- **Same clean-code win.** The ratchet measures scripts. Moving the script
  gives the whole Lobby.gd reduction; moving the nodes adds no ratchet gain.

A later pass can still save the branch as a scene. The new reveal
(Task 6) *is* its own `PackedScene`, because it is new.

**Component interface** (`Scripts/Lobby/DailyLoginPanel.gd`,
`@tool class_name DailyLoginPanel extends TextureRect`):

| Member | Kind | Job |
|---|---|---|
| `claimed(amount: int, previous_money: int)` | signal (up) | A claim paid out. Lobby rolls the wallet and fires RewardFeedback. |
| `claim_button: Button` | `@onready %ButtonClaim` | Public only so Lobby's hover-juice loop can include it (calls down). |
| `refresh(today: String) -> void` | call (down) | Resets a broken streak and redraws the strip for `today`. |
| `open() -> void` / `close() -> void` | call (down) | The panel's own pop-in / fade-out. Lobby keeps the blur and `reward_popup_open`. |
| `claim(today: String) -> int` | method | Writes money, date and the advanced day to GameState. Returns the amount, or 0 if `today` was already claimed. Touches no node, so tests can call it on a bare `DailyLoginPanel.new()`. |
| `day_after(day: int) -> int` | static | 7 wraps to 1. |
| `is_streak_broken(last_claim_date: String, today: String) -> bool` | static | More than one day since the last claim. |

What moves out of Lobby.gd, and what stays:

| From Lobby.gd | Goes to |
|---|---|
| The four untyped `@onready` (L71-74) | Replaced by one line: `@onready var daily_reward: DailyLoginPanel = %DailyReward`. The panel holds `claim_button` / `reward_coin` / `reward_amount`, typed, via `%`. |
| `DAILY_REWARD`, `CLAIMED_CUE_DIM_ALPHA`, `DAY_PANELS` (+ their `##`) | Panel const block. |
| `_check_daily_login_reset` | Panel `refresh()` + static `is_streak_broken()` (`86400` → `SECONDS_PER_DAY`). |
| `_update_daily_login_visual` | Panel `_show_day(day, is_claimed)`. |
| `_on_claim_pressed` | Panel `_on_claim_pressed` + `claim()`. `_animate_button_click_bounce(claim_button)` becomes `AnimUtils.squash_bounce(claim_button)`. A copy would be a duplicate body; the feel changes slightly. |
| Panel pop-in/fade-out halves of `_show_daily_reward` / `_hide_daily_reward` | Panel `open()` / `close()`. |
| **Stays in Lobby:** `_update_money_display`, `_on_daily_login_pressed`, the blur halves of `_show/_hide_daily_reward`, `_on_blur_overlay_input`, `_set_blur_*`, `_create_blur_overlay`, `reward_popup_open`, `_chatter_allowed`, the `popup_open`/`popup_close` sfx, and `RewardFeedback.play(&"coins_earned", money_label)`. The last one moves into a new three-line `_on_daily_reward_claimed`. |

**Expected baseline effect** (the dump prints the exact numbers):

| Entry | Before | After (approx.) |
|---|---|---|
| `LARGE_SCRIPTS` Lobby.gd | 1073 | ~990. At or under 1,000, the entry is **removed**, and Lobby.gd must never cross 1,000 again. |
| `UNTYPED` Lobby.gd | 128 | ~111 (−4 onready, −4 reset func+vars, −2 claim func+var, −1 `_setup_daily_login`, −3 `_show_daily_reward`, −2 `_hide_daily_reward`, +0 new typed handler) |
| `BARE_NUMBERS` Lobby.gd | 58 | ~44 (−1 `86400`, −1 `7`, −12 blur/close literals now named) |
| `LONG_FUNCTIONS` `_ready` / `_show_step` | 95 / 56 | unchanged (L189 swaps one token) |
| `DUPLICATE_GROUPS` | — | unchanged |

No function that carries a baseline key moves: the moved functions have no
per-function entries, and the new file starts at zero. So **no `--rekey`**.
Run the default dump. Its diff must be the Lobby.gd lines lowering or
disappearing, and nothing else. If it prints `RAISED` for `DailyLoginPanel.gd`,
the new script has debt; fix it.

Steps:

1. **[code]** Write `Scripts/Lobby/DailyLoginPanel.gd`. It is a new file and
   no editor tab holds it, so writing it before scene work is safe.
   ```gdscript
   @tool
   class_name DailyLoginPanel
   extends TextureRect

   ## The Lobby's daily-login popup: the seven-day calendar strip, its claim
   ## button and the reward it pays. Owns the streak rules (a missed day
   ## resets to day 1; a claim advances the day, wrapping 7 to 1) and writes
   ## GameState.player_money, daily_login_day and last_claim_date. It never
   ## reaches up: it announces a payout with `claimed`, and the Lobby rolls
   ## its wallet and fires RewardFeedback. The Lobby owns the backdrop blur
   ## and calls open() / close() / refresh() down.
   ##
   ## @tool so the editor's test runner can call claim() and the static
   ## rules. Every runtime side effect is gated behind
   ## Engine.is_editor_hint(): a @tool node that swaps its own texture or
   ## modulate in the editor gets that baked into Lobby.tscn on save.

   ## A claim paid out. `previous_money` is the balance before it, so the
   ## Lobby can roll its money display up from there.
   signal claimed(amount: int, previous_money: int)

   ## Coins paid per claim. Task 2 replaces this with REWARD_CURVE.
   const DAILY_REWARD := 10
   ## Days in one streak cycle; the day after the last wraps to day 1.
   const STREAK_DAYS := 7
   ## A gap longer than this since the last claim breaks the streak.
   const SECONDS_PER_DAY := 86400
   ## Turns a "YYYY-MM-DD" date into a datetime string Time can parse.
   const MIDNIGHT_SUFFIX := " 00:00:00"
   ## (CLAIMED_CUE_DIM_ALPHA: moved verbatim from Lobby.gd with its ## block.)
   ## (DAY_PANELS: moved verbatim from Lobby.gd with its ## block.)
   ## The popup's close: how long it fades and shrinks, and to what scale.
   const CLOSE_SECONDS := 0.15
   const CLOSE_SCALE := Vector2(0.8, 0.8)

   @onready var claim_button: Button = %ButtonClaim
   @onready var reward_coin: TextureRect = %RewardCoin
   @onready var reward_amount: Label = %RewardAmount


   func _ready() -> void:
   	if Engine.is_editor_hint():
   		return
   	claim_button.pressed.connect(_on_claim_pressed)


   ## Resets a broken streak and redraws the strip for `today` (YYYY-MM-DD).
   func refresh(today: String) -> void:
   	if is_streak_broken(GameState.last_claim_date, today):
   		GameState.daily_login_day = 1
   	_show_day(GameState.daily_login_day, GameState.last_claim_date == today)


   func open() -> void:
   	visible = true
   	Juice.pop_in(self)


   func close() -> void:
   	var tween := create_tween().set_parallel(true)
   	tween.tween_property(self, "modulate:a", 0.0, CLOSE_SECONDS).set_ease(Tween.EASE_IN)
   	tween.tween_property(self, "scale", CLOSE_SCALE, CLOSE_SECONDS).set_ease(Tween.EASE_IN)
   	tween.chain().tween_callback(hide)


   ## Pays today's reward into GameState and advances the streak. Returns
   ## the amount paid, or 0 when `today` was already claimed.
   func claim(today: String) -> int:
   	if GameState.last_claim_date == today:
   		return 0
   	var amount := DAILY_REWARD
   	GameState.player_money += amount
   	GameState.last_claim_date = today
   	GameState.daily_login_day = day_after(GameState.daily_login_day)
   	return amount


   static func day_after(day: int) -> int:
   	return day % STREAK_DAYS + 1


   static func is_streak_broken(last_claim_date: String, today: String) -> bool:
   	if last_claim_date == "" or last_claim_date == today:
   		return false
   	var today_unix := Time.get_unix_time_from_datetime_string(today + MIDNIGHT_SUFFIX)
   	var last_unix := Time.get_unix_time_from_datetime_string(last_claim_date + MIDNIGHT_SUFFIX)
   	return today_unix - last_unix > SECONDS_PER_DAY


   func _on_claim_pressed() -> void:
   	AnimUtils.squash_bounce(claim_button)
   	var today := Time.get_date_string_from_system()
   	if GameState.last_claim_date == today:
   		AudioDirector.play_sfx(&"error")
   		return
   	var claimed_day := GameState.daily_login_day
   	var previous_money := GameState.player_money
   	var amount := claim(today)
   	_show_day(claimed_day, true)
   	Juice.pop_in(self)
   	claimed.emit(amount, previous_money)


   func _show_day(day: int, is_claimed: bool) -> void:
   	texture = DAY_PANELS[clampi(day, 1, STREAK_DAYS) - 1]
   	claim_button.disabled = is_claimed
   	# (the "no separate claimed frame" comment moves with this)
   	var cue_alpha := CLAIMED_CUE_DIM_ALPHA if is_claimed else 1.0
   	for node: CanvasItem in [claim_button, reward_coin, reward_amount]:
   		node.modulate.a = cue_alpha
   ```
   The visual order is unchanged: the strip shows the *claimed* day, and the
   stored day has already advanced. That matches today's `_update_daily_login_visual`
   running before the old `+= 1`.
2. **[editor]** Scene work. Restart the editor first if any `.gd` was patched
   since launch. Then `filesystem_manage(op="scan")`, and
   `scene_open("res://Scenes/Lobby/Lobby.tscn")`.
   - Set `unique_name_in_owner = true` on `DailyReward`,
     `DailyReward/ButtonClaim`, `DailyReward/RewardCoin` and
     `DailyReward/RewardAmount`. Do this **before** attaching the script, or
     its `@onready %` lookups error in the editor log.
   - `script_attach` `res://Scripts/Lobby/DailyLoginPanel.gd` to
     `DailyReward`, then `scene_save`.
   - Diff `Lobby.tscn`. Expect only the four `unique_name_in_owner` lines, one
     script ext_resource and the `script =` line. Anything else, such as
     `texture` or `modulate`, means an ungated `@tool` side effect; fix it and
     re-save.
   - Run `git diff HEAD -- '*.gd'`. It must be empty.
3. **[code]** Patch `Scripts/Lobby/Lobby.gd`. Normalise to LF first.
   - Header L8-9: the daily-login writes now belong to `DailyLoginPanel`.
     Keep the same line count.
   - L71-74 → `@onready var daily_reward: DailyLoginPanel = %DailyReward`.
   - Delete `DAILY_REWARD`, `CLAIMED_CUE_DIM_ALPHA` and `DAY_PANELS`, with
     their comments. In their place:
     ```gdscript
     ## The daily-reward popup's backdrop blur: shader lod and darkness at
     ## full strength, and how long it takes to come in and to go out.
     const BLUR_LOD := 3.0
     const BLUR_DARKNESS := 0.3
     const BLUR_IN_SECONDS := 0.25
     const BLUR_OUT_SECONDS := 0.15
     ```
   - L189 juice loop: `claim_button` → `daily_reward.claim_button`.
   - Replace `_setup_daily_login`, and delete `_check_daily_login_reset`,
     `_update_daily_login_visual` and `_on_claim_pressed`:
     ```gdscript
     func _setup_daily_login() -> void:
     	_update_money_display()
     	daily_reward.refresh(Time.get_date_string_from_system())
     	if not daily_reward.claimed.is_connected(_on_daily_reward_claimed):
     		daily_reward.claimed.connect(_on_daily_reward_claimed)
     	if not daily_login_btn.pressed.is_connected(_on_daily_login_pressed):
     		daily_login_btn.pressed.connect(_on_daily_login_pressed)

     ## The panel paid out: roll the wallet up from the old balance.
     func _on_daily_reward_claimed(_amount: int, previous_money: int) -> void:
     	_update_money_display(previous_money)
     	RewardFeedback.play(&"coins_earned", money_label)
     ```
   - `_show_daily_reward` / `_hide_daily_reward` become typed and keep only
     the blur. Use named consts, `var tween := …`, no `if not daily_reward`
     guard, and `daily_reward.open()` / `daily_reward.close()` in place of
     the pop and fade:
     ```gdscript
     func _show_daily_reward() -> void:
     	AudioDirector.play_sfx(&"popup_open")
     	reward_popup_open = true
     	blur_overlay.visible = true
     	_set_blur_lod(0.0)
     	_set_blur_darkness(0.0)
     	daily_reward.open()
     	var tween := create_tween().set_parallel(true)
     	tween.tween_method(_set_blur_lod, 0.0, BLUR_LOD, BLUR_IN_SECONDS).set_ease(Tween.EASE_OUT)
     	tween.tween_method(_set_blur_darkness, 0.0, BLUR_DARKNESS, BLUR_IN_SECONDS).set_ease(Tween.EASE_OUT)

     func _hide_daily_reward() -> void:
     	reward_popup_open = false
     	daily_reward.close()
     	var tween := create_tween().set_parallel(true)
     	tween.tween_method(_set_blur_lod, BLUR_LOD, 0.0, BLUR_OUT_SECONDS).set_ease(Tween.EASE_IN)
     	tween.tween_method(_set_blur_darkness, BLUR_DARKNESS, 0.0, BLUR_OUT_SECONDS).set_ease(Tween.EASE_IN)
     	tween.chain().tween_callback(func() -> void: blur_overlay.visible = false)
     ```
   - Confirm `wc -l Scripts/Lobby/Lobby.gd` is ≤ 1073, with ~990 expected.
4. **[code]** Retarget the tests that pinned the moved code.
   - `tests/test_lobby.gd`:
     - `test_daily_login_uses_pop_in`: `Juice.pop_in(` is now scanned in
       `res://Scripts/Lobby/DailyLoginPanel.gd`. The `RewardFeedback.play(&"coins_earned"`
       scan stays on Lobby.gd.
     - `test_the_panel_swaps_art_per_day`: scan `DAY_PANELS` and
       `DailyLogin/day%d.png` in `DailyLoginPanel.gd`. `day_nodes` must be
       absent from both scripts.
     - Add `test_daily_reward_is_a_daily_login_panel`:
       `_lobby.get_node("DailyReward") is DailyLoginPanel`. Also scan that
       Lobby.gd no longer contains `daily_login_day` or `last_claim_date`,
       and does contain `claimed.connect(_on_daily_reward_claimed)`.
   - `tests/test_audio_coverage.gd`: delete the stale
     `"res://Scripts/Lobby/Lobby.gd:_on_claim_pressed"` allowlist entry and
     its comment. Lobby's new handler has a single cue, and the panel's
     `error` path ends in a guard `return`, which the scanner already
     excludes.
   - New `tests/test_daily_login_panel.gd` (`@tool`, `extends McpTestSuite`,
     `suite_name()` → `"daily_login_panel"`, `##` header):
     - `suite_setup` makes one `DailyLoginPanel.new()` (not in the tree, so
       `@onready` never runs) and `suite_teardown` frees it.
     - `setup` / `teardown` snapshot and restore `GameState.player_money`,
       `daily_login_day` and `last_claim_date`.
     - Tests:
       - `test_day_after_wraps`: 1→2 … 6→7, 7→1.
       - `test_streak_breaks_only_after_a_missed_day`: `("2026-09-26",
         "2026-09-28")` → true; `("2026-09-27", "2026-09-28")`, `("",
         "2026-09-28")` and same-day → false.
       - `test_claim_pays_and_advances`: day 3, yesterday → returns 10,
         money +10, day 4, date = today.
       - `test_second_claim_same_day_is_a_no_op`: returns 0 and nothing
         changes.
       - `test_day_panels_cover_the_streak`: `DAY_PANELS.size() ==
         STREAK_DAYS`.
       - `test_lobby_no_longer_owns_the_claim`: a source scan.
     - No test awaits.
5. **[editor]** Run a no-op `script_patch` on `Lobby.gd`,
   `DailyLoginPanel.gd`, `test_lobby.gd`, `test_audio_coverage.gd` and
   `test_daily_login_panel.gd`. Then run:
   - `test_run(suite="daily_login_panel")`, `"lobby"`, `"audio_coverage"`
   - `"student_chatter"`, `"tall_screen_layout"`, `"lobby_layout"`
   - `"viewport_editability"`, `"script_documentation"`
   - `"clean_code"`. It reports **shrank** for Lobby.gd.
6. **[code]** Run the dump (default mode, no `--rekey`). The
   `git diff ci/clean_code_baseline.gd` may only lower Lobby.gd's `UNTYPED`,
   `BARE_NUMBERS` and `LARGE_SCRIPTS`, or remove the `LARGE_SCRIPTS` entry.
   **[editor]** Run a no-op `script_patch` of the baseline, then
   `test_run(suite="clean_code")` green.
7. **[editor]** Smoke test: `project_stop`, scan, `project_run`, Debug ⚡ Seed
   Playtest State, teleport to Lobby. Open the reward, claim, and close it.
   The wallet must roll +10, the strip must dim and the blur must fade.
   Claiming twice must play `error`.

Commit: `refactor(lobby): extract the daily-login popup into DailyLoginPanel`.

## Task 2 — Escalating reward curve (old Phase 1)

Logic only, highest value. Ship it even if later tasks slip.

1. **[editor]** In `Lobby.tscn`, set `%RewardAmount.text` to `"80G"` (day 1)
   so the editor preview is honest. It is overwritten at runtime. Then
   `scene_save` and diff.
2. **[code]** Test first, in `tests/test_daily_login_panel.gd`:
   - `test_reward_curve_shape`: `REWARD_CURVE.size() == STREAK_DAYS`, each
     entry `>` the previous, the max at index `STREAK_DAYS - 1`, and the sum
     1500. The literal 1500 is fine in a test, since `tests/` is exempt, but
     name it `WEEKLY_TOTAL` for readability.
   - `test_claim_pays_the_days_reward`: for each day 1..7 (last claim
     yesterday), `claim(today) == REWARD_CURVE[day - 1]`, money rises by
     that much, and the day becomes `day_after(day)`. The day-7 case asserts
     the wrap to 1.
   - `test_reward_for_day_clamps`: 0 → day 1's reward; 8 → day 7's.
3. **[code]** In `DailyLoginPanel.gd`, replace `DAILY_REWARD` (no deprecation
   comment; git remembers):
   ```gdscript
   ## Daily-login reward per streak day (index 0 = day 1). A full 7-day
   ## streak totals 1500G, the priciest Koperasi item; day 7 is the "peti
   ## besar" payoff. Our own tunable (daily-login is not a Balance.gd value).
   const REWARD_CURVE: Array[int] = [80, 120, 160, 200, 240, 300, 400]
   ## How the reward amount reads on the panel.
   const AMOUNT_FORMAT := "%dG"

   static func reward_for_day(day: int) -> int:
   	return REWARD_CURVE[clampi(day, 1, STREAK_DAYS) - 1]
   ```
   - `claim()` uses `var amount := reward_for_day(GameState.daily_login_day)`.
   - `_show_day` adds `reward_amount.text = AMOUNT_FORMAT % reward_for_day(day)`.
   - Add `assert(REWARD_CURVE.size() == STREAK_DAYS)` in `_ready`, before the
     editor gate.
4. **[editor]** Run a no-op `script_patch` on each touched `.gd`. Then
   `test_run(suite="daily_login_panel")`, `"lobby"` and `"clean_code"`. The
   last must be green with no dump, since only the new file changed.

Commit: `feat(lobby): escalating daily-login reward curve (80→400G, 1500G/week)`.

## Task 3 — Wire the dead claim SFX + count-up (old Phase 2)

1. **[code]** Tests:
   - In `test_daily_login_panel.gd`, `test_claim_plays_the_daily_claim_cue`
     checks that `DailyLoginPanel.gd` contains
     `AudioDirector.play_sfx(&"daily_claim")`. It is a regression guard; the
     cue was dead.
   - In the same suite, `test_claim_counts_the_amount_up` checks that it
     contains `Juice.count_up(reward_amount`.
2. **[code]** In the panel's `_on_claim_pressed`, after the guard, add
   `AudioDirector.play_sfx(&"daily_claim")`. Replace the flat text with
   `Juice.count_up(reward_amount, 0.0, float(amount), AMOUNT_FORMAT)`. Keep
   the function under 50 lines, with one job per call.
   - Lobby's `RewardFeedback.play(&"coins_earned", money_label)` stays as it
     is.
   - The three cues (daily_claim, the Lobby's coin, and RewardFeedback's
     arpeggio) coincide until Task 6 moves the Lobby's part to the coin
     landing. Listen once.
3. **[editor]** Run a no-op `script_patch`, then
   `test_run(suite="daily_login_panel")`, `"audio_coverage"` and
   `"clean_code"`.
   - The double-fire scanner sees `error` → guard `return` → `daily_claim`.
     The return excludes the pair, so no allowlist entry is needed. If it
     does flag, re-read the function, since a stray local call that plays a
     cue may have crept in.
   - Manually: seed, open the Lobby, claim, and hear the cue.

Commit: `feat(lobby): play the daily_claim cue and count the reward up`.

## Task 4 — Layout fix (font clipping) (old Phase 3)

Scene only. `ButtonClaim` stays where it is: it is a `GhostButton` over the
gold pill baked into the art, and `lobby` pins it centred, in the lower third
and inside the panel.

1. **[editor]** Take a full-size screenshot of the open panel with
   `RewardAmount.text = "400G"` to see what actually clips. The authored rects
   do not overlap (button 330–612, coin 640–700, amount 708–828, panel 942
   wide). The likely culprit is the 120px amount box at `CoinLabel`'s
   `font_title` size. If it is something else, stop and report
   (question Q1).
2. **[editor]** Under `DailyReward`, create `RewardRow` (HBoxContainer,
   unique) where the coin and amount sit today. Move `RewardCoin` and
   `RewardAmount` into it, following the Global Constraints reparent note.
   - Size it so "400G" fits inside the art's frame: `RewardCoin` keeps its
     60×48 min size, and `RewardAmount` gets `size_flags_horizontal` =
     shrink-begin.
   - The row's `separation` is the one allowed constant override.
   - `scene_save`, then diff `Lobby.tscn`. No `theme_override_*` other than
     `separation`.
3. **[code]** In `tests/test_lobby.gd`, add `test_the_peak_reward_fits_its_row`
   (behavioural; setup already assigns the baked theme):
   - Set `%RewardAmount.text = "400G"`.
   - Assert that `%RewardRow` is an `HBoxContainer` parenting both nodes.
   - Assert that the row's `get_combined_minimum_size().x` plus its
     `offset_left` is ≤ the panel's `size.x`.
4. **[editor]** Run `test_run(suite="lobby")`, `"tall_screen_layout"`,
   `"lobby_layout"`, `"viewport_editability"` and `"clean_code"`. Take a
   full-size screenshot at 1080×1920 and at 1080×2400. The amount must not
   clip at either.

Commit: `fix(lobby): give the daily reward amount its own row so 400G fits`.

**Update (fix pass):** the greeting and `StreakLabel` moved from `H2Label` to
`ResultHeroLabel` in the same fix pass as Task 7's teaser, below — dark text
over the Lobby's blurred backdrop was unreadable, and `ResultHeroLabel` is a
gold display face with a dark outline instead.

## Task 5 — Welcome-back header + streak (old Phase 4)

Needs a flame icon. None exists in the repo, so a placeholder SVG is written
here and logged in DEBT.

1. **[code]** Create the asset
   `Assets/Images/UI/DailyLogin/streak_flame.svg`: a transparent,
   paths-only flame (no `<text>`, which ThorVG drops), about 64×64,
   drop-replaceable at the same path.
2. **[editor]** Scene work in `Lobby.tscn`. Restart the editor first if a
   `.gd` was patched since launch.
   - Under `DailyReward`, positioned **above the panel's top edge** so the
     strip art stays untouched (placement: question Q2):
     - `DailyGreeting`: Label, `H2Label`, text "Selamat datang kembali!".
     - `DailyStreak`: HBoxContainer holding `StreakFlame` (TextureRect,
       `streak_flame.svg`, keep-aspect) and `StreakLabel` (Label,
       `H2Label`).
   - All four get unique names and `mouse_filter = IGNORE`.
   - Wire the panel's exports in the Inspector (see step 4) only after the
     script has them. Wiring happens in Task 6's scene step, or restart
     first.
   - If no existing variation reads well over the blur, add one to
     `ThemeFactory.gd` in a separate sub-step:
     - Restart the editor, then run `test_run(suite="theme_rebake")` alone.
     - Restart again.
     - If the variation is on Boohong, add it to `DISPLAY_ROSTER` in
       `tests/test_theme_factory.gd`, and to that file's `expected` list.
     - Diff the bake before committing.
   - `scene_save` and diff.
3. **[code]** Tests:
   - In `test_lobby.gd`: `%DailyGreeting` has variation `H2Label` and its
     text; `%StreakLabel` and `%StreakFlame` exist, and the flame's texture
     path ends in `streak_flame.svg`.
   - In the same suite, a scan that `DailyLoginPanel.gd` contains
     `AnimUtils.popup_spring_in(`.
   - In `test_daily_login_panel.gd`: `flame_scale_for(1) ==
     flame_scale_min`, `flame_scale_for(STREAK_DAYS) == flame_scale_max`,
     and the values are non-decreasing in between. Call it on the bare
     instance; export initialisers run at construction.
4. **[code]** Add to `DailyLoginPanel.gd`:
   ```gdscript
   ## The streak line's text; %d is the day in the 7-day cycle.
   const STREAK_FORMAT := "Streak %d hari"

   @export_group("Streak")
   ## Flame scale on day 1 of the streak.
   @export var flame_scale_min: float = 0.8
   ## Flame scale on the last streak day.
   @export var flame_scale_max: float = 1.3
   ## Seconds for one idle flicker (dim and back).
   @export var flame_flicker_seconds: float = 0.6
   ## Flame alpha at the bottom of a flicker.
   @export var flame_flicker_alpha: float = 0.75

   @onready var greeting: Label = %DailyGreeting
   @onready var streak_row: HBoxContainer = %DailyStreak
   @onready var streak_label: Label = %StreakLabel
   @onready var streak_flame: TextureRect = %StreakFlame
   var _flicker: Tween
   ```
   - `func flame_scale_for(day: int) -> float` returns `lerpf(min, max,
     float(clampi(day, 1, STREAK_DAYS) - 1) / float(STREAK_DAYS - 1))`.
   - `func _show_streak(day: int) -> void` sets the label text,
     `Juice.set_pivot_center(streak_flame)` and the flame's scale. On the
     last day it sets the flame's modulate to `Juice.tokens().currency_gold`,
     and to `Color.WHITE` otherwise; no `Color(...)` literal.
   - `_show_day` calls `_show_streak(day)`.
   - `open()` adds `AnimUtils.popup_spring_in(greeting)`,
     `AnimUtils.popup_spring_in(streak_row)` and `_start_flicker()`.
     `close()` kills `_flicker`.
   - `_start_flicker()` returns early under `GameSettings.reduce_motion`.
     Otherwise it runs a looped tween on `streak_flame`'s
     `modulate:a`: `flame_flicker_alpha` then 1.0, half of
     `flame_flicker_seconds` each.
   - The streak shows `daily_login_day`, the position in the 7-day cycle,
     per the spec. It is not a lifetime count.
5. **[editor]** Run a no-op `script_patch`. Then
   `test_run(suite="lobby")`, `"daily_login_panel"`,
   `"script_documentation"`, `"tall_screen_layout"` and `"clean_code"`.
   Take a full-size screenshot of the open popup.

Commit: `feat(lobby): welcome-back greeting and a streak flame on the daily reward`.

## Task 6 — Prize-box reveal + burst (old Phase 5)

The biggest visual lift, as a **new component scene**. It ships on the gift
fallback (`use_chest_sprite = false`), so missing chest art never blocks the
task.

**Component:** `Scenes/Lobby/DailyRewardReveal.tscn` +
`Scripts/Lobby/DailyRewardReveal.gd`
(`@tool class_name DailyRewardReveal extends Control`). The root is
full-rect over the panel, and every node has `mouse_filter = IGNORE` so the
reveal never eats the claim tap.

| Node | Type | Role |
|---|---|---|
| `Shine` | TextureRect (`particle_glow.png`) | Slow spin behind the box during the burst. |
| `Box` | TextureRect | The gift fallback: an `AtlasTexture` sub-resource over `day1.png`'s slot-1 gift (region measured in the editor; this references the file, it does not re-slice it). With `use_chest_sprite`, it shows `chest_base_texture` instead. |
| `Lid` | TextureRect | `chest_lid_texture`. Hidden in the fallback. |
| `Fireworks` | instance of `ConfettiFireworks.tscn` | Burst volley. Only the instance root is positioned or scaled; never edit `Burst1-3` through the instance. |
| `Coins`, `Stars` | Control holders | Receive instances of the templates below. |
| `WalletCoin` | TextureRect (`particle_coin.png`), `top_level` | The one coin that arcs to the wallet. |

Templates: `Scenes/Lobby/RevealCoin.tscn` and `RevealStar.tscn`, each a
TextureRect with a particle texture. They are instanced per burst (per-call
dynamic count). `instantiate()` is not a `.new(` visual construction.

Interface: signals up `burst_started`, `coin_landed`; calls down
`show_ready()`, `play(is_peak: bool, wallet_position: Vector2)`, `skip()`.

1. **[editor]** Scene work. Restart first if a `.gd` changed since launch.
   - Build the two templates and `DailyRewardReveal.tscn` as above, with the
     script attached. The script comes from step 3, so write it first; it
     is a new file, which makes that safe.
   - Author every position, size and burst placement in the scene.
   - Instance the reveal under `DailyReward` in `Lobby.tscn` at the panel
     centre (placement: question Q3), unique name `DailyRewardReveal`.
   - On `DailyReward` (the panel node, not an instance child), set the new
     `wallet_anchor` export to `%DisplayUang`.
   - `scene_save` both scenes, and diff each.
2. **[code]** Tests, in `test_daily_login_panel.gd`:
   - Scan `DailyRewardReveal.tscn` for `ConfettiFireworks.tscn`, and for
     `Box`, `Lid`, `Shine` and `WalletCoin`.
   - `suite_setup` instances the reveal scene once (it is `@tool`) and
     frees it in `suite_teardown`. The tests assert:
     - `use_chest_sprite == false`, `coin_count == 14` and `star_count == 6`.
     - Every Control under the reveal has `mouse_filter == IGNORE`.
     - `DailyRewardReveal.gd` has no `.new(` of a visual type.
   - In `test_lobby.gd`, `%DailyRewardReveal` is a child of `DailyReward`,
     and `(DailyReward as DailyLoginPanel).wallet_anchor ==
     _lobby.get_node("%DisplayUang")`.
3. **[code]** `DailyRewardReveal.gd`:
   - A `##` header.
   - Exports, each with a `##` line:
     - `use_chest_sprite: bool = false`, `chest_base_texture: Texture2D`,
       `chest_lid_texture: Texture2D`.
     - `coin_count: int = 14`, `star_count: int = 6`,
       `peak_count_multiplier: float = 1.5` (question Q4),
       `fan_radius: float`.
     - An `@export_group("Timing")`: `crouch_seconds`, `lid_seconds`,
       `fan_seconds`, `shine_turn_seconds`, `wallet_arc_seconds`.
   - The sequence is small named steps, each ≤ 50 lines and none recursive.
     `play()` builds one tween by calling:
     - `_crouch(tween)`: squash down.
     - `_flip_lid(tween)`: skipped in the fallback.
     - `_burst(is_peak)`: emits `burst_started`; fires `Fireworks` bursts
       (the first only, or the whole volley on the peak day); fans the
       coins and stars.
     - `_spin_shine(tween)`.
     - `_fly_to_wallet(tween, wallet_position)`: emits `coin_landed` at the
       end.
   - `_fan_out(template: PackedScene, count: int, holder: Control)` handles
     instancing, with a hop and a squash landing via
     `AnimUtils.squash_bounce`. Instances are freed when the reveal ends.
   - Under `GameSettings.reduce_motion`, `play()` emits `burst_started` and
     `coin_landed` at once. `skip()` kills the tween and emits `coin_landed`
     if it is still pending, exactly once.
4. **[code]** `DailyLoginPanel.gd`:
   - Add `@export var wallet_anchor: Control` (`##`: "Where the reward coin
     flies; wired in Lobby.tscn to %DisplayUang.").
   - Add `@onready var reveal: DailyRewardReveal = %DailyRewardReveal`, and
     `@onready var reward_row: HBoxContainer = %RewardRow`.
   - `_on_claim_pressed` stops emitting `claimed` directly. It calls
     `_play_claim_moment(amount, claimed_day, previous_money)` instead,
     which does three things:
     - Stores the pending payout.
     - Connects `reveal.burst_started` (once) to
       `AnimUtils.spring_pop_in(reward_row)` +
       `Juice.count_up(reward_amount, …)`. The count-up moves here from
       Task 3's place.
     - Calls `reveal.play(claimed_day == STREAK_DAYS,
       wallet_anchor.global_position)`.
   - `reveal.coin_landed` → `_pay_out()` emits
     `claimed(amount, previous_money)` exactly once.
   - `close()` calls `reveal.skip()` first, so closing mid-reveal still pays
     the wallet.
   - On the peak day, `reward_amount.modulate` becomes
     `Juice.tokens().currency_gold`.
   - GameState is written at claim time, not at landing, so quitting
     mid-reveal loses nothing.
   - Lobby.gd is **not touched**.
5. **[editor]** Run a no-op `script_patch` on each touched `.gd`, then a
   scan. Then `test_run(suite="daily_login_panel")`, `"lobby"`,
   `"audio_coverage"`, `"viewport_editability"`, `"script_documentation"`,
   `"tall_screen_layout"` and `"clean_code"`.
   - Take a full-size capture of the reveal on day 3 and on day 7. Freeze
     game time inside one `game_eval`, using `Engine.time_scale = 0.02`,
     because GPU particles vanish at 0.
   - A scaled screenshot is not proof. The human judges the "generous, not
     a screen full" balance.

Commit: `feat(lobby): prize-box reveal, burst and coin-to-wallet on claim`.

## Task 7 — Idle invite + "besok" teaser (old Phase 6)

1. **[editor]** Scene work. Under `DailyReward`, add `BesokTeaser` (Label,
   `CaptionLabel`, unique, `mouse_filter = IGNORE`) below the strip, hidden
   by default. `scene_save` and diff.
2. **[code]** Tests:
   - In `test_daily_login_panel.gd`:
     - `teaser_text(2) == "Besok: +120G"`.
     - `teaser_text(day_after(STREAK_DAYS)) == "Besok: +80G"`, the 7→1
       wrap.
     - A scan for `AnimUtils.squash_bounce.bind(` and for `set_loops()`.
   - In `test_lobby.gd`, `%BesokTeaser` uses `CaptionLabel`.
3. **[code]** `DailyLoginPanel.gd`:
   - Add:
     ```gdscript
     ## The teaser under the strip; %d is tomorrow's reward.
     const TEASER_FORMAT := "Besok: +%dG"
     ## Seconds between two idle "tap me" bounces while today is unclaimed.
     @export var idle_invite_seconds: float = 3.0
     ```
   - `static func teaser_text(next_day: int) -> String` returns
     `TEASER_FORMAT % reward_for_day(next_day)`.
   - `_show_day` shows the teaser only when claimed, with
     `teaser_text(GameState.daily_login_day)`, since the day has already
     advanced.
   - `_start_idle_invite()`: skip if claimed today or under
     `reduce_motion`. Otherwise
     `_invite = create_tween().set_loops()`, then
     `tween_interval(idle_invite_seconds)`, then
     `tween_callback(AnimUtils.squash_bounce.bind(reward_row))`. The target
     is the reward row: `ButtonClaim` draws nothing, so bouncing it moves
     only the "KLAIM" text (question Q3).
   - `open()` starts the idle invite, and a claim or `close()` kills it.
     Do **not** loop `AnimUtils.wobble`, which snaps to scale 0.7 each call.
4. **[editor]** Run a no-op `script_patch`. Then
   `test_run(suite="daily_login_panel")`, `"lobby"` and `"clean_code"`.
   Take a screenshot before and after a claim.

Commit: `feat(lobby): idle claim invite and a "besok" reward teaser`.

**Update (fix pass):** `%BesokTeaser` moved from `CaptionLabel` to
`ResultDeltaLabel` (white text, dark outline) — the dark caption text was
unreadable over the Lobby's blurred backdrop.

## Task 8 — Docs, full run, ship

1. **[code]** Docs:
   - `docs/superpowers/CHANGELOG.md`: a new top entry covering the
     extraction (with Lobby.gd's ratchet numbers before and after), the
     curve, the cue, the layout, the streak, the reveal and the teaser.
   - `docs/superpowers/DEBT.md`:
     - Remove `daily_claim` from "Unused pack cues".
     - Add a grouped placeholder entry: `streak_flame.svg`, the unset
       `chest_base.png` / `chest_lid.png` (`use_chest_sprite` stays false
       until they land), and the gift `AtlasTexture` region that must be
       re-measured if `day1.png` is redrawn.
   - `CLAUDE.md`:
     - The Testing section's suite/test count, from the full run
       (161 → 162 suites).
     - The `GameState` / Lobby lines if the daily-login owner is named
       there.
     - Keep it under its 23,000-character budget.
2. **[editor]** One **full** `test_run` at this milestone. Budget an editor
   restart, since the bridge drops.
   - Run `git status`, then `git checkout --` `kejartes_theme.tres` and
     `default_bus_layout.tres` unless intended.
   - Run `git diff HEAD -- '*.gd'` for stray flushes.
   - Confirm there is no `theme_override_*` in `Lobby.tscn` /
     `DailyRewardReveal.tscn` apart from `separation`.
   - A final `test_run(suite="clean_code")` must be green, with nothing to
     dump.
3. Finish with the `ship-pr` skill. Bind the PR right after `gh pr create`,
   per memory.

## Risks / notes

- **Lobby.gd cap.** After Task 1 no task edits Lobby.gd. A later need to
  touch it must stay net-zero against the new, lower baseline, and must
  never cross 1,000 lines if Task 1 took it under.
- **Chest art is the only big new asset.** Tasks 1–5 and 7 have no chest
  dependency, and Task 6 completes on the gift fallback.
- **Fixed strip.** Every reveal element is an overlay or an existing node.
  Never re-slice `day1-7.png`.
- **Balance ownership.** `REWARD_CURVE` is ours and lives in
  `DailyLoginPanel.gd`. Do not move daily-login numbers into `Balance.gd`.
- **`@tool` bake hazard.** The panel and reveal are `@tool`. Any ungated
  runtime write (`texture`, `modulate`, `scale`, `visible`) is saved into
  the scene by the next `scene_save`. Diff every scene after every save.

## Questions for the human (answer before the task that needs it)

**Answered 2026-09-28 — every proposal below stands:** Q1 the clipping is the
larger amounts overflowing the 120px box (fit them in a text-sized row;
KLAIM stays put); Q2 above the panel, one flame that grows with the streak;
Q3 panel centre, shown only during the reveal (the idle invite bounces the
reward row); Q4 ×1.5 coins and stars plus the full three-firework volley.

- **Q1 (Task 4):** Confirm what clips. The authored rects do not overlap;
  the plan assumes it is "400G" overflowing the 120px amount box.
- **Q2 (Task 5):** Placement of the greeting and streak. The plan puts them
  above the panel, over the blur, because the "Daily Login" header is
  pinned and the art has no free plate. Also: one flame that grows with the
  streak, or N flames?
- **Q3 (Tasks 6–7):** Where does the box sit? The plan puts it at the panel
  centre, which covers slot 4; "today's slot" would need seven authored
  markers. Is it visible before the claim? The plan shows it only for the
  reveal, and the idle invite bounces the reward row instead.
- **Q4 (Task 6):** Day-7 "bigger burst". The spec gives no numbers; the plan
  proposes ×1.5 coins and stars plus the full three-firework volley,
  against one firework on other days.
