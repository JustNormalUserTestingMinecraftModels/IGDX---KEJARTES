# Lobby Scrapbook HUD — Design & Handoff

**Date:** 2026-09-27
**Screen:** `Scenes/Lobby/loby.tscn` (bottom UI + a new top header)
**Status:** Design approved by the user (relayed from their mentor). Not yet built.
**Reference mockups:** `assets/lobby-scrapbook-hud/` — `stepped_lobby.png` (the target
layout), `asym_books.png` (housing-shape exploration), `earn_over_lobby.png` (Phase 2 panel).

> All numbers below labelled **(Balance)** are proposals for the `Balance.gd` owner,
> not values we set ourselves. See CLAUDE.md § Conventions.

---

## 1. Why

The lobby's bottom bar reads as an unfinished placeholder: flat brown `LobbyCtaButton`
and `LobbyNavTile` slabs, four loose icon buttons, and a generic money `Card`. The user
wants it to feel like a finished, cute, school-themed mobile game — "a living scrapbook."

This spec restyles **only the text UI and money box** and adds a **grade/week header**.
It does **not** touch the four utility icon buttons' art — those are finished assets
(see the `lobby-icon-buttons-fixed-assets` memory).

The work splits into two phases that ship independently:

- **Phase 1 — Lobby restyle + HUD + animations.** Pure UI. Buildable now.
- **Phase 2 — "Dapatkan Uang" panel + dev-mode ad stub.** A real feature (new
  `GameState` fields, toasts, Balance sign-off, and — deferred — an ad SDK).

---

## 2. Visual direction

Warm-brown scrapbook: a hardcover book houses the primary buttons; nav tiles are
washi-taped "cards" with a slight tilt; the money and progress chrome are cream paper
plates with a chunky drop-lip. Everything obeys the project's visual rules:

- **No `theme_override_*`.** Every new look is a `ThemeFactory` type variation, rebaked
  via `Scripts/Design/BakeTheme.gd`. New variations proposed in § 6.
- **No runtime visual construction.** Static chrome is nodes in the `.tscn`; the book
  frame / badges / header plates are 9-patch PNG art; repeated tiles use the existing
  `ActivityRow`-style template pattern. See CLAUDE.md § Visual system.
- **Fills any phone.** Backgrounds Full Rect + Keep Aspect Covered; the HUD re-anchors to
  the bottom edge inside `SafeAreaMargin → UI`. Pinned by `tests/test_tall_screen_layout.gd`.

Two faces as always: **Boohong** (`font_display`) for JADWAL!, labels, badges, the KELAS
title and header numbers; **Open Sans** (`font_body`) for the subtitle and tip copy.

---

## 3. Layout — tightened Option B ("thumb hero")

Portrait 1080×1920, target in `stepped_lobby.png`. Top to bottom:

1. **Top-left — Progress header (NEW).** Cream paper plate. A `KELAS 7` grade badge +
   `Minggu 2 / 6` week counter on the top row; a star-progress bar toward `2.0 / 3.0`
   below. Driven by `GameState.current_grade`, the week counter, and `run_stars()`.
2. **Top-right — Coin box.** Cream plate: gold coin + balance (`GameState.player_money`)
   + a green **`+`** button that opens the Dapatkan Uang panel (Phase 2). The `+` stays
   **green**, never gold — a gold `+` reads as an IAP "buy currency" button, which the
   game must not imply (money is in-game G only).
3. **Middle — classroom diorama.** Unchanged existing desks/students/parallax; the
   `StudentChatBubble` surfaces a line here for life. Deliberately roomy — this is where
   students sit and animate.
4. **Right edge — icon rail.** The four **fixed** `TextureButton`s (DailyLogin, Settings,
   Achievement, SkinSwitch), art untouched, moved into a vertical rail. They carry
   notification badges (§ 5) and hide with the HUD on swipe (§ 4).
5. **Bottom — the stepped book HUD.** § 4.

### Idle fade
Header + coin box stay visible always, but after **~8 s of no input** they ease to
~55 % opacity (still readable); any touch snaps them back to full. Standard `Tween` on
`modulate:a`. Nothing else fades.

