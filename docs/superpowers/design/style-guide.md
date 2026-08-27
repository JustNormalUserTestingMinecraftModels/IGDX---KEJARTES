# UI Style Guide

This is the reference for anyone touching visuals in this project after the
core-ui-polish pass (Tasks 0-18). It covers how the design system is
structured, how to change it safely, and the one rule that keeps it that way.

Scope: the 10 core screens (Splashscreen, Loading, MainMenu, CutScene,
StudentCard, Lobby, AturJadwal, StudentList, SchoolDay, SemesterEnd) plus the
Settings screen added in Task 18. **Minigames (`Scenes/Minigames/**`) are
explicitly out of scope** — they inherit the Theme automatically but have not
had a dedicated juice/layout pass.

## Changing a color, radius, or font globally

Everything visual flows from one resource: `Assets/Theme/design_tokens.tres`
(a `DesignTokens` resource — see `Scripts/Design/DesignTokens.gd` for every
exported field: brand colors, category colors, spacing scale, radii, shadow,
outline widths, font slots/sizes, text colors, etc).

To change something globally:

1. Open `design_tokens.tres` (`Assets/Theme/design_tokens.tres`) in the Godot Inspector (select it in the
   FileSystem dock) and edit the field directly — e.g. `brand_primary`,
   `radius_pill`, `space_md`, `font_body`.
2. Rebake the Theme resource from the edited tokens: open
   `Scripts/Design/BakeTheme.gd` in the Script editor and run it with
   **File > Run** (or the "Run current script" shortcut, Ctrl+Shift+X). This
   calls `ThemeFactory.build(tokens)` and saves the result over the shared
   `Theme` resource every scene references.
3. Re-open any scenes you have open in the editor (or just re-run the game)
   to see the new values — Godot caches the Theme in memory per open scene.

No scene file, script, or `.tscn` needs to change for a token edit to take
effect everywhere. That's the point of the system.

## Theme variations (`Scripts/Design/ThemeFactory.gd`)

`ThemeFactory.build()` produces one `Theme` with named type variations. Use
the existing variation that matches intent rather than styling a node by
hand. As of this pass:

**Buttons** (`theme_type_variation` on a `Button`):
- `PrimaryButton` — the screen's main call-to-action / forward navigation.
- `SecondaryButton` — a lower-emphasis action alongside a primary one.
- `DangerButton` — destructive or cancel actions (red).
- `SuccessButton` — affirmative actions that aren't the screen's main nav
  (e.g. StudentCard's APPROVE) — green, distinct from brand blue.
- `QuirkBadge` / `PersonaBadge` — StudentCard's trait chips; same pill
  geometry, different accent so the two trait kinds stay distinguishable.
- `LobbyNavButton` — Lobby's hub nav buttons (replaced three loose
  hand-authored StyleBoxFlat `.tres` files).

**Panels**:
- `Card` — the standard raised surface (white bg, border, shadow).
- `SunkenPanel` — an inset/recessed surface (e.g. a text well).
- `Scrim` — a translucent full-screen dim behind a modal/dialog.

