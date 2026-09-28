# EventDialogue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put a per-event character line (EventDialogue) between the sliding EventWarning and every minigame or random event, with Tolak/Terima on the three pick-students events.

**Architecture:** A pure `EventDialogueCatalog` holds the 13 entries: line, speaker art, backdrop and mode. It also holds helpers that pick the featured student and fill `{nama}`. `EventDialogue.tscn` is a fully authored overlay whose script only dresses it and counts taps. SchoolDay awaits it, and both of SchoolDay's event paths run through one `_run_event()`, so the hooks exist once.

**Tech Stack:** Godot 4.6 GDScript. Tests are McpTestSuite suites run through the godot-ai MCP `test_run`. Art is generated with PowerShell + System.Drawing.

Spec: `docs/superpowers/specs/2026-09-14-event-dialogue-design.md`.

## Global Constraints

- **Suites.** Every suite is `@tool`, extends `McpTestSuite`, overrides `suite_name()`, and has no coroutine tests. Run a suite with `test_run(suite="<suite_name()>")`.
- **Scripts.** Every script has a `##` header in its first 12 lines and a `##` line directly above every `@export`.
- **No `theme_override_*`** except layout constants (`separation`, `margin_*`). Styling goes through ThemeFactory variations.
- **No runtime visual construction:** no `Control.new()` in scripts. Build `.tscn` files through the editor MCP (`scene_manage` create, `batch_execute`, `scene_save`), never by hand while the editor is attached.
- **Paths.** Children of a plain `Control` need `layout_mode = 1` before their anchors are set. `anchors_preset` is inert, so set the four anchors. Numbers go unquoted.
- **`Balance.gd` is read-only.**
- **Text.** UI text is Indonesian, with no emoji.
- **After an outside write to a `.gd`**, run `filesystem_manage(op="scan")`. If a test still runs old code, do a no-op `script_patch` on that file. Edit `SchoolDay.gd` only through `script_patch`, which keeps its open editor tab in sync.
- **Restarts.** A new `@export` on `DesignTokens` is invisible until the editor restarts. After a rebake, restart again before anything saves. The restart recipe: kill only the editor PID from `session_manage(op="list")`, relaunch `"C:/Users/user/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64.exe" --path "<project>" -e` as a background Bash command, then poll `session_manage(op="list")`.
- **Running the game.** Use `project_run(..., autosave=false)`, so a run never flushes editor buffers to disk.
- **Commits.** Conventional Commits with a scope, ending with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. Never stage `addons/godot_ai/utils/update_activation_runner.gd*`.

## File map

| File | Responsibility |
|---|---|
| `Scripts/SchoolSimulation/EventDialogueCatalog.gd` (new) | The 13 entries plus pure helpers |
| `Scripts/SchoolSimulation/EventDialogue.gd` (new) | Dresses the screen, counts taps, emits `closed(accepted)` |
| `Scenes/SchoolSimulation/EventDialogue.tscn` (new) | Every node of the screen |
| `Scenes/SchoolSimulation/event_dialogue_blur_material.tres` (new) | ShaderMaterial on the existing `blur.gdshader`, with a light tint |
| `Assets/Images/EventDialogue/*` (new) | School background, 3 splashes, rain background, calendar badge |
| `Scripts/Design/DesignTokens.gd` | New `font_body_bold` token |
| `Scripts/Design/ThemeFactory.gd` | Five new variations |
| `Assets/Theme/kejartes_theme.tres` | Rebaked |
| `Scripts/SchoolSimulation/SchoolDay.gd` | `event_dialogue_scene`, `_show_event_dialogue()`, `_run_event()`, the hooks |
| `tests/test_event_dialogue.gd` (new) | Catalog, screen, theme and SchoolDay wiring |
| `tests/test_theme_factory.gd` | Declares the five new variations |
| `CLAUDE.md`, `docs/superpowers/CHANGELOG.md` | Placeholder and copy debt; changelog entry |

---

### Task 1: Art and the catalog

**Files:**
- Create: `Assets/Images/EventDialogue/sekolah_background.jpg`, `splash_mom.png`, `splash_gurupenjas.png`, `splash_gurusenibudaya.png`, `hujan_background.png`, `calendar_badge.png`
- Create: `Scenes/SchoolSimulation/event_dialogue_blur_material.tres`
- Create: `Scripts/SchoolSimulation/EventDialogueCatalog.gd`
- Test: `tests/test_event_dialogue.gd`

**Interfaces:**
- Produces (used by Tasks 2 and 4):
  - `EventDialogueCatalog.MODE_TAP := "tap"` and `MODE_CHOICE := "choice"`
  - `SPEAKER_STUDENT := "student"`
  - the path constants `DEFAULT_BACKGROUND`, `HUJAN_BACKGROUND`, `SPLASH_MOM`, `SPLASH_GURU_PENJAS`, `SPLASH_GURU_SENI`, `CALENDAR_BADGE`
  - `NAME_FALLBACK := "murid-murid"`
  - `ENTRIES: Dictionary`, whose entries have the keys `mode`, `speaker`, `category`, `background`, `blur`, `line`
  - `static has_entry(key: String) -> bool` and `static entry(key: String) -> Dictionary`
  - `static pick_featured(students: Array, category: String) -> StudentData`
  - `static fill_line(line: String, featured: StudentData) -> String`
  - `static splash_path_for(e: Dictionary, featured: StudentData) -> String`
  - `static minigame_key(scene_path: String) -> String`

- [ ] **Step 1: Put the art in place**

The Drive files are already decoded in the scratchpad (`…/scratchpad/splash_mom.png` and `splash_gurupenjas.png`, both 1080×1920 transparent). Run in PowerShell from the project root:

```powershell
$scratch = "C:\Users\user\AppData\Local\Temp\claude\C--Users-user-Downloads-KejarTestAlphaVer2-15-KejarTestAlphaVer2-15-new-game-project\0df63631-bc6b-44ac-9bcf-c33adac39fa6\scratchpad"
$dir = "Assets\Images\EventDialogue"
New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item "C:\Users\user\Downloads\sekolah_background.jpg" "$dir\sekolah_background.jpg"
Copy-Item "$scratch\splash_mom.png" "$dir\splash_mom.png"
Copy-Item "$scratch\splash_gurupenjas.png" "$dir\splash_gurupenjas.png"
```

- [ ] **Step 2: Generate the three placeholders**

Write this to `$scratch\make_event_dialogue_placeholders.ps1`, then run it from the project root:

```powershell
Add-Type -AssemblyName System.Drawing
$dir = "Assets\Images\EventDialogue"
$argb = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
$png = [System.Drawing.Imaging.ImageFormat]::Png
function Col($a, $hex) { [System.Drawing.Color]::FromArgb($a, [Convert]::ToInt32($hex.Substring(0,2),16), [Convert]::ToInt32($hex.Substring(2,2),16), [Convert]::ToInt32($hex.Substring(4,2),16)) }
function RoundRect($x, $y, $w, $h, $r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure(); return $p }

# 1. Seni Budaya teacher: a flat silhouette on the same 1080x1920 frame as every other splash.
$bmp = New-Object System.Drawing.Bitmap 1080, 1920, $argb
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::Transparent)
$ink = New-Object System.Drawing.SolidBrush (Col 255 "6B4A36")
$g.FillEllipse($ink, 390, 400, 300, 340)
$body = New-Object System.Drawing.Drawing2D.GraphicsPath
$body.AddBezier(300, 1920, 280, 1100, 360, 800, 540, 780); $body.AddBezier(540, 780, 720, 800, 800, 1100, 780, 1920); $body.CloseFigure()
$g.FillPath($ink, $body)
$sash = New-Object System.Drawing.SolidBrush (Col 255 "C88A2E")
$g.FillPolygon($sash, [System.Drawing.Point[]]@((New-Object System.Drawing.Point 430, 820), (New-Object System.Drawing.Point 500, 800), (New-Object System.Drawing.Point 700, 1500), (New-Object System.Drawing.Point 630, 1520)))
$g.Dispose(); $bmp.Save("$dir\splash_gurusenibudaya.png", $png); $bmp.Dispose()

# 2. Rain: the school at dusk-blue with slanted streaks. Seeded, so a rerun is byte-identical.
$src = [System.Drawing.Image]::FromFile((Resolve-Path "$dir\sekolah_background.jpg"))
$bmp = New-Object System.Drawing.Bitmap 1080, 1920, $argb
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
$g.DrawImage($src, 0, 0, 1080, 1920)
$g.FillRectangle((New-Object System.Drawing.SolidBrush (Col 150 "1B2A44")), 0, 0, 1080, 1920)
$rng = New-Object System.Random 7
$pen = New-Object System.Drawing.Pen (Col 110 "DDE8FF"), 3
for ($i = 0; $i -lt 420; $i++) { $x = $rng.Next(-200, 1080); $y = $rng.Next(-100, 1920); $len = $rng.Next(50, 110); $g.DrawLine($pen, $x, $y, $x + [int]($len * 0.3), $y + $len) }
$g.Dispose(); $src.Dispose(); $bmp.Save("$dir\hujan_background.png", $png); $bmp.Dispose()

# 3. Calendar badge: cream page, orange band, four rings. The "Minggu" and "x/y" text are labels, not art.
$bmp = New-Object System.Drawing.Bitmap 220, 260, $argb
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::Transparent)
$g.FillPath((New-Object System.Drawing.SolidBrush (Col 255 "C8672F")), (RoundRect 16 48 196 206 22))
$page = RoundRect 8 40 196 206 22
$g.FillPath((New-Object System.Drawing.SolidBrush (Col 255 "FFF6E8")), $page)
$g.SetClip($page); $g.FillRectangle((New-Object System.Drawing.SolidBrush (Col 255 "F26B3A")), 8, 40, 196, 66); $g.ResetClip()
$g.DrawPath((New-Object System.Drawing.Pen (Col 255 "6B3A1A"), 6), $page)
$ring = New-Object System.Drawing.Pen (Col 255 "5A5A5A"), 8
foreach ($x in 34, 76, 118, 160) { $g.DrawArc($ring, $x, 8, 24, 60, 180, 180); $g.DrawLine($ring, $x + 24, 38, $x + 24, 60) }
$g.Dispose(); $bmp.Save("$dir\calendar_badge.png", $png); $bmp.Dispose()
Get-ChildItem $dir | Select-Object Name, Length
```

