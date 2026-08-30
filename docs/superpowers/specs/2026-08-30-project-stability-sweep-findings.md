# Project Stability Sweep — Findings

**Date:** 2026-08-30
**Branch:** `Textures`
**Method:** live editor session inspection (`editor_state`, `logs_read` on both
the `game` and `editor` buffers), full test-suite run (`test_run`), and static
scans of `Scripts/`, `Scenes/`, `tests/`.

This document is the *spec* for
`docs/superpowers/plans/2026-08-30-project-stability-sweep.md`. Every finding
below was observed, not inferred from reading code alone; where a claim rests on
a single observation rather than a reproduction, it says so.

---

## Baseline: what is already healthy

`test_run` on 2026-08-30 with `Scenes/Splashscreen/Splashscreen.tscn` open:

```
suite_count: 28, total: 421, passed: 420, failed: 1, duration_ms: 4425
```

The single failure is F3 below. Notably, **Known Issue #2 in `CLAUDE.md` (the
`test_audio_coverage` double-SFX failure across six functions) no longer
reproduces** — that suite passes. See F8.

---

## F1 — `_run_day()` is an unbounded self-recursive coroutine (crash)

**Severity: high — observed crash.**

The live editor session was found parked in a debugger break:

```
"break": { "reason": "Stack overflow (stack size: 1024). Check for infinite
           recursion in your script." }
```

`Scripts/SchoolSimulation/SchoolDay.gd` drives the five-day week by recursion,
not iteration. `_run_day()` has exactly two call sites:

- `SchoolDay.gd:230` — `start_simulation()` kicks off day 0
- `SchoolDay.gd:359` — **`_run_day()` calls itself** after `current_day += 1`

`_run_day()` is a coroutine: it `await`s eight times between lines 289 and 355.
A GDScript coroutine that tail-calls itself never unwinds — the parent frame is
suspended at its final `await`, still on the stack, when the child frame starts.
Depth therefore grows monotonically with the number of days run, and nothing in
the function ever returns to release a frame.

Stack traces captured from the editor buffer confirm the nesting is real and
that it is `_run_day` → `_run_day`:

```
SchoolDay.gd:653 @ _add_pill()
SchoolDay.gd:598 @ _build_pill_badges_for_student()
SchoolDay.gd:455 @ _render_embedded_student_status()
SchoolDay.gd:281 @ _run_day()
SchoolDay.gd:359 @ _run_day()     <-- self-call, one level down
```

versus the day-0 trace, which bottoms out in `_ready`:

```
SchoolDay.gd:281 @ _run_day()
SchoolDay.gd:230 @ start_simulation()
SchoolDay.gd:168 @ _ready()
```

**Honest limit on this finding:** a single five-day week nests only five frames,
which alone cannot exhaust a 1024-frame stack. The overflow was observed after a
long session in which the debug overlay was used to teleport into
`SchoolDay.tscn` repeatedly and two "START WEEK" presses were logged, and the
editor error buffer had already dropped 2708 entries by the time it was read, so
the frame that actually crossed the limit is no longer recoverable. What is
certain is the structural defect: **recursion depth here is unbounded by design
and grows with every day simulated.** Converting it to a loop removes the entire
failure class and costs nothing, which is why the plan fixes it first rather
than waiting for a reliable reproduction.

---

## F2 — `_add_pill()` re-parents a scene-owned Label, flooding the log

**Severity: medium — no visual breakage, but it destroys log usability.**

`SchoolDay.gd:475` `_make_chip()` instantiates `DaySummaryPill.tscn` and returns
the chip; its `Text` Label therefore carries `owner == <DaySummaryPill root>`.
`_add_pill()` then re-parents that Label under a freshly constructed
`HBoxContainer` whose owner is `null`:

```gdscript
chip.remove_child(lbl)
chip.add_child(hbox)
hbox.add_child(tex_rect)
hbox.add_child(lbl)        # SchoolDay.gd:653 -- warns here
```

Every call emits:

```
SchoolDay.gd:653 @ _add_pill(): Adding 'Text' as child to '@HBoxContainer@1617'
will make owner 'DaySummaryPill' inconsistent. Consider unsetting the owner
beforehand.
```

This fires once per badge, per student, per day. In the observed session it was
the overwhelming majority of both log buffers and directly caused
`dropped_count: 2708` on the editor buffer — which is what made F1's crash frame
unrecoverable. **Fixing this restores the ability to diagnose anything else on
this screen.**

The engine's own advice is the fix: clear `owner` before re-parenting.

---

## F3 — `test_volumes_persist_across_a_fresh_director` is a coroutine (fails)

**Severity: medium — a permanently red test.**

