# Minigame Polish — Part 1

**Date:** 2026-09-28
**Status:** Draft for review (design only — no code until approved)
**Author:** Handoff from a design/brainstorming session (mockups explored in the app's show-widget)
**Origin:** Mentor review notes, relayed. The mockups this spec encodes are the
mentor's to sign off — treat "mentor approval" as a hard gate before build.

---

## 1. Problem

The minigames don't share a UI kit. Each screen invents its own backdrop,
button style, HUD and colour language, so the same game mode looks like two
different apps, and two of the gameplay minigames have genuine "can't see what
to do" bugs. `CLAUDE.md` already records that minigames were **out of the
design-system pass so far** ("minigames inherit the Theme but had no polish
pass") — this spec is that pass.

Concrete faults found by reading the scenes:

- **Two visual identities for the quiz.** Some quizzes use a dark-wood backdrop
  with brown/grey buttons; others a light-orange wood with white pill buttons +
  blue underlines. Same mode, two looks.
- **Tutorial is a raw engine placeholder** — a flat blue-grey box with a
  hairline border and tiny "Ketuk untuk melanjutkan" text; ignores every design
  token.
- **Pause + quit dialogs are plain stacked buttons.** "Game diberhentikan!"
  reads like an error; quit's Iya/Tidak are identical brown buttons (easy to
  mis-tap the destructive one).
- **Result popups have no payoff.** A small popup, three static stars, "0/4" —
  no motion, win or lose.
- **Menjodohkan** ([Menjodohkan.tscn](../../../Scenes/Minigames/Akademis/Menjodohkan.tscn)):
  two independent swipe-wheels + a Kunci button; you never see the whole board,
  and swiping to an already-locked question **silently yanks** the other wheel
  to its match (`Menjodohkan.gd` lines ~603–620). Wheel cards eat ~28% of screen
  height, twice.
- **Badminton** ([Badminton.tscn](../../../Scenes/Minigames/Olahraga/Badminton.tscn)):
  **no background node at all** — physics bodies float on nothing; the
  "shuttlecock" is `puck.png` with `bounce=1.0, friction=0.0` (air-hockey physics).
- **MainBola** ([MainBola.tscn](../../../Scenes/Minigames/Olahraga/MainBola.tscn)):
  dead `visible=false` procedural goal nodes (`GoalBack/GoalNet/Crossbar/PostLeft/
  PostRight`); English + emoji placeholder HUD ("Shots Left: 8", "↑ Swipe Up to
  Shoot") with hardcoded `theme_override`s; field bg is a `.jpg`.
- **BuatBatik** ([BuatBatik.tscn](../../../Scenes/Minigames/SeniBudaya/BuatBatik.tscn)):
  four hand-authored blue-bordered (`#3380D9`) white tool cards on a warm table;
  every label uses hardcoded `theme_override_colors`/`font_sizes`.
- **LombaMenari** ([LombaMenari.tscn](../../../Scenes/Minigames/SeniBudaya/LombaMenari.tscn)):
  **the `HitZone` has no texture** — the player can't see where to swipe; the
  background carries offsets `(-276,-843)…(320,216)` on top of full-rect anchors,
  so it's shoved off-centre.

## 2. Goal & non-goals

**Goal:** one shared minigame UI kit — a single backdrop, card, button family,
overlay set, HUD and feedback-animation vocabulary — applied across the
minigames, plus fixing the two gameplay bugs, so the minigames read as one
polished, cute, lively game on a phone.

**Non-goals (explicitly out of Part 1):**
- **No economy change.** Minigame wins keep granting a *stat only* (grade win
  stat 10/8/6; loss penalty −3/−4/−5). A coin reward was considered and
  **rejected** for this pass — it's a `Balance.gd`-owned economy decision, not a
  UI change. If pursued later it goes as a separate proposal to the Balance
  owner.
- **No new persistence** (per `CLAUDE.md`).
- **No `Balance.gd` edits.** Tunables we add are our own `const`/`@export` in the
  script that owns the behaviour.
- Bespoke redesigns of the other Akademis minigames (`Password`, `Variabel`,
  `Kalkulator`) — they inherit the shared kit (backdrop, card, buttons, HUD,
  overlays, motion) but their per-screen layouts are **deferred to a later part**.
- CosmeticShop and any non-minigame screen.

## 3. Locked design decisions

From the mentor-note review session, these are settled:

| Piece | Decision |
|---|---|
| Card + buttons | **"Bingkai Kayu"** — a wooden frame (brand border) around a cream inner card; solid brand-filled answer buttons with a gold-lit top edge. Plus a shared **image-plate** variant. |
| Backdrop | **Light-orange wood**, canonical for every minigame. Cards carry a deeper amber drop-shadow + cream rim so they pop on the brighter wood. A thin category ribbon (blue Akademis / red Olahraga / green SeniBudaya) signals the skill. |
| Overlays | Redesigned **Tutorial**, **Pause** ("Jeda", not "Game diberhentikan!"), **Quit-confirm** (warning icon; safe=green, destructive=red). |
| Win / Lose | **Stats only.** Student **splash as hero** in a framed portrait medallion (`StudentSkins.splash_for_day`), a ribbon banner, a reward card (stars → score → stat gain, count-up), and a **persona-flavoured speech bubble** filling the space the coins would have. Lose = same frame, calmer, partial stars + gentle penalty + encouraging line. |
| Menjodohkan | **"Roda Diperbaiki"** — keep the two-wheel mechanic, but wood-craft reels with peeking neighbour cards at mobile scale, chunky wooden arrows (replacing the navy `StyleBoxFlat`), and a persistent **pairs tray** where each locked pair is a tappable chip with an unlink ✕. Image-plate works in the reel card. |
| Lomba Menari | **Dancer stays fixed** (anchored to BG — do not move it). All interaction lives in the **existing lower hit-band**. A **single horizontal runway**: notes carrying a direction arrow slide the full screen width from the right to a fixed hit-circle on the left. Long runway = reaction time; **difficulty is one tunable: travel duration.** Fixes the invisible `HitZone`. |
| Badminton | Real court (boundary lines + woven net), proper rackets, shuttlecock with a motion trail (not a bouncing puck). Shared wood HUD. |
| MainBola | Real netted goal + goalie (delete the dead ColorRects); Indonesian HUD via ThemeFactory ("Tendangan tersisa: N") and an icon swipe-hint (no emoji, no English). |
| BuatBatik | Cream ThemeFactory tool cards (gold ring = selected) replacing the blue-bordered ones; wood title plank; 5-step progress dots; no hardcoded overrides. |
| Motion | Shared **cute-and-lively** feedback vocabulary (below). |
| Economy | **Unchanged.** |

## 4. Architecture

### 4.1 Shared kit as ThemeFactory variations (not overrides)

Everything visual goes through `ThemeFactory` type variations + tokens — **no new
`theme_override_*`** (project rule; layout-only constant overrides for
`separation`/`margin_*` are the only exception). New variations to add in
[ThemeFactory.gd](../../../Scripts/Design/ThemeFactory.gd) and rebake via
`Scripts/Design/BakeTheme.gd` (File > Run):

- `MinigameCard` — the Bingkai Kayu frame: outer brand border + cream inner,
  `radius_lg`, deep amber drop-shadow.
- `MinigameCardInner` — the cream face (`surface_card`).
- `MinigameAnswerButton` — solid brand fill, `brand_primary_light` top edge,
  `brandD` hard shadow; plus `:hover`/`:pressed` and a **correct** (state_success)
  and **wrong** (state_danger) styling path driven by the script, not a variation
  swap that adds overrides.
- `MinigameImagePlate` — recessed slot (`preview_pill_fill`) with the sunken inset
  shadow; fixed-height; omitted when a question has no image so the card collapses
  to text height.
- `MinigamePlankLabel` — the carved `brandD` plank tab with gold text
  (SOAL/JAWABAN/title).
- `MinigameHudPill` — the `brandD` + cream-rim score pill (gold text).
- `MinigameHudIconButton` — the round pause/timer chrome buttons.
- `WoodNavArrow` — the reel arrows (replaces `StyleBoxFlat_nav_btn`).
- `MinigamePairChip` / `MinigamePairChipEmpty` — Menjodohkan pairs-tray chips.
- `MinigameToolCard` / `MinigameToolCardSelected` — BuatBatik tools.

New tokens (add to [DesignTokens.gd](../../../Scripts/Design/DesignTokens.gd),
rebake): a canonical `minigame_wood_*` backdrop tint if the light-orange wood
needs a token rather than the existing `meja_background.png`; the four
direction-note colours for LombaMenari already live in `LombaMenari.gd`
(`left_note_color` etc.) — reconcile those with tokens rather than duplicating.
Reuse existing `minigame_win_card*` tokens (already present from the
2026-09-25 win-screen spec).

### 4.2 Shared HUD

One `MinigameScoreHUD`-adjacent header used by every minigame:
pause icon-button (left) · score pill (centre) · timer icon-button (right),
built as static nodes in a small reusable scene/instance, styled by the
variations above. Existing [MinigameScoreHUD.tscn](../../../Scenes/Minigames/UI/MinigameScoreHUD.tscn)
is the seed; extend rather than fork.

### 4.3 Shared overlays

These already exist as scenes and are **shared across minigames** — redesign in
place (via the editor; see build rules in §7):
- [MinigameTutorial.tscn](../../../Scenes/Minigames/UI/MinigameTutorial.tscn)
- [PauseMenu.tscn](../../../Scenes/Minigames/UI/PauseMenu.tscn)
- [QuitConfirmDialog.tscn](../../../Scenes/Minigames/UI/QuitConfirmDialog.tscn)
- [MinigameWinScreen.tscn](../../../Scenes/Minigames/UI/MinigameWinScreen.tscn) +
  [MinigameResultPopup.tscn](../../../Scenes/Minigames/UI/MinigameResultPopup.tscn)

### 4.4 Win/Lose hero + dialogue

- Hero = `StudentSkins.splash_for_day(student_name, splash_path, day_name)` in a
  framed medallion. No new character art.
- Dialogue = extend the existing pattern in
  [EventDialogueCatalog.gd](../../../Scripts/SchoolSimulation/EventDialogueCatalog.gd),
  which already has `WIN_LINES`, `WIN_LINE_STUDENT` and `win_line_for()`. Add a
  `lines[persona][outcome]` pool (5 personas × {win, lose}, a few lines each,
  random pick). Persona is the base axis; **quirk** (Kutu Buku / Penyendiri /
  Semangat Juang / Penasaran / Biang Onar / Pekerja Keras) is an optional second
  pool that can override/append. Respect the Settings **Lewati Dialog Minigame**
  toggle (`GameSettings.skip_event_dialogue`) if the line should be suppressible.
- **The actual Indonesian copy is writing, not ours** — the catalog *structure*
  is in scope; the lines themselves are placeholders pending the voice owner.

### 4.5 Menjodohkan (Roda Diperbaiki)

Keep the mechanic and `Menjodohkan.gd`'s `locked_matches` model. Changes:
- Swap the navy `StyleBoxFlat_nav_btn` arrows for `WoodNavArrow`; clamp wheel
  cards to a fixed compact height (they must never balloon).
- Add a persistent **pairs tray**: one chip per question slot (colour + number),
  locked pairs show "Q → A" and an unlink ✕; empty slots show "belum
  dipasangkan". Tapping a chip selects/unlinks that pair — this **replaces the
  silent cross-wheel auto-jump** as the way to review/edit pairs (the auto-jump
  coupling at `Menjodohkan.gd` ~603–620 should be reconsidered so navigation is
  no longer surprising).

### 4.6 Lomba Menari (fixed dancer + runway)

- **Do not move `CharacterDisplay`** — it's anchored with the background; moving
  it risks BG-position bugs.
- Give `HitZone` a real look (texture or a documented `@tool` procedural draw)
  in the existing lower band — this fixes the invisible-hitzone bug.
- Reshape the note flow to a single horizontal runway: spawn at the right band
  edge, travel to a fixed hit-circle on the left; each note shows its
  `NoteType` arrow (colour per the existing `*_note_color`). Swipe direction on
  arrival. **Reaction difficulty = travel duration**, exposed as a documented
  `@export` (grade-scalable), owned by `LombaMenari.gd` — not `Balance.gd`.
- Fix the background offsets so it fills the frame (see §4.8 tall-phone rule).
- Beat-sync is **deferred**: truly locking spawns to the song needs the track's
  BPM from the audio owner. Part 1 keeps the existing pattern/`note_speed` timing;
  note the dependency and leave a clean seam.

### 4.7 Motion vocabulary (cute & lively)

All map to existing [Juice.gd](../../../Scripts/Design/Juice.gd) /
[AnimUtils.gd](../../../Scripts/AnimUtils.gd) + the existing
`ConfettiFireworks`/`StarBurst`/`ScorePopBurst` scenes — punchier easing, plus a
small shared **idle helper** (bob + breathe + sway loop) any element can opt into:

- Idle: resting cards/notes/dancer gently bob + tilt + breathe (never frozen).
- Press: jelly squash-and-stretch (`Juice.press`/`release`, exaggerated).
- Correct: a happy hop with squash landing + sparkle burst.
- Wrong: horizontal shake (`Juice.shake`), red.
- Stars: bounce-in with a spin + overshoot (`stagger_in` + `squash_bounce`).
- Count-up: pops bigger on each tick (`Juice.count_up` + a per-tick scale).
- Hit (Menari): fat squash on the receptor + a little **heart** burst.
- Win: bouncy title, shower of hearts + stars (`ConfettiFireworks`).
- Dancer: bobs to the beat throughout.

The idle helper is the one genuinely new bit of tech (a tiny static/`@tool`
tween utility); everything else is call-site tuning.

### 4.8 Cross-cutting rules to honour

- **No runtime-built visuals** beyond the documented ratchet
  (`tests/test_viewport_editability.gd` `BASELINE`/`ALLOWED`). Static chrome =
  nodes in the `.tscn`; repeated rows = a `PackedScene` template; responsive
  geometry = a `@tool` script with documented `@export`s.
- **Every script gets a `##` header and a `##` on every `@export`**
  (`tests/test_script_documentation.gd`).
- **Indonesian** UI text; **no emoji as iconography** (real transparent SVG
  textures).
- **Tall phones:** backgrounds Full Rect + Keep Aspect Covered; UI re-anchored
  inside `SafeAreaMargin → UI` (`tests/test_tall_screen_layout.gd`). LombaMenari's
  background offsets must be fixed the right way, not by shrinking any
  `sky_cover_margin`.

## 5. Phases (suggested build order)

Each phase is independently shippable and testable.

1. **Shared kit foundation** — new tokens + ThemeFactory variations + rebake;
   the shared HUD scene. Nothing else can land cleanly until these exist.
2. **Overlays** — Tutorial, Pause, Quit-confirm on the kit.
3. **Win / Lose** — medallion hero + reward card + persona-dialogue catalog
   structure + motion.
4. **Menjodohkan** — Roda Diperbaiki (arrows, card clamp, pairs tray).
5. **Gameplay MG polish + bug fixes** — Badminton court/shuttlecock, MainBola
   goal + Indonesian HUD + dead-node cleanup, BuatBatik tool cards, LombaMenari
   fixed-dancer runway + HitZone + background fix.
6. **Motion vocabulary** — idle helper + cute-easing tuning across all of the
   above.

Quiz (`PilihanGanda`) picks up the kit in Phase 1–2 as the reference screen.

## 6. Asset dependencies (flag early)

New / changed art the team must produce (some can be procedural-in-`.tscn`):
- Badminton **court** + a real **shuttlecock** (the puck is wrong).
- MainBola **goal net** texture (or a documented `@tool` procedural net) +
  keep/redraw the **goalie**.
- BuatBatik **tool icons** as transparent SVG textures (no emoji/glyph stand-ins).
- LombaMenari **HitZone** look + **direction-arrow note** textures.
- Canonical light-orange **wood backdrop** (may reuse `meja_background.png`).

Replacements must honour the constraints in `CLAUDE.md` §Visual system and any
asset README (e.g. `Assets/Images/UI/BarFill/README.md`).

## 7. Build & test constraints (for whoever implements)

- **Edit `.tscn` through the editor**, never by hand while the Godot AI MCP
  editor is attached (`scene_open` → `node_*`/`batch_execute` → `scene_save`).
  See `CLAUDE.md` §"Working efficiently here" for the save hazards (stale script
  buffers, instance-child overrides dropping, editor-across-pull). Give sub-scene
  `@export`s on their **root** (why `ShopHubTile`/`ActivityRow` carry their knobs).
- **Rescan after editing a `.gd`** before `test_run`; a full run rebakes the
  theme and rewrites `default_bus_layout.tres` — `git status` after and
  `git checkout --` what you didn't intend.
- **Tests** (extend `McpTestSuite`, `@tool`, no coroutines, run via MCP
  `test_run`): expect to touch/extend
  `tests/test_script_documentation.gd`, `tests/test_viewport_editability.gd`
  (the ratchet only lowers), `tests/test_tall_screen_layout.gd`, and add
  behavioural/source-scan suites per minigame (e.g. a Menjodohkan pairs-tray
  suite; a LombaMenari suite asserting the HitZone has a visible look and the
  dancer's anchors are unchanged). Follow the source-text-scan pattern where a
  screen can't be instantiated headlessly.
- Reach a state by **seeding**, not playing (Debug overlay → Seed Playtest
  State; Scenes tab teleports; minigame launcher).

## 8. Open items (gates, not blockers to writing the plan)

1. **Mentor sign-off** on the mockups this spec encodes (the whole set was
   explored in-app; send it over).
2. **Dialogue copy** — persona/quirk win+lose lines from the voice owner
   (structure is ours; words are theirs).
3. **LombaMenari BPM** — from the audio owner, only when beat-sync is pursued
   (deferred; Part 1 keeps existing timing).
4. **Coin economy** — rejected here; separate Balance-owner proposal if ever
   revived.

## 9. Success criteria

- Every minigame shares one backdrop, card, button family, HUD and overlay set;
  no two minigames of the same type look different.
- Tutorial, Pause and Quit-confirm are on-brand and unambiguous (safe vs
  destructive is colour-coded).
- Win/Lose feel like a reward: hero splash, count-up, stars, in-character line.
- Menjodohkan: all pairs visible/editable via the tray; wheel cards never
  balloon; no surprising cross-wheel jumps.
- LombaMenari: the hit target is visible; notes have a readable runway; the
  dancer's BG anchoring is unchanged.
- No new `theme_override_*`; no runtime-built visuals beyond the ratchet; all
  new scripts documented; all UI text Indonesian; no emoji iconography.
- Full `test_run` green (with the theme/bus-layout caveats handled).