Expected: six files listed, and `hujan_background.png` is 1080×1920.

- [ ] **Step 3: Write the blur material** (a new file, which the editor has never loaded)

`Scenes/SchoolSimulation/event_dialogue_blur_material.tres`:

```
[gd_resource type="ShaderMaterial" format=3]

[ext_resource type="Shader" uid="uid://qa800fpfmeqf" path="res://Scripts/Shaders/blur.gdshader" id="1_blur"]

[resource]
shader = ExtResource("1_blur")
shader_parameter/lod = 3.0
shader_parameter/darkness = 0.12
```

Then `filesystem_manage(op="scan")`. Expected: `.import` files appear next to the six images.

- [ ] **Step 4: Write the failing catalog tests**

`tests/test_event_dialogue.gd`:

```gdscript
@tool
extends McpTestSuite

## EventDialogue (2026-09-14 event-dialogue spec): the catalog's 13 entries,
## the screen's two tap rules, its theme variations, and SchoolDay's wiring.

const _SCENE := "res://Scenes/SchoolSimulation/EventDialogue.tscn"
const _SCHOOL_DAY := "res://Scripts/SchoolSimulation/SchoolDay.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _EVENT_KEYS := ["les_akademis", "latihan_olahraga", "workshop_seni", "nasi_kotak", "hujan"]
const _CHOICE_KEYS := ["les_akademis", "latihan_olahraga", "workshop_seni"]
const _MINIGAME_SCENES := [
	"res://Scenes/Minigames/Akademis/Menjodohkan.tscn",
	"res://Scenes/Minigames/Akademis/Variabel.tscn",
	"res://Scenes/Minigames/Akademis/PilihanGanda.tscn",
	"res://Scenes/Minigames/Akademis/Password.tscn",
	"res://Scenes/Minigames/Olahraga/MainBola.tscn",
	"res://Scenes/Minigames/Olahraga/Badminton.tscn",
	"res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn",
	"res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn",
]
const _THEA_SPLASH := "res://Assets/Images/SplashArtMurid/splash_thea.png"


func suite_name() -> String:
	return "event_dialogue"


func _student(n: String, specialty: String, splash: String = "") -> StudentData:
	var s := StudentData.new()
	s.student_name = n
	s.specialty_category = specialty
	s.splash_path = splash
	return s


# ── catalog ──────────────────────────────────────────────────────────────────

func test_every_event_and_minigame_has_an_entry() -> void:
	for key in _EVENT_KEYS:
		assert_true(EventDialogueCatalog.has_entry(key), "no dialogue for " + key)
	for path in _MINIGAME_SCENES:
		var key: String = EventDialogueCatalog.minigame_key(path)
		assert_true(EventDialogueCatalog.has_entry(key), "no dialogue for " + key)
	assert_eq(EventDialogueCatalog.ENTRIES.size(), 13, "exactly the spec's 13 entries")


func test_minigame_keys_are_scene_file_names() -> void:
	assert_eq(EventDialogueCatalog.minigame_key("res://Scenes/Minigames/Akademis/Variabel.tscn"), "Variabel")
	assert_false(EventDialogueCatalog.has_entry("Variabel Matematika"), "not _scene_name()'s display text")


func test_only_the_three_pick_students_events_ask() -> void:
	for key in EventDialogueCatalog.ENTRIES:
		var want: String = EventDialogueCatalog.MODE_CHOICE if key in _CHOICE_KEYS else EventDialogueCatalog.MODE_TAP
		assert_eq(EventDialogueCatalog.entry(key)["mode"], want, key + " mode")


func test_fixed_speakers_match_the_brief() -> void:
	assert_eq(EventDialogueCatalog.entry("nasi_kotak")["speaker"], EventDialogueCatalog.SPLASH_MOM)
	assert_eq(EventDialogueCatalog.entry("latihan_olahraga")["speaker"], EventDialogueCatalog.SPLASH_GURU_PENJAS)
	assert_eq(EventDialogueCatalog.entry("MainBola")["speaker"], EventDialogueCatalog.SPLASH_GURU_PENJAS)
	assert_eq(EventDialogueCatalog.entry("workshop_seni")["speaker"], EventDialogueCatalog.SPLASH_GURU_SENI)
	assert_eq(EventDialogueCatalog.entry("hujan")["speaker"], "", "rain has no speaker")


func test_students_speak_for_their_own_subject() -> void:
	var want := {
		"les_akademis": "Akademis", "Menjodohkan": "Akademis", "Variabel": "Akademis",
		"PilihanGanda": "Akademis", "Password": "Akademis", "Badminton": "Olahraga",
		"BuatBatik": "SeniBudaya", "LombaMenari": "SeniBudaya",
	}
	for key in want:
		var e: Dictionary = EventDialogueCatalog.entry(key)
		assert_eq(e["speaker"], EventDialogueCatalog.SPEAKER_STUDENT, key + " is voiced by a student")
		assert_eq(e["category"], want[key], key + " picks from its own subject")


func test_hujan_is_its_own_unblurred_background() -> void:
	var rain: Dictionary = EventDialogueCatalog.entry("hujan")
	assert_eq(rain["background"], EventDialogueCatalog.HUJAN_BACKGROUND)
	assert_false(rain["blur"], "the rain is the scene, so it stays sharp")
	for key in EventDialogueCatalog.ENTRIES:
		if key == "hujan":
			continue
		var e: Dictionary = EventDialogueCatalog.entry(key)
		assert_eq(e["background"], EventDialogueCatalog.DEFAULT_BACKGROUND, key + " sits on the school")
		assert_true(e["blur"], key + " blurs the school")


func test_every_art_path_loads() -> void:
	for p in [EventDialogueCatalog.DEFAULT_BACKGROUND, EventDialogueCatalog.HUJAN_BACKGROUND,
			EventDialogueCatalog.SPLASH_MOM, EventDialogueCatalog.SPLASH_GURU_PENJAS,
			EventDialogueCatalog.SPLASH_GURU_SENI, EventDialogueCatalog.CALENDAR_BADGE]:
		assert_true(ResourceLoader.exists(p), "missing art: " + p)
		assert_true(load(p) is Texture2D, p + " is not a texture")


func test_lines_are_written_and_emoji_free() -> void:
	for key in EventDialogueCatalog.ENTRIES:
		var line: String = EventDialogueCatalog.entry(key)["line"]
		assert_true(line.length() > 20, key + " has a real line")
		var clean := true
		for i in line.length():
			if line.unicode_at(i) >= 0x2000:
				clean = false
		assert_true(clean, key + " line carries a symbol or emoji")


func test_featured_student_shares_the_subject() -> void:
	var roster := [_student("Marcel", "Akademis"), _student("Doni", "Olahraga"), _student("Andi", "SeniBudaya")]
	for i in 8:
		assert_eq(EventDialogueCatalog.pick_featured(roster, "Olahraga").student_name, "Doni")


func test_featured_student_falls_back_to_anyone() -> void:
	var roster := [_student("Marcel", "Akademis")]
	assert_eq(EventDialogueCatalog.pick_featured(roster, "SeniBudaya").student_name, "Marcel")
	assert_eq(EventDialogueCatalog.pick_featured(roster, "").student_name, "Marcel")


func test_an_empty_roster_features_nobody() -> void:
	assert_eq(EventDialogueCatalog.pick_featured([], "Akademis"), null)
	assert_eq(EventDialogueCatalog.fill_line("Halo {nama}!", null), "Halo murid-murid!")


func test_nama_becomes_the_featured_name() -> void:
	var thea := _student("Thea", "SeniBudaya")
	assert_eq(EventDialogueCatalog.fill_line("Kudengar {nama} dan teman-temannya", thea),
		"Kudengar Thea dan teman-temannya")


func test_student_speakers_wear_their_own_splash() -> void:
	var thea := _student("Thea", "SeniBudaya", _THEA_SPLASH)
	assert_eq(EventDialogueCatalog.splash_path_for(EventDialogueCatalog.entry("BuatBatik"), thea), _THEA_SPLASH)
	assert_eq(EventDialogueCatalog.splash_path_for(EventDialogueCatalog.entry("nasi_kotak"), thea), EventDialogueCatalog.SPLASH_MOM)
	assert_eq(EventDialogueCatalog.splash_path_for(EventDialogueCatalog.entry("hujan"), thea), "")
	assert_eq(EventDialogueCatalog.splash_path_for(EventDialogueCatalog.entry("BuatBatik"), null), "")
```

