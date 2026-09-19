# Student Chatter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lobby students blink every 5–10 s and speak short trait/quirk/mood-based lines in a chat bubble that pops from their own seat, on tap or after 20–50 s idle, one at a time, spam-proof.

**Architecture:** A static line catalog + a shuffle-bag picker pick the text; a `StudentChatBubble` PackedScene (Herman's pop motion, mirrored tail) shows it at a per-seat `ChatAnchor`; a `LobbyChatter` node in `loby.tscn` owns taps, the spam guard, the idle timer and the gate that `loby.gd` hands it.

**Tech Stack:** Godot 4.6 GDScript, McpTestSuite via godot-ai `test_run`.

Spec: `docs/superpowers/specs/2026-09-19-student-chatter-design.md`.

## Global Constraints

- Worktree `.claude/worktrees/student-chatter`, branch `feat/student-chatter`. It has its own editor (ship-pr §3): every `test_run`/scene call passes that editor's `session_id`. Never `session_activate`, never kill every Godot.
- Scene work through the editor (`scene_open` → `node_*` → `scene_save`), never hand-edit `.tscn` while it is attached. Scene work first, script work second; after each `scene_save`, `git diff HEAD -- '*.gd'` for files you did not mean to touch.
- Edit `.gd` via `script_patch` or, after an outside write, a no-op `script_patch` before `test_run`.
- No `theme_override_*`; new visuals are type variations in `ThemeFactory.gd`, then rebake (`test_run(suite="theme_rebake")`).
- Every script: `##` header, `##` on every `@export`. Suites `@tool`, no coroutine tests, `suite_name()` overridden.
- Lines: Indonesian, ≤ 60 chars, no emoji, students say "Pak".
- Our tunables are named consts / `@export`s; `Balance.gd` untouched.
- Commits: Conventional Commits with scope, ending with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`; messages via `git commit -F`.

## File map

| File | Responsibility |
|---|---|
| `Scripts/Lobby/StudentChatterCatalog.gd` | line pools, `state_for`, `personality_of`, `trait_pool` |
| `Scripts/Lobby/StudentChatterPicker.gd` | per-student shuffle bags |
| `Scenes/Lobby/StudentChatBubble.tscn` + `Scripts/Lobby/StudentChatBubble.gd` | the bubble: placement, flip, pop in/out FSM |
| `Scripts/Lobby/LobbyChatter.gd` | seats, taps, spam guard, idle timer, gate |
| `Scenes/Lobby/loby.tscn`, `Scripts/Lobby/loby.gd` | anchors, bubble instance, `Chatter`, wiring |
| `Scripts/Design/ThemeFactory.gd` | `StudentChatBubble`, `StudentChatText` |
| `tests/test_student_chatter.gd` | suite `student_chatter` |
| `Scripts/Lobby/StudentFace.gd`, `tests/test_student_face.gd` | idle blink on, faded lid (addendum) |

---

### Task 0: Worktree editor

- [ ] Copy `imported/`, `shader_cache/`, `uid_cache.bin`, `global_script_class_cache.cfg`, `scene_groups_cache.cfg` from the main checkout's `.godot/` into the worktree's `.godot/`.
- [ ] Launch `<Godot exe> --path <worktree> -e` in the background; `session_manage(op="list")`; note the worktree's `session_id` (project_path ends in `student-chatter`).
- [ ] `test_run(suite="koperasi_chat_bubble", session_id=…)` — Expected: PASS (proves the editor works).

### Task 1: Theme variations

**Files:** Modify `Scripts/Design/ThemeFactory.gd`; Create `tests/test_student_chatter.gd`; rebake `Assets/Theme/kejartes_theme.tres`.

**Produces:** type variations `StudentChatBubble` (PanelContainer) and `StudentChatText` (Label).

- [ ] **Step 1: failing test** — create `tests/test_student_chatter.gd`:

```gdscript
@tool
extends McpTestSuite

## Student chatter in the Lobby (2026-09-19 spec): the line catalog and its
## shuffle-bag picker, the StudentChatBubble's placement/flip/FSM, the
## LobbyChatter's spam guard, idle timer and gate, and loby.tscn's wiring.
## @tool, and no test here is a coroutine: tweens are started but never
## awaited, so only synchronous state (text, position, pivot, busy) is read.

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _TOKENS_PATH := "res://Assets/Theme/design_tokens.tres"


func suite_name() -> String:
	return "student_chatter"


# ----- Theme -----

func test_bubble_variation_is_a_card_panel() -> void:
	var theme := load(_THEME_PATH) as Theme
	var tokens := load(_TOKENS_PATH) as DesignTokens
	assert_eq(theme.get_type_variation_base("StudentChatBubble"), &"PanelContainer")
	var box := theme.get_stylebox("panel", "StudentChatBubble") as StyleBoxFlat
	assert_true(box != null, "StudentChatBubble has a flat panel")
	if box:
		assert_eq(box.bg_color, tokens.surface_card)


func test_text_variation_is_bold_body_title_size() -> void:
	var theme := load(_THEME_PATH) as Theme
	var tokens := load(_TOKENS_PATH) as DesignTokens
	assert_eq(theme.get_type_variation_base("StudentChatText"), &"Label")
	assert_eq(theme.get_font("font", "StudentChatText"), tokens.font_body_bold)
	assert_eq(theme.get_font_size("font_size", "StudentChatText"), tokens.font_title)
	assert_eq(theme.get_color("font_color", "StudentChatText"), tokens.text_primary)
```

- [ ] **Step 2:** `test_run(suite="student_chatter")` — Expected: FAIL (variation base empty).

- [ ] **Step 3: implement** — in `ThemeFactory.gd` add a const next to `SHOP_CHAT_BUBBLE_RADIUS` and a builder after `_build_shop_chat_bubble`, called right after it at line 30:

```gdscript
## Corner radius of the Lobby students' chat bubble; smaller than Herman's
## because the bubble is about half his width.
const STUDENT_CHAT_BUBBLE_RADIUS := 24
```

```gdscript
	_build_student_chat(theme, tokens)
```

```gdscript
## The Lobby students' chat bubble (2026-09-19 student-chatter spec): the
## same card-white box as Herman's, with tighter margins for its 560 px
## width, and bold body text at font_title. Body font, so not on
## DISPLAY_ROSTER.
static func _build_student_chat(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("StudentChatBubble")
	theme.set_type_variation("StudentChatBubble", "PanelContainer")
	var bubble := StyleBoxFlat.new()
	bubble.bg_color = tokens.surface_card
	bubble.set_corner_radius_all(STUDENT_CHAT_BUBBLE_RADIUS)
	bubble.content_margin_left = tokens.space_md
	bubble.content_margin_right = tokens.space_md
	bubble.content_margin_top = 20
	bubble.content_margin_bottom = 20
	theme.set_stylebox("panel", "StudentChatBubble", bubble)

	theme.add_type("StudentChatText")
	theme.set_type_variation("StudentChatText", "Label")
	var bold: Font = tokens.font_body_bold if tokens.font_body_bold != null else tokens.font_body
	theme.set_font("font", "StudentChatText", bold)
	theme.set_font_size("font_size", "StudentChatText", tokens.font_title)
	theme.set_color("font_color", "StudentChatText", tokens.text_primary)
```

(The 20 px vertical margin is a literal because no token sits between `space_sm` and `space_md`; name it `STUDENT_CHAT_BUBBLE_PAD_Y := 20` beside the radius const and use that.)

- [ ] **Step 4:** no-op `script_patch` on `ThemeFactory.gd`, `test_run(suite="theme_rebake")`, then `test_run(suite="student_chatter")` and `test_run(suite="theme_factory")` — Expected: PASS. `git diff --stat Assets/Theme/kejartes_theme.tres` shows the bake changed.
- [ ] **Step 5: commit** `feat(theme): student chat bubble variations` (ThemeFactory, bake, test).

### Task 2: Catalog + picker

**Files:** Create `Scripts/Lobby/StudentChatterCatalog.gd`, `Scripts/Lobby/StudentChatterPicker.gd`; extend the suite.

**Produces:**
- `StudentChatterCatalog.PERSONALITY_LINES: Dictionary[String→Array]`, `QUIRK_LINES`, `STATE_LINES: Dictionary[StringName→Array]`, `GENERIC_LINES: Array`, `STATE_CHANCE := 0.4`, `MAX_LINE_CHARS := 60`
- `static func personality_of(student: Dictionary) -> String`
- `static func state_for(student: Dictionary) -> StringName` (`&""`, `&"LELAH"`, `&"BETE"`, `&"SENANG"`)
- `static func trait_pool(student: Dictionary) -> Array`
- `StudentChatterPicker.new()`, `.rng: RandomNumberGenerator`, `.pick(student: Dictionary) -> String`, `.draw(key: String, pool: Array) -> String`

- [ ] **Step 1: failing tests** — append:

```gdscript
# ----- Catalog -----

const _PERSONALITIES := ["Aktif", "Tekun", "Kreatif", "Santai", "Seni Dalam Kesunyian"]
const _QUIRKS := ["Kutu Buku", "Penyendiri", "Semangat Juang", "Penasaran", "Biang Onar", "Pekerja Keras"]


func _all_lines() -> Array:
	var out: Array = []
	for pool in StudentChatterCatalog.PERSONALITY_LINES.values():
		out.append_array(pool)
	for pool in StudentChatterCatalog.QUIRK_LINES.values():
		out.append_array(pool)
	for pool in StudentChatterCatalog.STATE_LINES.values():
		out.append_array(pool)
	out.append_array(StudentChatterCatalog.GENERIC_LINES)
	return out


func test_every_trait_has_eight_lines() -> void:
	for p in _PERSONALITIES:
		assert_true(StudentChatterCatalog.PERSONALITY_LINES.get(p, []).size() >= 8, "personality %s" % p)
	for q in _QUIRKS:
		assert_true(StudentChatterCatalog.QUIRK_LINES.get(q, []).size() >= 8, "quirk %s" % q)
	for s in [&"LELAH", &"BETE", &"SENANG"]:
		assert_true(StudentChatterCatalog.STATE_LINES.get(s, []).size() >= 6, "state %s" % s)
	assert_true(StudentChatterCatalog.GENERIC_LINES.size() >= 6)


func test_every_line_is_short_and_emoji_free() -> void:
	for line in _all_lines():
		var s := str(line)
		assert_true(s.strip_edges() != "", "empty line")
		assert_true(s.length() <= StudentChatterCatalog.MAX_LINE_CHARS, "too long (%d): %s" % [s.length(), s])
		for i in range(s.length()):
			var c := s.unicode_at(i)
			assert_false(c >= 0x1F000 or (c >= 0x2600 and c <= 0x27BF), "emoji in: %s" % s)


func test_every_line_fits_three_lines_of_the_bubble() -> void:
	var tokens := load(_TOKENS_PATH) as DesignTokens
	var font: Font = tokens.font_body_bold
	var size := tokens.font_title
	var width := float(StudentChatBubble.BODY_SIZE.x - 2 * tokens.space_md)
	var limit := font.get_height(size) * 3.0 + 1.0
	for line in _all_lines():
		var h := font.get_multiline_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, width, size).y
		assert_true(h <= limit, "wraps past 3 lines: %s" % line)


func test_personality_falls_back_to_persona() -> void:
	assert_eq(StudentChatterCatalog.personality_of({"personality": "Tekun"}), "Tekun")
	assert_eq(StudentChatterCatalog.personality_of({"persona": "Persona Aktif"}), "Aktif")
	assert_eq(StudentChatterCatalog.personality_of({"persona": "Persona Pendiam"}), "Seni Dalam Kesunyian")
	assert_eq(StudentChatterCatalog.personality_of({}), "")


func test_state_thresholds_and_energy_wins() -> void:
	# kepribadian1 = mood, kepribadian2 = energy
	assert_eq(StudentChatterCatalog.state_for({"kepribadian1": 50, "kepribadian2": 50}), &"")
	assert_eq(StudentChatterCatalog.state_for({"kepribadian1": 50, "kepribadian2": 30}), &"LELAH")
	assert_eq(StudentChatterCatalog.state_for({"kepribadian1": 30, "kepribadian2": 50}), &"BETE")
	assert_eq(StudentChatterCatalog.state_for({"kepribadian1": 75, "kepribadian2": 50}), &"SENANG")
	assert_eq(StudentChatterCatalog.state_for({"kepribadian1": 10, "kepribadian2": 10}), &"LELAH")
	assert_eq(StudentChatterCatalog.state_for({}), &"")


func test_trait_pool_mixes_personality_and_quirk() -> void:
	var s := {"personality": "Kreatif", "quirk": "Penasaran"}
	var pool := StudentChatterCatalog.trait_pool(s)
	assert_eq(pool.size(), StudentChatterCatalog.PERSONALITY_LINES["Kreatif"].size() + StudentChatterCatalog.QUIRK_LINES["Penasaran"].size())
	assert_eq(StudentChatterCatalog.trait_pool({}), StudentChatterCatalog.GENERIC_LINES)


# ----- Picker -----

func test_bag_cycles_without_repeats() -> void:
	var picker := StudentChatterPicker.new()
	picker.rng.seed = 7
	var pool := ["a", "b", "c", "d", "e"]
	var seen := {}
	for i in range(pool.size()):
		seen[picker.draw("k", pool)] = true
	assert_eq(seen.size(), pool.size(), "a full bag says every line once")


func test_bag_boundary_never_repeats() -> void:
	var picker := StudentChatterPicker.new()
	var pool := ["a", "b", "c"]
	for seed in range(40):
		picker.rng.seed = seed
		var last := ""
		for i in range(12):
			var line := picker.draw("k%d" % seed, pool)
			assert_ne(line, last, "same line twice in a row (seed %d)" % seed)
			last = line


func test_pick_uses_state_pool_sometimes_and_trait_pool_otherwise() -> void:
	var picker := StudentChatterPicker.new()
	picker.rng.seed = 3
	var tired := {"name": "X", "personality": "Tekun", "quirk": "Kutu Buku", "kepribadian1": 50, "kepribadian2": 5}
	var state_hits := 0
	for i in range(100):
		if picker.pick(tired) in StudentChatterCatalog.STATE_LINES[&"LELAH"]:
			state_hits += 1
	assert_true(state_hits > 20 and state_hits < 60, "about 40%% state lines, got %d" % state_hits)
	var fine := {"name": "Y", "personality": "Tekun", "quirk": "Kutu Buku", "kepribadian1": 50, "kepribadian2": 50}
	var pool := StudentChatterCatalog.trait_pool(fine)
	for i in range(20):
		assert_true(picker.pick(fine) in pool)
```

- [ ] **Step 2:** `test_run(suite="student_chatter")` — Expected: FAIL (unknown class `StudentChatterCatalog`). If the whole suite fails to load, that is the expected red.

- [ ] **Step 3: implement** `Scripts/Lobby/StudentChatterCatalog.gd`:

```gdscript
@tool
class_name StudentChatterCatalog
extends RefCounted

## Lines the Lobby's students say in their chat bubble (2026-09-19
## student-chatter spec). A student's trait pool is their personality's
## lines plus their quirk's; when their mood or energy is extreme,
## StudentChatterPicker sometimes draws from a STATE_LINES pool instead.
## Reads approved_students dictionaries only: kepribadian1 is MOOD and
## kepribadian2 is ENERGY (StudentData.mood / .energy across the bridge).
## Every line is <= MAX_LINE_CHARS and fits three lines of the bubble
## (tests/test_student_chatter.gd measures it with the real font).

const MAX_LINE_CHARS := 60
## Share of lines drawn from the state pool while a state applies.
const STATE_CHANCE := 0.4
## energy <= this reads as LELAH (and beats any mood state).
const LELAH_ENERGY_MAX := 30.0
## mood <= this reads as BETE.
const BETE_MOOD_MAX := 30.0
## mood >= this reads as SENANG.
const SENANG_MOOD_MIN := 75.0

const PERSONALITY_LINES := {
	"Aktif": [
		"Pak, istirahat nanti main bola yuk!",
		"Duduk terus bikin kaki gatel, Pak…",
		"Pak, boleh lari keliling lapangan dulu?",
		"Aku udah pemanasan dari tadi pagi!",
		"Pelajaran olahraga kapan lagi, Pak?",
		"Semangat, Pak! Hari ini pasti seru!",
		"Pak, aku kuat push-up lima puluh kali loh",
		"Diam itu capek, gerak itu segar!",
	],
	"Tekun": [
		"Pak, PR kemarin sudah aku kerjakan.",
		"Boleh minta soal latihan tambahan, Pak?",
		"Catatanku sudah rapi, Pak. Mau lihat?",
		"Sedikit demi sedikit, lama-lama bisa.",
		"Pak, besok ulangan bab berapa?",
		"Aku ulang materi tadi malam, Pak.",
		"Jadwal belajarku sudah kususun, Pak.",
		"Pelan-pelan asal paham, kan Pak?",
	],
	"Kreatif": [
		"Pak, aku punya ide gambar baru!",
		"Papan tulisnya boleh aku hias, Pak?",
		"Kalau meja ini jadi panggung, seru ya?",
		"Aku lagi bikin lagu, Pak. Mau dengar?",
		"Pak, warna langit hari ini bagus banget.",
		"Coretan di bukuku jadi karakter baru!",
		"Belajar sambil menggambar boleh, Pak?",
		"Inspirasi datang pas lagi bengong, Pak.",
	],
	"Santai": [
		"Santai aja, Pak. Masih lama kok.",
		"Pak, lima menit lagi ya… ngantuk.",
		"Hidup jangan dibawa tegang, Pak~",
		"Nanti juga beres sendiri, Pak.",
		"Pak, kantin buka jam berapa?",
		"Rebahan sebentar boleh kan, Pak?",
		"Tugasnya dikumpul besok aja ya, Pak?",
		"Pelan-pelan, yang penting sampai.",
	],
	"Seni Dalam Kesunyian": [
		"…Pak, kelasnya lagi tenang. Aku suka.",
		"Aku lebih fokus kalau sepi, Pak.",
		"Boleh aku gambar di pojok, Pak?",
		"…Hm? Oh, aku lagi dengar hujan.",
		"Pak, sunyi itu ada suaranya juga.",
		"Aku jarang ngomong, tapi aku dengar.",
		"Garis-garis kecil ini bikin aku tenang.",
		"…Makasih sudah nanya, Pak.",
	],
}

const QUIRK_LINES := {
	"Kutu Buku": [
		"Pak, perpustakaan buka jam berapa?",
		"Buku ini seru banget, Pak. Sudah baca?",
		"Aku pinjam tiga buku lagi minggu ini.",
		"Satu bab lagi… habis itu aku dengar, Pak.",
		"Kacamataku berembun kena uap teh, Pak.",
		"Ada buku referensi tambahan, Pak?",
		"Bau buku baru itu enak ya, Pak.",
		"Pak, catatan kaki itu bagian favoritku.",
	],
	"Penyendiri": [
		"Aku di sini aja ya, Pak.",
		"Kerja kelompok… harus ya, Pak?",
		"Rame banget hari ini… capek.",
		"Pak, aku boleh kerjain sendiri?",
		"Aku bukan sombong, cuma butuh waktu.",
		"Pojok kelas ini tempat favoritku.",
		"Istirahat nanti aku di perpus aja.",
		"Kalau berdua masih oke kok, Pak.",
	],
	"Semangat Juang": [
		"Aku nggak akan nyerah, Pak!",
		"Kalah kemarin? Hari ini balas!",
		"Pak, kasih aku tantangan paling susah!",
		"Jatuh sekali, bangun dua kali!",
		"Target minggu ini harus tembus, Pak!",
		"Capek itu tanda lagi berjuang, Pak.",
		"Siapa bilang aku nggak bisa? Lihat aja!",
		"Ayo, Pak! Kelas kita pasti lulus!",
	],
	"Penasaran": [
		"Pak, kenapa langit warnanya biru?",
		"Itu isinya apa, Pak? Boleh lihat?",
		"Pak, kalau semut jatuh, sakit nggak?",
		"Aku mau coba sendiri, biar tahu!",
		"Pak, dulu Bapak suka bolos nggak?",
		"Kok bisa begitu, Pak? Jelasin dong.",
		"Tombol ini fungsinya apa ya, Pak?",
		"Di ruang guru ada rahasia apa, Pak?",
	],
	"Biang Onar": [
		"Bukan aku, Pak! Sumpah bukan aku!",
		"Kapurnya hilang? Hehe, nggak tahu, Pak.",
		"Ada kecoak di laci, Pak! Eh, bercanda.",
		"Kalau bosan, kelas harus diramaikan!",
		"Pak, aku cuma pinjam, nanti dibalikin.",
		"Tenang, Pak. Kali ini aku anak baik.",
		"Ups… itu jatuh sendiri, Pak.",
		"Hukumannya bisa ditawar, Pak?",
	],
	"Pekerja Keras": [
		"Pak, ada tugas lagi? Aku siap.",
		"Sedikit lagi selesai, Pak!",
		"Aku lembur nyelesaiin proyekku, Pak.",
		"Kerja keras nggak pernah bohong.",
		"Pak, boleh bantu beresin kelas?",
		"Tanganku pegal, tapi hasilnya puas.",
		"Satu lagi, habis itu baru istirahat.",
		"Pak, aku mau hasil yang terbaik.",
	],
}

const STATE_LINES := {
	&"LELAH": [
		"Pak… aku ngantuk berat…",
		"Energiku tinggal sedikit, Pak.",
		"Boleh istirahat dulu, Pak? Lemes…",
		"Mataku berat banget, Pak…",
		"Kayaknya aku butuh tidur siang.",
		"Capek, Pak… jadwalnya padat banget.",
	],
	&"BETE": [
		"Lagi nggak mood, Pak…",
		"Hari ini rasanya suram, Pak.",
		"Pak, boleh jangan belajar dulu?",
		"Hmph. Lagi kesel aja.",
		"Semua kerasa berat hari ini…",
		"Pak, hiburan dong… bosen.",
	],
	&"SENANG": [
		"Hari ini aku senang banget, Pak!",
		"Pak, aku lagi semangat-semangatnya!",
		"Rasanya pengen nyanyi, Pak!",
		"Kelas ini paling seru deh, Pak.",
		"Makasih ya, Pak! Aku lagi happy.",
		"Mood-ku lagi bagus nih, Pak!",
	],
}

## Fallback for a student whose personality and quirk are both unknown.
const GENERIC_LINES := [
	"Pagi, Pak Guru!",
	"Pak, hari ini belajar apa?",
	"Aku siap belajar, Pak.",
	"Pak, kapan pulang?",
	"Hehe, halo Pak.",
	"Pak, kelas kita keren ya?",
]


## The student's personality key in PERSONALITY_LINES, or "" when unknown.
## Prefers `personality`; falls back to `persona` minus its "Persona "
## prefix, where Citra's "Pendiam" means "Seni Dalam Kesunyian".
static func personality_of(student: Dictionary) -> String:
	var p := str(student.get("personality", ""))
	if PERSONALITY_LINES.has(p):
		return p
	var persona := str(student.get("persona", "")).replace("Persona ", "").strip_edges()
	if persona == "Pendiam":
		return "Seni Dalam Kesunyian"
	return persona if PERSONALITY_LINES.has(persona) else ""


## LELAH / BETE / SENANG, or &"" for a student feeling ordinary. Energy
## (kepribadian2) is checked first: exhaustion is the more urgent read.
static func state_for(student: Dictionary) -> StringName:
	var mood := float(student.get("kepribadian1", 50))
	var energy := float(student.get("kepribadian2", 50))
	if energy <= LELAH_ENERGY_MAX:
		return &"LELAH"
	if mood <= BETE_MOOD_MAX:
		return &"BETE"
	if mood >= SENANG_MOOD_MIN:
		return &"SENANG"
	return &""


## Personality lines + quirk lines, or GENERIC_LINES when both are unknown.
static func trait_pool(student: Dictionary) -> Array:
	var pool: Array = []
	pool.append_array(PERSONALITY_LINES.get(personality_of(student), []))
	pool.append_array(QUIRK_LINES.get(str(student.get("quirk", "")), []))
	return pool if not pool.is_empty() else GENERIC_LINES
```

`Scripts/Lobby/StudentChatterPicker.gd`:

```gdscript
@tool
class_name StudentChatterPicker
extends RefCounted

## Anti-repetition for StudentChatterCatalog: one shuffle bag per
## (student, pool). Every line in a pool is said once before any repeats,
## and a refilled bag never opens with the line that closed the last one.
## LobbyChatter keeps one picker for the Lobby's lifetime.

## Drives shuffles and the state-vs-trait roll; tests seed it.
var rng := RandomNumberGenerator.new()
var _bags := {}
var _last := {}


func _init() -> void:
	rng.randomize()


## A line for `student`: STATE_CHANCE of the time from their state pool
## while a state applies, otherwise from their trait pool.
func pick(student: Dictionary) -> String:
	var who := str(student.get("name", ""))
	var state := StudentChatterCatalog.state_for(student)
	if state != &"" and rng.randf() < StudentChatterCatalog.STATE_CHANCE:
		return draw("%s|%s" % [who, state], StudentChatterCatalog.STATE_LINES[state])
	return draw("%s|trait" % who, StudentChatterCatalog.trait_pool(student))


## Next line from the bag `key`, refilled from `pool` when empty.
func draw(key: String, pool: Array) -> String:
	if pool.is_empty():
		return ""
	var bag: Array = _bags.get(key, [])
	if bag.is_empty():
		bag = pool.duplicate()
		for i in range(bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = bag[i]
			bag[i] = bag[j]
			bag[j] = t
		if bag.size() > 1 and bag.back() == _last.get(key, ""):
			var t2 = bag[0]
			bag[0] = bag[bag.size() - 1]
			bag[bag.size() - 1] = t2
	var line := str(bag.pop_back())
	_bags[key] = bag
	_last[key] = line
	return line
```

Note: `test_every_line_fits_three_lines_of_the_bubble` references `StudentChatBubble.BODY_SIZE`, which lands in Task 3 — run it red until then, or use `test_name` to run the rest. If any line fails the 3-line measure in Task 3, shorten that line; never widen the bubble for it.

- [ ] **Step 4:** no-op `script_patch` on both new files; `filesystem_manage(op="scan")`; `test_run(suite="student_chatter")` — Expected: all catalog/picker tests PASS; only the 3-line test fails (no `StudentChatBubble` yet).
- [ ] **Step 5: commit** `feat(lobby): student chatter lines and picker`.

### Task 3: StudentChatBubble

**Files:** Create `Scripts/Lobby/StudentChatBubble.gd`, `Scenes/Lobby/StudentChatBubble.tscn`; extend the suite.

**Consumes:** `StudentChatBubble` / `StudentChatText` variations.
**Produces:**
- `StudentChatBubble.BODY_SIZE := Vector2i(560, 200)`, `EDGE_MARGIN := 24.0`, `enum State { IDLE, SHOWING, LINGERING, HIDING }`, `signal finished`
- `show_line(text: String, anchor_global: Vector2, flip: bool) -> void`
- `dismiss() -> void`, `is_busy() -> bool`, `get_state() -> int`, `get_text() -> String`
- `tip_local(flip: bool) -> Vector2`
- `static func flip_for(anchor_x: float, screen_width: float) -> bool`
- `static func placement(anchor: Vector2, tip: Vector2, bubble_size: Vector2, bounds: Rect2, margin: float) -> Vector2`

Scene layout (`StudentChatBubble.tscn`, built in the editor, root 560×274):

```
StudentChatBubble (Control, script, size 560x274, mouse_filter IGNORE)
├─ Body (PanelContainer, StudentChatBubble variation, offsets 0,0 → 560,200, IGNORE)
│  └─ Text (Label, StudentChatText variation, autowrap WORD_SMART,
│           vertical_alignment CENTER, max_lines_visible 3,
│           text "Pak, aku punya ide gambar baru!", IGNORE)
└─ Tail (TextureRect, chat_bubble_tail.svg, expand_mode IGNORE_SIZE,
         stretch SCALE, offsets 488,196 → 532,274, IGNORE)
```

The tail svg is a right triangle whose tip is its bottom-right corner, so unflipped the tip is (532, 274) and the bubble grows LEFT of its speaker; flipped, the tail moves to x = 560 − 532 = 28 with `flip_h`, tip (28, 274), and the bubble grows RIGHT.

- [ ] **Step 1: failing tests** — append:

```gdscript
# ----- Bubble -----

const _BUBBLE_SCENE := "res://Scenes/Lobby/StudentChatBubble.tscn"


func _make_bubble() -> StudentChatBubble:
	var b := (load(_BUBBLE_SCENE) as PackedScene).instantiate() as StudentChatBubble
	b.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(b)
	return b


func test_flip_rule_is_left_half_of_screen() -> void:
	assert_true(StudentChatBubble.flip_for(200.0, 1080.0))
	assert_false(StudentChatBubble.flip_for(800.0, 1080.0))


func test_tip_mirrors_with_flip() -> void:
	var b := _make_bubble()
	assert_eq(b.tip_local(false), Vector2(532, 274))
	assert_eq(b.tip_local(true), Vector2(28, 274))
	b.queue_free()


func test_placement_puts_tip_on_anchor_when_room() -> void:
	var p := StudentChatBubble.placement(Vector2(700, 400), Vector2(532, 274), Vector2(560, 274), Rect2(0, 0, 1080, 1920), 24.0)
	assert_eq(p, Vector2(168, 126))


func test_placement_clamps_inside_bounds() -> void:
	var bounds := Rect2(0, 0, 1080, 1920)
	var top := StudentChatBubble.placement(Vector2(700, 100), Vector2(532, 274), Vector2(560, 274), bounds, 24.0)
	assert_eq(top.y, 24.0, "clamped below the top margin")
	var left := StudentChatBubble.placement(Vector2(300, 400), Vector2(532, 274), Vector2(560, 274), bounds, 24.0)
	assert_eq(left.x, 24.0, "clamped right of the left margin")


func test_show_line_flips_tail_and_sets_pivot_and_text() -> void:
	var b := _make_bubble()
	b.show_line("Halo, Pak!", Vector2(300, 600), true)
	var tail := b.get_node("Tail") as TextureRect
	assert_true(tail.flip_h)
	assert_eq(tail.position.x, 28.0)
	assert_eq(b.pivot_offset, b.tip_local(true))
	assert_eq(b.get_text(), "Halo, Pak!")
	assert_eq(b.get_state(), StudentChatBubble.State.SHOWING)
	assert_true(b.is_busy())
	b.show_line("Halo, Pak!", Vector2(800, 600), false)
	assert_false(tail.flip_h)
	assert_eq(tail.position.x, 488.0)
	b.queue_free()


func test_dismiss_starts_hiding() -> void:
	var b := _make_bubble()
	b.show_line("Halo, Pak!", Vector2(300, 600), true)
	b.dismiss()
	assert_eq(b.get_state(), StudentChatBubble.State.HIDING)
	assert_true(b.is_busy())
	b.queue_free()


func test_fresh_bubble_is_idle_and_hidden() -> void:
	var b := _make_bubble()
	assert_eq(b.get_state(), StudentChatBubble.State.IDLE)
	assert_false(b.is_busy())
	assert_eq(b.modulate.a, 0.0)
	b.queue_free()
```

- [ ] **Step 2:** `test_run(suite="student_chatter")` — Expected: FAIL (no `StudentChatBubble`).

- [ ] **Step 3: implement** `Scripts/Lobby/StudentChatBubble.gd`:

```gdscript
@tool
class_name StudentChatBubble
extends Control

## A Lobby student's speech bubble (2026-09-19 student-chatter spec):
## StudentChatBubble.tscn's Body (PanelContainer) > Text (Label) plus a
## Tail TextureRect. show_line() mirrors the tail to the speaker's side
## (flip = speaker in the left half of the screen: tail on the left, bubble
## grows right), lands the tail's tip on the speaker's ChatAnchor, clamps
## the body inside the visible screen, and pops in from that tip like
## Pak Herman's ChatBubble -- then lingers and shrinks back into it.
## States IDLE -> SHOWING -> LINGERING -> HIDING -> IDLE; is_busy() is
## everything but IDLE, which LobbyChatter's spam guard reads.
##
## @tool because the test suite instantiates the scene in the editor; the
## hidden pose and timer are skipped only for the scene open for editing,
## so saving it never bakes a shrunk, transparent bubble.

signal finished

enum State { IDLE, SHOWING, LINGERING, HIDING }

## Body's authored size; the 3-line fit test measures text against it.
const BODY_SIZE := Vector2i(560, 200)
## Minimum gap between the bubble and the visible screen edge, in px.
const EDGE_MARGIN := 24.0
const SHRUNK_SCALE := Vector2(0.2, 0.2)
const FADE_IN_S := 0.32
const FADE_OUT_S := 0.28

## How long a line stays fully shown before it retracts, in seconds.
@export var linger_s: float = 2.6

var _state: int = State.IDLE
var _tween: Tween
var _linger_timer: Timer
## Tail's authored (unflipped) x; the flipped x mirrors it across the body.
var _tail_x: float = 0.0

@onready var _label: Label = get_node_or_null("Body/Text") as Label
@onready var _tail: TextureRect = get_node_or_null("Tail") as TextureRect


func _ready() -> void:
	if _tail:
		_tail_x = _tail.position.x
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	_linger_timer = Timer.new()
	_linger_timer.one_shot = true
	add_child(_linger_timer)
	_linger_timer.timeout.connect(_hide)
	scale = SHRUNK_SCALE
	modulate.a = 0.0


func get_state() -> int:
	return _state


func is_busy() -> bool:
	return _state != State.IDLE


func get_text() -> String:
	return _label.text if _label else ""


## True when a speaker at `anchor_x` sits in the screen's left half.
static func flip_for(anchor_x: float, screen_width: float) -> bool:
	return anchor_x < screen_width * 0.5


## Top-left for a bubble whose tail tip (`tip`, bubble-local) should land
## on `anchor`, clamped so the whole bubble stays `margin` inside `bounds`.
static func placement(anchor: Vector2, tip: Vector2, bubble_size: Vector2, bounds: Rect2, margin: float) -> Vector2:
	var p := anchor - tip
	p.x = clampf(p.x, bounds.position.x + margin, bounds.end.x - margin - bubble_size.x)
	p.y = clampf(p.y, bounds.position.y + margin, bounds.end.y - margin - bubble_size.y)
	return p


## The tail tip in bubble-local px for the given side.
func tip_local(flip: bool) -> Vector2:
	if _tail == null:
		return Vector2.ZERO
	var w := _tail.size.x
	var bottom := _tail.position.y + _tail.size.y
	if flip:
		return Vector2(size.x - (_tail_x + w), bottom)
	return Vector2(_tail_x + w, bottom)


## Say `text` from a speaker whose ChatAnchor is at `anchor_global`.
func show_line(text: String, anchor_global: Vector2, flip: bool) -> void:
	if _label:
		_label.text = text
	if _tail:
		_tail.flip_h = flip
		_tail.position.x = size.x - (_tail_x + _tail.size.x) if flip else _tail_x
	var tip := tip_local(flip)
	pivot_offset = tip
	position = placement(_to_parent_space(anchor_global), tip, size, _visible_bounds(), EDGE_MARGIN)
	_set_state(State.SHOWING)
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	if _linger_timer:
		_linger_timer.stop()
	_kill_tween()
	scale = SHRUNK_SCALE
	modulate.a = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween = tw
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, FADE_IN_S)
	tw.tween_property(self, "modulate:a", 1.0, FADE_IN_S)
	tw.set_parallel(false)
	tw.tween_callback(_on_shown.bind(tw))


## Retract now (a popup opened over the Lobby). No-op while IDLE.
func dismiss() -> void:
	if _state == State.IDLE or _state == State.HIDING:
		return
	_hide()


func _on_shown(tw: Tween) -> void:
	if tw != _tween:
		return
	_set_state(State.LINGERING)
	if _linger_timer:
		_linger_timer.start(linger_s)


func _hide() -> void:
	_set_state(State.HIDING)
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		_set_state(State.IDLE)
		return
	if _linger_timer:
		_linger_timer.stop()
	_kill_tween()
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween = tw
	tw.set_parallel(true)
	tw.tween_property(self, "scale", SHRUNK_SCALE, FADE_OUT_S)
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT_S)
	tw.set_parallel(false)
	tw.tween_callback(_on_hidden.bind(tw))