---

## 4. The stepped book HUD

One book object housing the four text buttons (`asym_books.png` option B). An **asymmetric
stepped silhouette** so it never reads as a boxed-in slab:

- **Raised left block** (~62 % width) holds the **JADWAL!** hero on a ruled page, with a
  `6 murid` chip (roster count) and an "Atur kegiatan minggu ini" subtitle. *Build note:
  in the mockup the murid chip clips the block's right edge — widen the block or inset the
  chip so it clears.*
- **Lower full-width shelf** holds the three color-coded nav tiles.
- A big **book-style chevron grip** caps the raised block (pill grip + chevron glyph).

### Color-coded nav tiles
Each tile carries its own identity through colour **and** icon, on a washi-taped card with
a slight tilt (`transform` rotation baked into the art / node):

| Tile | Colour | Icon meaning | Route |
|---|---|---|---|
| Koperasi | green | storefront = "spend money here" | ShopHub → Koperasi |
| Inventory | blue | bag = "my stuff / apply items" | Inventory |
| Rapor | amber | report page = "grades/progress" | ReportCard |

Tile colours must be **sampled from `design_tokens.tres` accent ramps**, not the mockup's
invented hexes, so they read native. JADWAL! stays the biggest element and greenest
(primary action). Tiles show small status badges when relevant (e.g. Inventory unused-item
count), hidden at zero.

### Swipe interaction
The chevron grip (or a vertical drag on the book) swipes the **whole HUD** — book **and**
the four-icon rail — as one piece:

- **Down** → HUD slides off the bottom, leaving only the peeking chevron. "Idle, watch the
  class." A hint toast reads *"Ketuk dua kali untuk buka HUD."*
- **Up**, or a **double-tap anywhere**, → HUD springs back. "Game on."
- The chevron glyph rotates 180° to show state (its own spring, slightly delayed from the
  book, to sell the hinge).

### Motion (all via `Scripts/Design/Juice.gd` / `Scripts/AnimUtils.gd` — no new system)
- **Swipe:** `Tween` on the HUD's `position:y`, `TRANS_BACK` / `EASE_OUT` — a bouncy
  overshoot that settles back ("Feel A"). Tune the exact curve with the `motion-lab` skill.
- **Squash-on-land:** `AnimUtils.squash_bounce` on arrival (~1.0 → 1.04w/0.97h → 1.0).
- **Idle grip bob:** while hidden, the peeking chevron gently bobs every few seconds so the
  player remembers it's there.
- **Lobby entrance:** tiles drop-and-settle staggered (`Juice.stagger_in`).
- **Press:** every button squishes (`Juice.press`/`release`, already auto-wired by UIPolish).
- **JADWAL idle:** slow ~1.8 s breathe (scale pulse) + washi-tape flutter. Skip full-card
  "breathe" — too busy against the parallax.

---

## 5. Notification badges

Red dots/counts on the icon rail and nav tiles, driven by **real state**, hidden at zero:

- Daily-gift icon → `1` when the daily reward is unclaimed.
- Achievement icon → `!` when an achievement is claimable.
- Inventory tile → unused-item count.

### Badge motion (the "alive" star of the screen)
Pop in with an overshoot when the thing becomes claimable
(`AnimUtils.popup_spring_in`), then a periodic **heartbeat-wiggle** (gentle rotational
`Juice.shake`) to catch the eye. **Offset each badge's timing** so they don't wiggle in
unison. Also: **star-bar sparkle-fill** — when a target clears, the header bar slides up
(`Juice.fill_bar`) and a star sparkles at the new tip. Optional garnish: coin flip on
money change, chat-bubble squash-pop on entry.

---

## 6. New `ThemeFactory` variations (Phase 1)

Propose and rebake (`Ctrl+Shift+X` → `BakeTheme.gd`). Names indicative:

- `BookHeroButton` — the JADWAL! CTA (green, dashed washi border, thick bottom lip).
- `NavTileKoperasi` / `NavTileInventory` / `NavTileRapor` — the three taped tiles (colour +
  lip + dashed border), colours from token ramps.