- [ ] **Step 5: Run it to see it fail**

`filesystem_manage(op="scan")`, then `test_run(suite="event_dialogue")`.
Expected: the suite reports broken or failed, because `EventDialogueCatalog` does not exist yet.

- [ ] **Step 6: Write the catalog**

`Scripts/SchoolSimulation/EventDialogueCatalog.gd`:

```gdscript
@tool
class_name EventDialogueCatalog
extends RefCounted

## Every EventDialogue line, speaker and backdrop (2026-09-14 event-dialogue
## spec), keyed by random-event key or by minigame scene file name. Pure data
## and small helpers: SchoolDay picks the entry and the featured student, and
## EventDialogue dresses itself from them.
##
## The lines are drafts for the owner's writer (CLAUDE.md, copy
## placeholders). `{nama}` becomes the featured student's name.

## Tap twice to close; no buttons.
const MODE_TAP := "tap"
## Tolak / Terima; taps only finish the line.
const MODE_CHOICE := "choice"

## A `speaker` meaning "the featured student's own splash art".
const SPEAKER_STUDENT := "student"

const ART_DIR := "res://Assets/Images/EventDialogue/"
const DEFAULT_BACKGROUND := ART_DIR + "sekolah_background.jpg"
const HUJAN_BACKGROUND := ART_DIR + "hujan_background.png"
const SPLASH_MOM := ART_DIR + "splash_mom.png"
const SPLASH_GURU_PENJAS := ART_DIR + "splash_gurupenjas.png"
const SPLASH_GURU_SENI := ART_DIR + "splash_gurusenibudaya.png"
const CALENDAR_BADGE := ART_DIR + "calendar_badge.png"

## Stands in for {nama} when there is no roster (debug only).
const NAME_FALLBACK := "murid-murid"

## mode: MODE_TAP or MODE_CHOICE. speaker: "" for none, SPEAKER_STUDENT, or a
## texture path. category: the specialty the featured student is picked from
## ("" = anyone). background: a texture path. blur: blur the backdrop.
const ENTRIES := {
	"nasi_kotak": {
		"mode": MODE_TAP, "speaker": SPLASH_MOM, "category": "",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Kudengar {nama} dan teman-temannya sedang bekerja keras, semoga ini dapat menyemangati mereka!",
	},
	"hujan": {
		"mode": MODE_TAP, "speaker": "", "category": "",
		"background": HUJAN_BACKGROUND, "blur": false,
		"line": "Hujan deras sejak pagi membuat jalanan licin. Beberapa murid basah kuyup dan terpeleset di jalan menuju sekolah.",
	},
	"les_akademis": {
		"mode": MODE_CHOICE, "speaker": SPEAKER_STUDENT, "category": "Akademis",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Sekolah membuka les tambahan sepulang sekolah. Aku mau ikut, boleh kan?",
	},
	"latihan_olahraga": {
		"mode": MODE_CHOICE, "speaker": SPLASH_GURU_PENJAS, "category": "",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Lapangan sedang kosong sore ini. Bagaimana kalau {nama} dan yang lain ikut latihan tambahan bersamaku?",
	},
	"workshop_seni": {
		"mode": MODE_CHOICE, "speaker": SPLASH_GURU_SENI, "category": "",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Sanggar seni sedang mengadakan workshop batik dan tari daerah. Ajak {nama} dan teman-temannya bergabung, ya!",
	},
	"MainBola": {
		"mode": MODE_TAP, "speaker": SPLASH_GURU_PENJAS, "category": "",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Ayo latihan adu penalti! Tendang bolanya sekuat tenaga dan jangan sampai ditangkap kiper!",
	},
	"Badminton": {
		"mode": MODE_TAP, "speaker": SPEAKER_STUDENT, "category": "Olahraga",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Raketku sudah siap dari tadi. Ayo tanding badminton, siapa takut?",
	},
	"Menjodohkan": {
		"mode": MODE_TAP, "speaker": SPEAKER_STUDENT, "category": "Akademis",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Kartu soal dan jawabannya tercampur semua! Bantu aku menjodohkannya sebelum waktunya habis.",
	},
	"Variabel": {
		"mode": MODE_TAP, "speaker": SPEAKER_STUDENT, "category": "Akademis",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Ada teka-teki angka di papan tulis. Kira-kira berapa nilai tiap simbolnya, ya?",
	},
	"PilihanGanda": {
		"mode": MODE_TAP, "speaker": SPEAKER_STUDENT, "category": "Akademis",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Kuis dadakan! Tiga soal pilihan ganda. Aku pasti bisa!",
	},
	"Password": {
		"mode": MODE_TAP, "speaker": SPEAKER_STUDENT, "category": "Akademis",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Lemari kelas cuma terbuka kalau hitungannya benar. Ayo kita hitung bersama!",
	},
	"BuatBatik": {
		"mode": MODE_TAP, "speaker": SPEAKER_STUDENT, "category": "SeniBudaya",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Kain, canting, dan pewarna sudah siap. Aku mau membatik, tapi urutannya harus benar!",
	},
	"LombaMenari": {
		"mode": MODE_TAP, "speaker": SPEAKER_STUDENT, "category": "SeniBudaya",
		"background": DEFAULT_BACKGROUND, "blur": true,
		"line": "Lomba menari sebentar lagi dimulai! Ikuti iramanya dan jangan sampai salah langkah.",
	},
}


## True when `key` has a dialogue. SchoolDay skips the screen otherwise.
static func has_entry(key: String) -> bool:
	return ENTRIES.has(key)


## The entry for `key`, or an empty Dictionary.
static func entry(key: String) -> Dictionary:
	return ENTRIES.get(key, {})


## The catalog key for a minigame scene: its file name, no extension.
static func minigame_key(scene_path: String) -> String:
	return scene_path.get_file().get_basename()


## A random roster student whose specialty is `category`. Any roster student
## when nobody matches or `category` is empty; null for an empty roster.
static func pick_featured(students: Array, category: String) -> StudentData:
	if students.is_empty():
		return null
	var pool: Array = []
	if category != "":
		for s in students:
			if s is StudentData and s.specialty_category == category:
				pool.append(s)
	if pool.is_empty():
		pool = students
	return pool[randi() % pool.size()]


## `line` with {nama} replaced by the featured student's name.
static func fill_line(line: String, featured: StudentData) -> String:
	var who: String = NAME_FALLBACK if featured == null else featured.student_name
	return line.replace("{nama}", who)


## The speaker's texture path: the featured student's splash for
## SPEAKER_STUDENT, the fixed art otherwise, "" for none.
static func splash_path_for(e: Dictionary, featured: StudentData) -> String:
	var speaker: String = e.get("speaker", "")
	if speaker == SPEAKER_STUDENT:
		return "" if featured == null else featured.splash_path
	return speaker
```

- [ ] **Step 7: Run it to see it pass**

`filesystem_manage(op="scan")`, which registers the `class_name`, then `test_run(suite="event_dialogue")`.
Expected: every test in the suite passes.

- [ ] **Step 8: Commit**

