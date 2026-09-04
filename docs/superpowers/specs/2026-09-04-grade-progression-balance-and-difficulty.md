# Grade Progression, Difficulty Curve & Anti-Exploit Balance — Design

**Date:** 2026-09-04
**Branch:** `minigame-reward-feedback` (work continues here; main is `Textures`)
**Status:** approved for planning. The numeric targets in §4 and the caps in §3/§8
are **balance-pass estimates**, to be confirmed by the `test_balance_pacing.gd`
seed sweep (§7) and a manual grade-7 playthrough before merge — the same
"estimate pending a real-run balance pass" status the project already applies to
`RunGrade`'s scoring weights.

---

## Problem

1. **Grade 7 is too fast.** A single well-scheduled week can clear multiple of a
   student's three academic targets. The dominant cause: a minigame win in
   `StudentManager.record_minigame_result()` is applied to **every student on the
   roster** (intended — the run-result screen reports a "class total"), and the
   win points are uncapped, so one or two lucky minigame days hand the whole
   roster a target's worth of skill for free.
2. **Grades 8 and 9 do not ramp enough.** Target uplift rises (+30, +40) but with
   the same minigame blowout available the extra weeks are slack, not pressure.
3. **Progression carries stats.** `RunResult._apply_progression()` resets
   `kepribadian1/2` (mood, energy) to 80 and recomputes targets, but the three
   **skill** stats (`akademis1/2/3`) carry across grades untouched. The debug
   grade buttons (`DebugManager._set_grade()` → `GameState.set_grade()`) reset
   even less. Both make grade 8/9 start from wherever grade 7 ended, breaking the
   intended fresh-ish start.
4. **The minigame category is farmable.** When a day rolls "Minigame",
   `SchoolDay._roll_event()` picks the *category* strictly proportional to how
   many students study it that day. Scheduling all students onto one subject on
   one day guarantees that subject's minigame, so a player can farm a predictable
   category.
5. **AturJadwal gives no feedback that a day matches a student's specialty**, so
   the single most important scheduling lever (specialty study is cheaper and
   worth more) is invisible to a new player.

## Non-goals

- **Week counts are unchanged:** `JUMLAH_MINGGU_KELAS_7/8/9` stay `6 / 12 / 16`.
- **Minigame/event appearance frequency is unchanged:** `CHANCE_MINIGAME` (40),
  `CHANCE_EVENT` (40), the `active_studying * 15` minigame weight, `w_normal`,
  and "minigames are likelier when more students study" all stay exactly as they
  are. §8 changes only *which* category appears and *how many* are allowed per
  week, never *how often* the "Minigame" outcome is rolled.
- **No save system.** Everything stays session-scoped.
- **Minigame timers and per-difficulty win thresholds are already tuned** —
  `SchoolDay._play_minigame()` scales duration ×0.8 (grade 8) / ×0.6 (grade 9)
  and `BaseMinigame.get_target_win_score()` requires 1 / 2 / 3 correct by
  difficulty. This pass does **not** change those curves; it only lifts the two
  hardcoded time-scale literals into named `Balance` constants for
  discoverability (no behaviour change).

## Global constraints (apply to every task)

- **Godot 4.6**, mobile renderer, portrait. Main scene
  `Scenes/MainMenu/main_menu.tscn`.
- **Every tunable number lives in `Scripts/Balance.gd`** as a `static var`, with a
  `##` doc line, grouped under the existing section banners. No gameplay literal
  anywhere else.
- **`tests/test_balance.gd` pins every `Balance` field to its exact value.** Any
  add/rename/retune of a `Balance` field updates the `_EXPECTED` dictionary in
  `test_balance.gd` **in the same commit**, or the suite fails.
- **Test suites** extend `McpTestSuite`, are `@tool`, and contain **no
  coroutines** (`await` silently aborts a test under the runner). Run via the
  Godot AI MCP `test_run`. Open `Scenes/MainMenu/main_menu.tscn` in the editor
  before trusting a failure.
- **Rescan after editing a `.gd` from outside the editor** (`filesystem_manage`
  `op="scan"`), and if a new `@export` / `static var` stays invisible, force a
  reload with a no-op `script_patch` (add then remove a blank line) on that file.
- **Visual system:** no `theme_override_*` (use a `ThemeFactory` type variation
  or a layout-only constant override); no visual built at runtime that could be
  an authored node or a `PackedScene` template. `@tool` visual scripts gate real
  side effects behind `Engine.is_editor_hint()`.
- **UI text is Indonesian**; engine/systems identifiers are English.
- **Commits:** Conventional Commits with a scope, e.g.
  `feat(balance): cap weekly minigame skill gain per student`.

---

## Section 1 — Architecture

Five mechanical systems, each small and localised. No new autoloads. No new
scenes except the one AturJadwal particle template (§6).

