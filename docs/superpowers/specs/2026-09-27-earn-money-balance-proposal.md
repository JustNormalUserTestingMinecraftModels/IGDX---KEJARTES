# Proposal: Dapatkan Uang reward amounts (for the Balance.gd owner)

**Status:** proposal. The values below live in `Scripts/Lobby/DapatkanUang.gd`
as named consts until you sign off. They are **not** in `Balance.gd`, and we
will not put them there: that file is yours.

**Source:** spec §7 of `2026-09-27-lobby-scrapbook-hud-design.md` (Loby Final
Polish, Phase 2).

## The amounts

| Option (panel section) | Pays now | Ads owed | Const in `DapatkanUang.gd` |
|---|---|---|---|
| Iklan Singkat (Tonton iklan, dapat sekarang) | +150 G | 0 | `SHORT_AD_REWARD` |
| Video Penuh (Tonton iklan, dapat sekarang) | +450 G | 0 | `FULL_AD_REWARD` |
| Ambil dulu, kecil (Ambil dulu, tonton nanti) | +900 G | 4 | `CASH_IN_SMALL`, `CASH_IN_SMALL_ADS` |
| Ambil dulu, besar (Ambil dulu, tonton nanti) | +2000 G | 8 | `CASH_IN_LARGE`, `CASH_IN_LARGE_ADS` |

Each owed ad, once watched, lowers `GameState.ad_debt` by one. It pays nothing
more: the cash-in already paid.

## Why these numbers

What the game already pays and charges:

- **Wirausaha** earns 120–320 G a day per student
  (`Balance.WIRAUSAHA_UANG_MIN` / `WIRAUSAHA_UANG_MAX`, scaled down by low
  energy in `StudentManager`). That is about 600–1600 G a week for one student
  on Wirausaha every day.
- **Items** cost 400–1500 G (`ItemDatabase.gd`).
- **The daily-login week** pays 1500 G in total
  (`DailyLoginPanel.REWARD_CURVE`: 80, 120, 160, 200, 240, 300, 400).

So:

- **+150** is about one Wirausaha day. A short ad is a nudge, not a shortcut.
- **+450** buys the cheapest item (400 G). A full video is worth one purchase.
- **+900 for 4 ads** is 225 G an ad, between the two rewarded rates. Taking
  the money first costs nothing extra; the ads are just deferred.
- **+2000 for 8 ads** is 250 G an ad, a small bulk bonus. It is more than the
  whole daily-login week, and it still buys only one or two items.

The design aim (spec §7): ads are a boost, never a replacement. The panel's
third section, "Cara gratis", points players at Wirausaha, the free path.

## Your options

1. **Accept.** Move the six values into `Balance.gd` under names of your
   choosing, and we switch `DapatkanUang.gd` to read `Balance`.
2. **Adjust.** Send new numbers; we change the consts, and nothing else
   moves.
3. **Defer.** The consts stay as they are; the panel is dev-mode only until
   a real ad SDK lands, so nothing ships to players on these numbers yet.

## Deferred gate: before any real ad SDK

The audience likely includes minors (an Indonesian school sim). Before any ad
network is integrated, check its child-directed policies: **COPPA**,
**GDPR-K** (GDPR Article 8), and the network's **ad-content rating**
settings. This gates integration, not the design. The dev-mode stub shows no
ads and collects no data, so it is safe to build and ship behind its
DEV MODE tag.