```bash
git add Assets/Images/EventDialogue Scenes/SchoolSimulation/event_dialogue_blur_material.tres Scripts/SchoolSimulation/EventDialogueCatalog.gd tests/test_event_dialogue.gd
git commit -m "feat(event-dialogue): the catalog of 13 lines and its art"
```

Stage the `.import` and `.uid` files the scan created alongside them. `git add <dir>` does this.

---

### Task 2: The EventDialogue screen

**Files:**
- Create: `Scripts/SchoolSimulation/EventDialogue.gd`
- Create: `Scenes/SchoolSimulation/EventDialogue.tscn`, built in the editor
- Modify: `tests/test_event_dialogue.gd`, which gains the screen section

**Interfaces:**
- Consumes: Task 1's catalog.
- Produces (used by Task 4):
  - `signal closed(accepted: bool)`
  - `open(e: Dictionary, featured: StudentData, week: int, max_weeks: int, day_name: String) -> void`
  - `tap() -> void`
  - `static is_tap(event: InputEvent) -> bool`
  - `var mode: String` and `var armed: bool`
  - nodes `background`, `blur`, `splash`, `week_label`, `day_label`, `dialogue_box`, `line_label`, `hint`, `choices`, `tolak_button`, `terima_button`

- [ ] **Step 1: Append the failing screen tests** to `tests/test_event_dialogue.gd`

```gdscript
# ── the screen ───────────────────────────────────────────────────────────────

## Instantiated with the baked theme under the editor root, tracked for
## cleanup -- the same helper shape as test_school_day.gd's _instantiate().
## Untyped on purpose: typed as Control, GDScript rejects d.tap() and the
## other script members at compile time.
func _dialogue(key: String, featured: StudentData = null):
	var d = (load(_SCENE) as PackedScene).instantiate()
	d.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(d)
	track(d)
	d.open(EventDialogueCatalog.entry(key), featured, 2, 6, "Senin")
	return d


func test_a_tap_dialogue_takes_two_taps() -> void:
	var d = _dialogue("nasi_kotak")
	var got: Array = []
	d.closed.connect(func(accepted: bool): got.append(accepted))
	assert_true(d.line_label.visible_ratio < 1.0, "the line starts unrevealed")
	d.tap()
	assert_eq(got, [], "the first tap never closes")
	assert_eq(d.line_label.visible_ratio, 1.0, "the first tap finishes the line")
	assert_true(d.armed and d.hint.visible, "and shows the hint")
	d.tap()
	assert_eq(got, [true], "the second tap closes")


func test_a_finished_line_still_takes_two_taps() -> void:
	var d = _dialogue("hujan")
	var got: Array = []
	d.closed.connect(func(accepted: bool): got.append(accepted))
	d.line_label.visible_ratio = 1.0
	d.tap()
	assert_eq(got, [], "a first tap on a finished line only arms")
	d.tap()
	assert_eq(got, [true])


func test_a_tap_dialogue_has_no_buttons() -> void:
	var d = _dialogue("MainBola")
	d.tap()
	assert_false(d.choices.visible, "TAP entries never show Tolak / Terima")


func test_a_choice_dialogue_ignores_taps() -> void:
	var d = _dialogue("les_akademis")
	var got: Array = []
	d.closed.connect(func(accepted: bool): got.append(accepted))
	assert_false(d.choices.visible, "buttons wait for the line")
	d.tap()
	assert_true(d.choices.visible, "a tap finishes the line and shows the buttons")
	d.tap()
	d.tap()
	assert_eq(got, [], "taps never close a CHOICE dialogue")
	assert_false(d.hint.visible, "the tap hint is for TAP dialogues")


func test_terima_accepts_and_tolak_declines() -> void:
	var yes = _dialogue("workshop_seni")
	var got_yes: Array = []
	yes.closed.connect(func(accepted: bool): got_yes.append(accepted))
	yes.tap()
	yes.terima_button.pressed.emit()
	assert_eq(got_yes, [true])
	var no = _dialogue("latihan_olahraga")
	var got_no: Array = []
	no.closed.connect(func(accepted: bool): got_no.append(accepted))
	no.tap()
	no.tolak_button.pressed.emit()
	assert_eq(got_no, [false])


func test_open_dresses_the_screen() -> void:
	var thea := _student("Thea", "SeniBudaya", _THEA_SPLASH)
	var d = _dialogue("BuatBatik", thea)
	assert_eq(d.splash.texture.resource_path, _THEA_SPLASH, "the student's own splash")
	assert_true(d.splash.visible and d.blur.visible)
	assert_eq(d.background.texture.resource_path, EventDialogueCatalog.DEFAULT_BACKGROUND)
	assert_eq(d.week_label.text, "2/6")
	assert_eq(d.day_label.text, "Senin")


func test_nama_reaches_the_screen() -> void:
	var d = _dialogue("nasi_kotak", _student("Thea", "SeniBudaya"))
	assert_true(d.line_label.text.contains("Kudengar Thea"), d.line_label.text)
	assert_eq(d.splash.texture.resource_path, EventDialogueCatalog.SPLASH_MOM)


func test_hujan_hides_the_splash_and_the_blur() -> void:
	var d = _dialogue("hujan", _student("Thea", "SeniBudaya", _THEA_SPLASH))
	assert_false(d.splash.visible, "rain has no speaker")
	assert_false(d.blur.visible, "and a sharp backdrop")
	assert_eq(d.background.texture.resource_path, EventDialogueCatalog.HUJAN_BACKGROUND)


func test_only_a_left_press_counts_as_a_tap() -> void:
	var d = _dialogue("nasi_kotak")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	assert_true(d.is_tap(press))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	assert_false(d.is_tap(release), "a release is not a tap")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	assert_false(d.is_tap(right))
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	assert_false(d.is_tap(touch), "a touch also arrives as a click; counting both doubles every tap")


func test_the_scene_is_authored_and_themed() -> void:
	var d = _dialogue("nasi_kotak")
	var want := {
		"DialogueBox": &"EventDialoguePanel", "DialogueBox/Content/Line": &"EventDialogueText",
		"DialogueBox/Content/Hint": &"CaptionLabel",
		"DialogueBox/Content/Choices/TolakButton": &"SecondaryButton",
		"DialogueBox/Content/Choices/TerimaButton": &"PrimaryButton",
		"Header/DayBanner": &"DayBannerPanel", "Header/DayBanner/DayLabel": &"DayBannerLabel",
		"Header/Calendar/Text/MingguLabel": &"CalendarLabel", "Header/Calendar/Text/WeekLabel": &"DayBannerLabel",
	}
	for path in want:
		var n := d.get_node_or_null(path) as Control
		assert_true(n != null, "missing node " + path)
		if n != null:
			assert_eq(n.theme_type_variation, want[path], path)
	assert_eq(d.mouse_filter, Control.MOUSE_FILTER_STOP, "the root takes the taps")
	for path in ["Background", "Blur", "Splash", "Header", "DialogueBox", "DialogueBox/Content/Line"]:
		assert_eq((d.get_node(path) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
			path + " must let taps through to the root")
	assert_eq((d.get_node("Blur") as ColorRect).material.resource_path,
		"res://Scenes/SchoolSimulation/event_dialogue_blur_material.tres")
	assert_eq((d.get_node("Header/Calendar") as TextureRect).texture.resource_path,
		EventDialogueCatalog.CALENDAR_BADGE)
	var src := FileAccess.get_file_as_string("res://Scripts/SchoolSimulation/EventDialogue.gd")
	assert_false(src.contains(".new("), "the screen is fully authored")
	var scene := FileAccess.get_file_as_string(_SCENE)
	for kind in ["theme_override_colors", "theme_override_font_sizes", "theme_override_fonts", "theme_override_styles"]:
		assert_false(scene.contains(kind), "no " + kind + " in EventDialogue.tscn")
```

- [ ] **Step 2: Run it to see it fail**

`test_run(suite="event_dialogue")`. Expected: the new screen tests fail because the scene does not exist. The catalog tests still pass.

- [ ] **Step 3: Write the script**

`Scripts/SchoolSimulation/EventDialogue.gd`:

```gdscript
@tool
extends Control

## The per-event dialogue (2026-09-14 event-dialogue spec): one character
## line over a blurred school, between EventWarning and a minigame or random
## event. Two modes, both chosen by EventDialogueCatalog:
##
## - TAP: no buttons. Always two taps: the first finishes the line and shows
##   the hint, the second closes with accepted = true.
## - CHOICE: taps only finish the line; Tolak / Terima close it.
##
## Everything is authored in EventDialogue.tscn; open() only sets textures,
## text and visibility. SchoolDay awaits `closed`.

## Emitted once: true for Terima or a finished TAP dialogue, false for Tolak.
signal closed(accepted: bool)

## Typewriter speed in characters per second. Same default as the intro cutscene.
@export var typewriter_chars_per_second: float = 45.0

@onready var background: TextureRect = $Background
@onready var blur: ColorRect = $Blur
@onready var splash: TextureRect = $Splash
@onready var week_label: Label = $Header/Calendar/Text/WeekLabel
@onready var day_label: Label = $Header/DayBanner/DayLabel
@onready var dialogue_box: PanelContainer = $DialogueBox
@onready var line_label: RichTextLabel = $DialogueBox/Content/Line
@onready var hint: Label = $DialogueBox/Content/Hint
@onready var choices: HBoxContainer = $DialogueBox/Content/Choices
@onready var tolak_button: Button = $DialogueBox/Content/Choices/TolakButton
@onready var terima_button: Button = $DialogueBox/Content/Choices/TerimaButton

## EventDialogueCatalog.MODE_TAP or MODE_CHOICE, from the open entry.
var mode: String = EventDialogueCatalog.MODE_TAP
## True once a TAP dialogue's first tap has landed.
var armed: bool = false
var _reveal_tween: Tween
var _is_closed: bool = false


func _ready() -> void:
	tolak_button.pressed.connect(_close.bind(false))
	terima_button.pressed.connect(_close.bind(true))
	if Engine.is_editor_hint():
		return
	AudioDirector.play_sfx(&"popup_open")


## Dress the screen for one catalog entry. `featured` may be null (empty
## roster). At runtime the line types itself out; in the editor it waits at
## visible_ratio 0 for a tap, which is what the tests drive.
func open(e: Dictionary, featured: StudentData, week: int, max_weeks: int, day_name: String) -> void:
	mode = e.get("mode", EventDialogueCatalog.MODE_TAP)
	armed = false
	_is_closed = false
	var bg_path: String = e.get("background", EventDialogueCatalog.DEFAULT_BACKGROUND)
	background.texture = load(bg_path)
	blur.visible = e.get("blur", true)
	var splash_path: String = EventDialogueCatalog.splash_path_for(e, featured)
	splash.texture = load(splash_path) if splash_path != "" and ResourceLoader.exists(splash_path) else null
	splash.visible = splash.texture != null
	week_label.text = "%d/%d" % [week, max_weeks]
	day_label.text = day_name
	line_label.text = EventDialogueCatalog.fill_line(e.get("line", ""), featured)
	line_label.visible_ratio = 0.0
	hint.visible = false
	choices.visible = false
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	Juice.pop_in(dialogue_box)
	var chars := float(line_label.get_total_character_count())
	_reveal_tween = line_label.create_tween()
	_reveal_tween.tween_property(line_label, "visible_ratio", 1.0,
		chars / maxf(typewriter_chars_per_second, 1.0))
	_reveal_tween.finished.connect(_on_line_shown)


func _gui_input(event: InputEvent) -> void:
	if not is_tap(event):
		return
	accept_event()
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"tap")
	tap()


## True for the one event per tap this screen counts: a left mouse-button
## press. project.godot emulates touch from mouse and Godot emulates mouse
## from touch, so every tap also arrives as a ScreenTouch; counting both would
## close a TAP dialogue on its first tap. A ScreenTouch counts only when
## mouse-from-touch emulation is off.
static func is_tap(event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	if mb != null:
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	var st := event as InputEventScreenTouch
	if st != null:
		return st.pressed and not bool(ProjectSettings.get_setting(
			"input_devices/pointing/emulate_mouse_from_touch", true))
	return false


## One tap. TAP: finish the line and arm, or close once armed. CHOICE: finish
## the line; only the buttons close it.
func tap() -> void:
	if _is_closed:
		return
	if line_label.visible_ratio < 1.0:
		_finish_line()
	if mode == EventDialogueCatalog.MODE_CHOICE:
		return
	if not armed:
		armed = true
		hint.visible = true
		return
	_close(true)


func _finish_line() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	line_label.visible_ratio = 1.0
	_on_line_shown()


func _on_line_shown() -> void:
	if mode == EventDialogueCatalog.MODE_CHOICE:
		choices.visible = true


func _close(accepted: bool) -> void:
	if _is_closed:
		return
	_is_closed = true
	closed.emit(accepted)
```

Then `filesystem_manage(op="scan")`.

- [ ] **Step 4: Build the scene in the editor**

Create `Scenes/SchoolSimulation/EventDialogue.tscn` with `scene_manage(op="create", params={"path": "res://Scenes/SchoolSimulation/EventDialogue.tscn", "root_type": "Control", "root_name": "EventDialogue"})`. Then use `batch_execute` with `create_node {type, name, parent_path}` and `set_property {path, property, value}`. Paths are relative to the edited scene root, which is `/EventDialogue`. Create the nodes in this order, since order is the z-order:

| Node (parent) | Type | Properties |
|---|---|---|
| root `/EventDialogue` | Control | anchor_right 1, anchor_bottom 1, grow_horizontal 2, grow_vertical 2, mouse_filter 0 |
| Background (root) | TextureRect | layout_mode 1, then anchors 0/0/1/1, offsets 0; expand_mode 1, stretch_mode 6, mouse_filter 2, texture `res://Assets/Images/EventDialogue/sekolah_background.jpg` |
| Blur (root) | ColorRect | layout_mode 1, anchors 0/0/1/1; mouse_filter 2; material `res://Scenes/SchoolSimulation/event_dialogue_blur_material.tres` |
| Splash (root) | TextureRect | layout_mode 1, anchors 0/0/1/1; expand_mode 1, stretch_mode 5, mouse_filter 2, texture `res://Assets/Images/EventDialogue/splash_mom.png` (authoring preview) |
| Header (root) | Control | layout_mode 1, anchor_right 1, offset_bottom 300, mouse_filter 2 |
| DayBanner (Header) | PanelContainer | layout_mode 1, offset_left 250, offset_top 100, offset_right 936, offset_bottom 236, mouse_filter 2, theme_type_variation "DayBannerPanel" |
| DayLabel (Header/DayBanner) | Label | theme_type_variation "DayBannerLabel", text "Senin", horizontal_alignment 1, vertical_alignment 1 |
| Calendar (Header) | TextureRect | layout_mode 1, offset_left 104, offset_top 44, offset_right 312, offset_bottom 292, expand_mode 1, stretch_mode 5, mouse_filter 2, texture `res://Assets/Images/EventDialogue/calendar_badge.png` |
| Text (Header/Calendar) | VBoxContainer | layout_mode 1, anchor_right 1, anchor_top 0.42, anchor_bottom 0.96, alignment 1, mouse_filter 2, theme_override_constants/separation -10 |
| MingguLabel (…/Text) | Label | theme_type_variation "CalendarLabel", text "Minggu", horizontal_alignment 1 |
| WeekLabel (…/Text) | Label | theme_type_variation "DayBannerLabel", text "2/6", horizontal_alignment 1 |
| DialogueBox (root) | PanelContainer | layout_mode 1, anchor_top 1, anchor_right 1, anchor_bottom 1, offset_left 92, offset_top -644, offset_right -92, offset_bottom -184, grow_horizontal 2, grow_vertical 0, mouse_filter 2, theme_type_variation "EventDialoguePanel" |
| Content (DialogueBox) | VBoxContainer | mouse_filter 2, theme_override_constants/separation 24 |
| Line (…/Content) | RichTextLabel | size_flags_vertical 3, fit_content true, scroll_active false, mouse_filter 2, theme_type_variation "EventDialogueText", text: the `nasi_kotak` line with "Thea" |
| Hint (…/Content) | Label | theme_type_variation "CaptionLabel", text "Ketuk sekali lagi untuk lanjut", horizontal_alignment 1, mouse_filter 2 |
| Choices (…/Content) | HBoxContainer | alignment 1, mouse_filter 2, theme_override_constants/separation 32 |
| TolakButton (…/Choices) | Button | theme_type_variation "SecondaryButton", text "Tolak", size_flags_horizontal 3 |
| TerimaButton (…/Choices) | Button | theme_type_variation "PrimaryButton", text "Terima", size_flags_horizontal 3 |

Last, set the root's `script` to `res://Scripts/SchoolSimulation/EventDialogue.gd`, then call `scene_save`.
Check: `scene_get_hierarchy` shows the tree above, and `git diff HEAD -- '*.gd'` lists no file besides this task's.

- [ ] **Step 5: Run the suite to see it pass**

`test_run(suite="event_dialogue")`. Expected: every test passes. Theme variations the theme does not bake yet only fall back to their base type, and the tests compare the variation names, not their looks.

- [ ] **Step 6: Commit**