| System | Primary files | Nature of change |
|---|---|---|
| Roster reset + head-start on grade change | `GameState.gd` (new `reset_roster_for_new_grade()`), `RunResult.gd`, `GameState.set_grade()` | One shared function called by real progression **and** debug jumps |
| Weekly per-student minigame-points cap | `GameState.gd` (new `minigame_gain_this_week` dict), `StudentManager.record_minigame_result()`, `SchoolDay.start_simulation()` | Clip skill gained from minigame *wins* per student per week |
| Grade 8/9 target + skip + time-scale constants | `Balance.gd`, `SchoolDay._play_minigame()`, `SchoolDay` skip path, `test_balance.gd` | Pure number moves + two literals extracted to constants |
| Quirk / specialty amplification | `Balance.gd`, `test_balance.gd` | ~1.4× on a fixed list of `SIFAT_*` bonuses; tighten efficiency multipliers |
| AturJadwal specialty feedback | `ActivityPreview.gd`, `atur_jadwal.gd`, `DayStickyNote.gd/.tscn`, `ActivityRow.gd/.tscn`, new `SpecialtyMatchBurst.tscn`, `AudioDirector.gd` | New public helper + authored particle scene + one new SFX cue alias |
| Anti-exploit minigame category/allowance | `Balance.gd`, `SchoolDay._roll_event()`, `SchoolDay.start_simulation()`, `test_balance.gd` | Category-choice noise + randomised per-week minigame count |

Verification harness (`tests/test_balance_pacing.gd`, §7) is the iteration loop
for every estimated number above.

---

## Section 2 — Roster reset with head-start

### Behaviour

On **every** grade change where a roster exists — the normal
"beat a grade, advance" path and a debug grade-jump — each student's three skill
stats are rebased:

```
new_base = roster_base + HEAD_START_FRACTION * max(0.0, end_value - roster_base)
```

- `HEAD_START_FRACTION = 0.20` (new `Balance` const,
  `KENAIKAN_KELAS_HEAD_START_FRAKSI := 0.20`).
- `roster_base` is the student's original StudentCard value for that skill
  (see "roster_base capture" below).
- `end_value` is the skill's current value at the moment of the grade change.
- Floored at `roster_base` (a student who somehow *ended below* their roster base
  snaps back up to exactly `roster_base` — no negative head-start).
- The student's **current** skill value is then set to `new_base`.
- `kepribadian1` (mood) and `kepribadian2` (energy) are set to `80.0`.
- `base_akademis1/2/3` keys are erased so
  `GameState.initialize_grade_targets()` recomputes
  `target = new_base + uplift` on the next Lobby entry.

Worked example — Marcel, akademis, grade 7 → 8:
roster_base 28, ends grade 7 at 46. `new_base = 28 + 0.20*(46-28) = 31.6`.
Current akademis becomes 31.6; on next Lobby entry
`target_akademis1 = 31.6 + 34 = 65.6`. Net skill needed in grade 8 ≈ 34.

### roster_base capture

Add permanent keys `roster_base_akademis1/2/3` to each student Dictionary,
**never erased**:

- **Primary:** set them in `student_card.gd` at roster approval, where
  `GameState.approved_students` is populated from `student_data_list[i]`
  (around `student_card.gd:1179-1188`). Copy `akademis1/2/3` into the
  matching `roster_base_*` keys as the students are appended.
- **Fallback:** in `reset_roster_for_new_grade()`, if a student lacks
  `roster_base_akademisN`, capture it from the current `akademisN` value
  *before* applying the head-start formula (covers the debug
  `seed_playtest_state` path, which builds a roster without going through
  approval).

### `GameState.reset_roster_for_new_grade()` — new function

```gdscript
## Rebases every roster student's three skill stats for a new grade: keep
## KENAIKAN_KELAS_HEAD_START_FRAKSI of the gains made above roster base, snap
## mood/energy to 80, and drop the cached base_akademis* so
## initialize_grade_targets() recomputes targets from the new baseline.
##
## Called by RunResult._apply_progression() on a real grade advance and by
## set_grade() on a debug grade-jump, so both paths behave identically. A
## no-op when approved_students is empty.
func reset_roster_for_new_grade() -> void:
    if approved_students.is_empty():
        return
    var frac := Balance.KENAIKAN_KELAS_HEAD_START_FRAKSI
    var skill_keys := [
        ["akademis1", "roster_base_akademis1"],
        ["akademis2", "roster_base_akademis2"],
        ["akademis3", "roster_base_akademis3"],
    ]
    for student in approved_students:
        for pair in skill_keys:
            var cur := float(student.get(pair[0], 50.0))
            if not student.has(pair[1]):
                student[pair[1]] = cur
            var rbase := float(student[pair[1]])
            var kept := rbase + frac * maxf(0.0, cur - rbase)
            student[pair[0]] = kept
        student["kepribadian1"] = 80.0
        student["kepribadian2"] = 80.0
        student.erase("base_akademis1")
        student.erase("base_akademis2")
        student.erase("base_akademis3")
    minigame_gain_this_week.clear()
```

### Call sites

