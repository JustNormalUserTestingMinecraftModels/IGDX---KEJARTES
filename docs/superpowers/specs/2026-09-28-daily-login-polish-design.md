# Daily Login Polish — Design

Date: 2026-09-28
Branch: `daily-login-polish` (off `Textures`)
Status: **Handoff spec — not built.** Design approved; ready for a teammate to
execute via the implementation plan alongside this file.

## Problem

The Lobby's daily-login reward is economically invisible and emotionally flat:

- **Reward is a flat 10G every day** (`DAILY_REWARD := 10`, [Lobby.gd:92]).
  Starting money is 0; a single student earns **120–320G per Wirausaha day**
  (`Balance.gd` `WIRAUSAHA_UANG_MIN/MAX`), and shop items cost **400–1500G**
  (`ItemDatabase.gd`). 10G is ~3% of the cheapest item and 1/22 of one
  student's daily hustle. A full 7-day streak (70G) buys nothing, so the
  7-slot streak strip promises a payoff the code never delivers.
- **Claiming feels blank.** `_on_claim_pressed` ([Lobby.gd:828]) adds money,
  plays one `RewardFeedback.play(&"coins_earned", …)`, pops the panel, and dims
  the claim node. No greeting, no streak celebration, no reveal, no escalation.
- **The dedicated claim SFX is dead.** `&"daily_claim"` (`dailyLoginClaim.ogg`)
  is registered in `AudioDirector` ([AudioDirector.gd:137-138, 379]) but
  `play_sfx(&"daily_claim")` is never called anywhere.
- **Font clipping.** The reward amount ("10G") overlaps/overflows beside the
  KLAIM button in the current `DailyReward` layout.

## Constraints (read before touching anything)

- **The calendar strip is fixed art.** `Assets/Images/UI/DailyLogin/day1.png`
  …`day7.png` are baked single-texture panels (all 7 slots baked per day),
  swapped in `_update_daily_login_visual` ([Lobby.gd:721]). **Do not** rebuild
  the strip as per-day tile nodes or redraw the art. Every new visual layers
  **on top of** the strip (greeting, streak, reveal, burst) or lives on the
  existing overlay nodes (`ButtonClaim`, `RewardCoin`, `RewardAmount`).
- **Visual system rules apply.** No `theme_override_*` — use `ThemeFactory`
  variations (add one + rebake if none fits). No visual built at runtime that
  should be static: new chrome is a node in `Lobby.tscn`; the chest reveal is a
  `@tool` overlay driven by documented `@export`s, or a small `PackedScene`.
  Every script/`@export` needs `##` docs (`test_script_documentation`).
- **Escalation values are our own new tunables** (daily-login is not in
  `Balance.gd`). They go in a named `const`/`@export` block in `Lobby.gd`, never
  inline literals.
- **Persistence unchanged.** Only `daily_login_day` / `last_claim_date` already
  live on `GameState` (session-scoped). Do not add disk persistence.

## Existing helpers to reuse (do not reinvent)

- `AnimUtils.squash_bounce`, `spring_pop_in`, `popup_spring_in`, `wobble`,
  `coin_pulse`, `create_floating_text` ([Scripts/AnimUtils.gd]).
- `Juice.count_up`, `count_up_formatted`, `pop_in`, `shake` ([Scripts/Design/Juice.gd]).
- `ConfettiFireworks.tscn` ([Scenes/Minigames/UI/]) — instance for the burst.
- `AudioDirector.play_sfx(&"daily_claim")` — the already-registered claim SFX.
- `RewardFeedback.play(&"coins_earned", money_label)` — already wired.

## Design

### 1. Escalating reward curve (weekly total = 1500G)

