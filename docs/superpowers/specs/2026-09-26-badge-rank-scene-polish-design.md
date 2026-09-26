# RunResult (Badge Rank Scene) polish — design & handoff

**Branch:** `badgerankscenepolish` (off `Textures`)
**Screen:** `Scenes/EndGame/RunResult.tscn` / `Scripts/EndGame/RunResult.gd`
**Status:** design approved (layout, motion, button, captions). Ready for a
build pass by another session.

This is a **handoff spec**: the design was settled with the mentor; the numbers,
call sites and tests below are what the implementing session executes against.
Nothing here changes `RunGrade.gd` or how the rank badge is chosen — the
medallion art and `_badge_for()` stay exactly as they are.

---

## 1. Why

The current screen reads as six identical white pill rows stacked under a badge
card, with small type. Mentor's notes: too many boxes, too flat/boring, text
too small on a phone. The rank-badge mechanic is fine and must not change; only
the *layout, motion, the menu button's wording, and the grade caption* change.

Four layout directions were mocked; **Option C ("panggung juara")** was chosen:
a large celebratory medallion up top, the six figures compressed into **two
horizontal "medal strips" of three counters each**.

---

## 2. Scope

In scope:
- Re-layout RunResult to Option C (medallion hero + two medal strips).
- New reveal choreography (cute, rewarding), reusing existing `Juice` /
  `AnimUtils` calls.
- Contextual `BtnSelesai` label + icon that follows the real progression
  branch.
- A caption **pool per rank** (random pick) instead of one fixed line.
- Bigger type throughout (see §3).

Out of scope / must not change:
- `RunGrade.gd` scoring and rank letters.
- `_badge_for()` and the five `rank_badge_*` textures — the medallion draws its
  own letter + RANK ribbon.
- `_apply_progression()`'s destinations and side effects. The button's *label*
  is derived from the same inputs; its *routing* is untouched.
- Persistence. No new `user://` writes.

---

## 3. Layout — Option C

Portrait 1080-wide. Structure inside the existing
`MarginContainer/Column` VBox (keep `WinStage` + `BlurLayer` backdrop as-is):

```
Column (VBox)
├─ TitleLabel            "Hasil Kelas 7"  — masthead, gold on dark backdrop
├─ MedallionStack (VBox, centered)
│   ├─ GradeBadge        TextureRect, ~150–170 px, the rank medallion (unchanged)
│   └─ GradeCaption      one line, from the rank's caption pool (§6)
├─ MedalStrips (VBox, separation ~12)
│   ├─ StripTop          HBox of 3 StatCounter cells
│   └─ StripBottom       HBox of 3 StatCounter cells
└─ BtnSelesai            contextual label + icon (§5)
```

**StatCounter cell** (new `PackedScene`, `Scenes/EndGame/StatCounter.tscn` +
`Scripts/EndGame/StatCounter.gd`): a `Sheet` Panel with the `Card` variation,
containing icon (top), value `Label` (big), caption `Label` (small). Three per
strip, divided by a thin separator (a 1px `ColorRect` or a panel border — no
`theme_override`). This **replaces** `RunResultRow.tscn` for this screen;
`RunResultRow` may stay in the repo if other screens use it (grep first — as of
this writing RunResult is its only caller, so it can be deleted with the row
scene once this lands).

The six cells, in order (icon → value → caption), values from
`GameState.run_stats`:

| Strip | Cell | Icon | Value source | Caption |
|---|---|---|---|---|
| Top | 1 | minigame-menang | `minigames_won` | "Menang" |
| Top | 2 | minigame-kalah | `minigames_lost` | "Kalah" |
| Top | 3 | poin | `minigame_points` | "Poin" |
| Bottom | 1 | barang | `items_used` | "Barang" |
| Bottom | 2 | uang | `wirausaha_money` (+ "G") | "Wirausaha" |
| Bottom | 3 | event | `event_student_count()` | "Event" |

Reuse the six existing SVGs (`icon_minigame_menang/kalah`, `icon_poin`,
`icon_barang`, `icon_uang`, `icon_event`).

**Type sizes** — the mentor's "too small" note. Use `ThemeFactory` variations,
not overrides:
- Counter value: a display-weight variation around **28–34 px** (add
  `ResultStatValueLabel` if no existing variation fits — Boohong `font_display`).
- Counter caption: **≥13 px** (existing `CaptionLabel` is fine if it clears 13).
- GradeCaption: **≥14 px** (`CaptionLabel` or a new `ResultCaptionLabel`).
- Any new variation goes in `ThemeFactory.gd` and needs a **rebake**
  (`Scripts/Design/BakeTheme.gd` via File > Run), and an entry in
  `DISPLAY_ROSTER` in `tests/test_theme_factory.gd` if it's a display face.