```bash
git add Scripts/SchoolSimulation/EventDialogue.gd Scripts/SchoolSimulation/EventDialogue.gd.uid Scenes/SchoolSimulation/EventDialogue.tscn tests/test_event_dialogue.gd
git commit -m "feat(event-dialogue): the dialogue screen with two taps or Tolak/Terima"
```

---

### Task 3: Theme: the bold token and five variations

**Files:**
- Modify: `Scripts/Design/DesignTokens.gd`, after `font_body`
- Modify: `Scripts/Design/ThemeFactory.gd`, in `build()` and a new `_build_event_dialogue()`
- Modify: `tests/test_theme_factory.gd`, in `test_every_declared_variation_exists`
- Modify: `tests/test_event_dialogue.gd`, which gains the theme section
- Modify: `Assets/Theme/kejartes_theme.tres`, by rebaking

**Interfaces:**
- Produces: `DesignTokens.font_body_bold: FontFile`, and the variations `EventDialoguePanel` (PanelContainer), `EventDialogueText` (RichTextLabel), `DayBannerPanel` (PanelContainer), `DayBannerLabel` (Label) and `CalendarLabel` (Label).

- [ ] **Step 1: Write the failing theme tests** by appending to `tests/test_event_dialogue.gd`

```gdscript
# ── theme ────────────────────────────────────────────────────────────────────

const _VARIATIONS := {
	"EventDialoguePanel": &"PanelContainer", "EventDialogueText": &"RichTextLabel",
	"DayBannerPanel": &"PanelContainer", "DayBannerLabel": &"Label", "CalendarLabel": &"Label",
}


func test_the_bold_token_is_open_sans_bold() -> void:
	var t := DesignTokens.load_default()
	assert_true(t.font_body_bold != null, "font_body_bold is set")
	if t.font_body_bold != null:
		assert_eq(t.font_body_bold.resource_path, "res://Assets/Fonts/OpenSans-Bold.ttf")


func test_factory_builds_the_dialogue_variations() -> void:
	var t := DesignTokens.load_default()
	var theme := ThemeFactory.build(t)
	for v in _VARIATIONS:
		assert_eq(theme.get_type_variation_base(v), _VARIATIONS[v], v + " base type")
	assert_eq(theme.get_font("normal_font", "EventDialogueText"), t.font_body_bold)
	assert_eq(theme.get_color("default_color", "EventDialogueText"), t.text_primary)
	assert_eq(theme.get_font("font", "DayBannerLabel"), t.font_body_bold)
	assert_eq(theme.get_font("font", "CalendarLabel"), t.font_body_bold)
	var card := theme.get_stylebox("panel", "EventDialoguePanel") as StyleBoxFlat
	assert_true(card != null, "the card is a flat box")
	if card != null:
		assert_eq(card.bg_color, t.surface_card)
		assert_eq(card.corner_radius_top_left, ThemeFactory.EVENT_DIALOGUE_RADIUS)
	var pill := theme.get_stylebox("panel", "DayBannerPanel") as StyleBoxFlat
	assert_true(pill != null, "the banner is a flat box")
	if pill != null:
		assert_eq(pill.border_color, t.brand_primary_dark)
		assert_eq(pill.border_width_left, ThemeFactory.DAY_BANNER_OUTLINE)


func test_the_bake_declares_the_dialogue_variations() -> void:
	var baked := ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	for v in _VARIATIONS:
		assert_true(baked.get_type_list().has(v), v + " must be in the baked theme -- rebake")
```

In `tests/test_theme_factory.gd`, `test_every_declared_variation_exists`, extend `expected`:

```gdscript
		"CaptionLabel", "MicroLabel", "StatBar", "FilterChipButton",
		"EventDialoguePanel", "EventDialogueText", "DayBannerPanel", "DayBannerLabel", "CalendarLabel",
	]
```

- [ ] **Step 2: Run to see them fail**

`filesystem_manage(op="scan")`, then `test_run(suite="event_dialogue")` and `test_run(suite="theme_factory")`.
Expected: `event_dialogue` fails to compile or fails, because `font_body_bold` does not exist. `theme_factory` fails on the five missing types.

- [ ] **Step 3: Add the token** in `Scripts/Design/DesignTokens.gd`, directly after `@export var font_body: FontFile`

```gdscript
## Bold body face (Open Sans Bold) for EventDialogueText, DayBannerLabel and
## CalendarLabel: mockup_eventdialogue.png sets its line, day and week in it.
## Null falls back to font_body.
@export var font_body_bold: FontFile = preload("res://Assets/Fonts/OpenSans-Bold.ttf")
```

- [ ] **Step 4: Add the variations** in `Scripts/Design/ThemeFactory.gd`

In `build()`, after `_build_event_warning(theme, tokens)`, add `_build_event_dialogue(theme, tokens)`. Then add, right after `_build_event_warning()`:

```gdscript
## Measured off mockup_eventdialogue.png: the dialogue card's corner radius
## and the day banner's brown rim. No token matches either; both are
## single-screen values.
const EVENT_DIALOGUE_RADIUS := 80
const DAY_BANNER_OUTLINE := 12


## The event dialogue (2026-09-14 event-dialogue spec): a white rounded card
## with dark bold text, and the header's day banner and calendar labels, all
## in the bold body face the mockup uses.
static func _build_event_dialogue(theme: Theme, tokens: DesignTokens) -> void:
	var bold: Font = tokens.font_body_bold if tokens.font_body_bold != null else tokens.font_body

	theme.add_type("EventDialoguePanel")
	theme.set_type_variation("EventDialoguePanel", "PanelContainer")
	var card := StyleBoxFlat.new()
	card.bg_color = tokens.surface_card
	card.set_corner_radius_all(EVENT_DIALOGUE_RADIUS)
	card.shadow_color = tokens.shadow_color
	card.shadow_size = tokens.shadow_size
	card.shadow_offset = tokens.shadow_offset
	card.content_margin_left = tokens.space_xl
	card.content_margin_right = tokens.space_xl
	card.content_margin_top = tokens.space_lg
	card.content_margin_bottom = tokens.space_lg
	theme.set_stylebox("panel", "EventDialoguePanel", card)

	# RichTextLabel's theme items are "normal_font"/"normal_font_size"/
	# "default_color", not the Label names -- see _add_cutscene_dialogue.
	theme.add_type("EventDialogueText")
	theme.set_type_variation("EventDialogueText", "RichTextLabel")
	theme.set_font_size("normal_font_size", "EventDialogueText", tokens.font_title + 8)
	theme.set_color("default_color", "EventDialogueText", tokens.text_primary)
	if bold != null:
		theme.set_font("normal_font", "EventDialogueText", bold)

	theme.add_type("DayBannerPanel")
	theme.set_type_variation("DayBannerPanel", "PanelContainer")
	var pill := StyleBoxFlat.new()
	pill.bg_color = tokens.surface_card
	pill.border_color = tokens.brand_primary_dark
	pill.set_border_width_all(DAY_BANNER_OUTLINE)
	pill.set_corner_radius_all(tokens.radius_pill)
	# The calendar badge overlaps the banner's left end in the mockup.
	pill.content_margin_left = tokens.space_xl + tokens.space_lg
	pill.content_margin_right = tokens.space_lg
	theme.set_stylebox("panel", "DayBannerPanel", pill)

	for spec in [["DayBannerLabel", tokens.font_h1], ["CalendarLabel", tokens.font_body_size]]:
		var variation: String = spec[0]
		theme.add_type(variation)
		theme.set_type_variation(variation, "Label")
		theme.set_font_size("font_size", variation, spec[1])
		theme.set_color("font_color", variation, tokens.text_primary)
		if bold != null:
			theme.set_font("font", variation, bold)
```

- [ ] **Step 5: Restart the editor.** A new `@export` on `DesignTokens` is invisible until then; see Global Constraints. Then poll `session_manage(op="list")`.

- [ ] **Step 6: Rebake**

`test_run(suite="theme_rebake")`. Expected: 1 passed.
Check with `git diff --stat Assets/Theme/kejartes_theme.tres` and `grep -c "EventDialoguePanel\|DayBannerLabel\|CalendarLabel" Assets/Theme/kejartes_theme.tres`. The count must be non-zero.

- [ ] **Step 7: Restart the editor again** so the cached theme is not merged back on a later save, then poll `session_manage`.

- [ ] **Step 8: Run the suites to see them pass**

`test_run(suite="event_dialogue")`, `test_run(suite="theme_factory")` and `test_run(suite="event_warning")`. Expected: all pass. If one theme assertion fails in `theme_factory`, run that suite alone once more before believing it; see CLAUDE.md on suite order.

- [ ] **Step 9: Commit**