func _on_hidden(tw: Tween) -> void:
	if tw != _tween:
		return
	_set_state(State.IDLE)
	finished.emit()


func _kill_tween() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null


func _set_state(s: int) -> void:
	_state = s


## `p` (canvas/global px) in the parent's frame; identity without a
## Control parent, as in tests.
func _to_parent_space(p: Vector2) -> Vector2:
	var parent := get_parent() as CanvasItem
	if parent == null or not is_inside_tree():
		return p
	return parent.get_global_transform().affine_inverse() * p


## The visible screen in the parent's frame -- on a 20:9 phone the Lobby's
## Classroom is centred in a taller viewport, so this is not 0..1920.
func _visible_bounds() -> Rect2:
	if not is_inside_tree():
		return Rect2(Vector2.ZERO, Vector2(1080, 1920))
	var vis := get_viewport().get_visible_rect()
	var parent := get_parent() as CanvasItem
	if parent == null:
		return vis
	return parent.get_global_transform().affine_inverse() * vis
```

Build `Scenes/Lobby/StudentChatBubble.tscn` in the editor (`scene_manage` create with root Control named `StudentChatBubble`, then `batch_execute` the nodes per the layout above, attach the script, `scene_save`). Tail texture: `res://Assets/Images/Shop/UI/chat_bubble_tail.svg`. Root `size` 560×274 via offsets (0,0,560,274).