Category colours for the counter accents come from `DesignTokens.gd`
(`cat_akademis` #1F6FBA, `cat_senibudaya` #3D7F12, `cat_olahraga` #E03A18,
`currency_gold` #ffc93c, `brand_primary` #7A4A2B) — no new tokens.

**Tall phones:** re-anchor per the authoring guide's "Tall phones" — backdrop
Full Rect + Keep Aspect Covered, UI inside `SafeAreaMargin`. `test_tall_screen_layout.gd`
pins this.

---

## 4. Reveal choreography

Keep the game's dramatic order: **numbers build the case, the medallion is the
verdict.** Retune `_play_reveal()` / `_slam_grade()`; do not invent new easing —
reuse the vocabulary in `Juice.gd` and `AnimUtils.gd`.

1. `Juice.pop_in(title_label)`.
2. Strips arrive staggered: `AnimUtils.staggered_entrance(strip_top, 0.0)` then
   `staggered_entrance(strip_bottom, ~0.18)` (0 → 1.1 → 1.0 overshoot).
3. Each counter rolls up as its strip lands: `Juice.count_up(value_label, 0, v)`;
   the wirausaha cell uses `Juice.count_up_formatted` for the trailing "G".
   Keep the existing SFX split: coin cell → `AudioDirector.play_sfx(&"coin")`,
   others → `&"pop"`.
4. Drumroll pause (`grade_delay`), then the medallion slams in — the existing
   `_slam_grade()` tween (scale 3.0 → 1.0, `TRANS_BACK`), unchanged.
5. On land: `play_sfx(&"stamp")` + `Juice.shake(medallion.get_parent(), 8.0)` +
   **star confetti** + `RewardFeedback.play(&"run_win", self)` for S/A (keep the
   existing `is_top_grade` gate; keep `&"fail"` for D).
6. RANK ribbon / caption + button fade in last (`Juice.fade_in`).

Cutey extras (optional, but requested feel):
- `AnimUtils.idle_pulse(medallion)` after it settles — a heartbeat, not a freeze.
- Tap the medallion → `AnimUtils.wobble(medallion)` (easter egg).
- Button press → `AnimUtils.back_bounce` (it's the ← action button).
- **Skip-to-end:** a tap during the reveal jumps to the final state. `pop_in` /
  `count_up` / `staggered_entrance` return their tweens precisely so a skip can
  `.kill()` them and land on the final values. Keep this — replay/late taps
  must never strand a half-counted number.

**Confetti and tap-to-wobble are runtime-constructed visuals** and will trip
`tests/test_viewport_editability.gd`. Register them in that suite's `ALLOWED`
dict with a comment (per-call-dynamic reward FX), the same way the six report
rows are registered today — do **not** silently raise `BASELINE`. Prefer
`AnimUtils.create_floating_text` (reused with a ★ glyph) or a small pre-authored
burst `PackedScene` over hand-built nodes where possible, to keep the ALLOWED
surface small.

---

## 5. Contextual menu button

`BtnSelesai` currently reads "Kembali ke Menu" with `return_button.png`. Make
its label + icon follow the same branch `_apply_progression()` already takes,
computed once in `_ready()` after `_compute_grade()`. **Routing is unchanged** —
only text and icon are derived. Keep the label branch adjacent to (or derived
from the same match as) the destination branch so they can never drift.

| Condition | Destination (unchanged) | Label | Icon |
|---|---|---|---|
| Pass, grade 7 | StudentCard (grade 8) | `Lanjut ke Kelas 8` | forward arrow |
| Pass, grade 8 | StudentCard (grade 9) | `Lanjut ke Kelas 9` | forward arrow |
| Pass, grade 9 (game beaten) | MainMenu | `Selesaikan Permainan` | trophy |
| Fail, grade 7 | MainMenu (full restart) | `Mulai Ulang` | refresh |
| Fail, grade 8/9 | StudentCard (retry same grade) | `Ulangi Kelas N` | refresh |

- Interpolate the grade number with `GameState.get_grade_name()` rather than
  hardcoding, so "Kelas 8/9/N" stays correct.
- The **beat-the-game** state gets a distinct celebratory treatment: swap
  `PrimaryButtonM` → a success-green button variation for that one state (add
  `SuccessButtonM` to `ThemeFactory` if none exists; no `theme_override`).
- **Icons must be real transparent SVG textures, not glyphs** (project bans
  emoji/text iconography). Three new placeholder assets are needed:
  a forward arrow, a refresh/repeat, and a trophy, authored alongside the other
  `Assets/Images/UI/Nav` / `Placeholders` icons and drop-replaceable at the
  same path. Add a grouped entry to `docs/superpowers/DEBT.md`. The existing
  `return_button.png` is no longer used by this screen once the label is
  contextual — check for other callers before removing it.

---

## 6. Caption pool per rank

Replace the single-string `GRADE_CAPTIONS` with a **pool per rank**; pick one at
random in `_slam_grade()` (`arr.pick_random()`). This keeps the screen from
saying the same sentence every run. Wording (Indonesian, mentor-approved
starting set — tune freely):

```gdscript
const GRADE_CAPTIONS := {
    "S": [
        "Sempurna. Tidak ada yang tertinggal.",
        "Satu kelas, nol yang tertinggal. Luar biasa.",
        "Kamu hafal nama mereka, dan mereka takkan lupa namamu.",
        "Tidak ada yang bisa ditambah lagi. Sempurna.",
    ],
    "A": [
        "Luar biasa. Kelas ini beruntung punya kamu.",
        "Hampir sempurna. Mereka tumbuh di tanganmu.",
        "Guru seperti kamu yang mereka ceritakan nanti.",
        "Nyaris tanpa cela. Kerja yang bagus.",
    ],
    "B": [
        "Baik. Targetnya tercapai.",
        "Cukup solid. Mereka naik kelas dengan tenang.",
        "Kerja yang rapi. Masih ada ruang untuk lebih.",
        "Targetnya aman. Lain kali coba lebih tinggi.",
    ],
    "C": [
        "Lulus tipis. Lain kali lebih awal.",
        "Selamat, walau napasnya sampai habis.",
        "Lolos di detik terakhir. Untung terkejar.",
        "Berhasil, nyaris saja tidak.",
    ],
    "D": [
        "Belum berhasil. Mereka masih menunggumu.",
        "Kali ini belum. Mereka percaya kamu bisa.",
        "Bel berbunyi terlalu cepat. Coba sekali lagi.",
        "Belum sampai. Tapi belum berakhir.",
    ],
}
```

`_slam_grade()` becomes:
```gdscript
var pool: Array = GRADE_CAPTIONS.get(_grade_text, ["" ])
grade_caption.text = String(pool.pick_random())
```
Guard for an unmapped rank (fall back to `""`), matching today's `.get(..., "")`.

---

## 7. Tests

`tests/test_run_result.gd` is source-text scans plus structural checks on a bare
`instantiate()` (the scene is deliberately **not** `@tool`; live property reads
are off-limits). Follow that pattern:

- **Layout:** assert the scene has `MedalStrips` with two strips and six
  `StatCounter` instances; assert the medallion `TextureRect` still exists and
  still binds the five `rank_badge_*` exports.
- **Captions:** assert `GRADE_CAPTIONS` has an entry for each of S/A/B/C/D and
  that each is a non-empty `Array` (source scan). Optionally unit-test the pick:
  every pool member is a non-empty String.
- **Button:** assert the label helper returns each of the five strings for the
  five (`run_failed`, `current_grade`) input combinations. This is pure and can
  be tested directly if the helper is static or takes its inputs as args —
  prefer that shape so it's testable without the live scene.
- **Motion:** scan for the reused `Juice`/`AnimUtils` call names; assert the
  skip-to-end path kills the reveal tweens.
- **Editability:** add the confetti / wobble ALLOWED entries in
  `tests/test_viewport_editability.gd` with comments; confirm `BASELINE` is
  unchanged.
- **Theme:** if a new display variation was added, update `DISPLAY_ROSTER` in
  `tests/test_theme_factory.gd` and rebake.

Run with the Godot AI MCP `test_run` (targeted per suite; a full run rebakes the
theme and drops the bridge — see project guide). Check `git status` after any
full run and revert an unintended `kejartes_theme.tres` / `default_bus_layout.tres`.

---

## 8. Build order (suggested)

1. New `StatCounter` scene + script (`@tool`, documented `@export`s), and the
   Option C node tree in `RunResult.tscn` via the editor (never hand-edit the
   `.tscn` while attached).
2. Add ThemeFactory variations (value label, success button) + rebake.
3. Rework `_build_rows` → build two strips of `StatCounter`; retune
   `_play_reveal` / `_slam_grade` for the new choreography.
4. Caption pool + random pick.
5. Contextual button helper + icons (add SVG placeholders + DEBT entry).
6. Tests: extend `test_run_result.gd`, ALLOWED entries, theme roster.
7. Finish with the `ship-pr` skill.

---

## 9. Assets to create (placeholders, drop-replaceable)

- `nav_arrow_forward` (button "Lanjut")
- `nav_refresh` (button "Ulangi" / "Mulai Ulang")
- `nav_trophy` (button "Selesaikan Permainan")
- optional `fx_star` for confetti (or reuse `icon_poin`'s star)

All transparent SVG, authored beside the existing UI icons, same-path
drop-replaceable, logged in `docs/superpowers/DEBT.md`.