A full 7-day streak buys the priciest shop item. Day 7 is a real payoff
(~one student's Wirausaha day).

| Day | Reward |
|----:|-------:|
| 1 | 80G |
| 2 | 120G |
| 3 | 160G |
| 4 | 200G |
| 5 | 240G |
| 6 | 300G |
| 7 | **400G** (peti besar) |
| **Total** | **1500G** |

Implemented as a named, documented constant array in `Lobby.gd`, replacing the
flat `DAILY_REWARD`:

```gdscript
## Daily-login reward per streak day (index 0 = day 1). A full 7-day streak
## totals 1500G — the priciest Koperasi item. Day 7 is the "peti besar" payoff.
## Our own tunable (daily-login is not a Balance.gd value); retune freely here.
const REWARD_CURVE: Array[int] = [80, 120, 160, 200, 240, 300, 400]
```

`_on_claim_pressed` reads `REWARD_CURVE[clampi(daily_login_day, 1, 7) - 1]`;
the amount label shows that value; day 7 uses the bigger reveal (below).

### 2. Welcome-back header + streak

New nodes on the `DailyReward` popup (in `Lobby.tscn`, styled via `ThemeFactory`
variations):

- A greeting label: "Selamat datang kembali!" (`DisplayLabel`/`H2Label`).
- A streak line: "Streak N hari" with flame icons that **scale with the
  streak** (small at day 1, bigger/hotter by day 7) and gently **flicker**
  while idle. Flames are real transparent SVG textures (no emoji as iconography).
- Both land with an **overshoot settle** (`popup_spring_in`) rather than a hard
  appear.

### 3. Prize-box reveal (the core "reward" moment)

A new **2-part chest sprite** — base + lid — as a drop-in placeholder asset
under `Assets/Images/UI/DailyLogin/` (e.g. `chest_base.png`, `chest_lid.png`),
following the placeholder-replaceable convention. The reveal overlay is
positioned over the panel centre (roughly over today's slot); the fixed strip
is untouched beneath it.

Reveal sequence on claim (all via existing helpers/Tweens):

1. **Anticipation crouch** — the chest squishes *down* (squash) as wind-up.
2. **Lid flip** — lid tweens up + rotates off and fades.
3. **Burst** — instance `ConfettiFireworks` + ~14 coins fanning out with a
   **hop/squash landing** (`coin_pulse`-style) + ~6 sparkle stars. Tuned for
   "generous, not a screen full."
4. **Shine spin** — a slow rotating sparkle behind the reward during the burst.
5. **Springy number** — "+Xg" springs in with overshoot and **counts up**
   (`Juice.count_up`), instead of appearing flat.
6. **Coin-to-wallet** — one coin arcs from the burst into the Lobby money box,
   which then ticks up (`RewardFeedback.play(&"coins_earned", money_label)` +
   the existing `_update_money_display`).
7. **SFX** — layer the now-wired `play_sfx(&"daily_claim")` with the coin
   feedback (chest creak → coin cascade → chime, as the single ogg allows).

**Day-7 special:** bigger burst + gold tint on the number/flames since it's the
peak payoff.

**Fallback if chest art is not ready:** reuse the gift icon already baked into
strip slot 1 as the box; skip the lid-flip; the burst + count-up + coin-to-wallet
still carry the moment. Gate this behind an `@export var use_chest_sprite: bool`
so art can be dropped in later with no code change.

### 4. Idle invite

Before claiming, the chest (or the whole `DailyReward` affordance when the
reward is unclaimed for the day) does a soft **bounce/wiggle** every few seconds
(`AnimUtils.squash_bounce`/`wobble` on a loop) so it *asks* to be tapped. Stops
once claimed for the day.

### 5. "Besok" teaser

After a successful claim, show a small line: "Besok: +Xg" where X is
`REWARD_CURVE[next_day - 1]` (wrapping 7→1), giving a concrete reason to return
tomorrow. Plain `CaptionLabel`/`MicroLabel`.

### 6. Fix the clipping

Re-lay `RewardAmount` + `ButtonClaim` (and `RewardCoin`) inside their own sized
containers (an `HBoxContainer` with proper min sizes / separation) so the amount
never overlaps the button. Layout-only constant overrides are the one accepted
theme exception.

## Testing

Extend `tests/test_lobby.gd` (and add scans following the established
source-text-scan pattern where nodes can't be instantiated headlessly):

- **Curve:** `REWARD_CURVE` has 7 entries, is strictly non-decreasing, day 7 is
  the max, and the sum equals **1500**.
- **Claim math:** claiming on day N adds `REWARD_CURVE[N-1]` to `player_money`;
  streak advances N→N+1 and wraps 7→1; a second claim same day is a no-op
  (`last_claim_date` guard).
- **SFX wired:** source scan that `_on_claim_pressed` calls
  `play_sfx(&"daily_claim")` (currently absent — regression guard).
- **New nodes present:** scans for the greeting label, streak node, chest
  overlay (or gift fallback), and the "besok" teaser node in `Lobby.tscn` /
  `Lobby.gd`.
- **No `theme_override_*`** introduced on the new nodes (the repo already pins
  this globally; keep the new work clean).

Run targeted `test_run(suite="test_lobby")` during dev; one full run at the end
(budget an editor restart — a full run rebakes the theme and drops the bridge,
per CLAUDE.md).

## Out of scope

- Redrawing or re-slicing the calendar strip art.
- Any new disk persistence.
- Changing `Balance.gd` or the Wirausaha/shop economy.
- Cosmetic-shop / other Lobby surfaces.
