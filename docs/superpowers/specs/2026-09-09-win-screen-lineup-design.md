# Win screen lineup — design

2026-09-09. Overhauls the win branch of `EndCutscene` so it shows the run's
own roster standing with the teacher, on the new `win_background` art,
instead of the placeholder CG it uses today.

Note for whoever updates the docs: `CLAUDE.md:355` says the win backdrop is
`cg2.jpg`, but `EndCutscene.tscn:4` actually references
`Assets/Images/CG/cg_win.jpg`. The guide is stale on this point. This spec
replaces whichever one is wired, via the `win_backdrop` export.

## Scope

Only the **win** branch changes. The lose branch keeps `cg_lose.jpg`, keeps
the GAGAL stamp and keeps the stamp's slam animation, untouched. The beat's
shape survives — white fade in, hold, reveal, `Lanjut` — with the badge slam
skipped when the run passed.

`mockup_CG_winscreen.jpeg` in the Downloads folder is unrelated anime art,
not a mockup of this screen. `mockup_winscreen.png` is the reference.

## Source assets

Seven files from the Downloads folder, all authored for this screen:

| File | Size | Destination |
|---|---|---|
| `win_background.png` | 1536×2048 | `Assets/Images/CG/Win/` |
| `win_andi.png` | 1080×1080 | `Assets/Images/CG/Win/` |
| `win_citra.png` | 1080×1080 | `Assets/Images/CG/Win/` |
| `win_doni.png` | 1080×1080 | `Assets/Images/CG/Win/` |
| `win_marcel.png` | 1080×1080 | `Assets/Images/CG/Win/` |
| `win_sinta.png` | 1080×1080 | `Assets/Images/CG/Win/win_shinta.png` |
| `win_thea.png` | 1080×1080 | `Assets/Images/CG/Win/` |

`win_sinta.png` is renamed to `win_shinta.png` on import. The roster spells
her `Shinta` everywhere else (`splash_shinta.png`, `MuridPotrait/Shinta.png`,
`student_card.gd:991`); the Downloads spelling is the odd one out, and the
lookup in §4 keys on the roster name.

The teacher is baked into `win_background.png`. There is no separate teacher
sprite and none is needed.

## 1. Layout — a letterboxed art-space stage

The art is 1536×2048 (3:4). The screen is 1080×1920 (9:16). The whole
painting is shown, letterboxed, rather than cover-cropped:

    scale = min(1080/1536, 1920/2048) = 0.703125
    art on screen = 1080 × 1440, centred vertically
    bars = 240px at the top, 240px at the bottom

```
 1080 × 1920 screen
┌──────────────────────────┐
│   bar  (surface_overlay) │  y 0 .. 240
├──────────────────────────┤ ─┐
│  win_background.png      │  │
│  (teacher baked in)      │  │  1080 × 1440
│      ╷  teacher  ╷       │  │  y 240 .. 1680
│  [side-L] [mid] [side-R] │  │
│      [front-low: Doni]   │  │
├──────────────────────────┤ ─┘
│  bar        [ Lanjut ]   │  y 1680 .. 1920
└──────────────────────────┘
```

A `Stage` Control holds the backdrop at its native 1536×2048 and carries the
students as children in **art-space coordinates**, so numbers measured off
the mockup transfer to the scene 1:1 and the whole composition scales and
positions as one glued unit.

`Stage` is fitted by a `@tool` script rather than a hardcoded transform, per
the authoring guide's rule that responsive geometry is a script driven by
documented `@export` knobs:

    scale  = min(viewport.x / 1536, viewport.y / 2048)
    origin = (viewport - art_size * scale) / 2

Bars are the exposed background behind `Stage`, painted with the
`surface_overlay` token (`#141a2e`) rather than black, so they read as the
game's own chrome. Exposed as `@export var bar_color` for tuning.

`BtnNext` moves from y 1640–1780 to **1730–1870**, centring it in the bottom
bar clear of the art. It stays a screen-space sibling of `Stage`, not a
child — it must not scale with the painting.

Art-space to screen, for anyone reading coordinates later:

    screen_x = art_x * 0.703125
    screen_y = art_y * 0.703125 + 240

## 2. Slots

Four `TextureRect` nodes authored in the `.tscn`. The script sets only
`texture`, `visible`, `position` and `scale` — no node is constructed at
runtime, so `tests/test_viewport_editability.gd`'s ratchet is not disturbed.