`tests/test_audio_director.gd:108`. Documented in `CLAUDE.md` Known Issue #1 and
still present. It `await`s at line 111; the runner calls `suite.call(name)`
without awaiting, so the test is abandoned there and scores:

```
"Test completed with 0 assertions (likely skipped its logic)"
```

Its restore-to-1.0 cleanup on lines 121-122 never runs either. This is the only
failure in the suite.

---

## F4 — `test_rapid_volume_changes_do_not_write_once_per_change` passes while half-skipped

**Severity: medium — a test reporting false confidence.**

`tests/test_audio_director.gd:127`. Same defect as F3, but *worse*, because it is
invisible: this test has assertions **before** its `await` (line 140), so it
scores a non-zero assertion count and reports **PASS**.

Its post-`await` assertion — the one that actually proves the debounced write
lands rather than being silently dropped — never executes:

```gdscript
await Engine.get_main_loop().create_timer(0.5).timeout   # runner abandons here
var after: int = _director.get_volume_save_count()
assert_true(after - before == 1, ...)                    # NEVER RUNS
```

The test's own comment states this assertion exists precisely because "a
debounce that silently DROPPED the save (e.g. a stray early return) would still
pass the assertion above." That protection is currently absent while the suite
reports green.

---

## F5 — the audio suite dirties a committed asset on every run

**Severity: medium — repository hygiene, reproduced on demand.**

`Assets/Audio/default_bus_layout.tres` was clean before the sweep's `test_run`
and dirty immediately after:

```
-bus/1/volume_db = 0.0
+bus/1/volume_db = -7.535014      # BGM, set to 0.42 linear by F3
-bus/2/volume_db = 0.0
+bus/2/volume_db = -10.457575     # SFX, left by F4's 50-change loop
```

`CLAUDE.md` documents only the BGM half. **Both buses leak**, because F4 dirties
SFX and never restores it either.

The root cause is a wrong assumption in the suite's own `setup()` comment:

> "Instantiate a fresh copy rather than poking the live autoload, so volume
> changes in these tests do not leak into the running game."

Instantiating a fresh `AudioDirector` does **not** isolate anything.
`AudioDirector.set_bus_volume()` (`Scripts/Audio/AudioDirector.gd:380`) writes to
`AudioServer`, which is process-global. The editor's live mixer is mutated, and
Godot writes that state back into the project's default bus layout resource.

Per-test cleanup cannot fix this on its own, because a test that fails or is
abandoned mid-way (exactly what F3 does) never reaches its own restore. The
snapshot/restore must live in `setup()`/`teardown()`.

---

## F6 — 14 stale `ext_resource` UIDs across 6 scenes

**Severity: low — warnings only; Godot falls back to the text path and loads.**

`docs/superpowers/baseline/known-errors.md` records 4 of these and declares them
understood. A full audit of every `.tscn` against the true UID in each asset's
`.import` sidecar finds **14, in six scenes** — including `atur_jadwal.tscn`
(6 refs) and `SemesterEnd.tscn` (4 refs), neither of which appears in the
baseline document at all.

Every referenced asset exists on disk; only the UID is wrong. The complete
mapping (verified by reading `uid=` from each `<asset>.import`):