- **`RunResult._apply_progression()`**, the `GameState.current_grade < 9` branch
  (`RunResult.gd:197-210`): replace the inline loop that sets
  `kepribadian1/2 = 80.0` and erases `base_akademis*` with a single call to
  `GameState.reset_roster_for_new_grade()`. Keep the surrounding lines
  (`current_grade += 1`, `day_schedules.clear()`, `minggu_ke = 1`,
  `returned_from_student_card = false`, `lobby_tutorial_completed = true`,
  `run_stats.reset()`, and the `return` to `student_card.tscn`).
- **`GameState.set_grade(grade_num)`** (`GameState.gd:83`): after
  `current_grade = grade_num` and the existing resets, if `current_grade`
  actually changed **and** `approved_students` is non-empty, call
  `reset_roster_for_new_grade()`. This makes `DebugManager._set_grade()` (which
  already calls `GameState.set_grade()` when available) reset the roster the same
  way the real path does. Guard against re-running when the grade is unchanged so
  a stray double-press does not stack head-start reductions.
- The **"game beaten" branch** (`RunResult.gd:211+`) already clears the roster
  entirely — leave it untouched.

### Tests — `tests/test_roster_reset.gd` (new)

- Build a synthetic `approved_students` of 2 Dictionaries with known
  `roster_base_*`, `akademis*`, `kepribadian*`.
- After `reset_roster_for_new_grade()`:
  - each skill equals `roster_base + 0.20*(end - roster_base)` within `0.01`;
  - a skill whose `end < roster_base` equals `roster_base` exactly;
  - `kepribadian1/2 == 80.0`;
  - `base_akademis1/2/3` absent; `roster_base_akademis1/2/3` still present and
    unchanged;
  - a student dict lacking `roster_base_akademis2` gets it populated from the
    pre-reset `akademis2`.
- `reset_roster_for_new_grade()` with `approved_students == []` does not error.
- Source-scan: `RunResult.gd` calls `reset_roster_for_new_grade`, and no longer
  contains the literal `student["kepribadian1"] = 80.0` inline in
  `_apply_progression` (it moved into GameState).
- Source-scan: `GameState.set_grade` source references
  `reset_roster_for_new_grade`.

---

## Section 3 — Weekly per-student minigame-points cap

### Behaviour

Each student can gain at most a per-grade cap of **skill points from minigame
wins** per week. Losses are **not** capped and have no floor — a bad minigame
week still hurts in full.

New `Balance` constants (grouped under the existing "MINIGAME — menang dan kalah"
banner):

```
static var MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_7 := 14.0
static var MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_8 := 12.0
static var MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_9 := 10.0
```

`##` doc: "Batas poin skill yang bisa didapat SATU murid dari MENANG minigame
dalam satu minggu. Kekalahan tidak dibatasi. Menahan agar satu minggu penuh
kemenangan minigame tidak langsung menuntaskan satu target."

### State

`GameState.minigame_gain_this_week: Dictionary` — `student_id (int) -> float`
already gained this week. Cleared:

- in `SchoolDay.start_simulation()` next to `minigames_played_this_week = 0`
  (`SchoolDay.gd:263`), and
- in `GameState.reset_roster_for_new_grade()` (shown in §2).

### Clip logic — `StudentManager.record_minigame_result()`

`record_minigame_result()` (`StudentManager.gd:71`) loops the roster calling
`student.apply_minigame_result(category, won, score, max_score)`, which already
mutated the skill. After that call, for a **winning** result only:

```gdscript
var raw_delta: float = float(deltas.get("stat_delta", 0.0))
if won and raw_delta > 0.0:
    var cap: float = _weekly_minigame_cap()      # per-grade, from Balance
    var sid: int = student.id
    var already: float = float(GameState.minigame_gain_this_week.get(sid, 0.0))
    var allowed: float = maxf(0.0, cap - already)
    if raw_delta > allowed:
        var overflow: float = raw_delta - allowed
        # undo the overflow on the same skill apply_minigame_result() moved
        match category:
            "Akademis":   student.akademis   = clampf(student.akademis   - overflow, 0.0, 100.0)
            "SeniBudaya": student.seni_budaya = clampf(student.seni_budaya - overflow, 0.0, 100.0)
            "Olahraga":   student.olahraga   = clampf(student.olahraga   - overflow, 0.0, 100.0)
        deltas["stat_delta"] = allowed          # so the log + run_stats see the clipped value
    GameState.minigame_gain_this_week[sid] = already + minf(raw_delta, allowed)
```

Then the existing `roster_points += float(deltas.get("stat_delta", 0.0))` and
`log_stat_change(...)` lines use the (possibly clipped) `deltas` value, and
`GameState.run_stats.record_minigame(won, roster_points)` receives the clipped
roster total. `energy_delta` / `mood_delta` are never touched by the cap.

Add the private helper:

```gdscript
func _weekly_minigame_cap() -> float:
    match GameState.current_grade:
        8: return Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_8
        9: return Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_9
        _: return Balance.MINIGAME_MENANG_POIN_MAKS_PER_MINGGU_KELAS_7
```

### Tests — `tests/test_minigame_weekly_cap.gd` (new)