**Labels**:
- `DisplayLabel` — largest heading, outlined, uses the display font.
- `H1Label` — outlined, large.
- `H2Label` — large, no outline.
- `TitleLabel` — button/section-title size.
- `CaptionLabel` / `MicroLabel` — secondary, smaller text.
- `BarLabel` — text drawn directly on a `StatBar` fill (light text, thinner
  dark outline than `DisplayLabel` so it doesn't swallow small text).
- `ResultHeroLabel` / `ResultBodyLabel` — SemesterEnd-only, light-on-dark
  variants for its certificate-style dark backdrop (the one screen that
  intentionally doesn't use the light-surface defaults).

**Progress**:
- `StatBar` — the mood/energy/skill bars. Fill renders white so callers tint
  per-category via `self_modulate` rather than needing per-stat styleboxes.

Unstyled `Label`, `Button`, and `Panel` nodes (no variation set) still get a
sane themed default from `_build_base_overrides` — so a bare `Button` dropped
into a scene never renders as flat Godot gray.

**If a screen needs a style that doesn't exist yet**: add a new variation
function in `ThemeFactory.gd` (following the existing `_add_button_variation`
/ label-spec patterns), rebake, and use it by name. Do not reach for a
per-node `theme_override_*` (see The Rule, below).

## Swapping fonts

See `Assets/Fonts/README.md` for the exact procedure (font files live there;
`DesignTokens.font_body` / `font_display` are `FontFile` export slots — point
them at a new file and rebake).

## Filling or swapping audio

See `Assets/Audio/README.md`. Bus/SFX/BGM slots are defined on
`AudioDirector` and are currently silent placeholders (BGM tracks are
explicitly deferred — "a stronger authorship choice than SFX").

## The Juice API (`Scripts/Design/Juice.gd`)

Static helpers for consistent motion feel. All read shared timing/easing from
`Juice.tokens()` (a `DesignTokens` accessor also used by `StatBar` and
`Transition`).

| Method | One-line example |
|---|---|
| `Juice.set_pivot_center(node)` | `Juice.set_pivot_center(my_button)` — center a Control's pivot before scaling it. |
| `Juice.press(node)` | `Juice.press(button)` on `button_down` — quick squash toward the pivot. |
| `Juice.release(node)` | `Juice.release(button)` on `button_up`/`pressed` — spring back to scale 1. |
| `Juice.pop_in(node, delay)` | `Juice.pop_in(card, 0.1)` — scale-and-fade a Control in, optionally staggered. |
| `Juice.fade_in(node, delay)` | `Juice.fade_in(icon)` — plain alpha fade for a `CanvasItem`. |
| `Juice.stagger_in(nodes, step)` | `Juice.stagger_in(get_children())` — `pop_in` each node in sequence. |
| `Juice.count_up(label, from, to, fmt)` | `Juice.count_up($MoneyLabel, 0, 1500, "Rp%d")` — animate a number tick-up. |
| `Juice.fill_bar(bar, to, duration)` | `Juice.fill_bar($StatBar, 80.0)` — tween a `Range`/`ProgressBar` value. |
| `Juice.shake(node, strength)` | `Juice.shake(panel, 18.0)` — a denial/error shake. |

Buttons are auto-juiced (press/release wiring) by `UIPolish` when the scene
loads — most screens never call `Juice.press`/`release` directly.

## The rule: never add a `theme_override_*`

Per-node `theme_override_*` properties on a scene bypass the Theme entirely —
they can't be changed by editing tokens, they don't rebake, and they silently
drift from the rest of the game. **Do not add new ones.**

The one accepted exception, already present in a few scenes
(`Scenes/SchoolSimulation/SchoolDay.tscn`, `Scenes/UI/Settings.tscn`), is
**layout-only constant overrides** — `separation`, `margin_left/top/right/
bottom` — for spacing that is specific to one container's local layout rather
than a global rhythm. These carry no color or font information and don't
fight the Theme. A `theme_override_colors/*`, `theme_override_font_sizes/*`,
or `theme_override_styles/*` on a scene is always a regression: add or reuse
a `ThemeFactory` variation instead, and rebake.

## Opting a button out of auto-juicing

`UIPolish` wires press/release juice onto every `Button` it finds during
scene setup. To exclude a specific button (e.g. one that already has custom
animation, or one that must never scale-bounce):

```gdscript
my_button.set_meta(Juice.NO_AUTO_JUICE, true)
```

Set this before `UIPolish` processes the scene (e.g. in `_ready()` before
`super._ready()` if the base class wires juice there, or immediately after
instancing the button).

## Known constant-override exceptions (Step 2 verification)

The zero-`theme_override_*` grep across the 10 core scenes plus Settings
found exactly two files with non-zero counts, both exclusively
`theme_override_constants/separation` and `margin_*`:

- `Scenes/SchoolSimulation/SchoolDay.tscn` — 2 occurrences (container
  separation local to that screen's layout).
- `Scenes/UI/Settings.tscn` — 14 occurrences (separation/margin on the
  settings list and its rows).

No color, font-size, or stylebox overrides were found in either file — both
fall under the accepted layout-only exception above.

## `@tool` and `Engine.is_editor_hint()` for MCP-testable scripts

Any script that the in-editor MCP test runner needs to instantiate live
(i.e. a test adds an instance of it to a live tree) must be `@tool`. Without
it, Godot silently replaces the instance with an uncallable placeholder when
it's created inside the editor process — even ordinary method calls fail
with a "placeholder instance" error, and the test can't exercise anything.

But `@tool` has a cost: it makes `_ready()` run for real the moment a human
just opens that scene or resource in the editor, not only during actual
play. Any *real* side effect in `_ready()` — reading or writing another
autoload's state, playing audio, kicking off a gameplay-only animation
sequence, mutating save data — must therefore be gated behind
`if Engine.is_editor_hint(): return` (or an inline check) so it never fires
just from opening the scene. Pure UI wiring (connecting signals, reading
initial display values) should stay *above* that guard, ungated, since the
test suite needs to exercise exactly that wiring.

- See `Scripts/MainMenu/main_menu.gd` for the worked "gated" example: it's
  `@tool`, button-signal wiring runs unconditionally, and BGM/entry
  animation are gated behind `Engine.is_editor_hint()`.
- See `Scripts/UI/UIPolish.gd` for the worked "correctly needs no `@tool`"
  example: its `_ready()` can only ever run during a real `project_run`
  (nothing instantiates it live from the editor process), so there's no
  placeholder risk and nothing to gate.

## Out of scope (deferred, not this pass)

See the plan's task briefs for the full list — in short: minigames, haptic
vibration, BGM tracks, localization, landscape/tablet layouts, and custom
9-slice/icon art. None of these are regressions; they're documented,
intentional deferrals.
