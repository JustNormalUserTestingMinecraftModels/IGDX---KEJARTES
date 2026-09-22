# The SchoolDay header collision and the 3-star firework burst — design

2026-09-21, revised 2026-09-22 · branch `feat/editor-tunable-polish`
(off `origin/Textures`)

Two player-facing fixes, one on each of two screens:

1. **SchoolDay's header band.** The old `DayScreen` text chrome is painted over
   the new `BookClockWidget` header and makes the calendar badge unreadable.
2. **The minigame result popup.** The 3-star "fireworks" are literally a second
   confetti emitter — same texture, same silhouette, same tumble, no colour.

Two other requests from the same run are **not** in this spec. The user deferred
*"code so that i can adjust the position of every ilustration and UI elements on
the godot 2d viewport editor"* mid-run; it is recorded in
`docs/superpowers/DEBT.md` with its scoping numbers (§0). And *"replace all
return/back button icon with the new return_button in /downloads"* is being
specced separately — one interaction with this branch is flagged in §7.

---

## 0. Scope

**In:** items 1 and 2 above, and nothing else.

**Out, and where it went.** Viewport-draggable positioning across the game is a
multi-week programme, not a run. The analysis behind that claim is in
`.superpowers/gamecode/editor-tunable-polish/recon-viewport.md`; its two
shippable shapes are:

