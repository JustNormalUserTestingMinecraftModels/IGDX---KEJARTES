# Daily Login Polish — Implementation Plan

Date: 2026-09-28
Branch: `daily-login-polish` (off `Textures`)
Spec: `docs/superpowers/specs/2026-09-28-daily-login-polish-design.md`
Status: **Handoff — not built.** Execute phases in order; each ends green.

## Orientation (do this first)

- Read the spec, especially **Constraints** (fixed strip art, no
  `theme_override_*`, no runtime-built static visuals, no new persistence) and
  **Existing helpers**.
- Open `Scenes/MainMenu/MainMenu.tscn` in the editor before trusting any test
  result (`test_run` returns a `scene_warning` otherwise).
- Do **scene work first, script work second** in any session; after a
  `scene_save`, check `git diff HEAD -- '*.gd'` for stray flushed tabs. Edit
  `.gd` via `script_patch` (LF-normalised). Rescan after external `.gd` edits.
- Key anchors (verified on `Textures`):
  - `Scripts/Lobby/Lobby.gd`: `DAILY_REWARD := 10` (L92),
    `DAY_PANELS` (L104), `_update_daily_login_visual` (L721),
    `_show_daily_reward` (L745), `_hide_daily_reward` (L766),
    `_on_claim_pressed` (L828).
  - `Scenes/Lobby/Lobby.tscn`: `DailyReward` (TextureRect, L1058) with children
    `Label`, `ButtonClaim`, `RewardCoin`, `RewardAmount`.
  - `Scripts/Audio/AudioDirector.gd`: `&"daily_claim"` registered (L137-138,
    379) — **not currently played**.
  - Helpers: `Scripts/AnimUtils.gd`, `Scripts/Design/Juice.gd`,
    `Scenes/Minigames/UI/ConfettiFireworks.tscn`.

TDD throughout: write/extend the `test_lobby` assertion for a phase, watch it
fail, implement, watch it pass.

---

## Phase 1 — Escalating reward curve + economy fix (logic only)

Highest value, no art dependency. Ship this even if later phases slip.

1. **Test first** (`tests/test_lobby.gd`): assert a `REWARD_CURVE` const exists
   with 7 entries, strictly non-decreasing, max at index 6, `sum == 1500`.
2. Replace flat `DAILY_REWARD` with the documented `REWARD_CURVE` const from the
   spec (`[80,120,160,200,240,300,400]`). Keep `DAILY_REWARD` removed or leave a
   deprecation comment; update every reference.
3. In `_on_claim_pressed` ([L828]): award
   `REWARD_CURVE[clampi(GameState.daily_login_day, 1, 7) - 1]` instead of the
   flat value. Update the `RewardAmount` label to that value.
4. **Test:** claiming on day N adds `REWARD_CURVE[N-1]`; streak advances and
   wraps 7→1; same-day second claim is a no-op.

Gate: `test_run(suite="test_lobby")` green.

## Phase 2 — Wire the dead claim SFX + count-up

No art dependency.

1. **Test:** source-scan that `_on_claim_pressed` calls
   `AudioDirector.play_sfx(&"daily_claim")`.
2. Add the call in `_on_claim_pressed`. Keep the existing
   `RewardFeedback.play(&"coins_earned", money_label)`.
3. Make `RewardAmount` **count up** to the day's value with `Juice.count_up`
   (or `count_up_formatted` for the "+Ng" format) instead of setting text flat.

Gate: `test_run(suite="test_lobby")` green; manually confirm the sound plays
(seed via Debug ⚡, open Lobby, claim).

## Phase 3 — Layout fix (font clipping)

Scene work. No art dependency.

1. In `Lobby.tscn`, wrap `RewardAmount` + `RewardCoin` + `ButtonClaim` in an
   `HBoxContainer` (or give each a proper `custom_minimum_size` + separation) so
   the amount no longer overlaps the button. Layout-only constant overrides only.
2. Verify at full size on a tall phone (1080×2400) per the tall-screen rules —
   the amount must not clip at either aspect.