- Set `GameState.current_grade = 7`, clear `minigame_gain_this_week`, build a
  `StudentManager` with a 1-student roster whose `akademis` is low.
- Call `record_minigame_result("Ujian", "Akademis", "Test", true, score, max_score)`
  repeatedly with a score/max that yields ~+12 per win:
  - after win 1: `akademis` rose by ~12, `minigame_gain_this_week[id] ≈ 12`;
  - after win 2: `akademis` rose by only ~2 more (clipped at 14 total), and
    `minigame_gain_this_week[id] == 14.0`;
  - after win 3: `akademis` unchanged.
- A **loss** after the cap is hit still subtracts
  `MINIGAME_KALAH_POIN_KELAS_7` in full.
- `grade 8` cap is 12, `grade 9` cap is 10 (drive `_weekly_minigame_cap()` via a
  public probe or a source-scan of the match arms).
- Source-scan: `SchoolDay.start_simulation` source contains
  `minigame_gain_this_week` cleared alongside `minigames_played_this_week`.
- `test_balance.gd` `_EXPECTED` gains the three new fields.

---

## Section 4 — Balance number changes

All in `Scripts/Balance.gd`; every line below is also mirrored into
`tests/test_balance.gd`'s `_EXPECTED` in the same commit.

### Targets (SYARAT LULUS banner)

```
TARGET_KENAIKAN_KELAS_7 : 15.0  ->  15.0   (UNCHANGED — the §3 cap does the grade-7 work)
TARGET_KENAIKAN_KELAS_8 : 30.0  ->  34.0
TARGET_KENAIKAN_KELAS_9 : 40.0  ->  50.0
+ KENAIKAN_KELAS_HEAD_START_FRAKSI := 0.20   (new; consumed by §2)
```

### Specialty / efficiency (HARI BELAJAR banner)

```
BIAYA_KALAU_MAPEL_FAVORIT : 0.6   ->  0.55
BIAYA_KALAU_BUKAN_FAVORIT : 1.20  ->  1.28
BIAYA_KALAU_MURID_SEIMBANG: 0.85  ->  0.85   (unchanged)
```

### Named quirk bonuses (SIFAT PASIF banner) — ~1.4× the parts that reward
playing to a student's strength:

```
SIFAT_KUTU_BUKU_BONUS_POIN        : 1.0  ->  1.5
SIFAT_KUTU_BUKU_HEMAT_MOOD        : 0.25 ->  0.35
SIFAT_SEMANGAT_BONUS_MENANG       : 2.0  ->  3.0
SIFAT_PENASARAN_BONUS_MAPEL_LAIN  : 1.0  ->  1.5
SIFAT_PEKERJA_BONUS_MOOD_MENANG   : 3.0  ->  4.0
```

All other `SIFAT_*`, `DECAY_*`, `EVENT_*`, `WIRAUSAHA_*`, `BELAJAR_*` values,
and every `JUMLAH_MINGGU_*`: **unchanged**.

### Skip button — per-grade risk (MODE SKIP banner)

Replace the single field with a per-grade trio:

```
- static var SKIP_PELUANG_KALAH := 0.4
+ static var SKIP_PELUANG_KALAH_KELAS_7 := 0.4
+ static var SKIP_PELUANG_KALAH_KELAS_8 := 0.5
+ static var SKIP_PELUANG_KALAH_KELAS_9 := 0.6
```

Call site — `SchoolDay.gd:1257`
(`var won = randf() > Balance.SKIP_PELUANG_KALAH`): read the grade's value via a
local `match GameState.current_grade` (default arm → `KELAS_7`), mirroring the
pattern already used for minigame numbers in `StudentData.apply_minigame_result`.

`test_balance.gd`: remove `SKIP_PELUANG_KALAH`, add the three
`SKIP_PELUANG_KALAH_KELAS_*`. Grep the codebase for any other
`SKIP_PELUANG_KALAH` reference before renaming (expected: only
`SchoolDay.gd:1257` and `test_balance.gd`).

### Minigame time-scale — extract literals only (MINIGAME banner)

```
+ static var MINIGAME_WAKTU_SKALA_KELAS_8 := 0.8
+ static var MINIGAME_WAKTU_SKALA_KELAS_9 := 0.6
```

Call site — `SchoolDay._play_minigame()` (`SchoolDay.gd:1089-1091`): replace the
literal `* 0.8` / `* 0.6` with the constants. **No behaviour change** — this is
discoverability only. Add to `test_balance.gd` `_EXPECTED`.

---

## Section 5 — Base testing

- **`tests/test_balance.gd`**: `_EXPECTED` updated for every add / retune / rename
  in §3, §4, §8. This is the single pinning suite — if a field's name or value
  drifts, it fails.
- Full `test_run` (45+ suites) green, `Scenes/MainMenu/main_menu.tscn` open.
- Suites known to touch these areas — re-run and keep green:
  `test_balance`, `test_school_day`, `test_semester_end`, `test_run_result`,
  `test_economy_state`, `test_audio_coverage`, `test_project_hygiene`,
  `test_script_documentation`, `test_viewport_editability`.