| Option | Scope | Size |
|---|---|---|
| **B** | the cheap ratchet conversions (`TutorialPanel` ×3, `TutorialArrow`, `MinigameTutorial`, SchoolDay's per-student row, …) | 6-8 tasks, **~50 of the 123 BASELINE points** |
| **C** | literally every illustration and UI element: **123 runtime-constructed nodes across 20 files**, plus **~265 container nodes** whose children can never be dragged without a re-layout, plus Phases 2 and 3 of the tall-phone work (`DEBT.md:444`), plus extending `tests/test_tall_screen_layout.gd` to every screen | **30-50+ tasks** |

Both numbers, the two screens already analysed, and the recon pointer go into
`DEBT.md` as part of this branch. Nothing about the option is decided here.

**One consequence for item 1.** Without item 3, SchoolDay's HUD rows have no
reason to leave their `VBoxContainer`: per-element drag handles were the only
thing a reparent bought, and it would have cost five renamed node paths, four
assertions in `tests/test_school_day.gd` and one in
`tests/test_sky_transition.gd`. The collision is therefore fixed by
**re-anchoring the container**, which keeps every node path and every existing
assertion intact. §1c.

**Baseline before any edit** (targeted runs on this branch, green):
`book_clock_phases` 24 · `school_day` 36 · `confetti_fireworks` 8 ·
`viewport_editability` 2 · `tall_screen_layout` 27 · `minigame_result_popup` 33 ·
`sky_transition` 26 · `paper_confetti` 11 · `day_summary` 91 ·
`script_documentation` 2 — **260 passed, 0 failed.** Any red after this branch
is attributable.

**No new asset is created by this branch.** Every texture it needs is already on
disk. That is deliberate: `Scripts/Design/GenerateParticleSprites.gd` is an
`EditorScript` run by hand via File > Run, and the MCP bridge has no op that
runs one (`editor_manage` offers `game_eval`, which executes inside a *running
game*, not the editor; `script_manage` is read-only). A spec that needs a new
placeholder PNG therefore stalls on a human keystroke, and the user is async.
§2b.

---

## 1. Item 1 — the old texts over the header band

### 1a. What is on screen today

`SchoolDay.tscn` has four root children, in this order
(`SchoolDay.tscn:23/32/35/115`, pinned by `tests/test_sky_transition.gd:299-311`):

```
SchoolDay (Control, Full Rect)
├── 0 Background        ColorRect + SimulationBackground.gd
├── 1 BookClockWidget   instance — carries Header/DayBanner + Header/Calendar
├── 2 DayScreen         VBoxContainer, anchors 0.05 / 0.06 / 0.95 / 0.94
└── 3 GameContainer     Control, Full Rect, mouse_filter = 2
```

`DayScreen` has the **higher** sibling index, so everything in it paints **over**
the new header. Confirmed visually from a full-resolution capture of
`SchoolDay.tscn`'s 2D viewport: the pill and the badge render correctly on their
own; all of the damage is legacy `DayScreen` chrome drawn on top of them.

```
 BEFORE — 1080 x 1920, the collision (as captured)
 ─────────────────────────────────────────────────────────────────────────

 x:    0    104        250                        936    1026
       │     │          │                          │       │
 y=44  ┆   ┌─┴──────────┴──────────────────────────┴───┐   ┆  Calendar top
       ┆   │ Calendar   │                              │   ┆
 y=100 ┆   │ badge   ┌──┴──────────────────────────────┴┐  ┆  Pill top
 y=115 ┆═══╪═════════╪═══  Hari 1 dari 5  ══════════════╪══┆ ◀ DayNumberLabel
 y=145 ┆   │"Minggu" │                                  │  ┆   115..~145, across
       ┆   │         │            Senin                 │  ┆   the TOP of the pill
 y=163 ┆▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓┆ ◀ ProgressBar
 y=223 ┆▓▓▓│  "2/6"  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓┆   163..223, h = 60
 y=236 ┆   │         └──┬──────────────────────────────┬─┘  ┆  Pill bottom
 y=241 ┆   │  StatusLabel (empty in the editor, one line in play)
 y=289 ┆   │            │  DayBanner pill x 250..936   │    ┆
 y=292 ┆   └────────────┘                                   ┆  Calendar bottom
       ┆      Calendar x 104..312, y 44..292                ┆
       ┆   StudentScroll …                                  ┆
       └────────────────────────────────────────────────────┘
       x=54                                              x=1026

 ▓ = DayScreen/ProgressBar, the dark rounded bar. It slices the LOWER HALF
     of "Senin" and cuts straight through the badge's "Minggu" and "2/6",
     which is what makes both unreadable.
```

Two notes the capture makes concrete:

- **`DayNumberLabel` lands across the TOP of the pill, above "Senin".** It is
  horizontally centred at x 540, squarely inside the pill's x 250..936, and
  starts ~15 px below the pill's top edge.
- **The bar is what ruins the badge.** At runtime `ProgressBar` is hidden for
  most of the day (`SchoolDay.gd:1519`) and shown only at `:438` and `:1329` —
  but in the **editor** it is always visible, and the editor is where the user
  saw this. The fix has to clear the bar off the badge in both.

Label heights above come from the real type scale:
`DayNumberLabel` is a `CaptionLabel` at `font_caption = 22`
(`DesignTokens.gd:256`), so it is about 30 px tall, not 40; `StatusLabel` is a
`TitleLabel` at `font_title = 36` (`:260`), about 48 px. The band edges, the
anchors, `separation = 18` and the 60 px `ProgressBar` are exact.

Invisible children — `DayLabel`, `ClickToContinueLabel`, `BackButton`,
`SkipButton` — take no space in a `VBoxContainer`, which is why they do not
appear in the stack above. That is true **during the week**, when
`_reset_day_ui()` hides all of them. It is not true at the week-end screen,
where `BackButton` is shown and becomes the column's visible tail — §7 depends
on that second moment, and the two are easy to conflate.

### 1b. Delete the duplicated day name

**Delete** `DayScreen/DayLabel` (`SchoolDay.tscn:53-60`). It is the one
duplicated text, it is already `visible = false`, and `ba98d10`'s commit message
defers exactly this deletion; the user has now made that call.

With the node go `SchoolDay.gd:87`'s `@onready var day_label: Label` and its
three writes — `:359` (`day_label.text = day_name`), `:1328`
(`"Akhir Pekan"`, see §1e) and `:1523` (`_reset_day_ui()`'s blank).

`_DAY_CHROME_PATHS` (`SchoolDay.gd:732-736`) already does **not** list it
(`af047f9` removed it), so nothing can un-hide a node that no longer exists.

**Also changed, because it is the line above:** `SchoolDay.gd:1327` writes
`"Minggu selesai! 🎉"` into `DayNumberLabel`. That is player-facing display-text
emoji, which `## Conventions` forbids outright, and **nothing tracks it** —
`DEBT.md:248-252` records only `BackButton`'s `🔙` and CutScene's `🏫`/`🎓`; a
grep of `DEBT.md` for `Minggu selesai` or the glyph returns nothing. It sits one
line above `:1328`, which this branch rewrites anyway, so it is folded in as a
**plain text deletion**:

```gdscript
	day_number_label.text = "Minggu selesai!"
```

No replacement glyph and no icon: the sentence already carries the meaning, so
deleting the codepoint costs one word and needs no art. §6c adds a scan so it
cannot come back.

**Not changed here, and not this spec's to record either.** `SchoolDay` puts
real emoji in display text in six more places, and CLAUDE.md's rule is that
emoji get replaced by **real transparent SVG textures**, not deleted — six
strings is a genuine art pass, not a drive-by on this branch:

| Where | Glyph, in display text |
|---|---|
| `SchoolDay.gd:78` `end_tutorial_title` | `🎓` |
| `SchoolDay.gd:80` `end_tutorial_text` | `🎯`, and `➔` twice |
| `SchoolDay.gd:437` → `status_label` | `✓` |
| `SchoolDay.gd:959` → `status_label` | `🌿` |
| `SchoolDay.tscn:95` `ClickToContinueLabel` | `✨`, `➔` |
| `SchoolDay.tscn:113` `SkipButton` | `⏭` |

`SchoolDay.tscn:105`'s `BackButton` `"🔙 Kembali ke Menu"` is **not in this
list**: it is already in `DEBT.md:248`, and the back-button-icon branch owns
that node.

And the opposite, so nobody "fixes" it: the 📚/⚽/🎨 at `SchoolDay.gd:537-538`
and `:628-655` are **icon keys**, not display text — `_add_pill()` strips them
and swaps in a texture at `:660-682`. They are never drawn. `DEBT.md:300-303`
already says so.

> **Who writes the emoji ledger.** Not this spec.
> `docs/superpowers/specs/2026-09-21-back-button-icon-design.md` already
> rewrites `DEBT.md:248-252` — it fixes the `🔙` that paragraph records — so
> two specs editing the same paragraph would be a merge collision for no gain.
> **That spec owns all emoji `DEBT.md` bookkeeping**, including adding the six
> rows above and the icon-key exemption. This spec writes **nothing** to
> `DEBT.md` about emoji; it only makes the one-word code change at `:1327` and
> guards it. The plan must order the two branches so the ledger lands once.

### 1c. Re-anchor `DayScreen` clear of the header

One node, four anchors, four offsets. No reparent, no new node, no path change.

| Property | Before | After |
|---|---|---|
| `anchor_left` | `0.05` | **`0.0`** |
| `anchor_top` | `0.06` | **`0.0`** |
| `anchor_right` | `0.95` | **`1.0`** |
| `anchor_bottom` | `0.94` | **`1.0`** |
| `offset_left` | `0.0` | **`54.0`** |
| `offset_top` | `0.0` | **`320.0`** |
| `offset_right` | `0.0` | **`-54.0`** |
| `offset_bottom` | `0.0` | **`-144.0`** |
| `theme_override_constants/separation` | `18` | `18` — unchanged (layout-only constant, the one permitted override) |

Everything else in the scene is untouched. `DayNumberLabel`, `ProgressBar`,
`StatusLabel`, `StudentScroll` → `StudentStatusContainer`,
`ClickToContinueLabel`, `BackButton` and `SkipButton` keep their paths, their
`layout_mode = 2`, their theme variations and their stacking order.

```
 AFTER — 1080 x 1920, the band cleared
 ─────────────────────────────────────────────────────────────────────────

 y=44   ┌───────────┐                                      ┐
        │ Calendar  │   ┌──────────────────────────────┐   │ BookClockWidget
 y=100  │  "Minggu" │   │  DayBanner:  Senin           │   │ Header — untouched
 y=236  │   "2/6"   │   └──────────────────────────────┘   │ (anchors 0,0,1,0;
 y=292  └───────────┘                                      ┘  offset_bottom 300)
 y=300  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   Header bottom
        ░░░░░░░░░ 28 px of clear air below the badge ░░░░░░░
 y=320  ┌────────────────────────────────────────────────┐ ┐
 y=350  │            Hari 1 dari 5            (h ≈ 30)   │ │ DayScreen
 y=368  │ ███████████████████████░░░░░░░░░░░░░░░░░░░░░░░ │ │ VBoxContainer
 y=428  │                                      (h = 60)  │ │ x 54..1026
 y=446  │        Perjalanan ke sekolah...     (h ≈ 48)   │ │ y 320..1776
 y=494  ├────────────────────────────────────────────────┤ │ separation 18
 y=512  │  StudentScroll → StudentStatusContainer        │ │
        │  ClickToContinueLabel / BackButton / SkipButton│ │
 y=1776 └────────────────────────────────────────────────┘ ┘
```

The stack, top-down, with `separation = 18`: `DayNumberLabel` `320..~350`,
`ProgressBar` `368..428`, `StatusLabel` `446..~494`, then `StudentScroll` from
`512`. The badge's bottom is 292, so **the bar clears it by 76 px** and the
caption clears it by 28 px — in the editor and at runtime alike.

**What is preserved and what deliberately moves.** The horizontal band is
identical: `0.05 × 1080 = 54` and `0.95 × 1080 = 1026` become the offsets `54`
and `-54`, the same x 54..1026. The **top** moves 115.2 → 320, which is the fix.
The **bottom** moves 1804.8 → 1776 at 1920, a deliberate 28.8 px gain — see §7
for why `-144.0` rather than `-115.2`.

`StudentScroll` shrinks. With the bar visible (its worst case) the stack above
it is `30 + 18 + 60 + 18 + 48 + 18 = 192` px, so at 1920 the scroll goes from
**1497.6 px to 1264 px**, a 233.6 px loss. It carries `size_flags_vertical = 3`
and is a `ScrollContainer`, so it absorbs the loss and its content scrolls — no
row is cut off. (For most of the day the bar is hidden and the scroll is 78 px
taller than that.)

### 1d. What this does and does not fix on a tall phone

`BookClockWidget/Header` is anchored `0 / 0 / 1 / 0` with `offset_bottom = 300`
— **pixels from the top edge**, the same on every phone. `DayScreen`'s top was
`anchor_top = 0.06` — **a fraction of screen height**:

| | 1080×1920 | 1080×2400 (20:9) |
|---|---|---|
| Header bottom | y 300 | y 300 |
| `DayScreen` top, **before** | y 115.2 → 184.8 px inside the header | y 144.0 → 156 px inside the header |
| `DayScreen` top, **after** | y 320 → 20 px clear | y 320 → 20 px clear |

**The collision exists at every aspect**, and it is not a tall-phone bug: at
1920 the stack starts 184.8 px inside the header, at 2400 it starts 156 px
inside it. The 28.8 px of difference between them is drift, and it is noise next
to the overlap. Pinning both edges in pixels fixes that drift as a side effect,
and is the correct way to express "clear a pixel-anchored header" — but the
branch is not claiming to fix a tall-phone defect.

For the record: `SchoolDay` is **not** on `DEBT.md:444`'s deferred tall-phone
list (that list names AturJadwal, CutScene, Rapor, Inventory, StatCheck,
EndCutscene, the ResultCheckup confetti and MainBola), and
`docs/superpowers/specs/2026-09-15-tall-phone-layout-design.md:315` audits
SchoolDay as **"fine"** at 1080×2400. The one thing that genuinely changes at
2400 is the bottom inset, and §7 handles it.

### 1e. "Akhir Pekan" — the silent regression

`SchoolDay.gd:1328` writes `"Akhir Pekan"` into a node that has been permanently
invisible since `ba98d10`, so the player never sees the end-of-week banner.
Deleting `DayLabel` must not quietly delete the message too.

It is routed to the widget's own day slot. `BookClockWidget.gd`'s `set_day()`
also calls `set_progress(0.0)`, which would snap the sky back to sunrise on the
week's closing screen — so `set_day()` is split rather than reused:

```gdscript
## Writes the banner without moving the sky. The week's closing screen shows
## "Akhir Pekan" over an evening sky, so it must not rewind to morning.
func set_banner(text: String) -> void:
	_day_name = text
	_write_header()


## Starts a fresh day. Records the weekday, writes it to the banner and
## rewinds the sky to morning.
func set_day(day_name_in: String) -> void:
	set_banner(day_name_in)
	set_progress(0.0)
```

`SchoolDay.gd:1328` becomes:

```gdscript
	if book_clock_widget and book_clock_widget.has_method("set_banner"):
		book_clock_widget.call("set_banner", "Akhir Pekan")
```

`day_name()` keeps returning whatever was last written, so
`tests/test_book_clock_phases.gd:190-195` is unaffected.

**It fits the pill — measured, not assumed.** `Header/DayBanner` is authored at
x 250..936 — 686 px — and `DayBannerPanel`'s stylebox sets
`content_margin_left = space_xl + space_lg = 72 + 44 = 116` and
`content_margin_right = space_lg = 44` (`ThemeFactory.gd:144-146`,
`DesignTokens.gd:210-212`), leaving a **526 px** text box.

The face is **Open Sans Bold**, not Boohong. `DayBannerLabel` is built at
`ThemeFactory.gd:149-156` inside `_build_event_dialogue()`, whose `bold` is
`tokens.font_body_bold` (`:112`); `DesignTokens.gd:249` documents it as *"Bold
body face (Open Sans Bold) for EventDialogueText, DayBannerLabel and
CalendarLabel"*; and `tests/test_event_dialogue.gd:307` pins it
(`assert_eq(theme.get_font("font", "DayBannerLabel"), t.font_body_bold)`). It is
also absent from `DISPLAY_ROSTER` in `tests/test_theme_factory.gd`, which is the
other direction of the same pin. The size is `font_h1 = 64`
(`DesignTokens.gd:264`).

Measured from the project's own font files at em = 64 px: **"Akhir Pekan" is
422.5 px in Open Sans Bold** — and 490.5 px even under the wrong Boohong
assumption — against the 526 px box. **It fits, with ~104 px of headroom.**

The risk it was checked against is real and stays worth guarding:
`DayBanner` is a `PanelContainer`, so an overrun grows the pill past its
authored x 936, and `BookClockWidget`'s root has `clip_contents = true`, so the
banner would then be cut at the widget's edge, mid-word. §6c therefore keeps a
**regression guard** — a real `Font.get_string_size` measurement against
526 px, not a source scan for the string — with the theme actually assigned so
the assert can fail (§6c spells out why that matters).

No fallback ladder is carried. Had it overrun, the remedies would have been to
widen the authored pill in `BookClockWidget.tscn` (a drag; `EventDialogue.tscn`
keeps its own copy) or to shorten the string. A narrower `DayBannerLabel`
variation — the only remedy that would have cost a `ThemeFactory` change **and a
rebake** — is dead and is not specced.

The Wirausaha chip at `SchoolDay.gd:1336` —
`status_label.get_parent().add_child(wirausaha_chip)` — needs **no** change:
`StatusLabel`'s parent is still the same `VBoxContainer`, so the chip still
stacks under it.

### 1f. Extent — and the one-line follow-up if the user wants more

**Deleted:** `DayScreen/DayLabel` only, the duplicated weekday.

**Kept, and moved only by their container:** `DayNumberLabel`
("Hari 1 dari 5"), `StatusLabel` and `ProgressBar`. They carry facts the header
does not — the day's place in the week, and the current phase of the day — so
they stop colliding because the stack moves, not because they go. This is
`decisions.md` §"Item 1" decision 3, unchanged.

**If the user does want "Hari 1 dari 5" gone as well**, that is a one-line
follow-up: set `DayScreen/DayNumberLabel`'s `visible = false` in
`SchoolDay.tscn` and flip `tests/test_school_day.gd:733`'s
`test_the_day_number_is_still_shown` to assert the opposite. The VBox simply
closes the gap. Same again for `StatusLabel`.

### 1g. The alternative reading, costed

"Remove the old texts" could instead mean *all* of `DayScreen`'s legacy text
chrome, not just the one duplicated weekday. That is a different **shape** of
fix, not a bigger one, so it is costed here — if the user picks it at the plan
gate it is a small edit, not a re-spec.

**What it would be:** `DayLabel` still deleted, plus `visible = false` on three
nodes — `DayScreen/DayNumberLabel`, `DayScreen/StatusLabel`,
`DayScreen/ProgressBar`. Invisible children take no space in a
`VBoxContainer`, so the stack closes up on its own and `StudentScroll` rises to
the top of `DayScreen`.

**And two code edits, which are not optional.** A `.tscn` `visible = false` on
`ProgressBar` is **undone at runtime**: `SchoolDay.gd:438` calls
`progress_bar.show()` at the end of every day, and `:1329` calls it again at week
end, immediately before `Juice.fill_bar(progress_bar, 100.0)` at `:1330`. Left
alone, the bar reappears over the calendar badge every single day and at week
end — the exact bug this branch exists to remove, shipped inside the fix for it.
So this path must also delete or guard `:438` and `:1329`, and decide what
`:1330`'s fill is now animating (a hidden bar still tweens; the call becomes
dead motion and should go with the `show()`).

`DayNumberLabel` and `StatusLabel` have no equivalent trap: nothing calls
`.show()` on either, and their writes (`:358`, `:360`, `:396`, `:429`, `:437`,
`:959`, `:1327`, `:1331`, `:1524-1525`) only set `.text`, which is harmless on a
hidden node.

**What it would drop from this spec:** the whole of §1c's re-anchor (eight
property writes), §1d, §7's rect table, and both new anchor tests in §6c. The
re-anchor becomes unnecessary because nothing is left in the band to collide.