```bash
git add Scripts/Design/DesignTokens.gd Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_theme_factory.gd tests/test_event_dialogue.gd
git commit -m "feat(theme): bold body token and the event dialogue variations"
```

---

### Task 4: SchoolDay wiring

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd`, through `script_patch` only
- Modify: `tests/test_event_dialogue.gd`, which gains the wiring section

**Interfaces:**
- Consumes: `EventDialogueCatalog.has_entry` / `entry` / `pick_featured` / `minigame_key` from Task 1, and `open()` / `closed` from Task 2.
- Produces:
  - `@export var event_dialogue_scene: PackedScene`
  - `_show_event_dialogue(key: String) -> bool`
  - `_run_event(event_id: int, day_name: String) -> void`
  - `_handle_interactive_event(..., dialogue_key: String = "")`

- [ ] **Step 1: Append the failing wiring tests** to `tests/test_event_dialogue.gd`

```gdscript
# ── SchoolDay wiring (source scans) ──────────────────────────────────────────

func _body(src: String, fn: String) -> String:
	var start := src.find("\nfunc %s(" % fn)
	if start == -1:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end if end != -1 else src.length()) - start)


func test_the_dialogue_scene_is_lazy_loaded() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY)
	assert_contains(src, "@export var event_dialogue_scene: PackedScene")
	assert_contains(src, 'load("res://Scenes/SchoolSimulation/EventDialogue.tscn")')


func test_minigames_hear_their_line_between_warning_and_play() -> void:
	var body := _body(FileAccess.get_file_as_string(_SCHOOL_DAY), "_roll_event")
	for pair in [["KEGIATAN AKADEMIS!", "Akademis"], ["KEGIATAN OLAHRAGA!", "Olahraga"], ["KEGIATAN SENI BUDAYA!", "SeniBudaya"]]:
		var warn := body.find('_show_event_warning("%s")' % pair[0])
		var talk := body.find("_show_event_dialogue(EventDialogueCatalog.minigame_key(scene.resource_path))", warn)
		var play := body.find('_play_minigame(scene, "%s")' % pair[1], warn)
		assert_true(warn != -1 and talk > warn and play > talk,
			pair[1] + ": warning, then dialogue, then minigame")


func test_every_minigame_scene_school_day_loads_has_a_line() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY)
	for path in _MINIGAME_SCENES:
		assert_true(src.contains(path), "SchoolDay no longer loads " + path)
		assert_true(EventDialogueCatalog.has_entry(EventDialogueCatalog.minigame_key(path)), path)


func test_global_events_speak_before_they_apply() -> void:
	var body := _body(FileAccess.get_file_as_string(_SCHOOL_DAY), "_run_event")
	for trio in [["Kejutan Nasi Kotak Orang Tua!", "nasi_kotak", "EVENT_NASI_KOTAK_ENERGI"],
			["Hujan Deras & Jalanan Licin!", "hujan", "EVENT_HUJAN_ENERGI"]]:
		var warn := body.find('_show_event_warning("%s")' % trio[0])
		var talk := body.find('_show_event_dialogue("%s")' % trio[1], warn)
		var apply := body.find(trio[2], warn)
		assert_true(warn != -1 and talk > warn and apply > talk, trio[1] + ": warning, dialogue, effect")


func test_pick_students_events_pass_their_key() -> void:
	var body := _body(FileAccess.get_file_as_string(_SCHOOL_DAY), "_run_event")
	for key in _CHOICE_KEYS:
		assert_contains(body, '"%s"' % key)


func test_tolak_returns_before_the_picker() -> void:
	var body := _body(FileAccess.get_file_as_string(_SCHOOL_DAY), "_handle_interactive_event")
	var warn := body.find("await _show_event_warning(title)")
	var ask := body.find("_show_event_dialogue(dialogue_key)")
	var bail := body.find("return", ask)
	var picker := body.find("dialog_scene.instantiate()")
	assert_true(warn != -1 and ask > warn and bail > ask and picker > bail,
		"warning, dialogue, and a declined dialogue returns before the picker exists")


func test_the_event_list_exists_once() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY)
	assert_eq(src.count('"Les Tambahan Akademis"'), 1, "one copy of the event table")
	assert_contains(_body(src, "_trigger_random_event"), "_run_event(randi() % 5, day_name)")
	assert_contains(_body(src, "force_event"), "_run_event(event_id, day_name)")
```

- [ ] **Step 2: Run to see them fail**

No-op `script_patch` on `tests/test_event_dialogue.gd` if the runner serves a stale copy, then `test_run(suite="event_dialogue")`. Expected: the seven wiring tests fail; everything else passes.

- [ ] **Step 3: Patch SchoolDay.gd** using `script_patch` only. Read lines 39–46 first for the exact anchor text.

(a) After the `event_student_select_scene` export, add:

```gdscript
## The per-event character line between the warning and a minigame or event
## (2026-09-14 event-dialogue spec). Null lazy-loads
## Scenes/SchoolSimulation/EventDialogue.tscn.
@export var event_dialogue_scene: PackedScene
```

(b) In `_roll_event`, each minigame branch gets one line between the warning and the play. Shown here for Akademis; the Olahraga and SeniBudaya branches are identical apart from their captions and categories:

```gdscript
			await _show_event_warning("KEGIATAN AKADEMIS!")
			await _show_event_dialogue(EventDialogueCatalog.minigame_key(scene.resource_path))
			await _play_minigame(scene, "Akademis")
```

(c) Replace `_trigger_random_event()`, from its `var event_id = randi() % 5` line through the end of its `match`, and replace `force_event()`'s duplicated Biang Onar block and `match`, so that the three functions read:

```gdscript
func _trigger_random_event(day_name: String) -> void:
	events_triggered_this_week += 1
	# Every student on the roster is present for an event, so
	# an event marks the whole roster as having participated.
	for s in GameState.approved_students:
		GameState.run_stats.record_event_student(int(s.get("id", -1)))
	await _run_event(randi() % 5, day_name)


## Plays random event `event_id` (0-4) on `day_name`: its warning, its
## dialogue, then its effect. The one copy of the event list --
## _trigger_random_event() rolls the id, force_event() takes it from the
## debug overlay.
func _run_event(event_id: int, day_name: String) -> void:
	# ── Quirk: Biang Onar — events are ±20% stronger when active ──
	# Check if any student with Biang Onar is in the roster (affects all events)
	var biang_onar_active: bool = false
	var biang_onar_scale: float = 0.0
	if student_manager:
		for s in student_manager.students:
			if s.quirk == "Biang Onar":
				biang_onar_active = true
				biang_onar_scale = Balance.SIFAT_BIANG_ONAR_EVENT_BAGUS
				break

	match event_id:
		0:
			var stat_val := Balance.EVENT_AKADEMIS_POIN * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := Balance.EVENT_AKADEMIS_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Les Tambahan Akademis",
				"Sekolah membuka kelas Les Bimbingan Intensif setelah jam pelajaran.",
				"Akademis +%d" % int(stat_val),
				"Energy %d" % int(nrg_val),
				"Akademis", stat_val, nrg_val, 0.0,
				"les_akademis"
			)
		1:
			var stat_val := Balance.EVENT_OLAHRAGA_POIN * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_val := Balance.EVENT_OLAHRAGA_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := Balance.EVENT_OLAHRAGA_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Latihan Olahraga Ekstra",
				"Fasilitas lapangan terbuka gratis untuk sesi latihan bersama.",
				"Olahraga +%d, Mood +%d" % [int(stat_val), int(mood_val)],
				"Energy %d" % int(nrg_val),
				"Olahraga", stat_val, nrg_val, mood_val,
				"latihan_olahraga"
			)
		2:
			var stat_val := Balance.EVENT_SENI_POIN * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_val := Balance.EVENT_SENI_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var nrg_val := Balance.EVENT_SENI_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			await _handle_interactive_event(
				day_name,
				"Workshop Sanggar Seni",
				"Terdapat workshop pembuatan kerajinan dan tari daerah setempat.",
				"Seni Budaya +%d, Mood +%d" % [int(stat_val), int(mood_val)],
				"Energy %d" % int(nrg_val),
				"SeniBudaya", stat_val, nrg_val, mood_val,
				"workshop_seni"
			)
		3:
			await _show_event_warning("Kejutan Nasi Kotak Orang Tua!")
			await _show_event_dialogue("nasi_kotak")
			# Biang Onar: global positive events are stronger
			var energy_bonus := Balance.EVENT_NASI_KOTAK_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_bonus := Balance.EVENT_NASI_KOTAK_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var names: Array[String] = []
			for s in student_manager.students:
				# Route through apply_event_effects so quirks like Penyendiri apply correctly
				s.apply_event_effects("", 0.0, energy_bonus, mood_bonus)
				names.append(s.student_name)
			student_manager.record_event_result(day_name, "Nasi Kotak Berbagi", names, "Semua siswa mendapat Energy +%d dan Mood +%d" % [int(energy_bonus), int(mood_bonus)])
			await _animate_embedded_stat_updates(0.6)
			await get_tree().create_timer(0.8).timeout
		4:
			await _show_event_warning("Hujan Deras & Jalanan Licin!")
			await _show_event_dialogue("hujan")
			# Biang Onar: global negative events are worse
			var energy_penalty := Balance.EVENT_HUJAN_ENERGI * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var mood_penalty := Balance.EVENT_HUJAN_MOOD * (1.0 + biang_onar_scale if biang_onar_active else 1.0)
			var names: Array[String] = []
			for s in student_manager.students:
				# Route through apply_event_effects so quirks like Penyendiri apply correctly
				s.apply_event_effects("", 0.0, energy_penalty, mood_penalty)
				names.append(s.student_name)
			student_manager.record_event_result(day_name, "Kehujanan & Terpeleset", names, "Semua siswa mendapat Energy %d dan Mood %d" % [int(energy_penalty), int(mood_penalty)])
			await _animate_embedded_stat_updates(0.6)
			await get_tree().create_timer(0.8).timeout