- Every new `static var` in `Balance.gd` carries a `##` doc line
  (`test_script_documentation` enforces this) in Indonesian, matching the file.
- Every new function and every new `@export` in a `.gd` touched here carries its
  `##` documentation.

---

## Section 6 — AturJadwal specialty feedback

### Goal

When the player assigns a day whose activity matches the selected student's
specialty, the day's sticky note reacts — a gold particle burst, a scale-punch,
and a distinct SFX — and the Penjadwalan activity picker marks the specialty row
with a ★ badge **before** the player chooses, so the single most important
scheduling lever is legible.

### 6.1 `ActivityPreview.is_specialty()` — new public helper

`Scripts/AturJadwal/ActivityPreview.gd` already has private `_specialty_of()`.
Add:

```gdscript
## True when `category` is this student's normalized specialty. The one
## place any screen should ask "does this activity play to the student's
## strength" — the raw hobby_category spelling ("Akademik") is a trap.
static func is_specialty(category: String, student: Dictionary) -> bool:
    return _specialty_of(student) == category
```

### 6.2 `Scenes/AturJadwal/SpecialtyMatchBurst.tscn` — new authored particle scene

Modelled on `Scenes/SchoolSimulation/RewardBurst.tscn`. Root
`CPUParticles2D` (deterministic, cheap, no compile step), script
`Scripts/AturJadwal/SpecialtyMatchBurst.gd` (`@tool`, `class_name
SpecialtyMatchBurst`):

- `texture` = `res://Assets/Images/Particles/particle_star.png`.
- `one_shot = true`, `explosiveness = 1.0`, `emitting = false` at rest.
- `@export var burst_amount: int = 14` — `## Jumlah partikel bintang saat murid
  dijadwalkan ke mapel favoritnya.`
- `@export var spread_px: float = 46.0` — `## Radius sebaran partikel dari titik
  tengah note, dalam piksel.`
- `@export var life_seconds: float = 0.7` — `## Umur tiap partikel.`
- `@export var burst_color: Color` — `## Warna partikel; default emas dari
  DesignTokens.currency_gold jika dibiarkan kosong.` Resolved in `_ready()` from
  `DesignTokens.load_default().currency_gold` when left at the default.
- `func play()` → sets `amount`, `lifetime`, `emission_sphere_radius` /
  `spread` from the exports, `restart()`, `emitting = true`, then
  `await`-free self-free via a `SceneTreeTimer` connected to `queue_free`
  (the timer callback frees; `play()` itself does not await). Gated:
  `if Engine.is_editor_hint(): return` before emitting.
- Documented `##` file header per project rule.

### 6.3 `DayStickyNote` — matched-state visuals

`Scenes/AturJadwal/DayStickyNote.tscn` gains **two authored child nodes** under
`$Paper`, both `visible = false` by default:

- `MatchGlow` — `TextureRect`, `res://Assets/Images/Particles/particle_glow.png`,
  centred behind the labels, `mouse_filter = IGNORE`.
- `SpecialtyStar` — `TextureRect`, the ★ placeholder SVG
  (`res://Assets/Images/UI/Placeholders/icon_poin.svg` if no dedicated star SVG
  exists; otherwise add `icon_specialty_star.svg` alongside the other
  placeholders), small, top-left corner, `mouse_filter = IGNORE`.

`Scripts/AturJadwal/DayStickyNote.gd`:

- `@onready var _match_glow: TextureRect = $Paper/MatchGlow`
- `@onready var _specialty_star: TextureRect = $Paper/SpecialtyStar`
- `@export var specialty_match_burst_scene: PackedScene =
  preload("res://Scenes/AturJadwal/SpecialtyMatchBurst.tscn")` — `## Partikel
  yang muncul saat hari ini cocok dengan mapel favorit murid. @export agar tim
  visual bisa mengganti per instance.`
- Extend `_apply()` (or `show_scheduled()` / `show_empty()`) to hide both
  matched-state nodes whenever the note repaints, so a specialty state never
  lingers onto a later non-specialty assignment or a different student.
- New method:

```gdscript
## Plays the specialty-match reaction on top of the normal assign-pop: a
## gold particle burst from the note centre, a stronger scale-punch, and a
## persistent ★ + glow on the note. No-op in the editor. atur_jadwal.gd
## calls this INSTEAD OF play_assign_pop() when the assigned activity is the
## selected student's specialty.
func play_specialty_match() -> void:
    play_assign_pop()
    if _specialty_star:
        _specialty_star.visible = true
    if _match_glow:
        _match_glow.visible = true
    if Engine.is_editor_hint() or not is_inside_tree():
        return
    if _match_glow:
        _match_glow.modulate.a = 0.0
        var t := _get_tokens()
        var glow_tw := create_tween()
        glow_tw.tween_property(_match_glow, "modulate:a", 0.55, t.dur_fast)
        glow_tw.tween_property(_match_glow, "modulate:a", 0.30, t.dur_normal)
    if specialty_match_burst_scene:
        var burst := specialty_match_burst_scene.instantiate()
        add_child(burst)
        burst.position = size / 2.0
        if burst.has_method("play"):
            burst.play()
```