**What it would cost in tests:**

| Suite / test | Change |
|---|---|
| `test_school_day.gd:733` `test_the_day_number_is_still_shown` | inverts — must assert `visible = false` |
| `test_school_day.gd:703` `test_the_hidden_day_label_is_not_un_hidden_by_the_chrome_toggle` | inverts at `:712`: by that test's own logic a permanently hidden node must **not** be in `_DAY_CHROME_PATHS`, so all three entries leave and the `assert_true` becomes `assert_false` |
| `test_day_summary.gd:1027-1038` | still green, but `_set_day_chrome_visible` would be looping an **empty** list. Either it takes `"DayScreen/StudentScroll"` instead, or it is deleted — and deleting it breaks this test. A decision the user's answer forces |
| `test_school_day.gd:258` `test_day_progress_bar_is_a_statbar_filled_through_juice` | still green — the node still exists with its `StatBar` script |

**Size:** one deletion, three property writes **and two code edits**
(`SchoolDay.gd:438`, `:1329-1330`), against this spec's one deletion plus eight
property writes and two new tests. Still cheaper, and still a small edit — but
not the three-line edit an earlier draft of this subsection advertised, and the
difference is a shipped bug, so the two call sites are named rather than left to
be found. It also costs the player the day's place in the week and the day's
current phase, which is exactly why `decisions.md` chose to keep them. **The
default stands;** this subsection exists so the alternative is cheap and
correct, not so it is cheap.

---

## 2. Item 2 — the "fireworks" that are confetti

### 2a. The defect, in one line

`ConfettiFireworks.tscn`'s three bursts point at **the same texture uid**
(`uid://skr3tjxap0qw`, `particle_confetti.png`) as `ResultConfetti.tscn`, with
the same rounded-rect chip silhouette, the same scale range and the same
±320 °/s tumble, and **neither sets any colour**, so both render flat white.
Every difference between the two is ballistics. Nothing in the appearance
column differs — which is exactly the user's report.

Three sub-symptoms, all authored in the `.tscn`, none in code:

| User's words | Cause |
|---|---|
| "the same as the conffeti" | identical texture, identical (absent) colour, identical scale |
| "three colors" | the red/yellow/blue the user knows is `Scenes/SchoolSimulation/PaperConfetti.tscn:13-16`; these bursts have **no** ramp, so they read as another instance of "that confetti idea" |
| "flipping like papers" | `angular_velocity ±320` on a rounded **rectangle**, made live by `particle_flag_disable_z = true` |

Placement and the crosshair-ring `@tool` gizmo are the user's own design
(`55504cd`) and **do not change**. Only the appearance does. The filenames
`ConfettiFireworks.tscn` / `.gd` stay — CLAUDE.md warns against "fixing"
load-bearing names, and a rename is blast radius for no player-visible gain.
The doc comments are updated instead.

### 2b. The texture: `particle_spark.png`, already on disk

All three bursts point at
**`res://Assets/Images/Particles/particle_spark.png`**
(`uid://d4lt82q0pi5xe`, 983 B, 128×128). **No new asset is created**, and
`Scripts/Design/GenerateParticleSprites.gd` is not touched.

**Why it is the right silhouette.** Its alpha was sampled directly: 255 at the
centre, falling to 0 at r = 63 along both the horizontal and the vertical axis,
and **exactly 0 on the diagonals at every radius**. That is a four-point
star-flare, not a disc and not a chip — the classic firework-spark shape, and a
better one than a round dot would be. It is white, so the per-burst
`color_initial_ramp` in §2d tints it freely, exactly as the confetti sprite is
tinted nowhere today.

**Why sharing this texture is fine, when sharing the confetti texture was the
whole defect.** `particle_spark.png` is already thrown by two other effects:

| Scene | Screen | Colour | Ballistics |
|---|---|---|---|
| `Scenes/Minigames/UI/ScorePopBurst.tscn` | the **in-play score HUD**, on a score tick — `MinigameScoreHUD.gd:26-27`; it has no result-card use at all | none (white) | `spread 55`, `velocity 70-150`, `gravity 300`, `scale 0.12-0.22`, `lifetime 0.45` |
| `Scenes/SchoolSimulation/RewardBurst.tscn` | ResultCheckup / StatCheck, on a bar that clears | `Color(1, 0.843, 0.416)` gold | `spread` default, `velocity 120-260`, `gravity 420`, `scale 0.18-0.34` |
| **These bursts** | the result card's **3-star volley** | three different shell ramps, §2d | `spread 180`, `velocity 320-500`, `gravity 180`, `damping 90-140`, `scale 0.26-0.48`, `lifetime 1.35` |

The confetti case was different in kind: `ConfettiFireworks` and
`ResultConfetti` fire **on the same screen, in the same second, both white,
both tumbling, at the same scale**. Neither spark user is on that screen at that
moment — `ScorePopBurst` belongs to the minigame itself and is gone by the time
the result card appears, and `RewardBurst` lives on ResultCheckup and StatCheck.
Two effects that share only a silhouette, on different screens, with different
colour and roughly triple the velocity and spread, do not read as each other.

