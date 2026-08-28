# Balance Tuning — One Master Script

**Date:** 2026-08-28
**Status:** Approved, pending implementation plan

> Replaces an earlier draft of this document that proposed a tunable
> `Resource` plus an in-game editing panel plus a batch simulator. That design
> was larger than the problem. See "What was cut, and why" at the end.

## Problem

KejarTes is decided by numbers. Whether a student clears their three targets
before the grade's final week depends on decay rates, study gains, efficiency
multipliers, minigame win/loss amounts, trait coefficients, and the per-grade
target uplift.

A tester who plays a week and feels something is wrong — "losing that minigame
gutted her mood" — cannot act on it. The number they want is a bare literal
inside a function body: `roundf(randf_range(6.0, 8.0))` in
`apply_personality_daily_decay`, or `mood_change = -18.0` inside an
`elif grade_num == 8` branch. Finding it means reading gameplay source. There
are roughly ninety such numbers across four files.

**The tester should be able to open one file, understand what each number
does, change it, and re-run — without reading code and without asking anyone.**

## Goals

1. Every number affecting balance lives in exactly one file.
2. That file is readable by someone who does not program: each number says, in
   Indonesian, what it does in the game and which student it affects.
3. Changing a number and re-running the game applies it. No code editing
   elsewhere, no hunting.
4. The change is a normal file edit, so it is a git diff a developer can review.

## Non-Goals

- **No in-game editing panel.** Testers here run the project from the Godot
  editor, so they can edit the file directly. A panel is deferred, not
  rejected — see the `static var` note below, which keeps it cheap to add.
- **No batch simulator.** An earlier draft proposed running semesters headlessly
  and reporting win rates. That answers "is this statistically winnable", which
  is not the question being asked. The tester plays the game.
- **No new save system.** `Balance.gd` is source, versioned in git. `GameState`
  gains no persistence.
- **No rebalancing.** This ships today's numbers unchanged. It supplies the
  instrument, not the tuning.

---

## 1. The file

`Scripts/Balance.gd` — a `class_name Balance` holding every tunable as a
`static var`, grouped and commented in Indonesian.

```gdscript
## Balance.gd — semua angka yang menentukan murid lulus atau tidak.
##
## Cara pakai: ubah angkanya, simpan (Ctrl+S), lalu jalankan ulang game.
## Angka-angka ini tidak ada di tempat lain — semuanya dibaca dari sini.
##
## Biar cepat balik ke situasi yang mau diuji setelah restart:
## tekan F1 > "Seed Playtest State", lalu buka tab "Scenes" untuk
## langsung lompat ke layar yang kamu mau.
##
## Catatan buat programmer: di dalam kode, kategori "Libur" tersimpan
## dengan nama "Istirahat". Nama di file ini mengikuti tombol yang
## dilihat tester, bukan nama internalnya.
class_name Balance
```

### `static var`, not `const`

Two reasons, and the second is the important one:

1. A GDScript `const` is compile-time. Nothing can ever change it at runtime.
2. `static var` costs nothing today and preserves the option: if restart
   friction later proves annoying, an editing panel can write to these
   directly, with **zero rework across the ~90 call sites**. With `const`,
   adding a panel would mean redoing every one.

`static var` is already used in five places in this codebase
(`AnimUtils.gd`, `Juice.gd`, `atur_jadwal.gd`, `student_list.gd`), so it is
established, not novel.

### Call sites

Each literal becomes a field read:

```gdscript
# before
"Aktif":
	energy_loss = roundf(randf_range(6.0, 8.0))

# after
"Aktif":
	energy_loss = roundf(randf_range(Balance.DECAY_AKTIF_ENERGI_MIN,
		Balance.DECAY_AKTIF_ENERGI_MAX))
```

**Randomness is untouched.** Where the game rolls a random amount, the *range*
becomes tunable; the roll itself is unchanged.

---

## 2. Readability is the product

The file's usability by a non-programmer is the deliverable, not a nicety. Five
conventions carry that:

**Ordered by impact, not alphabetically or by source file.** A tester scrolling
from the top meets the biggest levers first: passing requirements → study days
→ minigames → personality decay → traits → Wirausaha.

**Names and comments both in Indonesian.** `MINIGAME_KALAH_MOOD_KELAS_8` reads
directly. This extends a habit the codebase already has — `WIRAUSAHA_EARN_MIN`
is an Indonesian domain word with English structure.

**Game vocabulary, not code vocabulary.** The file says *Libur* because that is
the button in Atur Jadwal, even though the category is stored internally as
`"Istirahat"`. It says *Sifat Pasif* because that is the heading on the student
card. The tester should be able to move from what they saw on screen to the
right line without translating.

**Every trait names its student.** A tester tuning *Kutu Buku* should not have
to work out that this is Marcel.

**Percentage-style numbers are translated.** `0.25` alone means nothing;
"25% lebih hemat" does. These are the ones most likely to be changed in the
wrong direction, so each states which way is which. Likewise every random range
is a `_MIN`/`_MAX` pair with a note that the game rolls between them — so it is
clear both must move to shift the range.

### Sample