| Scene | Line | Scene claims | True UID | Asset |
|---|---|---|---|---|
| `Scenes/AturJadwal/atur_jadwal.tscn` | 4 | `uid://dvkb3glcg53su` | `uid://bmxugmsumo04o` | `Assets/Images/UI/whiteboard.png` |
| `Scenes/AturJadwal/atur_jadwal.tscn` | 6 | `uid://0c5vps0sx30f` | `uid://dbkqgaqqwkp57` | `Assets/Images/UI/stickynotes.png` |
| `Scenes/AturJadwal/atur_jadwal.tscn` | 7 | `uid://0ycjsvqdwjf3` | `uid://cqc6snupncqgd` | `Assets/Images/UI/pngwing.com (2).png` |
| `Scenes/AturJadwal/atur_jadwal.tscn` | 8 | `uid://4slit8im18tb` | `uid://6rhjvqlmehwq` | `Assets/Images/UI/Screenshot 2026-08-02 104848.png` |
| `Scenes/AturJadwal/atur_jadwal.tscn` | 10 | `uid://bhanm4qbpra2a` | `uid://dlyxcrhuswotn` | `Assets/Images/UI/paper.png` |
| `Scenes/AturJadwal/atur_jadwal.tscn` | 11 | `uid://cuih86con4sr1` | `uid://c8uw72nl2167r` | `Assets/Images/UI/pngwing.com (1).png` |
| `Scenes/CutScene/cut_scene.tscn` | 4 | `uid://f0niudwtemxb` | `uid://cfe2yal5hh4dl` | `Assets/Images/UI/BG.jpg` |
| `Scenes/EndGame/SemesterEnd.tscn` | 4 | `uid://bhanm4qbpra2a` | `uid://dlyxcrhuswotn` | `Assets/Images/UI/paper.png` |
| `Scenes/EndGame/SemesterEnd.tscn` | 5 | `uid://b6p4x47c2s0gq` | `uid://b0ah0m8tx4h7q` | `Assets/Images/UI/Placeholders/icon_akademis.svg` |
| `Scenes/EndGame/SemesterEnd.tscn` | 6 | `uid://cye75x61s7rge` | `uid://cxym6c466l7q8` | `Assets/Images/UI/Placeholders/icon_seni.svg` |
| `Scenes/EndGame/SemesterEnd.tscn` | 7 | `uid://chfshk4b7u2w` | `uid://cj4co2v2kmqrg` | `Assets/Images/UI/Placeholders/icon_olahraga.svg` |
| `Scenes/Loading/loading.tscn` | 4 | `uid://cwmltvrg3rr1t` | `uid://b1l1tgslf2wkw` | `Assets/Images/UI/—Pngtree—book icon vector_4358423.png` |
| `Scenes/StudentList/student_list.tscn` | 4 | `uid://c7gmkcle3uv8o` | `uid://d2cvc7nosdip2` | `Assets/Images/MuridPotrait/Murid1.jpg` |
| `Scenes/StudentList/student_list.tscn` | 6 | `uid://bhanm4qbpra2a` | `uid://dlyxcrhuswotn` | `Assets/Images/UI/paper.png` |

Note `uid://bhanm4qbpra2a` appears three times for `paper.png` — one wrong UID
copy-pasted across three scenes.

---

## F7 — leftover `DEBUG` prints in production code

**Severity: low — log noise, but it compounds F2.**

Five `print("DEBUG…")` calls survive outside `Scripts/Debug/`:

| File | Line | Statement |
|---|---|---|
| `Scripts/AturJadwal/atur_jadwal.gd` | 564 | `print("DEBUG selected_student: ", GameState.selected_student)` |
| `Scripts/AturJadwal/atur_jadwal.gd` | 659 | `print("DEBUG: TOMBOL TERTEKAN!")` |
| `Scripts/AturJadwal/atur_jadwal.gd` | 692 | `print("DEBUG: START WEEK DITEKAN!")` |
| `Scripts/AturJadwal/atur_jadwal.gd` | 875 | `print("DEBUG: PROCEEDING START WEEK")` |
| `Scripts/StudentCard/student_card.gd` | 1528 | `print("DEBUG approve ditekan, tutorial_active: ", tutorial_active)` |

`atur_jadwal.gd:564` is the worst: it dumps the entire `selected_student`
dictionary and was observed firing **six times per student selection**.

---

## F8 — `CLAUDE.md` is stale in four places

**Severity: low — but it actively misleads the next session.**

| Claim in `CLAUDE.md` | Reality on 2026-08-30 |
|---|---|
| "23 suites, 284 tests" | 28 suites, 421 tests |
| "Current work: branch `feat/koperasi-inventory-integration`" | branch is `Textures`; the koperasi tasks are committed and the recent log is all day-summary work |
| Known Issue #2: `test_audio_coverage` double-SFX failure | does not reproduce — that suite passes |
| Known Issue #3: stale UIDs in `student_list.tscn` and `loading.tscn` | 14 refs across 6 scenes (F6) |

Known Issue #1 (the coroutine test) remains accurate and is F3 here.

---

## Explicitly out of scope

- **Minigames** (`Scenes/Minigames/**`) and `Scripts/Debug/DebugManager.gd` —
  `CLAUDE.md` declares both outside the design system. Their
  `add_theme_*_override` calls are not treated as defects here.
- **`Scripts/Inventory/inventory.gd` and `Scripts/Koperasi/koprasi.gd` hardcoded
  colors** — these are the ported shop screens, and restyling them onto the theme
  is already the subject of the koperasi integration spec's Asset Policy. Not
  re-litigated here.
- **`addons/godot_ai/**` working-tree changes** — a vendored plugin update, not
  this project's code.
- **`SafeAreaMargin` clamp warnings** — the clamp is deliberate, documented in
  the source, and the warning is the intended diagnostic for a windowed editor
  run. Working as designed.
- **`Assets/Theme/kejartes_theme.tres` working-tree diff** — Godot 4.6 adding
  `uid=` attributes on resave. Incidental, not a defect.