`ScorePopBurst` is still white and uncoloured, and stays that way — these bursts
are the only spark user that gains a ramp, which is a further separation, not a
clash.

**Scale, re-checked against a four-point sparkle.** The confetti chip fills 60 %
of the canvas width and 90 % of its height as a solid rounded rectangle, so at
`scale 0.25-0.5` its on-screen mass was roughly 19×29 to 38×58 px of opaque
pixels. The sparkle spans the whole 128 px along its two axes but carries alpha
on only those axes, so **at the same scale number it reads substantially
smaller**. The earlier draft's `0.16-0.30` was sized for a disc and would give a
20-38 px flare with a ~6-14 px bright core — too faint on a 1080-wide phone.
Raised to:

| | Burst 1 | Burst 2 | Burst 3 |
|---|---|---|---|
| `scale_min` | **0.26** | **0.26** | **0.28** |
| `scale_max` | **0.44** | **0.44** | **0.48** |

That is a 33-61 px flare: the same overall footprint as the old chip, with about
a third of the opaque area, which is what a spark should be. The range is raised
at the bottom and tightened at the top relative to the confetti's 0.25-0.5.

**These two numbers are a task-time check, not a frozen decision.** The flare
size is arithmetic (128 × 0.26 = 33.3, × 0.48 = 61.4); how bright the core reads
at that size is a look judgement nobody has seen yet. **No test in §6c asserts
`scale_min` or `scale_max`**, deliberately — so one capture of a 3-star result
at `Engine.time_scale = 0.02` during the task corrects two `.tscn` numbers at
zero cost. It is not a reason to hold the plan.

### 2c. The three bursts, property by property

Every value below is authored in `Scenes/Minigames/UI/ConfettiFireworks.tscn`.
No script change is needed for any of it, which keeps the ratchet at zero.

**Node properties** (`Bursts/Burst1`, `Burst2`, `Burst3`):

| Property | Before (all three) | After |
|---|---|---|
| `texture` | `particle_confetti.png` (`uid://skr3tjxap0qw`) | **`particle_spark.png`** (`uid://d4lt82q0pi5xe`) |
| `amount` | 26 | **48** |
| `lifetime` | 1.1 | **1.35** |
| `explosiveness` | 0.95 | **1.0** |
| `one_shot` | true | true |
| `emitting` | false | false |
| `visibility_rect` | **unset** → Godot's 200×200 default | **`Rect2(-900, -900, 1800, 1800)`** |
| `position` | `(250,760)` / `(830,700)` / `(540,1020)` | **unchanged** |

**The `visibility_rect` is hygiene, not a bug being fixed.** `GPUParticles2D`'s
`visibility_rect` gates whether the **node** is processed, not where its
particles may draw; it never clips. All three emitters sit at on-screen
positions — `(250,760)`, `(830,700)`, `(540,1020)` on a full-rect `Dim` — so the
node has always been active and every particle has always drawn. Nothing has
been culled, and the CHANGELOG must not claim otherwise. The rect is set to
match `Scenes/SchoolSimulation/PaperConfetti.tscn` and to protect a future
reparent or off-screen placement; `Rect2(-900, -900, 1800, 1800)` covers the
farthest a spark can travel (500 px/s × 1.35 s + ½ × 180 × 1.35² ≈ 839 px).

**`ParticleProcessMaterial_burst1/2/3`** — three byte-identical copies today;
they diverge so the volley escalates the way `STAR_POP_SCALES` already does:

| Property | Before (all three) | Burst 1 | Burst 2 | Burst 3 |
|---|---|---|---|---|
| `particle_flag_disable_z` | true | true | true | true |
| `emission_shape` | 1 (sphere) | 1 | 1 | 1 |
| `emission_sphere_radius` | 14.0 | **6.0** | **6.0** | **6.0** |
| `direction` | `(0,-1,0)` | `(0,-1,0)` | `(0,-1,0)` | `(0,-1,0)` |
| `spread` | 55.0 | **180.0** | **180.0** | **180.0** |
| `initial_velocity_min` | 260.0 | **320.0** | **360.0** | **400.0** |
| `initial_velocity_max` | 520.0 | **400.0** | **450.0** | **500.0** |
| `angular_velocity_min` | −320.0 | **0.0** | **0.0** | **0.0** |
| `angular_velocity_max` | 320.0 | **0.0** | **0.0** | **0.0** |
| `damping_min` | unset | **90.0** | **90.0** | **90.0** |
| `damping_max` | unset | **140.0** | **140.0** | **140.0** |
| `gravity` | `(0,620,0)` | **`(0,180,0)`** | **`(0,180,0)`** | **`(0,180,0)`** |
| `scale_min` | 0.25 | **0.26** | **0.26** | **0.28** |
| `scale_max` | 0.5 | **0.44** | **0.44** | **0.48** |
| `color_initial_ramp` | unset | **`GradientTexture1D_shell1`** | **`_shell2`** | **`_shell3`** |
| `color_ramp` | unset | **`GradientTexture1D_fade`** (shared) | same | same |

`spread = 180` opens the shell in every direction (`StarBurst.tscn:11` already
does this); `damping` is what makes the ring bloom and then hang instead of
sailing off; `gravity` drops from 620 to 180 because sparks drift, they do not
fall like paper.

`angular_velocity_*` is **set to 0.0 explicitly, not deleted**. Deleting a
property line from a `.tscn` does not reset it in a running editor's cache
(`CHANGELOG.md:1362-1365`) — the old ±320 would survive an in-place reload. It
matters less than it did now that the sprite is four-fold symmetric, but a
90°-symmetric flare still visibly rotates, so the value is written.

### 2d. Colour — three shells, and a fade