- [ ] **Step 4:** no-op `script_patch`; scan; `test_run(suite="student_chatter")` — Expected: PASS, including the 3-line fit test. If a line fails the fit, shorten it in the catalog.
- [ ] **Step 5: commit** `feat(lobby): student chat bubble`.

### Task 4: LobbyChatter

**Files:** Create `Scripts/Lobby/LobbyChatter.gd`; extend the suite.

**Consumes:** `StudentChatBubble`, `StudentChatterPicker`.
**Produces:** `LobbyChatter` with `@export bubble: StudentChatBubble`, `@export idle_min_s := 20.0`, `idle_max_s := 50.0`, `tap_cooldown_s := 0.5`; `var can_speak: Callable`; `set_seats(seats: Array)` (each `{"student": Dictionary, "hit": Control, "anchor": Control}`); `request_line(i: int) -> bool`; `speak_idle() -> bool`; `seat_at(global_pos: Vector2) -> int`; `next_idle_delay() -> float`; `dismiss()`; `reset_idle_timer()`; `get_last_speaker() -> int`.

- [ ] **Step 1: failing tests** — append:

```gdscript
# ----- LobbyChatter -----

func _make_seat(x: float, who: String) -> Dictionary:
	var hit := Control.new()
	hit.position = Vector2(x, 400)
	hit.size = Vector2(300, 300)
	var anchor := Control.new()
	anchor.position = Vector2(x + 150, 500)
	return {"student": {"name": who, "personality": "Tekun", "quirk": "Kutu Buku",
		"kepribadian1": 50, "kepribadian2": 50}, "hit": hit, "anchor": anchor}


func _make_chatter(seat_count: int = 2) -> LobbyChatter:
	var root := Control.new()
	root.size = Vector2(1080, 1920)
	Engine.get_main_loop().root.add_child(root)
	var c := LobbyChatter.new()
	c.bubble = _make_bubble()
	c.bubble.reparent(root)
	root.add_child(c)
	var seats: Array = []
	for i in range(seat_count):
		var s := _make_seat(100.0 + 520.0 * i, "S%d" % i)
		root.add_child(s.hit)
		root.add_child(s.anchor)
		seats.append(s)
	c.set_seats(seats)
	return c


func _free_chatter(c: LobbyChatter) -> void:
	c.get_parent().queue_free()


func test_tap_speaks_then_spam_is_refused() -> void:
	var c := _make_chatter()
	assert_true(c.request_line(0), "first tap speaks")
	var shown := c.bubble.get_text()
	for i in range(10):
		assert_false(c.request_line(1), "spam while busy is refused")
	assert_eq(c.bubble.get_text(), shown, "the line on screen is untouched")
	_free_chatter(c)


func test_cooldown_after_bubble_finishes() -> void:
	var c := _make_chatter()
	c._on_bubble_finished()
	assert_false(c.request_line(0), "within tap_cooldown_s of the last line")
	c._idle_since_ms = Time.get_ticks_msec() - int(c.tap_cooldown_s * 1000.0) - 1
	assert_true(c.request_line(0))
	_free_chatter(c)


func test_gate_blocks_everything() -> void:
	var c := _make_chatter()
	c.can_speak = func() -> bool: return false
	assert_false(c.request_line(0))
	assert_false(c.speak_idle())
	assert_false(c.bubble.is_busy())
	_free_chatter(c)


func test_idle_delay_is_twenty_to_fifty_seconds() -> void:
	var c := LobbyChatter.new()
	assert_eq(c.idle_min_s, 20.0)
	assert_eq(c.idle_max_s, 50.0)
	for i in range(50):
		var d := c.next_idle_delay()
		assert_true(d >= 20.0 and d <= 50.0, "delay %f" % d)
	c.free()


func test_idle_speaker_differs_from_previous() -> void:
	var c := _make_chatter(2)
	for i in range(8):
		var before := c.get_last_speaker()
		c.bubble._kill_tween()
		c.bubble._set_state(StudentChatBubble.State.IDLE)
		c._idle_since_ms = -100000
		assert_true(c.speak_idle())
		assert_ne(c.get_last_speaker(), before)
	_free_chatter(c)


func test_seat_at_finds_the_tapped_face() -> void:
	var c := _make_chatter(2)
	assert_eq(c.seat_at(Vector2(200, 500)), 0)
	assert_eq(c.seat_at(Vector2(750, 500)), 1)
	assert_eq(c.seat_at(Vector2(540, 50)), -1)
	_free_chatter(c)


func test_no_seats_no_chatter() -> void:
	var c := _make_chatter(0)
	assert_false(c.speak_idle())
	assert_false(c.request_line(0))
	_free_chatter(c)
```