### 6.4 `atur_jadwal.gd::_on_activity_selected()`

At `atur_jadwal.gd:979`, after the day is written into
`GameState.day_schedules` and the existing `_assigned_note.play_assign_pop()`
block (`atur_jadwal.gd:997-999`):

```gdscript
var _student := GameState.selected_student
if _assigned_note and ActivityPreview.is_specialty(category, _student):
    _assigned_note.play_specialty_match()      # replaces the plain play_assign_pop()
    AudioDirector.play_sfx(&"specialty_match")
elif _assigned_note:
    _assigned_note.play_assign_pop()
    # existing AudioDirector.play_sfx(&"select") at line 980 stays as the default
```

Keep the existing `AudioDirector.play_sfx(&"select")` at line 980 for the
non-specialty path; on the specialty path play `&"specialty_match"` **instead of**
`&"select"` (restructure so the line-980 `select` call is in the `elif` branch,
not unconditional). Exactly one of `play_specialty_match()` / `play_assign_pop()`
runs, and exactly one SFX cue plays.

### 6.5 `AudioDirector` — new cue `&"specialty_match"`

`Scripts/Audio/AudioDirector.gd`:

- New `@export var sfx_specialty_match: AudioStream` — `## Dimainkan saat pemain
  menjadwalkan murid ke mapel favoritnya di Atur Jadwal. PLACEHOLDER: alias
  sfx_reward sampai ada aset sendiri.`
- Add `&"specialty_match": return sfx_specialty_match` to the `match` block in
  `_stream_for()` (around `AudioDirector.gd:235`).
- Add the cue to the `## play_sfx(...)` documentation list in the file header.
- In `project.godot` / the AudioDirector scene, assign `sfx_specialty_match` the
  **same stream resource as `sfx_reward`** (placeholder alias — matches how
  `tally`, `sparkle`, `star_earn_*` were introduced).

### 6.6 `ActivityRow` — specialty badge in the picker

`Scenes/AturJadwal/ActivityRow.tscn` gains an authored `SpecialtyBadge`
(`TextureRect`, the ★ SVG, top-right of `Container`, `visible = false`,
`mouse_filter = IGNORE`).

`Scripts/AturJadwal/ActivityRow.gd::refresh(student, grade, progress_percent)`:
at the end, toggle it:

```gdscript
var badge := get_node_or_null("Container/SpecialtyBadge") as TextureRect
if badge:
    badge.visible = ActivityPreview.is_specialty(category, student)
```

`refresh()` already runs every time the popup opens, so the badge follows the
selected student with no extra wiring.

### 6.7 Tests — `tests/test_atur_jadwal_specialty_feedback.gd` (new)

Source-scan + light-instantiate, matching the project's established AturJadwal
test style:

- `ActivityPreview.is_specialty("Akademis", marcel_dict)` is `true`;
  `is_specialty("Olahraga", marcel_dict)` is `false`; `"Akademik"` hobby
  normalizes (`is_specialty("Akademis", {"hobby_category":"Akademik"})` true).
- `SpecialtyMatchBurst.tscn` instantiates; root is `CPUParticles2D`;
  `one_shot == true`; has method `play`.
- `DayStickyNote.gd` source: `play_specialty_match` exists, calls
  `play_assign_pop`, sets `_specialty_star.visible` / `_match_glow.visible`,
  and `_apply()` (or the show_* methods) hide those two nodes on repaint.
- `DayStickyNote.tscn` contains nodes named `MatchGlow` and `SpecialtyStar`.
- `atur_jadwal.gd` source: `_on_activity_selected` references
  `ActivityPreview.is_specialty` and `play_specialty_match` and the
  `&"specialty_match"` cue, guarded so only one of the two note animations runs.
- `AudioDirector.gd` source: `sfx_specialty_match` export + `&"specialty_match"`
  match arm + header doc line.
- `ActivityRow.gd` source: `refresh` toggles `SpecialtyBadge` via
  `ActivityPreview.is_specialty`; `ActivityRow.tscn` contains a
  `SpecialtyBadge` node.
- `test_audio_coverage` / `test_project_hygiene` / `test_script_documentation` /
  `test_viewport_editability` stay green (new authored nodes, documented
  script, one-shot particle scene registered as an authored template — not a
  `BASELINE` regression).

---

## Section 7 — Beatability verification

Three layers, cheapest first. Layer 1 is the executable proof and the
tuning loop; layers 2–3 are human sanity checks done during execution.

### 7.1 `tests/test_balance_pacing.gd` — headless greedy simulation (new)

A `@tool`, non-coroutine `McpTestSuite` that runs the **actual** simulation
functions week-by-week under two scripted player policies, for each grade, and
asserts the clear-week lands in the intended window.

**Harness shape (no `await`, deterministic):**