Five new `SubResource`s in the `.tscn`: one shared fade, plus one shell gradient
per burst. Godot multiplies `color_initial_ramp` (sampled once per particle at
spawn) by `color_ramp` (sampled over the particle's life), so a white-RGB fade
ramp and a coloured initial ramp compose cleanly.

**Shared fade** — the single biggest tell that this is not a firework today is
that every piece vanishes at full opacity:

```
[sub_resource type="Gradient" id="Gradient_fade"]
offsets = PackedFloat32Array(0, 0.55, 1)
colors  = PackedColorArray(1,1,1,1,  1,1,1,1,  1,1,1,0)
[sub_resource type="GradientTexture1D" id="GradientTexture1D_fade"]
gradient = SubResource("Gradient_fade")
```

**Three shells**, each `interpolation_mode = 1` (constant), two stops: the shell
hue and its hot highlight. One hue per burst — a real firework shell is one
colour, and one colour per burst is the opposite of "three colors mixed
together":

| Burst | Shell | Highlight |
|---|---|---|
| 1 — left, `(250,760)` | **`#FF8A3D`** amber | **`#FFD9B0`** |
| 2 — right, `(830,700)` | **`#FF5FA2`** rose | **`#FFC2DC`** |
| 3 — low centre, `(540,1020)` | **`#4ADEDE`** turquoise | **`#C4FBFB`** |

Amber / rose / turquoise deliberately shares no hue with
`Scenes/SchoolSimulation/PaperConfetti.tscn`'s red `#E5484D` / yellow `#FFC93C` /
blue `#3B82F6` — that palette is the very thing the user says this already looks
like, so it is not reused here. It is also distinct from `RewardBurst.tscn`'s
gold `Color(1, 0.843, 0.416)`.

Exact `PackedColorArray` values, in the order the `.tscn` wants them:

```
Gradient_shell1  offsets (0, 0.5)  colors (1, 0.5411765, 0.23921569, 1,  1, 0.85098039, 0.69019608, 1)
Gradient_shell2  offsets (0, 0.5)  colors (1, 0.37254902, 0.63529412, 1,  1, 0.76078431, 0.8627451, 1)
Gradient_shell3  offsets (0, 0.5)  colors (0.29019608, 0.87058824, 0.87058824, 1,  0.76862745, 0.98431373, 0.98431373, 1)
```

**Not done, and why.** No particle trail (`trail_enabled` needs
`trail_sections` tuning and a ribbon-friendly texture — the fade plus damping
already reads as a shell) and no `particle_ring.png` shockwave (a fourth node
per burst triples the scene for a second-order gain). Both are listed as
follow-ups in `DEBT.md`.

### 2e. The volley fires on losses

`MinigameResultPopup.gd:287` calls `fireworks.fire_burst(star_index)`
unconditionally inside the star loop, which walks **all three** `StarRow`
children whether earned or not. Its own comment at `:283-286` claims a short
volley; `star_row` always has exactly three children
(`MinigameResultPopup.tscn:50-57`), so the index never goes out of range and
the volley is never short. A one-star, loss-adjacent result gets the full
three-burst celebration today. This is a real defect on its own, not deferred
viewport work.

`_star_count` is the right gate: `configure()` sets `_star_count = stars` at
`:135`, the star loop's own `filled := i < stars` at `:164` uses the identical
comparison, and `ResultStar.celebrate()` already self-gates on `is_filled`
(`ResultStar.gd:79`) — so `fire_burst` is the **only** thing firing on an
unearned star.

```gdscript
		star.celebrate(star_index)
		# One firework per EARNED star, at the burst's own authored place on
		# the screen rather than behind the star. A one- or two-star finish
		# leaves the remaining bursts quiet -- a celebration on a near-miss is
		# the tonal miss this gate exists to prevent.
		if star_index < _star_count:
			fireworks.fire_burst(star_index)
```

`ConfettiFireworks.gd:73-75`'s matching doc comment is corrected in the same
change: out-of-range is still ignored, but the *caller* is now what makes a
volley short.

`Dim/ResultConfetti` — the separate full-house rain gated at
`CONFETTI_STAR_THRESHOLD = 3` — is **untouched**, per `decisions.md`, which
scopes item 2 to the bursts.

**The consequence, stated rather than hidden.** At exactly 3 stars the popup
fires *both*, so after this branch a full house shows three coloured spark
shells **next to the same white, tumbling paper rain**.

That is an aesthetic consequence, not evidence of a mis-aimed fix, and it is
arguably the requested outcome: the complaint is that the two currently read as
one effect, and this is what stops them doing so. The user's own words —
*"the fireworks particles is the same as the conffeti"* — name the **bursts** as
what looks wrong and the confetti as the **reference** they are being compared
against. Item 2 changes the bursts. Colouring the rain is **not** in scope; the
user did not ask for it, and widening scope on a guess is how a two-item branch
becomes a four-item one. It goes to `DEBT.md` as a one-line follow-up (§4).

**And `recon-fireworks` §3b's parked "three colors" reading is closed from
source**, so nothing here waits on a screenshot:
`MinigameResultPopup.gd:192` applies `_CATEGORY_COLORS` to
`badge_icon.self_modulate` and to nothing else — it never touches either
emitter; `Scripts/SchoolSimulation/RewardParticles.gd` contains no
`color` / `modulate` / `ramp` at all; and neither does
`Scenes/Minigames/UI/ResultConfetti.tscn`. No colour is applied anywhere in the
minigame result path, so both emitters are unambiguously white and three
coloured pieces are not reproducible there. The user was naming the game's known
red/yellow/blue paper burst as a comparison, which is reading 1 of
`recon-fireworks` §3b.

---

## 3. State

**Neither item touches game state.**

- Item 1 deletes one scene node, re-points three `Label.text` writes and changes
  eight numbers on one container. `SchoolDay.gd` still reads
  `GameState.minggu_ke` and `GameState.get_max_weeks()` exactly as it does
  today, to feed the header.
- Item 2 is entirely `.tscn` particle data plus one `if` in the popup's reveal
  loop.

Nothing here reads or writes `GameState.approved_students` or constructs a
`StudentData`, so the bridge's naming trap — `akademis2` (seni_budaya),
`akademis3` (olahraga), `kepribadian1` (**mood**), `kepribadian2` (**energy**) —
does not apply to this branch. `GameState.inventory`, the one persisted field,
is untouched, as are `Achievements`, `Cart` and `GameSettings`.

---

## 4. Files

| File | Change |
|---|---|
| `Scenes/SchoolSimulation/SchoolDay.tscn` | delete `DayScreen/DayLabel`; re-anchor `DayScreen` to `0/0/1/1` with offsets `54 / 320 / -54 / -144` |
| `Scripts/SchoolSimulation/SchoolDay.gd` | drop `@onready day_label` (`:87`) and its writes (`:359`, `:1328`, `:1523`); `"Akhir Pekan"` → `book_clock_widget.call("set_banner", …)`; `:1327` loses its `🎉` |
| `Scripts/SchoolSimulation/BookClockWidget.gd` | new `set_banner()`; `set_day()` delegates to it |
| `Scenes/Minigames/UI/ConfettiFireworks.tscn` | `particle_spark.png`, five colour sub-resources, `visibility_rect`, spin to 0, the per-burst ballistics table in §2c |
| `Scripts/Minigames/UI/ConfettiFireworks.gd` | header + `fire_burst()` doc comments corrected — **no code change** |
| `Scripts/Minigames/UI/MinigameResultPopup.gd` | `:287` gated on `star_index < _star_count`; `:283-286` comment corrected |
| `tests/test_school_day.gd` | see §6 |
| `tests/test_book_clock_phases.gd` | see §6 |
| `tests/test_confetti_fireworks.gd` | see §6 |
| `docs/superpowers/DEBT.md` | see below |
| `docs/superpowers/CHANGELOG.md` | one entry, newest first |

**No new asset. `Scripts/Design/GenerateParticleSprites.gd` is not touched**, so
there is no manual File > Run step and no new `.import` to scan in.

`tests/test_book_clock_phases.gd` also gains a **fixture** change, not just
tests: `_widget()` (`:21-24`) assigns `res://Assets/Theme/kejartes_theme.tres`.
That is what makes §6c's pill measurement capable of failing, and it benefits
every later test in that suite that touches a themed property.

`DEBT.md` gets **four** edits, grouped rather than one entry per item. It gets
**no emoji edit at all**: `2026-09-21-back-button-icon-design.md` already
rewrites `DEBT.md:248-252`, so that spec owns the whole emoji ledger and this
one stays out of the paragraph (§1b).

1. **New grouped entry, deferred section:** *viewport-draggable positioning
   across the game* — what it is, Option B (~50 of 123 BASELINE points, 6-8
   tasks) and Option C (123 points across 20 files, ~265 container subtrees,
   tall-phone Phases 2-3, 30-50+ tasks), the two screens already analysed
   (SchoolDay's `DayScreen` VBox and `MinigameResultPopup`'s container tree, both
   still undraggable after this branch), and a pointer to
   `.superpowers/gamecode/editor-tunable-polish/recon-viewport.md`.
2. **New line on the fireworks follow-ups:** particle trails and a
   `particle_ring.png` shockwave per burst, both deliberately out of §2c — plus
   one line recording that at 3 stars the newly coloured shells now fire beside
   a still-white, still-tumbling `Dim/ResultConfetti` rain. Out of scope because
   the user did not ask for it (§2e); written down so the next pass does not
   have to rediscover it.
3. **`:324-329`, the BookClockWidget editor hang:** one dated line — *2026-09-21:
   the scene opened by hand this session, and MCP `scene_open` on it also
   succeeded cleanly (`settle: "settled"`, no timeout) on Godot 4.6.2-stable with
   plugin 3.2.5; `test_run(suite="book_clock_phases")` then ran 24/24 green
   against it as the edited scene and the bridge survived. The entry may be
   stale or specific to an older plugin build.* The entry is **not** deleted.
4. **`:421-424`'s stale ratchet count** (23 entries / 22 nonzero / 131) is
   corrected to 21 / 20 / 123 for `BASELINE`, 30 / 130 including `ALLOWED`.
**Handed to the back-button spec, not done here:** the grouped entry for
`SchoolDay`'s six remaining display-text emoji, the icon-key exemption, and the
extension of `DEBT.md:248-252` (which is incomplete — it names only
`BackButton`'s `🔙` and CutScene's `🏫`/`🎓`, and reads as if that were the whole
list). All three belong in the branch that is already rewriting that paragraph.
§1b carries the six rows as evidence so the hand-off has something to copy.

No `theme_override_*` is added anywhere. `DayScreen`'s existing
`theme_override_constants/separation = 18` is a layout-only constant and stays.
No `ThemeFactory` variation changes and no node changes its variation, so **no
rebake at all** — §1e's measurement settled the one thing that could have forced
one, and that contingency is deleted rather than carried. `test_book_clock_phases`
*loads* the baked theme; it does not write it.

---

## 5. Kelas 7 / 8 / 9

**Tidak berbeda per kelas** — for both items.

Item 1 deletes a node and moves a container. The one grade-scaled string on the
screen is the header's week fraction, already fed by `GameState.get_max_weeks()`
(6 / 12 / 16), which this branch does not touch. Deleting `DayLabel` does not
change what `set_week()` writes, and `"Hari %d dari %d"` counts weekdays, which
is 5 in every grade.

Item 2 is particle appearance. The minigame win/loss stat deltas are grade-scaled
(10 / 8 / 6 on a win, −3 / −4 / −5 on a loss), but the celebration does not read
them — it reads `_star_count`, which is 0-3 in every grade.

`Balance.gd` is not read and not edited: it is the collaborator's file.

---

## 6. Tests

Every suite here is already `@tool extends McpTestSuite`. **No test added below
is a coroutine** — the runner calls each one without awaiting, so an `await`
aborts the test silently and reports "0 assertions".

### 6a. Existing tests that break

**Exactly one**, because nothing is reparented and no node path changes:

| Suite | Test | Today | Must become |
|---|---|---|---|
| `tests/test_school_day.gd` | `test_the_day_name_is_not_shown_twice` (`:689-695`, docstring from `:683`) | `_scene_node_block('[node name="DayLabel" type="Label" parent="DayScreen"')` must be `!= ""`, and the block must contain `visible = false` | the block must be `""`. Rename to `test_the_duplicated_day_name_is_gone`; the docstring records that the user made the call `ba98d10` deferred, replacing the "hidden, not deleted" rationale |

### 6b. Existing tests that stay green untouched

Worth naming, because the re-anchor was chosen partly to keep them so:

| Suite | Test | Why it survives |
|---|---|---|
| `tests/test_school_day.gd` | `test_the_hidden_day_label_is_not_un_hidden_by_the_chrome_toggle` (`:703-713`) | `_DAY_CHROME_PATHS` is unchanged: it still omits `"DayScreen/DayLabel"` and still lists `"DayScreen/DayNumberLabel"`. Only its docstring is refreshed — the label is now gone, not hidden |
| `tests/test_school_day.gd` | `test_the_day_number_is_still_shown` (`:733-740`) | `DayNumberLabel` keeps `parent="DayScreen"` and stays visible |
| `tests/test_school_day.gd` | `test_day_progress_bar_is_a_statbar_filled_through_juice` (`:258-263`) | `DayScreen/ProgressBar` keeps its path and its `StatBar` script |
| `tests/test_school_day.gd` | `test_interactive_controls_meet_the_minimum_touch_target` (`:229-253`) | `DayScreen/BackButton`, `DayScreen/SkipButton` keep their paths and their `custom_minimum_size` |
| `tests/test_school_day.gd` | `test_scenes_have_no_theme_overrides` (`:204-213`, helper `:327-345`) | `_collect_overrides` flags only `theme_override_colors/ font_sizes/ styles`; `constants/separation` is exempt by omission, and no new override is added |
| `tests/test_sky_transition.gd` | `test_the_cinematic_is_a_full_screen_backdrop_not_a_vbox_row` (`:301-311`) | no root child is added or removed, so `Background < BookClockWidget < DayScreen` holds |
| `tests/test_book_clock_phases.gd` | `:182-295`, all nine | `set_day()` keeps its signature and still writes the banner; `set_week()` and the header's three Labels are untouched |
| `tests/test_day_summary.gd` | `test_school_day_hides_its_chrome_behind_the_summary` (`:1027-1038`) | `_set_day_chrome_visible` keeps its name, its declaration and both call sites |
| `tests/test_minigame_result_popup.gd` | all 33 | `PARTICLE_SCENES` (`:289-293`) does not list `ConfettiFireworks.tscn`, and the node-path list at `:60` lists `Dim/ResultConfetti` but not `Dim/ConfettiFireworks` |
| `tests/test_tall_screen_layout.gd` | all 27 | it covers five screens, none of them SchoolDay — see §7 |

No test anywhere pins `DayScreen`'s current anchors (verified by grepping
`DayScreen` and `anchor_top` across `tests/`), which is what makes "exactly one
breaks" true.