3. **Test:** extend `test_lobby`/`test_lobby_layout` scan for the new container
   node; no `theme_override_*` added.

Gate: relevant suites green; screenshot at full size to confirm no clipping.

## Phase 4 — Welcome-back header + streak

Scene + script. Needs a flame SVG texture (small; can start from an existing
transparent icon asset — no emoji).

1. Add greeting label ("Selamat datang kembali!") and a streak node
   ("Streak N hari" + flame icons) as children of `DailyReward` in `Lobby.tscn`,
   styled with `ThemeFactory` variations (add one + rebake if none fits).
2. In `_show_daily_reward` ([L745]): populate streak text/flame count from
   `GameState.daily_login_day`; scale flames with the streak; land header +
   streak with `AnimUtils.popup_spring_in` (overshoot settle). Optional idle
   flame flicker via a looped Tween.
3. **Test:** scans for the greeting + streak nodes and the spring-in call.

Gate: `test_lobby` green; screenshot the popup.

## Phase 5 — Prize-box reveal + burst (the core moment)

Biggest visual lift. Needs the 2-part chest sprite (`chest_base.png`,
`chest_lid.png`) as drop-in placeholders; ship the **gift-icon fallback** first
so the phase completes without final art.

1. Add `@export var use_chest_sprite: bool` (documented). Fallback path reuses
   the baked gift look; true path uses the chest sprites.
2. Build the reveal as a `@tool` overlay (documented `@export` knobs) or small
   `PackedScene`, layered over the panel centre — **not** over/into the strip
   texture. Sequence (spec §3): anticipation crouch → lid flip → burst
   (`ConfettiFireworks` + ~14 hop/squash coins + ~6 sparkle stars) → shine spin
   → springy "+Ng" count-up → coin-to-wallet arc → money-box tick.
3. Day-7 special: bigger burst + gold tint.
4. Keep particle counts as documented `@export`s so the "not too much" balance
   is tunable.
5. **Test:** scans for the chest overlay (or fallback), the `ConfettiFireworks`
   instance, and the reveal entry call; the `use_chest_sprite` export exists.

Gate: `test_lobby` green; screenshot/record the reveal at full size for the user
to verify (a small screenshot is not proof — see the project's verify-visuals rule).

## Phase 6 — Idle invite + "besok" teaser

Scene + script. No new art.

1. Idle invite: when the reward is unclaimed for the day, loop a soft
   `squash_bounce`/`wobble` on the affordance; stop once claimed.
2. "Besok" teaser: after a claim, show "Besok: +Xg" where X =
   `REWARD_CURVE[next_day - 1]` (wrap 7→1), as a `CaptionLabel`/`MicroLabel`
   node.
3. **Test:** scans for the teaser node and the idle-loop call; teaser value math
   (wrap) if unit-testable.

Gate: `test_lobby` green.

## Phase 7 — Finalise

1. One **full** `test_run` (budget an editor restart; a full run rebakes
   `kejartes_theme.tres` and `AudioDirector` rewrites `default_bus_layout.tres` —
   `git checkout --` whichever you did not intend, per CLAUDE.md).
2. `git diff HEAD -- '*.gd'` for stray tab flushes; confirm no `theme_override_*`
   and all new scripts/`@export`s are `##`-documented
   (`test_script_documentation`, `test_viewport_editability`).
3. Update `docs/superpowers/CHANGELOG.md` (newest first) and delete any resolved
   `DEBT.md` entry; add a DEBT entry if the chest art ships as a placeholder.
4. Finish with the `ship-pr` skill.

## Risks / notes

- **Chest art is the only new asset.** Phases 1–4, 6 have zero art dependency;
  Phase 5 completes on the gift-icon fallback, so a missing sprite never blocks
  the branch.
- **Fixed strip:** every reveal element is an overlay/existing node — never
  re-slice `day1-7.png`.
- **Balance ownership:** `REWARD_CURVE` is ours (in `Lobby.gd`); do not move
  daily-login numbers into `Balance.gd`.
- **Editor/save hazards:** follow CLAUDE.md's scene-first / script-second order
  and the single-client bridge rule (subagents write code, you run the editor).