A slot is a **bottom-centre anchor plus a scale plus a ground line**. That
works uniformly across all six splashes because every figure centres on
x ≈ 540 in its own 1080² canvas and sits with its feet near the canvas
bottom; the variation that remains (Thea airborne, Doni crouched) is
deliberate and is preserved by anchoring on the canvas, not on the figure.

The ground line is carried separately from the bottom anchor because Thea's
shadow decouples from her feet (§5).

Measured from the mockup: the four figures occupy art-space
x 244–1386, y 818–1797 — the lower half of the painting, about 74% of its
width.

### Arrangement per roster size

`student_card.gd:99-102` caps approvals by grade — grade 7 approves 2, grade
8 approves 3, grade 9 approves 4. Each count gets its own hand-tuned
arrangement so the smaller rosters read as deliberate compositions rather
than a 4-slot map with holes:

| Slot | 4 students (grade 9) | 3 (grade 8) | 2 (grade 7) |
|---|---|---|---|
| Front-low | Doni | Doni | Doni |
| Front-mid | student 2 | student 2 | — |
| Side-left | student 3 | student 3 | student 2 |
| Side-right | student 4 | — | — |

"Student 2/3/4" means the second, third and fourth entries of the fill order
below — positions in a sequence, not fixed identities. Only Doni is pinned.

### Fill order

- **Doni takes Front-low whenever he is approved.** This is the one fixed
  rule.
- Everyone else fills the remaining slots in `GameState.approved_students`
  order.
- If Doni is not approved, Front-low goes to the first student in roster
  order, and the rest follow.

Deterministic and reproducible, so the arrangement can be asserted in tests
and screenshotted without surprise.

Draw order is front over side, Doni frontmost.

## 3. Where the logic lives

`Scripts/EndGame/WinLineup.gd` — plain static functions, no scene required,
following the `Scripts/Debug/EndGameRehearsal.gd` pattern so the assignment
is behaviourally testable without instantiating the cutscene.

    static func assign(names: Array[String]) -> Array[Dictionary]

Returns one entry per student: the name, the slot it landed in, and that
slot's anchor, scale and ground line. `EndCutscene` calls it once in
`_dress_for_verdict()` and applies the result to the four authored nodes.

Keeping it out of `EndCutscene.gd` matters because that script is already
carrying the verdict branch, the beat coroutine and the exit blur.

## 4. Texture lookup

Splash textures are wired as an `@export var win_splashes: Dictionary` on
the scene root, keyed by roster name (`"Doni"`, `"Shinta"`, …). Inspector-
swappable, consistent with how `win_backdrop` and the badges are already
exported.

A roster name with no entry logs a warning and leaves its slot hidden rather
than crashing the end-of-grade sequence.

## 5. Ground shadows

One shared asset: `Assets/Images/UI/Placeholders/shadow_ellipse.png`, a soft
radial-gradient ellipse generated with PowerShell + `System.Drawing`, the
same way the event-popup placeholders were. It is a transparent PNG suitable
for drop-replacement and joins **Outstanding debt & placeholders** in
`CLAUDE.md` until real art lands.

The existing `Scripts/Shaders/soft_shadow.gdshader` is deliberately **not**
reused here. It blurs in source-texel space, so squashing a silhouette down
to floor height collapses its blur below one pixel; getting a soft floor pool
out of it would need a radius around 30 against its `hint_range` cap of 8,
and its 9 taps would band badly at that size. It also serves four other
scenes, and widening it for this one would put those at risk.

### Draw order — two layers, not per-slot pairs

```
Stage
├── Backdrop        win_background.png
├── Shadows         4 TextureRects   ← every shadow drawn first
└── Students        4 TextureRects   ← then every figure on top
```

Pairing each shadow with its own sprite would let Doni's wide crouch-shadow
smear across Sinta's shoes. Drawing all shadows, then all figures, removes
that class of artifact entirely.

### Per-character anchors

Measured from the alpha of each splash — the lowest opaque row, and the
horizontal span of opaque pixels within the bottom 6% of the figure. Held as
a documented `const FOOT_ANCHORS` in `WinLineup.gd`, in each splash's own
1080² canvas space:

| | foot centre x | ground y | foot span |
|---|---|---|---|
| Doni | 590 | 993 | 603 |
| Andi | 488 | 1079 | 392 |
| Citra | 514 | 1034 | 354 |
| Sinta (Shinta) | 526 | 1014 | 188 |
| Marcel | 391 | 1053 | 123 → widened |
| Thea | 559 | 984 → lowered | 105 → widened, faded |