### 6c. New tests

**`tests/test_school_day.gd`** — item 1.

| New test | Asserts |
|---|---|
| `test_the_day_stack_clears_the_header_band` | **reads the header's own number rather than hardcoding it.** `var header := day.get_node_or_null("BookClockWidget/Header") as Control`; `assert_true(header != null, …)` so a rename fails loudly; then `assert_true(day_screen.offset_top >= header.offset_bottom, …)`. A hardcoded `>= 300.0` would pass while the header grew to 400 and the bar cut through "Minggu" again |
| `test_the_day_stack_is_pixel_anchored_to_both_edges` | `day_screen.anchor_top == 0.0`, `anchor_bottom == 1.0`, `anchor_left == 0.0`, `anchor_right == 1.0`. A fractional top anchor is what let the stack's distance from a pixel-anchored header change with screen height |
| `test_the_end_of_week_banner_reaches_the_player` | source scan of `SchoolDay.gd`: contains `"set_banner"` and `"Akhir Pekan"`, and no longer contains `day_label` |
| `test_the_week_end_headline_carries_no_emoji` | source scan of `SchoolDay.gd` for the 🎉 codepoint — written as `String.chr(0x1F389)` so the test file does not itself carry the glyph. Guards the §1b deletion at `:1327`. Scoped to that one codepoint on purpose: the six strings in §1b's table are the back-button spec's ledger, not this branch's work, and a blanket emoji scan would fail on them |

**`tests/test_book_clock_phases.gd`** — the new method, and the pill's width.

| New test | Asserts |
|---|---|
| `test_set_banner_writes_the_day_without_rewinding_the_sky` | `w.set_progress(0.8)`; `w.set_banner("Akhir Pekan")`; `assert_eq(w.day_text(), "Akhir Pekan")` **and** `assert_true(absf(w.progress() - 0.8) < 0.001)` |
| `test_the_week_end_banner_fits_the_pill` | see below — it needs a fixture change first |

**The fixture change that makes that test mean anything.** This suite's
`_widget()` (`:21-24`) instantiates the scene and sets `size` — it assigns **no
theme** and never enters the tree. So `get_theme_font(&"font")` and
`get_theme_font_size(&"font_size")` would resolve the *engine default* face at
its default size, and an assert of `… .x <= 526.0` would pass at any string
length: a guard that cannot fail, which reads as coverage and is worse than
none. `tests/test_school_day.gd:93-99` already solves this —
`inst.theme = load(_THEME_PATH)` against
`res://Assets/Theme/kejartes_theme.tres` — and `_widget()` takes the same line.

The test then pins the resolution *before* it measures, so a silent fallback
fails loudly rather than passing quietly:

```gdscript
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
## The pill's text box: 686 px (x 250..936) minus DayBannerPanel's
## content_margin_left 116 and content_margin_right 44 (ThemeFactory.gd:144-146).
const _BANNER_TEXT_WIDTH := 526.0

func test_the_week_end_banner_fits_the_pill() -> void:
	var w := _widget()          # now assigns _THEME_PATH
	var label := w.get_node_or_null(BookClockWidget.DAY_LABEL_PATH) as Label
	assert_true(label != null, "the day banner label must exist")
	if label == null:
		w.free()
		return
	var tokens := DesignTokens.load_default()
	var f := label.get_theme_font(&"font")
	var s := label.get_theme_font_size(&"font_size")
	# Without these two the measurement below is the engine default face and
	# the width assert can never fail.
	assert_eq(f, tokens.font_body_bold,
		"DayBannerLabel must resolve to the bold body face, not a fallback")
	assert_eq(s, tokens.font_h1, "DayBannerLabel must resolve to font_h1")
	var width := f.get_string_size(
		"Akhir Pekan", HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	assert_true(width <= _BANNER_TEXT_WIDTH,
		"\"Akhir Pekan\" measures %d px at font_size %d; the pill's text box is %d px"
			% [int(width), s, int(_BANNER_TEXT_WIDTH)])
	w.free()
```

Not a coroutine. Expected to pass with ~104 px to spare (§1e); it is a
regression guard against a longer string or a wider face, not an open question.
`tests/test_event_dialogue.gd:307` is the model for reading the face this way.

**`tests/test_confetti_fireworks.gd`** — item 2. The model to copy for a
coloured emitter is `tests/test_paper_confetti.gd`.

| Test | Change / asserts |
|---|---|
| `test_every_burst_is_confetti_not_stars` (`:54-67`) | **rewritten.** Rename to `test_every_burst_throws_a_spark_not_a_paper_chip`; assert `String(node.texture.resource_path).ends_with("particle_spark.png")`. Its stated intent — "must throw confetti, not stars" — is now the defect it was enforcing |
| `test_firing_a_burst_a_short_volley_does_not_have_is_harmless` (`:87-94`) | behaviour unchanged; docstring re-worded — the caller now makes the volley short, not an out-of-range index |
| `test_the_sparks_do_not_tumble` | **new.** For each burst, `mat.angular_velocity_min == 0.0` and `mat.angular_velocity_max == 0.0` — the "flipping like papers" symptom, pinned |
| `test_each_burst_wears_its_own_shell_colour` | **new.** Each `mat.color_initial_ramp != null`; the three ramps' first gradient colour are three **distinct** values, and none equals PaperConfetti's `#E5484D` / `#FFC93C` / `#3B82F6` |
| `test_the_sparks_fade_out` | **new.** Each `mat.color_ramp != null`, and its `gradient`'s last colour has `a == 0.0` — no hard pop at full opacity |
| `test_visibility_rect_covers_the_flight` | **new.** Each burst's `visibility_rect.size.x >= 1000` and `.y >= 1000`. Modelled on `test_paper_confetti.gd:193-199`, which asserts `> 1000` on x and `> 1500` on y for a full-screen rain; `Rect2(-900,-900,1800,1800)` passes either threshold, and 1000 on both axes is the honest bound for a radial burst |
| `test_the_shell_opens_in_every_direction` | **new.** Each `mat.spread >= 180.0` |
| `test_the_volley_is_gated_on_earned_stars` | **new.** Source scan of `MinigameResultPopup.gd` for **both** `star_index < _star_count` **and** `_star_count = stars`. The second half matters: a scan for the gate alone passes while `_star_count` is never assigned and **no** burst ever fires — the opposite tonal bug, a silent 3-star win. A behavioural assert is not available: `play()` is a coroutine and no test may await |