- [ ] **Step 2:** `test_run(suite="student_chatter")` — Expected: FAIL (no `LobbyChatter`).

- [ ] **Step 3: implement** `Scripts/Lobby/LobbyChatter.gd`:

```gdscript
@tool
class_name LobbyChatter
extends Node

## Who talks in the Lobby, and when (2026-09-19 student-chatter spec).
## loby.gd hands in the seated students (set_seats) and a can_speak gate
## (false during the tutorial, the daily-reward popup and the skin picker).
## A tap on a student's face asks them to talk; so does an idle timer of
## idle_min_s..idle_max_s, re-rolled on every tap and after every line,
## which picks a random seated student other than the last idle speaker.
## One bubble, one speaker: a request is refused while the bubble is busy
## and for tap_cooldown_s after it finishes, so spamming taps leaves the
## line on screen exactly as it was.

## The one bubble every student speaks through (loby.tscn's ChatBubble).
@export var bubble: StudentChatBubble
## Shortest wait, in seconds, before an idle student pipes up.
@export var idle_min_s: float = 20.0
## Longest wait, in seconds, before an idle student pipes up.
@export var idle_max_s: float = 50.0
## After a line retracts, taps are ignored for this long, in seconds.
@export var tap_cooldown_s: float = 0.5

## Returns whether anyone may talk right now; loby.gd replaces it.
var can_speak: Callable = func() -> bool: return true

var _seats: Array = []
var _picker := StudentChatterPicker.new()
var _idle_timer: Timer
var _last_speaker: int = -1
## When the bubble last went idle (Time.get_ticks_msec()).
var _idle_since_ms: int = -100000


func _ready() -> void:
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	_idle_timer = Timer.new()
	_idle_timer.one_shot = true
	add_child(_idle_timer)
	_idle_timer.timeout.connect(_on_idle_timeout)
	if bubble and not bubble.finished.is_connected(_on_bubble_finished):
		bubble.finished.connect(_on_bubble_finished)
	reset_idle_timer()


## Seats as {student: Dictionary, hit: Control, anchor: Control}.
func set_seats(seats: Array) -> void:
	_seats = seats.filter(func(s): return s is Dictionary \
		and s.get("hit") is Control and s.get("anchor") is Control)
	_last_speaker = -1


func get_last_speaker() -> int:
	return _last_speaker


func next_idle_delay() -> float:
	return randf_range(idle_min_s, idle_max_s)


func reset_idle_timer() -> void:
	if _idle_timer and _idle_timer.is_inside_tree():
		_idle_timer.start(next_idle_delay())


func dismiss() -> void:
	if bubble:
		bubble.dismiss()


## Seat `i` says a line. False when gated, busy, cooling down or invalid.
func request_line(i: int) -> bool:
	if i < 0 or i >= _seats.size() or bubble == null:
		return false
	if not bool(can_speak.call()):
		return false
	if bubble.is_busy():
		return false
	if Time.get_ticks_msec() - _idle_since_ms < int(tap_cooldown_s * 1000.0):
		return false
	var seat: Dictionary = _seats[i]
	var line := _picker.pick(seat.student)
	if line.is_empty():
		return false
	var anchor_pos: Vector2 = (seat.anchor as Control).global_position
	var width := 1080.0
	if bubble.is_inside_tree():
		width = bubble.get_viewport().get_visible_rect().size.x
	bubble.show_line(line, anchor_pos, StudentChatBubble.flip_for(anchor_pos.x, width))
	_last_speaker = i
	return true


## A random seated student other than the last speaker talks.
func speak_idle() -> bool:
	if _seats.is_empty():
		return false
	var choices: Array = range(_seats.size())
	if choices.size() > 1:
		choices.erase(_last_speaker)
	return request_line(choices[randi() % choices.size()])


## Index of the seat whose face contains `global_pos`, or -1.
func seat_at(global_pos: Vector2) -> int:
	for i in range(_seats.size()):
		var hit := _seats[i].hit as Control
		if hit.is_visible_in_tree() and hit.get_global_rect().has_point(global_pos):
			return i
	return -1


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	var pressed := (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	reset_idle_timer()
	var i := seat_at(event.get("position") as Vector2)
	if i >= 0:
		request_line(i)


func _on_idle_timeout() -> void:
	speak_idle()
	reset_idle_timer()


func _on_bubble_finished() -> void:
	_idle_since_ms = Time.get_ticks_msec()
	reset_idle_timer()
```