- `seed(n)` at the top of each scenario via `RandomNumberGenerator` / `seed()`.
- Build an `Array[StudentData]` from a fixed 4-student roster (the real
  `student_data_list` values from `student_card.gd`, hard-copied into the test as
  a `const` so a roster edit does not silently move the goalposts).
- For each week, for each student, the **policy** picks 5 day-categories; write
  them into `GameState.day_schedules`; then drive one simulated week by calling
  the same methods `SchoolDay` calls in order:
  `StudentManager.apply_daily_decay_all(day)` for each of 5 days, with a
  scripted minigame outcome injected on the days the policy expects one
  (`record_minigame_result(...)` with a policy-chosen score ratio), honouring
  the §3 weekly cap and the §8 randomised allowance.
- After each week, `write_back_to_gamestate()`, then check
  `GameState.check_semester_passed()`. Record the first week where it is true.
- At each grade boundary call `GameState.reset_roster_for_new_grade()` so the
  head-start path is exercised too.

**Policies:**

- **`_policy_well_played(student, week)`** — assign the student's specialty on
  3–4 days, `Istirahat` when projected energy would drop below
  `Balance.IZIN_OTOMATIS_BATAS_ENERGI + one day's cost`, rotate the
  "focus subject" week to week so all three targets advance, take minigame wins
  at ~0.7 score ratio.
- **`_policy_careless(student, week)`** — always the same even split (2/2/1
  across the three skills), never `Istirahat`, never plays to specialty,
  minigame wins at ~0.4 ratio.
- **`_policy_stack_exploit(student, week)`** — every student onto the *same*
  single subject every day of the week, cycling subject per week; used only by
  the §8 assertion.

**Assertions:**

| Grade | well-played clears by | careless | not before |
|---|---|---|---|
| 7 | week ≤ 4 (of 6) | clears by week 6 (never unwinnable) | week 2 |
| 8 | week ≤ 9 (of 12) | misses ≤ 1 student-subject | — |
| 9 | week ≤ 14 (of 16) | misses ≤ 1 student-subject | — |

- **Seed spread:** run `_policy_well_played` for each grade across 20 seeds;
  assert the clear-week's mean is within the window and its spread is ≤ ±1 week
  from the median (numbers must not hinge on lucky RNG).
- **Exploit bound (§8):** `_policy_stack_exploit` clears grade 7 no earlier than
  **one week sooner** than `_policy_well_played` on the same seed — stacking may
  give a small edge, never a runaway one.

If any assertion fails, the executor tunes the §4 targets / §3 caps / §8
constants and re-runs (`test_run` is ~2 s). The final passing values replace the
estimates in §4 and this file's Status block is updated with the date.

### 7.2 MCP seeded manual playthrough (during execution)

- `⚡ Seed Playtest State` → Scenes tab → AturJadwal. Assign a real week,
  **screenshot the specialty burst + SFX firing** (§6), run SchoolDay, read
  ResultCheckup. Repeat for all **6 weeks of grade 7** — confirm it clears
  around week 3–4 with sensible play and is *not* clearable in week 1.
- For grades 8 and 9: seed, jump grade (confirm the roster reset visibly took —
  skills rebased, mood/energy 80), play the **first 3 weeks** of each, and check
  the per-week skill deltas match `test_balance_pacing.gd`'s figures for those
  weeks. The full 12/16-week tail is covered by the sim harness — 28 weeks of
  hand-clicking is out of scope and against the project's "seed, don't play to a
  state" guidance.

### 7.3 Status block maintenance

On merge, update this file's Status block: replace "estimates" with "verified by
`test_balance_pacing.gd` seed sweep on <date> + manual grade-7 confirm", and note
any value that moved from the §4 table during tuning.

---

## Section 8 — Anti-exploit: unpredictable minigame category & weekly allowance

The outer roll in `SchoolDay._roll_event()` (`w_normal` / `w_minigame` /
`w_event`, `active_studying * 15`, `CHANCE_*`) is **not touched**. Two changes
sit strictly inside the "which category" and "how many this week" sub-logic.

### 8.1 Category-choice noise

New `Balance` const (MINIGAME banner):

```
static var MINIGAME_KATEGORI_ACAK_PELUANG := 0.35
```

`##` doc: "Saat sebuah hari memunculkan Minigame, sebesar peluang ini
kategorinya diundi rata (Akademis/Olahraga/Seni) tanpa melihat jadwal. Sisanya
tetas ikut proporsi murid yang belajar. Bukan peluang munculnya minigame —
itu tidak berubah — hanya kategori mana yang muncul."

`SchoolDay._roll_event()`, the `outcome == "Minigame"` branch
(`SchoolDay.gd:889-905`), before the existing `total_subject_weight` logic:

```gdscript
if randf() < Balance.MINIGAME_KATEGORI_ACAK_PELUANG:
    var r := randi() % 3
    category_selected = "Akademis" if r == 0 else ("Olahraga" if r == 1 else "SeniBudaya")
else:
    # ── existing schedule-proportional pick, unchanged ──
    ...
```