---

## 7. The tall-phone rule, and the bottom edge

`project.godot` sets `window/stretch/aspect="expand"`, so a 20:9 phone runs the
game at **1080×2400**. Exactly one rect moves in this branch:

| Rect | Before, at 2400 | After, at 2400 | Why it still fills |
|---|---|---|---|
| `DayScreen` | `x 54..1026`, `y 144..2256` (all four anchors fractional) | `x 54..1026`, `y 320..2256` | all four anchors become `0 / 0 / 1 / 1` with pixel offsets `54 / 320 / -54 / -144`. The top is pinned 20 px below `BookClockWidget/Header`'s pixel-anchored `offset_bottom = 300`, so the clearance is identical at every aspect; the bottom keeps the **same 144 px inset it has at 2400 today**. `StudentScroll` (`size_flags_vertical = 3`) absorbs the extra 480 px, so no band of empty space appears |
| `BookClockWidget/Header` and its children | unchanged | unchanged | already `0 / 0 / 1 / 0`, `offset_bottom = 300` |
| `ConfettiFireworks` bursts | `(250,760)` · `(830,700)` · `(540,1020)` on a Full-Rect Control | identical | positions are not touched by this branch. On a 2400-tall screen the three bursts sit 240 px higher relative to centre than on 1920 — **pre-existing**, authored by `55504cd`, and the user's own placement is explicitly kept |
| `MinigameResultPopup`'s card | `clampf(1080 × 0.78, 340, 820)` = 820, centred on a full-rect `Dim` | identical | no geometry in that popup is touched by this branch |

**Why `offset_bottom = -144.0` and not `-115.2`.** `0.94 × 1920 = 1804.8` and
`0.94 × 2400 = 2256` are two different insets — 115.2 px and 144 px — from the
same anchor. Pinning the bottom in pixels has to pick one, and the larger is the
right pick: `DayScreen`'s last visible child is `BackButton`
(`SchoolDay.tscn:99`), the only exit from the end-of-week screen, on a screen
that has **no** `SafeAreaMargin`. `-144.0` leaves the 2400 bottom edge exactly
where it is today and *gains* 28.8 px of clearance at 1920; `-115.2` would have
preserved 1920 exactly and taken 28.8 px away at 2400, moving the exit button
toward the gesture bar. The 28.8 px the 1920 layout gives up is invisible next
to the 204.8 px the stack already moves down.

**Interaction with the back-button icon work (separate branch).** The request
*"replace all return/back button icon with the new return_button in /downloads"*
will give `DayScreen/BackButton` an icon and grow it. That is safe against this
change, but the reason is subtler than it looks, so the mechanism is written out
rather than asserted — the incoming branch will read this paragraph as its
licence.

`BackButton` is **not** the last child of `DayScreen`: `SkipButton` is
(`SchoolDay.tscn:107`, after `BackButton` at `:99`). Both are authored
`visible = false`, and an invisible child takes no space in a `VBoxContainer`,
so which one sits on `DayScreen`'s bottom edge depends on the moment:

| Moment | Visible tail of the column | Bottom edge |
|---|---|---|
| During the week (`_reset_day_ui()`, `SchoolDay.gd:1526-1528`) | neither — both hidden | `StudentScroll` expands to fill; no button on screen |
| Week end (`_on_week_complete()`) | **`BackButton` only** — `:1299-1300` hides `SkipButton` *before* `:1337` shows `BackButton` | `BackButton`'s bottom = `DayScreen`'s bottom |

So at the only moment `BackButton` is on screen, it is the last **visible**
child of a bottom-anchored VBox, and its bottom edge is `DayScreen`'s bottom
edge: **144 px above the screen bottom at both 1920 and 2400** after this
branch. Growth from an icon pushes its *top* up, not its bottom down, so the
gesture-bar clearance is fixed at 144 px whatever the icon does — provided
`:1299-1300` keeps hiding `SkipButton` first. Its
`custom_minimum_size = Vector2(0, 96)` and the `touch_target_min` assertion at
`test_school_day.gd:229-253` are both unchanged by this branch.

(`SkipButton` also carries a `⏭` in its text, and `BackButton` a `🔙` — neither
is this branch's; see §1b and §4.)

**Does `tests/test_tall_screen_layout.gd` cover this?** **No.** That suite covers
**five** screens — Lobby (`:22`), Koperasi (`:201`), StudentCard (`:267`),
StudentList (`:371`) and Rapor / ReportCard (`:437`). SchoolDay is not among
them, so none of its 27 tests goes red and none needs editing.

Nor is SchoolDay deferred: it is **not** on `DEBT.md:444`'s tall-phone list, and
`docs/superpowers/specs/2026-09-15-tall-phone-layout-design.md:315` audits it as
"fine" at 1080×2400. So nothing there would catch a regression either, which is
why §6c's `test_the_day_stack_is_pixel_anchored_to_both_edges` asserts the
**authored anchors** rather than a settled rect: `anchor_top == 0.0` is the
property that makes the aspect-independent behaviour true, and it is checkable
without standing a frame up.

---

## 8. The ratchet

`tests/test_viewport_editability.gd`'s `BASELINE` (`:64-86`) — **21 entries, 20
of them nonzero, sum 123** — and `ALLOWED` (`:96-130`) — **9 entries, sum 7**.

**This change does not move either dict. 123 / 7 before, 123 / 7 after.**

| Entry | Before | After |
|---|---|---|
| `res://Scripts/SchoolSimulation/SchoolDay.gd` | 9 | **9** |
| `res://Scripts/SchoolSimulation/BookClockWidget.gd` | 0 | **0** |
| `res://Scripts/Minigames/UI/MinigameResultPopup.gd` | *(absent → implicit 0)* | **still absent** |
| `res://Scripts/Minigames/UI/ConfettiFireworks.gd` | *(absent → implicit 0)* | **still absent** |
| Totals | **123 / 7** | **123 / 7** |

Why it does not move, in both directions:

- **It cannot go up.** Nothing added here constructs a `VISUAL_TYPES` node at
  runtime. The `DayScreen` re-anchor is scene data; every particle property is
  `.tscn` data; the only `.gd` edits are a deleted `@onready`, a new pure
  method on `BookClockWidget`, one `if`, and comments. The two scripts at an
  implicit allowance of 0 stay at 0.
- **It cannot go down.** SchoolDay's nine constructions — the per-student status
  card (`:506-529`), the stat rows (`:612`, `:697-700`) and the scrim
  `Panel.new()` (`:1450`) — are untouched, so `test_baseline_is_not_stale`
  (`:227`) stays green without an edit.

**Honest statement:** the ratchet records *runtime construction*, and this branch
pays none of it off. Paying it off is the deferred item 3, now in `DEBT.md`.
`DEBT.md:424`'s claim of "23 entries, 22 of them nonzero, 131 constructions" is
stale against the current file and is corrected here.

---

## 9. Implementation hazards specific to this work

Not a wish-list — each of these has already eaten work in this repo.

1. **Never hand-edit a `.tscn` while the editor is attached.** The `DayScreen`
   anchors, the `DayLabel` deletion and every particle change go through
   `scene_open` → `node_set_property` / `node_manage` / `batch_execute` →
   `scene_save`.
2. **`anchors_preset` is inert through the bridge** — set the four anchors
   individually, unquoted (`1`, not `"1.0"`). `DayScreen` currently carries
   `anchors_preset = -1`, which stays as-is; only the four anchors and four
   offsets are written.
3. **A `ParticleProcessMaterial` edit is a resource edit**, not a node property
   — `resource_manage` or the Inspector, not a text patch.
4. **Setting `angular_velocity_*` to 0 must be an explicit write.** Deleting the
   lines does not reset the value in a live editor's cache
   (`CHANGELOG.md:1362-1365`).
5. **Scene work first, script work second.** `scene_save` flushes every open
   script tab over whatever was patched; after any `scene_save`, check
   `git diff HEAD -- '*.gd'`, and restart the editor after patching a script and
   before the next `scene_save`.
6. **`BookClockWidget.tscn` is no longer off-limits, but treat it with care.**
   `DEBT.md:324-329` records that `scene_open` on it hung the editor. On
   2026-09-21 the scene opened by hand *and* through MCP `scene_open`
   (`settle: "settled"`, no timeout) on Godot 4.6.2-stable with plugin 3.2.5,
   and `test_run(suite="book_clock_phases")` ran 24/24 green against it
   afterwards with the bridge intact. §6c's header test therefore reads
   `BookClockWidget/Header.offset_bottom` from the instanced scene rather than
   hardcoding 300. The DEBT entry keeps its dated caution; do not open the
   scene casually mid-task, and prefer a task boundary if you must.
7. **Take one 3-star capture as the first step of item 2**, at
   `Engine.time_scale = 0.02` — not 0, where every `GPUParticles2D` is invisible
   (`CHANGELOG.md:1360-1361`). It is a task-time check on the **look**, not a
   gate on the design: `scale 0.26-0.48` and the shell hues are the two things
   nobody has seen yet, and no test freezes either (§2b), so a before-and-after
   pair corrects `.tscn` numbers at zero cost. Nothing in the spec waits on it —
   the "three colors" question is closed from source in §2e.
8. **Verify the collision fix at full resolution.** A scaled-down capture cannot
   show whether the bar clears the badge; that is a 76 px judgement at the bar
   and a 28 px one at the caption.
9. **Run `book_clock_phases` alone immediately after the `_widget()` fixture
   line, before anything else in the branch.** That one line
   (`w.theme = load("res://Assets/Theme/kejartes_theme.tres")`, §6c) changes how
   **every** test in a currently-green 24/24 suite resolves themed properties.
   It is the single highest-risk edit here precisely because it looks trivial:
   `test_the_header_is_authored_with_the_shared_variations` (`:235-253`) and the
   rotation test (`:275-282`) both read the scene through a widget that has
   never had a theme before. Land the line, run the suite, then continue.
10. **Prefer targeted `test_run(suite=…)`.** For item 1: `school_day`,
    `sky_transition`, `book_clock_phases`, `day_summary`. For item 2:
    `confetti_fireworks`, `minigame_result_popup`, `paper_confetti`. Plus
    `viewport_editability` and `script_documentation` as the ratchet and doc
    guards. The green baseline for all ten is in §0. Take the full run once, at
    the end, and budget an editor restart for it.

---

## 10. Ditolak, dan yang diputuskan

Nothing in `decisions.md` is rejected outright. Four changes against the
controller's original decisions, three of them consequences of the user's
mid-run scope cut and all four binding rulings from the controller:

- **Item 3 is out of this branch entirely** — the user's own call: *"maybe delay
  the viewport positioning for now"*. The `decisions.md` §"Item 3" scope (drag
  handles on SchoolDay's band, `@export` knobs on `MinigameResultPopup`, a
  generalised placement gizmo) is not implemented here. Its analysis and both
  option sizings move to `DEBT.md` with a pointer to `recon-viewport.md`.