Tests in `_make_chatter` add the chatter to the editor root, so its `_input` is live during the test; that is harmless (tests finish synchronously) and the root is freed after.

- [ ] **Step 4:** no-op `script_patch`; `test_run(suite="student_chatter")` — Expected: PASS.
- [ ] **Step 5: commit** `feat(lobby): lobby chatter spam guard and idle timer`.

### Task 5: Wire into the Lobby

**Files:** `Scenes/Lobby/loby.tscn` (editor), `Scripts/Lobby/loby.gd`; extend the suite.

- [ ] **Step 1: failing tests** — append:

```gdscript
# ----- Lobby wiring -----

const _LOBY_TSCN := "res://Scenes/Lobby/loby.tscn"
const _LOBY_GD := "res://Scripts/Lobby/loby.gd"


func test_every_portrait_slot_has_a_chat_anchor() -> void:
	var src := FileAccess.get_file_as_string(_LOBY_TSCN)
	for slot in ["StudentPortraitsContainer_Back/Slot1", "StudentPortraitsContainer_Back/Slot2",
			"StudentPortraitsContainer_Front/Slot3", "StudentPortraitsContainer_Front/Slot4"]:
		assert_true(src.contains('[node name="ChatAnchor" type="Control" parent="Classroom/%s"' % slot),
			"ChatAnchor missing in %s" % slot)


func test_lobby_has_one_bubble_and_a_chatter() -> void:
	var src := FileAccess.get_file_as_string(_LOBY_TSCN)
	assert_true(src.contains('[node name="ChatBubble" parent="Classroom" instance='), "bubble instanced under Classroom")
	assert_true(src.contains('[node name="Chatter" type="Node" parent="."'), "Chatter node")
	assert_true(src.contains('bubble = NodePath("../Classroom/ChatBubble")'), "Chatter wired to the bubble")


func test_bubble_is_classrooms_last_child() -> void:
	var scene := (load(_LOBY_TSCN) as PackedScene).get_state()
	var last_under_classroom := ""
	for i in range(scene.get_node_count()):
		if str(scene.get_node_path(i, true)).trim_prefix("./") == "Classroom":
			last_under_classroom = str(scene.get_node_name(i))
	assert_eq(last_under_classroom, "ChatBubble", "drawn above every desk and student")


func test_loby_hands_seats_and_gate_to_chatter() -> void:
	var src := FileAccess.get_file_as_string(_LOBY_GD)
	assert_true(src.contains("chatter.set_seats("))
	assert_true(src.contains("chatter.can_speak = _chatter_allowed"))
	assert_true(src.contains("func _chatter_allowed() -> bool:"))
	assert_true(src.contains("not tutorial_active and not reward_popup_open and not _skin_popup_open"))
	assert_true(src.contains("chatter.dismiss()"))
```