- `CoinPlate`, `ProgressPlate` — cream paper plates for the coin box and header.
- `GradeBadge`, `WeekLabel`, `StarNumLabel` — header type variations.
- `NotifBadge` — the red badge pill.

The book cover/spine/page-edge, the chevron grip, and the paper plates are **9-patch PNG
art** (drop-replaceable at fixed paths; log them in `docs/superpowers/DEBT.md` as
placeholders until final art lands). Only layout-only constant overrides
(`separation`, `margin_*`) are allowed inline.

Update `DISPLAY_ROSTER` in `tests/test_theme_factory.gd` and `ThemeFactory` together, or
the theme suite fails.

---

## 7. Phase 2 — "Dapatkan Uang" panel + dev-mode ad stub

Opens from the coin box `+`. A scrapbook money-book popup over a dimmed lobby
(`earn_over_lobby.png`). Three sections:

1. **Tonton iklan, dapat sekarang** — rewarded ads: Iklan Singkat → **+150 (Balance)**,
   Video Penuh → **+450 (Balance)**.
2. **Ambil dulu, tonton nanti** — cash-in-now: **+900 / 4 ads owed (Balance)**,
   **+2000 / 8 ads owed (Balance)**.
3. **Cara gratis** — a tip card teaching the free path: assign students to **Wirausaha**
   in Atur Jadwal to earn every week, no ads. Keeps it from feeling pay-to-win.

### Economy grounding
Wirausaha earns **120–320 G/day/student** (`Balance.WIRAUSAHA_UANG_MIN/MAX`), ~600–1600/wk
for one student; items cost **400–1500 G** (`ItemDatabase.gd`). So +150 ≈ one Wirausaha
day, +450 ≈ a cheap item — ads are a boost, not a replacement. Amounts are **Balance**.

### Dev-mode stub (build this first; no ad SDK)
Each option simulates instantly and fires an `AchievementToast`-styled success toast with
a red **DEV MODE** tag. New `GameState` field: `ad_debt: int` (session-scoped; do **not**
persist — CLAUDE.md § persistence).

| Action | Effect | Toast |
|---|---|---|
| Iklan Singkat | `player_money += 150` | "Sukses! Mentransfer +150 koin ke kas kelas…" |
| Video Penuh | `player_money += 450` | "Sukses! Mentransfer +450 koin ke kas kelas…" |
| +900 (4 nanti) | `+900`, `ad_debt += 4` | "Sukses! +900 koin — 4 iklan menunggu" |
| +2000 (8 nanti) | `+2000`, `ad_debt += 8` | "Sukses! +2000 koin — 8 iklan menunggu" |
| owed ad watched | `ad_debt -= 1` | "Sukses menonton iklan!" |

Swapping in a real ad SDK later replaces "simulate + toast" with "play ad → on reward,
same payout + toast"; everything else stays. The DEV MODE tag hides in real mode.

### ⚠️ Deferred before real ads ship
If the audience includes minors (school sim, Indonesian), ad networks have child-directed
policies (COPPA / GDPR-K, ad-content ratings). Check before integrating any SDK. This is an
integration-time gate, not a design blocker — the dev-mode stub is safe to build now.

---

## 8. Out of scope / constraints carried

- Four utility icon buttons' **art** is untouched (fixed assets). They move and gain badges
  only.
- Only `GameState.inventory` + achievements persist; roster/money/week/grade/schedules and
  the new `ad_debt` are session-scoped by design. Do not add persistence.
- `Balance.gd` values are the collaborator's; the reward amounts here are proposals.

---

## 9. Build order

**Phase 1:** header + coin plate → `ThemeFactory` variations + 9-patch placeholders →
stepped book HUD nodes → nav tiles from a template → swipe + squash + idle-bob motion →
notification badges wired to real state → idle fade → theme rebake + `test_theme_factory`
+ `test_tall_screen_layout` + `test_script_documentation` green.

**Phase 2:** `ad_debt` field → Dapatkan Uang panel scene → dev-mode payouts + toasts →
Balance proposal for the amounts. Real ad SDK deferred behind the policy check.

Finish each phase with the `ship-pr` skill.