- **Item 1's fix is a container re-anchor, not a reparent.** `decisions.md`
  §"Item 1" decision 3 says to *move* `DayNumberLabel`, `StatusLabel` and
  `ProgressBar` clear of the header. They do move — the container they sit in
  moves, from `anchor_top = 0.06` to `offset_top = 320`. An earlier draft
  promoted them into a new plain `Control` so each would have its own drag
  handle; that was item 3a's payment and it is withdrawn with item 3. The cheap
  version keeps every node path, so exactly one existing test changes instead of
  five.
- **The four `MinigameResultPopup` geometry `@export`s are dropped** —
  `card_width_fraction`, `card_width_min`, `card_width_max`,
  `continue_button_min_size`, with `_apply_card_geometry()` and the
  `DESIGN_WIDTH` editor-stub workaround. They were `decisions.md` §"Item 3"
  verbatim and are pure item 3. The `:287` star gate in the same file is **not**
  dropped: it is a real defect in the celebration, listed under item 2's
  decisions.
- **`Scripts/Design/PlacementGizmo.gd` is dropped** — the "generalize the
  crosshair-ring gizmo" half of `decisions.md` §"Item 3". `ConfettiFireworks.gd`
  keeps its own `_draw()` exactly as the user wrote it.

And four corrections to this spec's own earlier draft, from the spec gate:

- **No new sprite.** `particle_firework.png` and a new `_draw_firework_spark()`
  in `GenerateParticleSprites.gd` are dropped. The generator is an
  `EditorScript` that only a human can run, so the branch would have stalled;
  and `particle_spark.png` — already on disk, already a four-point star-flare —
  is the better silhouette anyway. §2b, with the scale numbers re-derived for a
  sparkle rather than a disc.
- **The header test reads the header.** `offset_top >= 300.0` became
  `offset_top >= header.offset_bottom`, so it cannot go quietly blind if the
  header ever grows.
- **§1d is reworded.** The collision exists at every aspect; the 28.8 px of
  drift is noise beside a 156-185 px overlap, and SchoolDay is audited "fine"
  for tall phones. Pinning both edges fixes the drift as a side effect, and the
  branch does not claim a tall-phone fix.
- **Four counts corrected:** `test_tall_screen_layout.gd` covers five screens,
  not four; the bar's clearance over the badge is 76 px, not 86, because
  `CaptionLabel` is 22 px not ~40; `StudentScroll`'s endpoints are 1497.6 → 1264
  at 1920, not `DayScreen`'s own height; and `PaperConfetti.tscn` lives at
  `Scenes/SchoolSimulation/`, not `Scenes/Minigames/UI/`.

And, from the second gate — six more, all against this spec rather than against
`decisions.md`:

- **`SchoolDay.gd:1327`'s `🎉` is now in scope**, as a plain text deletion plus a
  codepoint scan. An earlier draft refused it, citing `DEBT.md:248` as already
  tracking it; **that citation was false** — grepping `DEBT.md` for
  `Minggu selesai` or the glyph returns nothing, and `:248-252` covers only
  `BackButton`'s `🔙` and CutScene's `🏫`/`🎓`. The six *other* display-text
  emoji stay out of the branch, because CLAUDE.md requires replacing emoji with
  real SVG textures rather than deleting them. §1b, §4, §6c.
- **The emoji ledger is handed to the back-button spec, not written here.**
  `2026-09-21-back-button-icon-design.md` already rewrites `DEBT.md:248-252`,
  because it fixes the `🔙` that paragraph records. Two specs editing one
  paragraph is a merge collision for no gain, so that spec owns the grouped
  entry, the icon-key exemption and the `:248-252` extension. This spec's only
  `DEBT.md` emoji content is the six-row table in §1b, kept as evidence for the
  hand-off. The plan must order the two branches. §1b, §4.
- **§2e's "this might be fixing the wrong thing" framing is withdrawn.** The
  user's words name the bursts as what looks wrong and the confetti as the
  reference; item 2 changes the bursts, which is the right target. That a full
  house will show coloured shells beside a still-white rain is an aesthetic
  consequence — arguably the requested one, since the complaint is that the two
  read as one effect — and it is recorded as a one-line `DEBT.md` follow-up
  rather than used to widen scope onto the rain, which the user did not ask for.
- **`recon-fireworks` §3b's "three colors" question is closed from source, not
  parked.** `MinigameResultPopup.gd:192` applies `_CATEGORY_COLORS` to
  `badge_icon.self_modulate` only; `RewardParticles.gd` and
  `ResultConfetti.tscn` contain no `color` / `modulate` / `ramp` at all. No
  colour reaches either emitter, so three coloured pieces are not reproducible
  in that path. §9.7's capture drops from "load-bearing" to a look check on
  `scale` and the shell hues.
- **The pill measurement was vacuous and the typeface was wrong.**
  `test_book_clock_phases.gd`'s `_widget()` assigns no theme and never enters the
  tree, so the measurement resolved the engine default and could not fail at any
  string length. The fixture now loads the baked theme and the test pins the face
  and size before measuring. And `DayBannerLabel` is **Open Sans Bold**
  (`ThemeFactory.gd:112` → `:149`, `DesignTokens.gd:249`, pinned by
  `test_event_dialogue.gd:307`), not Boohong. Measured: 422.5 px against a
  526 px box — so **rung 3, the narrower-variation contingency and the only
  branch that would have cost a rebake, is deleted rather than carried.**
- **§1g was wrong in the way that mattered most.** `visible = false` on
  `ProgressBar` is undone by `progress_bar.show()` at `SchoolDay.gd:438` and
  `:1329`, so the alternative reading — the whole point of which is to be a
  cheap option for the user at the plan gate — would have put the bar straight
  back over the calendar badge. The two call sites and `:1330`'s fill are now
  named in its cost table.
- **The culling claim is withdrawn.** `visibility_rect` gates node *activation*,
  not clipping, and all three emitters are on screen, so nothing was ever culled.
  The property is still set — hygiene, matching `PaperConfetti.tscn` — but it is
  no longer presented as a bug being fixed, and the CHANGELOG must not claim one.
- **§7's guarantee was right for the wrong reason.** `SkipButton`, not
  `BackButton`, is `DayScreen`'s last child (`SchoolDay.tscn:107` vs `:99`). The
  144 px holds because `_on_week_complete()` hides Skip (`:1299-1300`) before it
  shows Back (`:1337`). The real mechanism is now written out, because the
  back-button-icon branch will read that paragraph as its licence.
- **Three smaller corrections:** `ScorePopBurst` belongs to
  `MinigameScoreHUD.gd:26-27`, the in-play HUD, and has no result-card use (which
  strengthens the "different screens" argument rather than weakening it); it is
  still white and uncoloured, so the claim that none of the three spark users is
  has been dropped; and `Gradient_shell3`'s first float was `0.28627451` (`#49`)
  where `#4ADEDE` needs `0.29019608`.