Foot spans run 5× from Marcel to Doni, and foot centres drift up to 149px
off canvas centre (Marcel at 391, not 540), which is why the shadows are
measured per character rather than sharing one size.

Two documented exceptions, both arising from the poses:

- **Thea is airborne.** A shadow at her feet would nail a jumping figure to
  the floor. Hers drops to the slot's ground line, below her, and goes wider
  and fainter — which reads as height, and turns the pose into an asset.
- **Marcel leans on one foot**, giving a 123px span. A shadow that narrow
  under a standing figure reads as a smudge, so his widens toward his body's
  true centre.

### Knobs

Four scene-level `@export`s, rather than per-character export sprawl:

| Export | Default | Meaning |
|---|---|---|
| `shadow_texture` | the ellipse | Drop-replacement point for real art. |
| `shadow_opacity` | 0.28 | Alpha of every shadow. |
| `shadow_spread` | 1.25 | Multiplier on the measured foot span. |
| `shadow_flatness` | 0.28 | Ellipse height as a fraction of its width. |

The per-character numbers above are measured fact and live in the `const`
table; these four are the art-direction surface.

### Known consequence

The teacher is baked into the background and casts no shadow — nothing in
the painting does. With the students grounded and him not, he may read as
slightly detached at full size. Accepted for this pass. The fix, if it
proves necessary on device, is one more ellipse node in `Shadows` at his
known foot position, drawn above `Backdrop` and below `Students`; the asset
and the knobs will already exist.

## 6. Badge

The chalkboard already reads *Selamat Kelulusan*, so the LULUS stamp is
redundant on the win path and would cover the art. The win branch shows
backdrop, shadows, students and `Lanjut`.

The `Badge` node, `win_badge`/`lose_badge` exports and `_slam_badge()` all
stay — the lose branch still stamps GAGAL, and
`tests/test_end_cutscene.gd:34`'s pixel check on the rendered stamp words
continues to hold. Only the win path skips the slam, which shortens the win
beat by `button_delay_seconds`; `_play()` reveals the button directly after
`image_hold_seconds` when the run passed.

## 7. Exit blur

`BlurLayer` must sit **above `Stage`** so the students blur out with the
backdrop on the way to RunResult. Today it sits between `Backdrop` and
`Badge`; the students are new siblings and would otherwise stay sharp while
the painting behind them softened.

Final node order:

    EndCutscene
    ├── Stage      (Backdrop, Shadows, Students)
    ├── BlurLayer
    ├── Badge      (lose path only)
    ├── BtnNext
    └── WhiteFade

## 8. Coordinates are estimates

The group's overall extent — art-space x 244–1386, y 818–1797 — is measured
by diffing `mockup_winscreen.png` against `win_background.png`. The
per-character foot anchors in §5 are measured from each splash's alpha.

The **four individual slot anchors and scales are estimates**, seeded from
the mockup and tuned in a single editor screenshot pass. Stated plainly
here so nobody later mistakes them for derived values.

## 9. Tests

New `tests/test_win_lineup.gd`, behavioural against the static functions:

- Doni lands in Front-low at every roster size, 2, 3 and 4.
- Non-Doni students fill remaining slots in `approved_students` order.
- A roster without Doni still fills Front-low, from roster order.
- Each roster size yields exactly that many placements, and no two share a
  slot.
- `FOOT_ANCHORS` has an entry for all six roster names, `Shinta` included.

Added to `tests/test_end_cutscene.gd`:

- The scene carries four authored student slots and four authored shadow
  slots; neither is built at runtime.
- All shadows draw beneath all students, and `Shadows` precedes `Students`
  under `Stage`.
- Every visible student has exactly one visible shadow, and the visible
  count tracks roster size.
- `BlurLayer` draws above `Stage`, so students blur on exit.
- The win path shows no badge; the lose path still does.
- `Stage` fits by computed scale, not a hardcoded transform.

## 10. Placeholders this pass leaves behind

For the `CLAUDE.md` debt list:

- `Assets/Images/UI/Placeholders/shadow_ellipse.png` — a generated
  radial-gradient ellipse, not hand-authored art.

`cg2.jpg`'s entry under **End cutscene art** is retired for the win backdrop,
which is now real art. The win badge line goes with it. The lose backdrop and
both stamps stay listed.