- [ ] **Step 2:** `test_run(suite="student_chatter")` — Expected: the four wiring tests FAIL.

- [ ] **Step 3: scene** (editor, one session, then `scene_save`; scene work before script work):
  - `scene_open("res://Scenes/Lobby/loby.tscn")`.
  - In each `Classroom/StudentPortraitsContainer_*/SlotN` create `ChatAnchor` (Control, `layout_mode = 1`, anchors 0, `mouse_filter = 2`, zero size) at slot-local positions — Slot1 (330, 300), Slot2 (70, 300), Slot3 (330, 250), Slot4 (70, 250). These are starting guesses: Task 6 tunes them on a screenshot.
  - Instance `res://Scenes/Lobby/StudentChatBubble.tscn` as `Classroom/ChatBubble`, `layout_mode = 1`, anchors 0, offsets (0,0,560,274); `move_node` it to Classroom's last index.
  - Create `Chatter` (Node) as a root child, attach `Scripts/Lobby/LobbyChatter.gd`, set `bubble = NodePath("../Classroom/ChatBubble")`.
  - `scene_save`; `git diff HEAD -- '*.gd'` must be empty; `git diff --stat` must show only `loby.tscn` (plus `StudentChatBubble.tscn` if touched — revert that).

- [ ] **Step 4: script** — `script_patch` `Scripts/Lobby/loby.gd`:

  After `@onready var bg_layer = %BGLayer` add:

```gdscript
## Seated students' chatter (2026-09-19 spec); may be absent in old scenes.
@onready var chatter: LobbyChatter = get_node_or_null("Chatter") as LobbyChatter
## True while a SkinSelectPopup is open; mutes chatter.
var _skin_popup_open := false
```

  In `_ready()`, before `_setup_students()`:

```gdscript
	if chatter:
		chatter.can_speak = _chatter_allowed
```

  In `_setup_students()`: at the empty-roster early return, before `return`, add `if chatter: chatter.set_seats([])`. Declare `var seats: Array = []` after `var ordered = …`. Inside the seated branch, after the face/portrait `if/else`, add:

```gdscript
			var hit: Control = face if face != null else portrait_node
			var anchor := p_slot.get_node_or_null("ChatAnchor") as Control
			if anchor:
				seats.append({"student": s, "hit": hit, "anchor": anchor})
```

  After the loop: `if chatter: chatter.set_seats(seats)`.

  In `_on_skin_switch_pressed()`, before `add_child(popup)`:

```gdscript
	_skin_popup_open = true
	if chatter:
		chatter.dismiss()
	popup.closed.connect(func(): _skin_popup_open = false)
```

  Add:

```gdscript
## LobbyChatter's gate: nobody talks over the tutorial, the daily reward
## or the skin picker.
func _chatter_allowed() -> bool:
	return not tutorial_active and not reward_popup_open and not _skin_popup_open
```