func force_event(event_id: int) -> void:
	# Trigger a specific event immediately during simulation
	var day_name = DAYS[current_day] if current_day < DAYS.size() else "Senin"
	events_triggered_this_week += 1
	# Every student on the roster is present for an event, so
	# an event marks the whole roster as having participated.
	for s in GameState.approved_students:
		GameState.run_stats.record_event_student(int(s.get("id", -1)))
	await _run_event(event_id, day_name)
```

(d) `_handle_interactive_event`: add the parameter and the early return:

```gdscript
func _handle_interactive_event(
	day_name: String, title: String, description: String,
	benefit: String, cost: String, category: String,
	stat_boost: float, energy_cost: float, mood_boost: float,
	dialogue_key: String = ""
) -> void:
	await _show_event_warning(title)
	# Tolak skips the event: no picker, nothing applied or recorded. It still
	# counted toward the week's limit when it was rolled.
	var wants_in: bool = await _show_event_dialogue(dialogue_key)
	if not wants_in:
		return

	var dialog_scene = event_student_select_scene
```

(The rest of the function is unchanged.)

(e) Add `_show_event_dialogue()` directly after `_show_event_warning()`:

```gdscript
## Shows the EventDialogue for catalog `key` over the day and waits for it
## (2026-09-14 event-dialogue spec). Returns the player's answer: false only
## for Tolak. With no catalog entry, such as a new minigame without a line
## yet, there is nothing to show and it returns true.
func _show_event_dialogue(key: String) -> bool:
	if not EventDialogueCatalog.has_entry(key):
		return true
	var dialogue_scene = event_dialogue_scene
	if dialogue_scene == null:
		dialogue_scene = load("res://Scenes/SchoolSimulation/EventDialogue.tscn")
	if dialogue_scene == null:
		return true
	var e: Dictionary = EventDialogueCatalog.entry(key)
	var roster: Array = []
	if student_manager:
		roster = student_manager.students
	var featured: StudentData = EventDialogueCatalog.pick_featured(roster, e.get("category", ""))
	var day_name: String = DAYS[current_day] if current_day < DAYS.size() else ""
	var dialogue = dialogue_scene.instantiate()
	add_child(dialogue)
	dialogue.open(e, featured, GameState.minggu_ke, GameState.get_max_weeks(), day_name)
	var accepted: bool = await dialogue.closed
	dialogue.queue_free()
	return accepted
```

- [ ] **Step 4: Run to see them pass**

`test_run(suite="event_dialogue")`, `test_run(suite="event_warning")` and `test_run(suite="school_day")`. Expected: all pass. `event_warning` pins the warning captions and the three event titles; `school_day` pins the minigame launch path.
Also run `logs_read(source="editor")`. Expected: no parse errors in `SchoolDay.gd`.

- [ ] **Step 5: Commit**

```bash
git add Scripts/SchoolSimulation/SchoolDay.gd tests/test_event_dialogue.gd
git commit -m "feat(school-day): show the event dialogue before every minigame and event"
```

---

### Task 5: See it live, then write it down

**Files:**
- Modify: `CLAUDE.md` (the loop line, placeholder art, copy placeholders)
- Modify: `docs/superpowers/CHANGELOG.md` (a new top entry)

- [ ] **Step 1: Render each mode in the running game**

`project_run(mode="main", autosave=false)`, then poll `editor_state` until the game is live. In one `editor_manage(op="game_eval")`:

```gdscript
var d = load("res://Scenes/SchoolSimulation/EventDialogue.tscn").instantiate()
get_tree().root.add_child(d)
var s = StudentData.new()
s.student_name = "Thea"
s.specialty_category = "SeniBudaya"
s.splash_path = "res://Assets/Images/SplashArtMurid/splash_thea.png"
d.open(EventDialogueCatalog.entry("nasi_kotak"), s, 2, 6, "Senin")
d.tap()
return d.line_label.text
```

Then `editor_screenshot(source="game", max_resolution=0)`. Judge it **at full size** against `C:\Users\user\Downloads\mockup_eventdialogue.png`: calendar and banner at top, splash centred behind the box, white rounded box with bold dark text, and a blurred, bright school. Free it (`d.queue_free()`) and repeat for `"les_akademis"`, where one `tap()` must show Tolak and Terima, and for `"hujan"`, which must be sharp and blue with no splash.

- [ ] **Step 2: Drive the real path once**

In a `game_eval`:
1. Seed with DebugManager's *Seed Playtest State* function. Find its name with `grep -n "func _seed" Scripts/Debug/DebugManager.gd`.
2. Fill `GameState.day_schedules` for each roster id with `{"Senin": {"category": "Akademis"}, …}` for all five days.
3. `Transition.change_scene("res://Scenes/SchoolSimulation/SchoolDay.tscn")`.
4. Once SchoolDay is current, call `get_tree().current_scene.force_event(0)`.

Take a screenshot: expect the warning, then the Les dialogue. Click **Tolak**: read its `global_rect` with `game_manage(op="get_ui_elements", params={"root_path": "/root/SchoolDay", "max_depth": 6})`, send a `motion` event, then a `button` press and release at `global_x * original_width / 1080`. Confirm with `get_ui_elements` that no `EventStudentSelectDialog` appeared. Then `project_manage(op="stop")`.
If the seeded day loop gets in the way, Step 1 plus Task 4's source tests are the evidence; say so in the final report.

- [ ] **Step 3: Update CLAUDE.md**
- **Loop paragraph:** after "SchoolDay (simulate 5 days)", add one sentence: "Each minigame and random event opens with the sliding EventWarning, then an EventDialogue line (`EventDialogueCatalog`) — Tolak/Terima on the three pick-students events."
- **Generated placeholder art list:** add "the 2026-09-14 EventDialogue set: `Assets/Images/EventDialogue/splash_gurusenibudaya.png`, `hujan_background.png`, `calendar_badge.png`".
- **Copy placeholders:** add "every `line` in `EventDialogueCatalog.ENTRIES` is a draft".

- [ ] **Step 4: Add the CHANGELOG entry** at the top, under the intro, in the house style: a `## 2026-09-14 — EventDialogue: a line before every minigame and event` heading, then what was built, the two modes, the art sources, the single `_run_event()`, and the tap-counting fact.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md docs/superpowers/CHANGELOG.md
git commit -m "docs(event-dialogue): changelog, placeholder art and draft copy"
```

---

### Task 6: Full suite

- [ ] **Step 1: Run everything**

`test_run()` with no suite, with `Scenes/MainMenu/main_menu.tscn` open. Expected: all pass. Note the totals `<passed>/<total>`. If the bridge drops after the reply arrives, the results still count; restart the editor.

- [ ] **Step 2: Clean up what the run wrote**

`git status`. If `Assets/Audio/default_bus_layout.tres` changed, restore it with `git checkout -- Assets/Audio/default_bus_layout.tres`. If `Assets/Theme/kejartes_theme.tres` changed, diff it: a byte-identical rebake shows nothing, and anything else means Task 3's bake was stale, so commit the fresh bake.

- [ ] **Step 3: Update the suite count** in CLAUDE.md's Testing line, "N suites, M tests (2026-09-14)", from the run's totals. Then commit:

```bash
git add CLAUDE.md
git commit -m "docs: suite count after the event dialogue"
```