Net effect: a 4-on-Akademis day lands an Akademis minigame ≈ `0.35/3 + 0.65 ≈
0.78` of the time instead of 1.0, and a subject nobody scheduled can still
appear. Scheduling still *tilts* the odds — it just no longer *guarantees* the
category.

### 8.2 Randomised weekly minigame allowance

New `Balance` consts (MINIGAME banner):

```
static var MINIGAME_MAKS_MINGGU_MIN := 1
static var MINIGAME_MAKS_MINGGU_MAX := 3
```

`##` doc: "Berapa minigame paling banyak dalam satu minggu — diundi ulang tiap
minggu di rentang ini (rata-rata ~2, sama seperti sebelumnya, tapi tidak bisa
dipastikan). Angka bulat."

`SchoolDay.gd`:

- Replace the hardcoded `minigames_played_this_week < 2` guard
  (`SchoolDay.gd:850`) with `minigames_played_this_week < max_minigames_this_week`.
- Add `var max_minigames_this_week: int = 2` next to the existing
  `var max_events_this_week: int = 2` (`SchoolDay.gd:121`), with a `##` doc line.
- In `start_simulation()` (`SchoolDay.gd:265`), next to
  `max_events_this_week = randi_range(1, 2)`, add
  `max_minigames_this_week = randi_range(Balance.MINIGAME_MAKS_MINGGU_MIN,
  Balance.MINIGAME_MAKS_MINGGU_MAX)`.

Average stays ~2, so §7's pacing windows hold, but "I will farm my two
guaranteed minigames" stops being a plan.

### 8.3 Interaction

These stack with the §3 per-student weekly points cap: category unreliable,
count 1–3, and even a lucky 3-win Akademis week is clipped at 14/12/10. The
exploit is closed from three directions without changing appearance frequency.

### 8.4 Tests

- `test_balance.gd` `_EXPECTED` gains `MINIGAME_KATEGORI_ACAK_PELUANG`,
  `MINIGAME_MAKS_MINGGU_MIN`, `MINIGAME_MAKS_MINGGU_MAX`.
- `tests/test_school_day.gd` (source-scan): `start_simulation` rolls
  `max_minigames_this_week` via `randi_range` (no literal `2` guard remains);
  `_roll_event` branches on `MINIGAME_KATEGORI_ACAK_PELUANG` before the
  proportional pick; the `minigames_played_this_week` guard compares against
  `max_minigames_this_week`.
- `test_balance_pacing.gd` `_policy_stack_exploit` bound from §7.1.

---

## File-touch summary

| File | Sections |
|---|---|
| `Scripts/Balance.gd` | 3, 4, 8 |
| `tests/test_balance.gd` | 3, 4, 8 (pinning) |
| `Scripts/GameState.gd` | 2, 3 |
| `Scripts/EndGame/RunResult.gd` | 2 |
| `Scripts/SchoolSimulation/StudentManager.gd` | 3 |
| `Scripts/SchoolSimulation/SchoolDay.gd` | 3, 4, 8 |
| `Scripts/StudentCard/student_card.gd` | 2 (roster_base capture) |
| `Scripts/AturJadwal/ActivityPreview.gd` | 6 |
| `Scripts/AturJadwal/atur_jadwal.gd` | 6 |
| `Scripts/AturJadwal/DayStickyNote.gd` + `.tscn` | 6 |
| `Scripts/AturJadwal/ActivityRow.gd` + `.tscn` | 6 |
| `Scenes/AturJadwal/SpecialtyMatchBurst.tscn` + `Scripts/AturJadwal/SpecialtyMatchBurst.gd` | 6 (new) |
| `Scripts/Audio/AudioDirector.gd` + AudioDirector scene | 6 |
| `tests/test_roster_reset.gd` | 2 (new) |
| `tests/test_minigame_weekly_cap.gd` | 3 (new) |
| `tests/test_atur_jadwal_specialty_feedback.gd` | 6 (new) |
| `tests/test_balance_pacing.gd` | 7 (new) |
| `Scripts/Debug/DebugManager.gd` | 2 (verify `_set_grade` path calls through `GameState.set_grade`) |

## Open risks

- **Head-start via `set_grade()` double-application.** Guarded by "grade actually
  changed & roster non-empty", but a debug user pressing G8 twice must not stack.
  The plan's `set_grade` task includes an explicit "grade unchanged → no-op" test.
- **`roster_base_*` missing on an in-progress save-less session** that predates
  this change — impossible (no persistence), but the fallback capture in
  `reset_roster_for_new_grade()` covers the debug-seed roster path regardless.
- **Pacing estimates.** `TARGET_KENAIKAN_KELAS_9 = 50` and the caps are the least
  certain numbers. §7.1 is designed so they can move without touching any other
  section.
- **Editor cache** on the new `Balance` `static var`s and the new `@export`s
  (`DayStickyNote.specialty_match_burst_scene`, `AudioDirector.sfx_specialty_match`)
  — expect to need a `script_patch` no-op reload; noted in Global Constraints.