```gdscript
## ═══════════════════════════════════════════════════════════
## HARI BELAJAR BIASA
## (saat kamu menjadwalkan Akademis, Seni Budaya, atau Olahraga)
## ═══════════════════════════════════════════════════════════

## Poin mata pelajaran yang didapat dari satu hari belajar.
static var BELAJAR_POIN_KELAS_7 := 3.0

## Energi yang terpakai untuk satu hari belajar. Game mengacak
## angka di antara kedua nilai ini, jadi tiap hari tidak persis sama.
static var BELAJAR_BIAYA_ENERGI_MIN := 15.0
static var BELAJAR_BIAYA_ENERGI_MAX := 20.0

## Pengali biaya di atas, tergantung mata pelajarannya.
## Di bawah 1.0 = lebih hemat. Di atas 1.0 = lebih melelahkan.
## 0.6 artinya mapel favorit cuma memakan 60% biaya.
static var BIAYA_KALAU_MAPEL_FAVORIT := 0.6

## ── Kutu Buku (Marcel) ──
## Poin Akademis tambahan di hari belajar.
static var SIFAT_KUTU_BUKU_BONUS_POIN := 1.0

## Kreatif — Andi DAN Thea. Mengubah angka ini kena dua murid sekaligus.
static var DECAY_KREATIF_ENERGI_MIN := 5.0
```

---

## 3. What gets extracted

Roughly **90 numbers**, counted from source:

| Group | Count | Source |
|---|---|---|
| Passing requirement (target uplift per grade) | 3 | `GameState.initialize_grade_targets` |
| Study day gains (base + specialty, per grade) | 8 | `StudentManager.apply_daily_decay_all`, `apply_jadwal_effects_all` |
| Study day costs + rest recovery | 8 | `StudentData.apply_jadwal_activity` |
| Efficiency multipliers | 3 | `StudentData.get_category_efficiency_multiplier` |
| Thresholds (auto-Izin, tired) | 2 | `StudentData` |
| Minigame win/loss amounts | ~24 | `StudentData.apply_minigame_result` |
| Personality decay ranges | 20 | `StudentData.apply_personality_daily_decay` |
| Trait coefficients | 19 | `StudentData` `@export`s |
| Wirausaha | 5 | `StudentManager` const block |
| Skip-mode minigame odds | 1 | `SchoolDay.skip_to_results` |

The plan enumerates each line individually; this spec fixes the groups and
their sources.

### Two data facts the file should record

Both surfaced while mapping students to traits, and both are balance
information a tester would want:

1. **The comments in `StudentData.gd` today are wrong.** Its decay branches are
   labelled `# Budi: Sporty`, `# Ani: Academic`, `# Cici: Artistic` — names
   from `StudentManager`'s fallback roster, not the actual six students. Anyone
   reading them is misled. The new file corrects this.
2. **Citra's personality bonus rarely fires.** Her personality is *Seni Dalam
   Kesunyian*, which rewards studying Seni Budaya alone, but her favourite
   subject is **Olahraga**. The file notes this beside the number, since
   "this seems to do nothing" is otherwise a confusing dead end.

### The safety property

Extraction must be provably behaviour-preserving. Two things guarantee it:

1. `Balance.gd` ships seeded with **today's exact values**, so a correct
   extraction changes nothing observable.
2. The existing 303-test suite already pins numeric outcomes —
   `test_wirausaha`, `test_school_day`, `test_economy_state` — so a value that
   shifts during the move fails a test rather than silently altering difficulty.

Extraction lands in one commit per group, suite green after each.

---

## 4. Testing

- `tests/test_balance.gd` — a source scan asserting the four touched functions
  contain no leftover bare numeric literals. This is the real guard: a missed
  extraction leaves a field in the file that silently does nothing when the
  tester changes it, which is worse than not having the field. Plus: every
  field named in the spec exists on the class, and defaults match the values
  the game shipped with.
- **The existing suite is the extraction's guard.** No new test proves a
  literal moved correctly; `test_wirausaha` and `test_school_day` already do,
  by asserting outcomes that depend on those numbers.

Per the runner's constraints: the suite is `@tool` and no test is a coroutine.

---

## 5. Risks

1. **~90 mechanical edits in gameplay-critical files.** The volume is the main
   cost and the main risk, mitigated by per-group commits each verified green.
2. **A missed literal is invisible.** Its field appears in the file and does
   nothing. The no-bare-literals source scan is the defence.
3. **A typo is a parse error.** `6.o` instead of `6.0` stops the game booting.
   Loud and immediate rather than silent, but the tester must be comfortable
   that this is their own fix. The file header could note it; the grouping and
   one-number-per-line layout keep the blast radius small.
4. **Restart per change.** Accepted deliberately. `Seed Playtest State` plus
   the Scenes tab is the fast path back, and the file header points at it.

---

## What was cut, and why

The first draft of this design proposed a `BalanceTokens` Resource, a
`.tres` asset, an in-game Balance tab with ~90 rows plus grouping, filtering,
change-tracking and reset, a `ResourceSaver` path, an export-snippet
generator, scenario snapshot/restore, and a headless batch simulator.

The extraction — the actual work — is **identical** in both designs. Everything
above it was scaffolding for live editing, which is not needed when the tester
runs the project from the editor and accepts a restart. Two pieces turned out
redundant rather than merely unbuilt:

- The **export snippet** is pointless when the file *is* the artifact; a
  developer gets a git diff.
- **Snapshot/restore** does not survive a restart, and `Seed Playtest State`
  already does that job and does survive.

Deferred, recorded rather than deleted: the in-game panel (cheap to add later
thanks to `static var`), `.tres` persistence, and batch simulation.