- [ ] **Step 5:** `test_run(suite="student_chatter")`, `test_run(suite="lobby")`, `lobby_layout`, `lobby_skins`, `viewport_editability`, `script_documentation`, `tall_screen_layout` — Expected: PASS. (Use each suite's real `suite_name()`; grep it first.)
- [ ] **Step 6: commit** `feat(lobby): students chat in the lobby`.

### Task 5b: Students blink (addendum)

**Files:** Modify `Scripts/Lobby/StudentFace.gd`, `tests/test_student_face.gd`, `docs/superpowers/DEBT.md`.

**Consumes:** the existing `Eyelid` layer (`<nama>_eyelid.png`, the closed-eye art) and `blink()` / `advance_motion()`.
**Produces:** `StudentFace.idle_blink_enabled` default `true`, `blink_hold_range` default `Vector2(5, 10)`, new `@export var blink_fade_seconds: float = 0.05`, and `get_eyelid_alpha() -> float`.

- [ ] **Step 1: failing tests** — in `tests/test_student_face.gd`, replace `test_a_blink_closes_the_eye_and_lifts_again` and `test_idle_blinking_is_wired_in_but_switched_off` with the following (keep `test_switching_idle_blinking_on_makes_the_eye_blink` as is), and update the header comment "Blink is deliberately inert…" to say idle blinking is on, 5–10 s apart, with a faded lid:

```gdscript
func test_a_blink_fades_the_lid_in_holds_and_fades_out() -> void:
	var eyelid := _layer("Eyelid")
	assert_false(eyelid.visible, "eyes start open")
	_face.blink()
	assert_true(eyelid.visible, "blink() starts lowering the lid")
	assert_true(_face.get_eyelid_alpha() < 0.01, "the lid fades in, it does not cut")
	_face.advance_motion(_face.blink_fade_seconds * 0.5)
	var half := _face.get_eyelid_alpha()
	assert_true(half > 0.2 and half < 0.8, "half-way through the fade (got %f)" % half)
	_face.advance_motion(_face.blink_fade_seconds * 0.5 + 0.001)
	assert_true(_face.get_eyelid_alpha() > 0.99, "fully shut after the fade")
	_face.advance_motion(_face.blink_close_seconds)
	assert_true(eyelid.visible, "still shut or lifting after the hold")
	_face.advance_motion(_face.blink_fade_seconds + 0.01)
	assert_false(eyelid.visible, "the lid is gone once the fade-out ends")
	assert_true(_face.get_eyelid_alpha() > 0.99, "alpha reset for the next blink")


func test_idle_blinking_is_on_every_five_to_ten_seconds() -> void:
	assert_true(_face.idle_blink_enabled, "students blink by default")
	assert_eq(_face.blink_hold_range, Vector2(5.0, 10.0))
	var eyelid := _layer("Eyelid")
	var closes: Array = []
	var was_closed := false
	var t := 0.0
	for _i in range(4000):  # 64 s
		_face.advance_motion(0.016)
		t += 0.016
		if eyelid.visible and not was_closed:
			closes.append(t)
		was_closed = eyelid.visible
	assert_true(closes.size() >= 5, "about one blink every 5-10 s (got %d)" % closes.size())
	assert_true(closes[0] <= 10.1, "the first blink comes within 10 s")
	for i in range(1, closes.size()):
		var gap: float = closes[i] - closes[i - 1]
		assert_true(gap >= 5.0 and gap <= 10.5, "gap %f outside 5-10 s" % gap)
```

Also in `tests/test_face_rig_roster.gd`, `test_only_the_eyelid_starts_hidden` stays valid (the lid still starts hidden). Grep the other face suites for `idle_blink_enabled` and flip any assertion that pins it off.

- [ ] **Step 2:** `test_run(suite=<test_student_face's suite_name>)` — Expected: FAIL (`get_eyelid_alpha` missing, idle blink off).

- [ ] **Step 3: implement** in `StudentFace.gd`:
  - Header "Blink" bullet → `the Eyelid layer (the student's closed-eye art) fades in over blink_fade_seconds, holds blink_close_seconds and fades out; on by default, every blink_hold_range seconds.`
  - Exports:

```gdscript
@export_group("Blink")
## Idle blinking: each rig closes its eyes on its own every blink_hold_range
## seconds (its own RNG, so the four seats never blink in step).
@export var idle_blink_enabled: bool = true
## How long the eyes stay fully shut per blink, in seconds.
@export var blink_close_seconds: float = 0.08
## How long the lid takes to fade in, and again to fade out, in seconds --
## what makes the blink read as a blink rather than a hard cut.
@export var blink_fade_seconds: float = 0.05
## Shortest and longest pause between idle blinks, in seconds.
@export var blink_hold_range: Vector2 = Vector2(5.0, 10.0)
```

  - Replace `_blink_remaining` with `var _blink_t: float = -1.0` (seconds into the current blink; < 0 means none).
  - Replace `set_eyes_closed`, `blink`, `_advance_blink`, and add `get_eyelid_alpha`:

```gdscript
## Shows or hides the blink pose at full strength. That is the Eyelid layer
## alone -- it carries both the lid and its own lash line, and it is drawn
## above the open eye, so nothing else has to be toggled with it.
func set_eyes_closed(closed: bool) -> void:
	_blink_t = -1.0
	_set_eyelid(closed, 1.0)


## The lid's current opacity, 0..1.
func get_eyelid_alpha() -> float:
	var eyelid := _layer("Eyelid")
	return eyelid.modulate.a if eyelid != null else 0.0


## Plays one blink: fade in, hold, fade out, stepped by advance_motion().
func blink() -> void:
	_blink_t = 0.0
	_set_eyelid(true, 0.0)


func _set_eyelid(shown: bool, alpha: float) -> void:
	var eyelid := _layer("Eyelid")
	if eyelid == null:
		return
	eyelid.visible = shown
	eyelid.modulate.a = alpha


func _advance_blink(delta: float) -> void:
	if _blink_t >= 0.0:
		_blink_t += delta
		var fade := maxf(blink_fade_seconds, 0.0001)
		var shut_end := fade + maxf(blink_close_seconds, 0.0)
		if _blink_t < fade:
			_set_eyelid(true, _blink_t / fade)
		elif _blink_t < shut_end:
			_set_eyelid(true, 1.0)
		elif _blink_t < shut_end + fade:
			_set_eyelid(true, 1.0 - (_blink_t - shut_end) / fade)
		else:
			set_eyes_closed(false)
		return
	if not idle_blink_enabled:
		return
	_blink_hold -= delta
	if _blink_hold <= 0.0:
		_blink_hold = _rng.randf_range(blink_hold_range.x, blink_hold_range.y)
		blink()
```

  - Check the six `*Face.tscn` for saved `idle_blink_enabled`/`blink_hold_range` overrides (`grep`); there are none today — if one appears, remove it in the editor.
- [ ] **Step 4:** no-op `script_patch` on `StudentFace.gd`; run the face suites (`test_student_face`, `test_face_rig_roster`, and any other `grep -l StudentFace tests/`), plus `script_documentation` — Expected: PASS.
- [ ] **Step 5:** delete the DEBT entry "Deferred: blinking on the layered faces" (its whole paragraph). Commit `feat(lobby): students blink every 5-10 s with a faded lid`.

### Task 6: Look at it, tune anchors, changelog, full run

- [ ] Launch the worktree editor's game, debug overlay → ⚡ Seed Playtest State → Scenes → Lobby, close the daily reward. From `game_eval`, call `Chatter.request_line(i)` for i = 0..3 with `Engine.time_scale` frozen after the pop (memory: freeze game time for screenshots), screenshot each at full size. Tail tip should sit at the student's face, bubble toward the room's centre, left seats flipped. Move `ChatAnchor`s in the editor if not (scene_save, then re-check `git diff HEAD -- '*.gd'`).
- [ ] Also check at 1080×2400 (`resize_window` / window size) that clamping keeps the bubble on screen.
- [ ] Add a `docs/superpowers/CHANGELOG.md` entry (newest first) — "Lobby student chatter": what, files, tunables (`idle_min_s`/`idle_max_s`/`tap_cooldown_s`/`linger_s`, `STATE_CHANCE`, thresholds).
- [ ] Full `test_run(session_id=…)` (no suite). Expect a bridge drop; results count once returned. `git status`: revert `default_bus_layout.tres` if touched; keep `kejartes_theme.tres` only if it matches Task 1's bake.
- [ ] Commit `docs(lobby): changelog for student chatter`.
