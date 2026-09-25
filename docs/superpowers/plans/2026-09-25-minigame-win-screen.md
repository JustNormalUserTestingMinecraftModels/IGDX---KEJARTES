# Minigame Win Screen, Day Outfits and Icon Refresh — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A won minigame ends on a new win screen (speaker splash, line, stat count-up, three stars, LOBBY/LANJUT) over the live minigame; EventDialogue speakers sit where the mockup has them; Kamis/Jumat event screens dress students in batik/pramuka; the Lobby icons and every back arrow wear the delivered art.

**Architecture:** Icons and the back arrow are drop-replaced at their existing paths. `StudentSkins.day_splash_for` and `EventDialogueCatalog` (day-aware `splash_path_for`, `win_speaker_path`, `WIN_LINES`) own who is drawn. `MinigameWinScreen` (CanvasLayer 999, authored scene, `MinigameWinStat` template rows) is shown by `BaseMinigame._show_result_overlay` on a win; SchoolDay hands the minigame a `host_context` and a `result_reporter` Callable so stats are applied, once, before the screen opens, and reads `result_exit` to leave the week on LOBBY.

**Tech Stack:** Godot 4.6 GDScript, godot-ai MCP bridge (`test_run`, `scene_*`, `node_*`, `script_patch`, `game_manage`), McpTestSuite.

**Spec:** `docs/superpowers/specs/2026-09-25-minigame-win-screen-design.md`

## Global Constraints

- Worktree: `.claude/worktrees/minigame-win-screen`, branch `feat/minigame-win-screen`. Every bridge call passes `session_id=<WT>` — the worktree editor's id from Task 0. Never `session_activate`; never kill every Godot process.
- `Balance.gd` is not touched.
- No `theme_override_*` except layout constants (`separation`, `margin_*`). New looks are ThemeFactory variations, then a rebake.
- No visual built at runtime; no `.new(` for visuals in the new scripts.
- Every script: `##` file header, `##` line on every `@export` and `const` (`test_script_documentation`).
- Test suites are `@tool`, no test is a coroutine, new suites override `suite_name()`.
- Scene edits to EXISTING scenes go through the editor (`scene_open` → `node_set_property` → `scene_save`) and happen in Tasks 1–2 only, before any script is patched. New scenes are written as text and never `scene_save`d.
- After an outside edit to a `.gd`, do a no-op `script_patch` on that file before `test_run`.
- UI text Indonesian; commits Conventional (`type(scope): …`) ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, written to a file and committed with `git commit -F <file>` (plain git commands, no `&&` chains, no heredocs).
- Tall phones: every win-screen piece anchored to the bottom edge (anchors 0,1,1,1).

---

### Task 0: The worktree's editor

**Files:** none tracked.

- [ ] **Step 1: Seed the cache.** Copy `imported/`, `shader_cache/`, `uid_cache.bin`, `global_script_class_cache.cfg`, `scene_groups_cache.cfg` from the main checkout's `.godot/` (`../../../.godot/`) into the worktree's `.godot/` (skip `.godot/editor/`).
- [ ] **Step 2: Launch detached.** PowerShell: `Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine = '"<Godot exe>" --path "<worktree abs path>" -e'}` (the exe path is in memory note `godot-editor-restarts-are-authorized`).
- [ ] **Step 3: Find its session.** `session_manage(op="list")` until a session whose `project_path` is the worktree shows `ready`; record its id as `<WT>`.
- [ ] **Step 4: Baseline.** `test_run(suite="event_dialogue", session_id=<WT>)` and `test_run(suite="minigame_single_result", session_id=<WT>)` — Expected: all pass. If not, stop and report.
- [ ] **Step 5:** `git status --short` — revert `Assets/Audio/default_bus_layout.tres` and any `*.png.import` the boot rewrote (`git checkout -- <file>`), only after confirming the diff is the known etc2/bus churn.

---

### Task 1: Icons and back arrow, drop-replaced

**Files:**
- Replace: `Assets/Images/Achievements/achievement_button.png`, `Assets/Images/UI/setting.png`, `Assets/Images/UI/skin_switch.png`, `Assets/Images/UI/icon_daily_login.png`, `Assets/Images/UI/Nav/return_button.png`
- Modify: `Scenes/Lobby/loby.tscn` (`Safe/UI/BottomBar/DailyLogin.stretch_mode` 0 → 5)
- Create: `tests/test_ui_icon_refresh.gd`

**Interfaces:** Produces nothing code-facing; every existing scene keeps its path.

- [ ] **Step 1: Write the failing test** — `tests/test_ui_icon_refresh.gd`:

```gdscript
@tool
extends McpTestSuite

## The 2026-09-25 icon refresh (spec:
## docs/superpowers/specs/2026-09-25-minigame-win-screen-design.md, sections 1
## and 5): the four Lobby icons and the canonical back arrow were replaced in
## place with the owner's delivered art. Each file is pinned by the MD5 of the
## delivered original, so a lost copy or a stale file fails here rather than
## on a phone. A future art swap updates the hash on purpose.
##
## Must be @tool, and no test here may be a coroutine.

## res:// path -> MD5 of the file delivered in Downloads on 2026-09-25.
const DELIVERED := {
	"res://Assets/Images/Achievements/achievement_button.png": "8bdcd0b22d81846bb2544a136ca1fac9",
	"res://Assets/Images/UI/setting.png": "06020ee18ea4d3bb00ea5fa4ce61504d",
	"res://Assets/Images/UI/skin_switch.png": "0f777eb6e443a0e5bdee3bdfca9434ac",
	"res://Assets/Images/UI/icon_daily_login.png": "6a5ab7bf6da4257bbd5986ff43c03320",
	"res://Assets/Images/UI/Nav/return_button.png": "7891144f317b79d2d93bf52343e4bd5a",
}
const _LOBBY := "res://Scenes/Lobby/loby.tscn"


func suite_name() -> String:
	return "ui_icon_refresh"


func test_every_delivered_icon_is_in_place() -> void:
	for path in DELIVERED:
		assert_eq(FileAccess.get_md5(path), DELIVERED[path],
			"%s must be the art delivered on 2026-09-25" % path)


## The new calendar is 322x359; drawn with stretch_mode 0 it squashed into the
## 96x96 box. Its three siblings already keep aspect.
func test_the_daily_login_button_keeps_its_aspect() -> void:
	var lobby := (load(_LOBBY) as PackedScene).instantiate()
	track(lobby)
	for path in ["Safe/UI/BottomBar/DailyLogin", "Safe/UI/BottomBar/SettingsButton",
			"Safe/UI/BottomBar/AchievementButton", "Safe/UI/BottomBar/SkinSwitchButton"]:
		var btn := lobby.get_node_or_null(path) as TextureButton
		assert_true(btn != null, path + " must exist")
		if btn != null:
			assert_eq(btn.stretch_mode, TextureButton.STRETCH_KEEP_ASPECT_CENTERED,
				path + " must keep its icon's aspect")
```

- [ ] **Step 2: Run it red.** No-op `script_patch` on `tests/test_ui_icon_refresh.gd`, then `Run: test_run(suite="ui_icon_refresh", session_id=<WT>)`. Expected: FAIL — five MD5 mismatches and DailyLogin's stretch mode.
- [ ] **Step 3: Copy the art.** From `C:/Users/user/Downloads/`: `achievement_icon.png` → `Assets/Images/Achievements/achievement_button.png`; `settings_icon.png` → `Assets/Images/UI/setting.png`; `skinselect_icon.png` → `Assets/Images/UI/skin_switch.png`; `dailylogin_icon.png` → `Assets/Images/UI/icon_daily_login.png`; `return_button.png` → `Assets/Images/UI/Nav/return_button.png`. Then `filesystem_manage(op="scan", session_id=<WT>)` and `filesystem_manage(op="reimport", …)` for those five paths.
- [ ] **Step 4: The DailyLogin stretch.** `scene_open("res://Scenes/Lobby/loby.tscn")`, `node_set_property(path="Safe/UI/BottomBar/DailyLogin", property="stretch_mode", value=5)`, `scene_save`. Then `git diff -- Scenes/Lobby/loby.tscn` shows only `stretch_mode = 5` (a default-valued line may simply vanish or appear); `git diff HEAD --stat -- '*.gd'` lists only `tests/test_ui_icon_refresh.gd`.
- [ ] **Step 5: Run green.** `Run: test_run(suite="ui_icon_refresh", session_id=<WT>)`, then `back_controls`, `lobby`, `lobby_skins`, `achievement_screen`, `main_menu`, `shorten`, `book_clock_phases`, `texture_mipmaps`. Expected: all PASS.
- [ ] **Step 6: Each `.import` kept its `uid=` and `mipmaps/generate=true`** (`git diff -- '*.png.import'`: only the `dest_files`/hash lines may move).
- [ ] **Step 7: Commit** `feat(ui): the delivered Lobby icons and back arrow` — the five PNGs, their `.import`s if changed, `loby.tscn`, `tests/test_ui_icon_refresh.gd(.uid)`.

---

### Task 2: EventDialogue speakers lowered to the mockup

**Files:**
- Modify: `Scenes/SchoolSimulation/EventDialogue.tscn` (`Splash`)
- Test: `tests/test_event_dialogue.gd`

**Interfaces:** none new.

- [ ] **Step 1: Write the failing tests** — append to `tests/test_event_dialogue.gd`:

```gdscript
# ── placement (2026-09-25 minigame-win-screen spec, section 2) ──────────────

## Matched against eventdialogue_mockup.jpeg: the splash is drawn 1:1, 276 px
## lower and 30 px left of centre, as a 1080x1920 box hung off the bottom edge
## so it stays locked to the bottom-anchored dialogue box on a tall phone.
func test_the_speaker_hangs_off_the_bottom_edge_where_the_mockup_has_them() -> void:
	var d = (load(_SCENE) as PackedScene).instantiate()
	track(d)
	var s := d.get_node("Splash") as TextureRect
	assert_eq(Vector4(s.anchor_left, s.anchor_top, s.anchor_right, s.anchor_bottom),
		Vector4(0, 1, 1, 1), "the splash hangs off the bottom edge")
	assert_eq(Vector4(s.offset_left, s.offset_top, s.offset_right, s.offset_bottom),
		Vector4(-30, -1644, -30, 276), "1080x1920, shifted (-30, +276)")
	assert_eq(s.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)


## At 1080x1920 the art's top-left lands on (-30, 276); at 1080x2400 it keeps
## the same distance from the bottom edge.
func test_the_speaker_keeps_its_place_above_the_box_on_a_tall_phone() -> void:
	for screen in [Vector2(1080, 1920), Vector2(1080, 2400)]:
		var frame := track(preload("res://tests/layout_frame.gd").stand_up(_SCENE, screen)) as Control
		var s := frame.get_child(0).get_node("Splash") as TextureRect
		var r := s.get_global_rect()
		assert_eq(r.size, Vector2(1080, 1920), "the box is the art's own size at %s" % screen)
		assert_eq(r.position, Vector2(-30, screen.y - 1920 + 276), "placed from the bottom at %s" % screen)
```

- [ ] **Step 2: Run red.** No-op `script_patch` on the test file; `Run: test_run(suite="event_dialogue", session_id=<WT>)`. Expected: the two new tests FAIL (anchors 0,0,1,1).
- [ ] **Step 3: Re-anchor.** `scene_open("res://Scenes/SchoolSimulation/EventDialogue.tscn")`; on `Splash` set `layout_mode=1` then `anchor_left=0`, `anchor_top=1`, `anchor_right=1`, `anchor_bottom=1`, `offset_left=-30`, `offset_top=-1644`, `offset_right=-30`, `offset_bottom=276` (one `batch_execute` of `set_property`; numbers unquoted); `scene_save`.
- [ ] **Step 4: Diff.** `git diff -- Scenes/SchoolSimulation/EventDialogue.tscn` touches only `Splash`'s anchor/offset lines (and `anchors_preset`). `git diff HEAD --stat -- '*.gd'` lists only `tests/test_event_dialogue.gd`.
- [ ] **Step 5: Run green.** `Run: test_run(suite="event_dialogue", session_id=<WT>)`, `illustration_ao`, `paper_shadow`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(event-dialogue): lower every speaker to the mockup's place`.

---

### Task 3: Day outfit art and `StudentSkins.day_splash_for`

**Files:**
- Create: `Assets/Images/SplashArtMurid/Seragam/splash_<name>_batik.png` and `…_pramuka.png` for andi, citra, doni, marcel, shinta, thea (12, plus their `.import`)
- Modify: `Scripts/Skins/StudentSkins.gd`
- Test: `tests/test_student_skins.gd`

**Interfaces:**
- Produces: `StudentSkins.DAY_OUTFITS: Dictionary` (`{"Kamis": "batik", "Jumat": "pramuka"}`), `StudentSkins.OUTFIT_DIR: String`, `static func day_outfit_path(student_name: String, outfit: String) -> String`, `static func day_splash_for(student_name: String, day_name: String) -> String` ("" off-day or missing file).

- [ ] **Step 1: Download (approved at the plan gate).** Load the Claude in Chrome tools; for each id below navigate a tab to `https://drive.usercontent.google.com/download?id=<id>&export=download`; files land in `C:/Users/user/Downloads/` under their Drive titles. Match each by byte size:

| Title | id | bytes |
|---|---|---|
| Andi_batik | 1ZycXRxv5kfZLxJOhrUDF26CNsuAqx7K0 | 651869 |
| Citra_batik | 1ISR9m3m0elSPbtquWhVf4j2Ze_qKMbjj | 743925 |
| Doni_batik | 14HMkANDNWkKKAB0V7wgDD8JomvVnoj4Q | 716352 |
| Marcel_batik | 1u9nm0cs8vBDV7fTxurnhvh4M1zJF31mT | 597174 |
| Shinta_batik | 1KfEukOEQyVBGM-dXejQz3O1ol5gQ4wNO | 634316 |
| Thea_batik | 125CTIYb2Dz8ZRnunESsfk-VgTXa0tq5m | 762504 |
| Andi_pramuka | 1KjJrj3DsF0d_WnBqOfI1NeYi3iSNdiSa | 294689 |
| Citra_pramuka | 12mRHm6_DVNNzxFBtt68R-cyQbROHvyyl | 276628 |
| Doni_pramuka | 1N7zQuTjF2gu29FuAshcntCXnXScNXSQq | 282500 |
| Marcel_pramuka | 1eMVB-FFFrfipm4ZrXKgh4QPnM4ZHhxOX | 292977 |
| Shinta_pramuka | 1z5GiFVmgw_a4nZhuk4t30_ACDVmyHb70 | 307515 |
| Thea_pramuka | 1RR--dByL7xkCOTY4juDv1Ik8o1x4pjaY | 309436 |

- [ ] **Step 2: Verify registration** (Python/PIL, scratchpad): each is 1080×1920 RGBA and the first alpha>128 row is within ±40 px of its default splash's (andi 34, citra 83, doni 143, marcel 60, shinta 130, thea 104). Draw a 12-up contact sheet at 1/4 scale and look at it once. Any file off → stop and report (do not import it).
- [ ] **Step 3: Write the failing tests** — append to `tests/test_student_skins.gd`:

```gdscript
# ── day outfits (2026-09-25 minigame-win-screen spec, section 6) ────────────

func test_kamis_is_batik_and_jumat_is_pramuka() -> void:
	for n in StudentSkins.NAMES:
		var lower: String = n.to_lower()
		assert_eq(StudentSkins.day_splash_for(n, "Kamis"),
			"res://Assets/Images/SplashArtMurid/Seragam/splash_%s_batik.png" % lower, n + " on Kamis")
		assert_eq(StudentSkins.day_splash_for(n, "Jumat"),
			"res://Assets/Images/SplashArtMurid/Seragam/splash_%s_pramuka.png" % lower, n + " on Jumat")


func test_the_other_days_and_strangers_have_no_outfit() -> void:
	for day in ["Senin", "Selasa", "Rabu", "", "Sabtu"]:
		assert_eq(StudentSkins.day_splash_for("Thea", day), "", "no outfit on '%s'" % day)
	assert_eq(StudentSkins.day_splash_for("Bejo", "Kamis"), "", "only the six have outfits")


## Same canvas and import as the default splashes, or the outfit would jump
## on screen or ship uncompressed.
func test_every_outfit_is_a_splash_canvas_imported_like_the_default() -> void:
	for n in StudentSkins.NAMES:
		for outfit in StudentSkins.DAY_OUTFITS.values():
			var path := StudentSkins.day_outfit_path(n, outfit)
			assert_true(ResourceLoader.exists(path), path + " must be imported")
			var tex := load(path) as Texture2D
			if tex != null:
				assert_eq(tex.get_size(), Vector2(1080, 1920), path + " is a 1080x1920 splash canvas")
			var cfg := ConfigFile.new()
			assert_eq(cfg.load(path + ".import"), OK, path + ".import must exist")
			assert_eq(cfg.get_value("params", "compress/mode"), 2, path + " is VRAM-compressed like splash_thea")
			assert_eq(cfg.get_value("params", "mipmaps/generate"), true, path + " carries mipmaps like splash_thea")
```

- [ ] **Step 4: Run red.** No-op `script_patch` on the test; `Run: test_run(suite="student_skins", session_id=<WT>)`. Expected: FAIL — `day_splash_for` not found.
- [ ] **Step 5: Import.** Copy each Downloads file to `Assets/Images/SplashArtMurid/Seragam/splash_<lower name>_<outfit>.png`; `filesystem_manage(op="scan")`. Then in each new `.import` set `[params] compress/mode=2` and `mipmaps/generate=true` (match `splash_thea.png.import`) and `filesystem_manage(op="reimport", paths=[the 12])`.
- [ ] **Step 6: Implement** — add to `Scripts/Skins/StudentSkins.gd` after `FALLBACK_BUST_CENTER`:

```gdscript
## The outfit every student wears on a school day, on the two event screens
## that draw the full-body splash: EventDialogue and the minigame win screen
## (2026-09-25 spec). A day not listed keeps the student's own look. On these
## days the outfit wins over an equipped skin there, as a uniform day would;
## the bust crops (avatar strip, day summary, event picker) keep the skin.
const DAY_OUTFITS: Dictionary = {"Kamis": "batik", "Jumat": "pramuka"}
## Where the day outfits live, named splash_<name>_<outfit>.png.
const OUTFIT_DIR := "res://Assets/Images/SplashArtMurid/Seragam/"
```

and after `bust_center`:

```gdscript
## The path one day outfit's splash would live at.
static func day_outfit_path(student_name: String, outfit: String) -> String:
	return OUTFIT_DIR + "splash_%s_%s.png" % [student_name.to_lower(), outfit]


## The splash `student_name` wears on `day_name`'s event screens, or "" on a
## day without an outfit, for a name outside NAMES, or when the file is gone.
static func day_splash_for(student_name: String, day_name: String) -> String:
	var outfit: String = DAY_OUTFITS.get(day_name, "")
	if outfit == "" or not NAMES.has(student_name):
		return ""
	var path := day_outfit_path(student_name, outfit)
	return path if ResourceLoader.exists(path) else ""
```

- [ ] **Step 7: Run green.** No-op `script_patch` on `StudentSkins.gd`; `Run: test_run(suite="student_skins", session_id=<WT>)`, `skin_select`, `lobby_skins`. Expected: PASS.
- [ ] **Step 8: Commit** `feat(skins): batik on Kamis, pramuka on Jumat` — 12 PNGs + `.import`s, `StudentSkins.gd`, test.

---

### Task 4: Day-aware speakers and the win speaker rule

**Files:**
- Modify: `Scripts/SchoolSimulation/EventDialogueCatalog.gd`, `Scripts/SchoolSimulation/EventDialogue.gd:59`
- Test: `tests/test_event_dialogue.gd`

**Interfaces:**
- Consumes: `StudentSkins.day_splash_for(student_name, day_name) -> String`.
- Produces: `EventDialogueCatalog.WIN_TEACHER_CHANCE: float` (0.5), `WIN_LINE_STUDENT: String`, `WIN_LINES: Dictionary` (teacher splash path → line), `WIN_TEACHER: Dictionary` (category → teacher splash path), `static func student_splash(featured: StudentData, day_name: String) -> String`, `static func splash_path_for(e: Dictionary, featured: StudentData, day_name: String = "") -> String`, `static func win_speaker_path(category: String, featured: StudentData, day_name: String, roll: float) -> String`, `static func win_line_for(speaker_path: String) -> String`.

- [ ] **Step 1: Write the failing tests** — append to `tests/test_event_dialogue.gd` (and change `_dialogue` to take a day):

```gdscript
func _dialogue(key: String, featured: StudentData = null, day: String = "Senin"):
	var d = (load(_SCENE) as PackedScene).instantiate()
	d.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(d)
	track(d)
	d.open(EventDialogueCatalog.entry(key), featured, 2, 6, day)
	return d
```

```gdscript
# ── day outfits and the win speaker (2026-09-25 spec, sections 3 and 6) ────

const _BATIK_THEA := "res://Assets/Images/SplashArtMurid/Seragam/splash_thea_batik.png"
const _PRAMUKA_THEA := "res://Assets/Images/SplashArtMurid/Seragam/splash_thea_pramuka.png"


func test_a_student_speaker_wears_the_day_outfit() -> void:
	var thea := _student("Thea", "SeniBudaya", _THEA_SPLASH)
	var e := EventDialogueCatalog.entry("BuatBatik")
	assert_eq(EventDialogueCatalog.splash_path_for(e, thea, "Kamis"), _BATIK_THEA)
	assert_eq(EventDialogueCatalog.splash_path_for(e, thea, "Jumat"), _PRAMUKA_THEA)
	assert_eq(EventDialogueCatalog.splash_path_for(e, thea, "Rabu"), _THEA_SPLASH)
	assert_eq(EventDialogueCatalog.splash_path_for(e, thea), _THEA_SPLASH, "no day, own look")


func test_teachers_and_mom_keep_their_clothes_on_outfit_days() -> void:
	var thea := _student("Thea", "SeniBudaya", _THEA_SPLASH)
	for key in ["nasi_kotak", "MainBola", "workshop_seni"]:
		var e := EventDialogueCatalog.entry(key)
		assert_eq(EventDialogueCatalog.splash_path_for(e, thea, "Kamis"), e["speaker"], key)


func test_the_screen_dresses_for_the_day() -> void:
	var d = _dialogue("BuatBatik", _student("Thea", "SeniBudaya", _THEA_SPLASH), "Kamis")
	assert_eq(d.splash.texture.resource_path, _BATIK_THEA)


func test_akademis_is_thanked_by_the_student() -> void:
	var thea := _student("Thea", "Akademis", _THEA_SPLASH)
	for roll in [0.0, 0.49, 0.99]:
		assert_eq(EventDialogueCatalog.win_speaker_path("Akademis", thea, "Senin", roll), _THEA_SPLASH)
	assert_eq(EventDialogueCatalog.win_speaker_path("Akademis", thea, "Jumat", 0.0), _PRAMUKA_THEA)
	assert_eq(EventDialogueCatalog.win_speaker_path("Akademis", null, "Senin", 0.0), "",
		"an empty roster has nobody to show")


func test_seni_and_olahraga_are_the_teacher_or_the_student() -> void:
	var thea := _student("Thea", "SeniBudaya", _THEA_SPLASH)
	var below := EventDialogueCatalog.WIN_TEACHER_CHANCE - 0.01
	var above := EventDialogueCatalog.WIN_TEACHER_CHANCE + 0.01
	assert_eq(EventDialogueCatalog.win_speaker_path("SeniBudaya", thea, "Senin", below), EventDialogueCatalog.SPLASH_GURU_SENI)
	assert_eq(EventDialogueCatalog.win_speaker_path("SeniBudaya", thea, "Senin", above), _THEA_SPLASH)
	assert_eq(EventDialogueCatalog.win_speaker_path("Olahraga", thea, "Senin", below), EventDialogueCatalog.SPLASH_GURU_PENJAS)
	assert_eq(EventDialogueCatalog.win_speaker_path("Olahraga", thea, "Kamis", above), _BATIK_THEA)
	assert_eq(EventDialogueCatalog.win_speaker_path("Olahraga", null, "Senin", above), EventDialogueCatalog.SPLASH_GURU_PENJAS,
		"with nobody on the roster the teacher always speaks")


func test_each_speaker_has_its_own_thanks() -> void:
	assert_eq(EventDialogueCatalog.win_line_for(_THEA_SPLASH), "Terima kasih, Guru!")
	assert_eq(EventDialogueCatalog.win_line_for(""), "Terima kasih, Guru!")
	assert_eq(EventDialogueCatalog.win_line_for(EventDialogueCatalog.SPLASH_GURU_PENJAS), "Kerja bagus! Latihannya berhasil.")
	assert_eq(EventDialogueCatalog.win_line_for(EventDialogueCatalog.SPLASH_GURU_SENI),
		"Indah sekali! Terima kasih sudah membimbing mereka.")
```

- [ ] **Step 2: Run red.** No-op `script_patch` on the test; `Run: test_run(suite="event_dialogue", session_id=<WT>)`. Expected: new tests FAIL (unknown functions / wrong arity).
- [ ] **Step 3: Implement** in `EventDialogueCatalog.gd` — after `NAME_FALLBACK`:

```gdscript
## Chance a won SeniBudaya or Olahraga minigame is thanked by that subject's
## teacher rather than a student (2026-09-25 win-screen spec).
const WIN_TEACHER_CHANCE := 0.5
## What a student says on the win screen. A draft for the owner's writer.
const WIN_LINE_STUDENT := "Terima kasih, Guru!"
## Each teacher's own thanks, keyed by their splash. Drafts for the writer.
const WIN_LINES := {
	SPLASH_GURU_PENJAS: "Kerja bagus! Latihannya berhasil.",
	SPLASH_GURU_SENI: "Indah sekali! Terima kasih sudah membimbing mereka.",
}
## The teacher who may thank the player for each category's win.
const WIN_TEACHER := {"SeniBudaya": SPLASH_GURU_SENI, "Olahraga": SPLASH_GURU_PENJAS}
```

replace `splash_path_for` with:

```gdscript
## The featured student's splash on `day_name`: the day outfit on Kamis and
## Jumat, their own (equipped) look otherwise, "" for nobody.
static func student_splash(featured: StudentData, day_name: String) -> String:
	if featured == null:
		return ""
	var outfit := StudentSkins.day_splash_for(featured.student_name, day_name)
	return outfit if outfit != "" else featured.splash_path


## The speaker's texture path: the featured student's splash (dressed for
## `day_name`) for SPEAKER_STUDENT, the fixed art otherwise, "" for none.
static func splash_path_for(e: Dictionary, featured: StudentData, day_name: String = "") -> String:
	var speaker: String = e.get("speaker", "")
	if speaker == SPEAKER_STUDENT:
		return student_splash(featured, day_name)
	return speaker


## Who thanks the player on the win screen. Akademis: the featured student.
## SeniBudaya / Olahraga: the subject's teacher when `roll` (0-1) falls under
## WIN_TEACHER_CHANCE or nobody is featured, else the featured student.
static func win_speaker_path(category: String, featured: StudentData, day_name: String, roll: float) -> String:
	var teacher: String = WIN_TEACHER.get(category, "")
	if teacher != "" and (featured == null or roll < WIN_TEACHER_CHANCE):
		return teacher
	return student_splash(featured, day_name)


## The win screen's line for a speaker: the teacher's own, else a student's.
static func win_line_for(speaker_path: String) -> String:
	return WIN_LINES.get(speaker_path, WIN_LINE_STUDENT)
```

and in `EventDialogue.gd:59`: `var splash_path: String = EventDialogueCatalog.splash_path_for(e, featured, day_name)`.

- [ ] **Step 4: Run green.** No-op `script_patch` on both scripts; `Run: test_run(suite="event_dialogue", session_id=<WT>)`. Expected: PASS (the old `test_student_speakers_wear_their_own_splash` still passes: `day_name` defaults to "").
- [ ] **Step 5: Commit** `feat(event-dialogue): dress speakers for the day, pick the win speaker`.

---

### Task 5: Win-screen theme

**Files:**
- Modify: `Scripts/Design/DesignTokens.gd` (after `event_warning_caption_outline`), `Scripts/Design/ThemeFactory.gd`, `Assets/Theme/kejartes_theme.tres` (rebake)
- Modify: `tests/test_theme_factory.gd` (`DISPLAY_ROSTER`)
- Create: `tests/test_minigame_win_screen.gd`

**Interfaces:**
- Produces: tokens `minigame_win_card: Color`, `minigame_win_card_radius: int`, `minigame_win_stat_size: int`; variations `MinigameWinCard` (PanelContainer), `MinigameWinBubble` (PanelContainer), `MinigameWinLine` (Label), `MinigameWinStatLabel` (Label).

- [ ] **Step 1: Write the failing tests.** Add `"MinigameWinLine", "MinigameWinStatLabel",` to `DISPLAY_ROSTER` in `tests/test_theme_factory.gd` under a `# 2026-09-25 minigame win screen: the bubble line and the stat numbers.` comment. Create `tests/test_minigame_win_screen.gd`:

```gdscript
@tool
extends McpTestSuite

## The minigame win screen (spec:
## docs/superpowers/specs/2026-09-25-minigame-win-screen-design.md): its theme,
## its stat rows, its authored scene, its bottom-hung layout on a tall phone,
## its reveal order and its two exits.
##
## Must be @tool, and no test here may be a coroutine.

const _THEME := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "minigame_win_screen"


func _baked() -> Theme:
	return ResourceLoader.load(_THEME, "Theme", ResourceLoader.CACHE_MODE_IGNORE) as Theme


# ── theme ────────────────────────────────────────────────────────────────────

func test_the_bake_carries_the_four_variations() -> void:
	var theme := _baked()
	var want := {
		"MinigameWinCard": &"PanelContainer", "MinigameWinBubble": &"PanelContainer",
		"MinigameWinLine": &"Label", "MinigameWinStatLabel": &"Label",
	}
	for v in want:
		assert_eq(theme.get_type_variation_base(v), want[v], v + " must be baked on " + want[v])


func test_the_card_is_the_mockup_cream_with_a_square_bottom() -> void:
	var tokens := DesignTokens.load_default()
	var card := _baked().get_stylebox("panel", "MinigameWinCard") as StyleBoxFlat
	assert_true(card != null, "MinigameWinCard is a flat box")
	if card == null:
		return
	assert_eq(card.bg_color, tokens.minigame_win_card)
	assert_eq(card.corner_radius_top_left, tokens.minigame_win_card_radius)
	assert_eq(card.corner_radius_top_right, tokens.minigame_win_card_radius)
	assert_eq(card.corner_radius_bottom_left, 0, "the card meets the screen's bottom edge")
	assert_eq(card.corner_radius_bottom_right, 0)


## chat_bubble_tail.svg is filled #FFFDF8; the bubble must be the same white.
func test_the_bubble_is_the_tail_s_white() -> void:
	var bubble := _baked().get_stylebox("panel", "MinigameWinBubble") as StyleBoxFlat
	assert_true(bubble != null)
	if bubble != null:
		assert_eq(bubble.bg_color, DesignTokens.load_default().surface_card)
		assert_eq(bubble.bg_color, Color("FFFDF8"), "the tail svg's own fill")


func test_the_stat_numbers_are_white_with_the_day_summary_rim() -> void:
	var tokens := DesignTokens.load_default()
	var theme := _baked()
	assert_eq(theme.get_font_size("font_size", "MinigameWinStatLabel"), tokens.minigame_win_stat_size)
	assert_eq(theme.get_color("font_color", "MinigameWinStatLabel"), Color.WHITE)
	assert_eq(theme.get_color("font_outline_color", "MinigameWinStatLabel"), tokens.day_glyph_outline)
	assert_eq(theme.get_constant("outline_size", "MinigameWinStatLabel"), tokens.text_outline_size)
```

- [ ] **Step 2: Run red.** No-op `script_patch` on both tests; `Run: test_run(suite="minigame_win_screen", session_id=<WT>)` and `theme_factory`. Expected: FAIL (variations and tokens absent).
- [ ] **Step 3: Tokens** — insert after `event_warning_caption_outline` in `DesignTokens.gd`:

```gdscript

## Minigame win screen (2026-09-25, minigamewinscreen_mockup.jpeg).
## The card's fill: the mockup card's mid-tone. Its top-to-bottom gradient is
## dropped for one flat fill.
@export var minigame_win_card: Color = Color("E8EDCD")
## Radius of the card's two top corners; its bottom meets the screen edge.
@export var minigame_win_card_radius: int = 72
## Font size of the win screen's "+8" / "-5" stat numbers, off the mockup.
@export var minigame_win_stat_size: int = 96
```

- [ ] **Step 4: Variations** — in `ThemeFactory.build`, add `_build_minigame_win(theme, tokens)` after `_build_student_chat(theme, tokens)`; add the builder after `_build_student_chat`:

```gdscript
## The minigame win screen (2026-09-25 spec, minigamewinscreen_mockup.jpeg):
## the card that rises from the bottom edge, the speaker's bubble, its line
## and the stat numbers. The bubble is surface_card, the colour
## chat_bubble_tail.svg is filled with, so the tail joins it without a seam.
## The two labels are on the display face (DISPLAY_ROSTER).
static func _build_minigame_win(theme: Theme, tokens: DesignTokens) -> void:
	theme.add_type("MinigameWinCard")
	theme.set_type_variation("MinigameWinCard", "PanelContainer")
	var card := StyleBoxFlat.new()
	card.bg_color = tokens.minigame_win_card
	card.corner_radius_top_left = tokens.minigame_win_card_radius
	card.corner_radius_top_right = tokens.minigame_win_card_radius
	card.content_margin_left = tokens.space_xl
	card.content_margin_right = tokens.space_xl
	card.content_margin_top = tokens.space_md
	card.content_margin_bottom = tokens.space_xl
	theme.set_stylebox("panel", "MinigameWinCard", card)

	theme.add_type("MinigameWinBubble")
	theme.set_type_variation("MinigameWinBubble", "PanelContainer")
	var bubble := StyleBoxFlat.new()
	bubble.bg_color = tokens.surface_card
	bubble.set_corner_radius_all(STUDENT_CHAT_BUBBLE_RADIUS)
	bubble.content_margin_left = tokens.space_xl
	bubble.content_margin_right = tokens.space_xl
	bubble.content_margin_top = tokens.space_md
	bubble.content_margin_bottom = tokens.space_md
	theme.set_stylebox("panel", "MinigameWinBubble", bubble)

	theme.add_type("MinigameWinLine")
	theme.set_type_variation("MinigameWinLine", "Label")
	theme.set_font_size("font_size", "MinigameWinLine", tokens.font_h2)
	theme.set_color("font_color", "MinigameWinLine", tokens.text_primary)
	if tokens.font_display != null:
		theme.set_font("font", "MinigameWinLine", tokens.font_display)

	theme.add_type("MinigameWinStatLabel")
	theme.set_type_variation("MinigameWinStatLabel", "Label")
	theme.set_font_size("font_size", "MinigameWinStatLabel", tokens.minigame_win_stat_size)
	theme.set_color("font_color", "MinigameWinStatLabel", Color.WHITE)
	theme.set_constant("outline_size", "MinigameWinStatLabel", tokens.text_outline_size)
	theme.set_color("font_outline_color", "MinigameWinStatLabel", tokens.day_glyph_outline)
	if tokens.font_display != null:
		theme.set_font("font", "MinigameWinStatLabel", tokens.font_display)
```

- [ ] **Step 5: Restart the worktree editor** (new Resource `@export`s need it): `editor_manage(op="quit", session_id=<WT>)` (or stop its PID after checking the CommandLine), relaunch as in Task 0 Step 2, re-list for the new `<WT>`.
- [ ] **Step 6: Rebake alone.** `Run: test_run(suite="theme_rebake", session_id=<WT>)`. Then `git diff --stat -- Assets/Theme/kejartes_theme.tres` and read the diff: it adds the four types (and their StyleBoxFlats); if unrelated styles changed, quit the editor, `git checkout -- Assets/Theme/kejartes_theme.tres`, relaunch, rebake again.
- [ ] **Step 7: Restart the editor again** (memory: a cached theme after a rebake can be written back stale), then `Run: test_run(suite="minigame_win_screen", session_id=<WT>)`, `theme_factory`, `theme_rebake`, `script_documentation`. Expected: PASS.
- [ ] **Step 8: Commit** `feat(theme): the minigame win screen's card, bubble and numbers`.

---

### Task 6: `MinigameWinStat`, the stat row template

**Files:**
- Create: `Scenes/Minigames/UI/MinigameWinStat.tscn`, `Scripts/Minigames/UI/MinigameWinStat.gd`
- Test: `tests/test_minigame_win_screen.gd`

**Interfaces:**
- Consumes: `DaySummaryStatRow.shows_chevron(delta: float) -> bool`, `Juice.pop_in`, `Juice.count_up_formatted`.
- Produces: `class_name MinigameWinStat extends HBoxContainer`; `static func format_delta(d: float) -> String`; `func set_stat(tex: Texture2D, delta: float) -> void`; `func reveal(count_time: float) -> void` (coroutine); nodes `IconBox` (Control), `IconBox/Icon`, `IconBox/Chevron`, `Value`.

- [ ] **Step 1: Write the failing tests** — append to `tests/test_minigame_win_screen.gd`:

```gdscript
# ── the stat row ─────────────────────────────────────────────────────────────

const _STAT := "res://Scenes/Minigames/UI/MinigameWinStat.tscn"
const _ENERGY_ICON := "res://Assets/Images/StudentCard/stat_energy.png"


func _chip() -> MinigameWinStat:
	var c := (load(_STAT) as PackedScene).instantiate() as MinigameWinStat
	c.theme = load(_THEME)
	Engine.get_main_loop().root.add_child(c)
	track(c)
	return c


func test_a_delta_carries_its_sign() -> void:
	assert_eq(MinigameWinStat.format_delta(8.0), "+8")
	assert_eq(MinigameWinStat.format_delta(7.6), "+8", "rounded, not truncated")
	assert_eq(MinigameWinStat.format_delta(-5.0), "-5")
	assert_eq(MinigameWinStat.format_delta(0.0), "+0")


## The chevron art points up and has no down variant (DaySummaryStatRow's rule).
func test_the_chevron_shows_only_on_a_gain() -> void:
	var c := _chip()
	c.set_stat(load(_ENERGY_ICON), -5.0)
	assert_false(c.chevron.visible, "an energy cost gets no up arrow")
	assert_eq(c.value.text, "-5")
	c.set_stat(DaySummaryStatRow.ICON_FOR["akademis"], 8.0)
	assert_true(c.chevron.visible, "a skill gain gets the gold chevron")
	assert_eq(c.icon.texture, DaySummaryStatRow.ICON_FOR["akademis"])
	assert_eq(c.value.text, "+8")


func test_the_row_is_authored() -> void:
	var c := _chip()
	assert_eq(c.value.theme_type_variation, &"MinigameWinStatLabel")
	assert_eq(c.chevron.texture.resource_path, "res://Assets/Images/DaySummary/icon_chevron_up.png")
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameWinStat.gd")
	assert_false(src.contains(".new("), "the row is authored, never built")
```

- [ ] **Step 2: Run red.** No-op `script_patch` on the test; `Run: test_run(suite="minigame_win_screen", session_id=<WT>)`. Expected: FAIL (scene/class missing).
- [ ] **Step 3: Script** — `Scripts/Minigames/UI/MinigameWinStat.gd`:

```gdscript
@tool
class_name MinigameWinStat
extends HBoxContainer

## One stat on the minigame win screen (MinigameWinStat.tscn; 2026-09-25
## spec): the stat's icon with the gold chevron over its corner on a gain, and
## the signed number beside it. set_stat() fills it; reveal() pops the icon in
## first and then counts the number up from zero. The win screen holds two,
## the skill and energy.

@onready var icon_box: Control = $IconBox
@onready var icon: TextureRect = $IconBox/Icon
@onready var chevron: TextureRect = $IconBox/Chevron
@onready var value: Label = $Value

var _delta: float = 0.0


## "+8" / "-5" / "+0": the sign always shows, the number is rounded.
static func format_delta(d: float) -> String:
	var n := int(round(d))
	return ("+%d" % n) if n >= 0 else ("%d" % n)


## Show `tex` and `delta` at rest. The chevron shows only on a gain.
func set_stat(tex: Texture2D, delta: float) -> void:
	_delta = delta
	icon.texture = tex
	chevron.visible = DaySummaryStatRow.shows_chevron(delta)
	value.text = format_delta(delta)


## The chip's turn in the reveal: the icon (with its chevron) pops in, then
## the number counts 0 -> delta over `count_time`. Returns when it lands.
func reveal(count_time: float) -> void:
	value.modulate.a = 1.0
	var pop := Juice.pop_in(icon_box)
	if pop != null:
		await pop.finished
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"tally")
	var count := Juice.count_up_formatted(value, 0.0, _delta, format_delta, 0.0, count_time)
	if count != null:
		await count.finished
```

- [ ] **Step 4: Scene** — `Scenes/Minigames/UI/MinigameWinStat.tscn` (hand-written; never opened in the editor for saving):

```
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/Minigames/UI/MinigameWinStat.gd" id="1_stat"]
[ext_resource type="Texture2D" path="res://Assets/Images/DaySummary/icon_chevron_up.png" id="2_chev"]

[node name="MinigameWinStat" type="HBoxContainer"]
theme_override_constants/separation = 12
alignment = 1
script = ExtResource("1_stat")

[node name="IconBox" type="Control" parent="."]
custom_minimum_size = Vector2(216, 168)
layout_mode = 2
mouse_filter = 2

[node name="Icon" type="TextureRect" parent="IconBox"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_right = -40.0
mouse_filter = 2
expand_mode = 1
stretch_mode = 5

[node name="Chevron" type="TextureRect" parent="IconBox"]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -66.0
offset_top = -90.0
mouse_filter = 2
texture = ExtResource("2_chev")
expand_mode = 1
stretch_mode = 5

[node name="Value" type="Label" parent="."]
layout_mode = 2
size_flags_vertical = 4
theme_type_variation = &"MinigameWinStatLabel"
text = "+0"
vertical_alignment = 1
```

- [ ] **Step 5: Scan and run green.** `filesystem_manage(op="scan", session_id=<WT>)`; no-op `script_patch` on `MinigameWinStat.gd`; `Run: test_run(suite="minigame_win_screen", session_id=<WT>)`, `script_documentation`, `viewport_editability`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(minigame): the win screen's stat row`.

---

### Task 7: `MinigameWinScreen` — scene, `configure`, layout

**Files:**
- Create: `Scenes/Minigames/UI/MinigameWinScreen.tscn`, `Scripts/Minigames/UI/MinigameWinScreen.gd`
- Modify: `tests/test_illustration_ao.gd` (`CUTOUTS`, count 30 → 31), `tests/test_look_layer.gd` (`GRADED`)
- Test: `tests/test_minigame_win_screen.gd`

**Interfaces:**
- Consumes: `MinigameWinStat`, `ResultStar.set_filled(filled, filled_tex, empty_tex, filled_color, empty_color)`, `DaySummaryStatRow.ICON_FOR`.
- Produces: `class_name MinigameWinScreen extends CanvasLayer`; `func configure(stars: int, speaker_path: String, line: String, category: String, shown: Dictionary) -> void` (`shown` keys `stat_delta`, `energy_delta`, both optional); `signal exited(choice: StringName)`; `func arm_buttons() -> void`; `func play() -> StringName` (Task 8); consts `REVEAL_ORDER`, `SKILL_KEY`, `ENERGY_ICON`, `EMPTY_STAR_COLOR`; node refs `root, blur, splash, bubble, line_label, card, star_row, stat_row, skill_chip, energy_chip, button_row, lobby_button, lanjut_button, fireworks, confetti`.

- [ ] **Step 1: Write the failing tests** — append to `tests/test_minigame_win_screen.gd`:

```gdscript
# ── the screen ───────────────────────────────────────────────────────────────

const _SCREEN := "res://Scenes/Minigames/UI/MinigameWinScreen.tscn"
const _CITRA := "res://Assets/Images/SplashArtMurid/splash_citra.png"


func _screen() -> MinigameWinScreen:
	var s := (load(_SCREEN) as PackedScene).instantiate() as MinigameWinScreen
	Engine.get_main_loop().root.add_child(s)
	s.root.theme = load(_THEME)
	track(s)
	return s


func _filled(s: MinigameWinScreen) -> int:
	var n := 0
	for star in s.star_row.get_children():
		if (star as ResultStar).is_filled:
			n += 1
	return n


func test_configure_fills_the_screen() -> void:
	var s := _screen()
	s.configure(2, _CITRA, "Terima kasih, Guru!", "Akademis", {"stat_delta": 8.0, "energy_delta": -5.0})
	assert_eq(s.splash.texture.resource_path, _CITRA)
	assert_true(s.splash.visible)
	assert_eq(s.line_label.text, "Terima kasih, Guru!")
	assert_true(s.line_label.uppercase, "the mockup's line is in capitals")
	assert_eq(_filled(s), 2, "two of the three stars are earned")
	assert_eq(s.skill_chip.icon.texture, DaySummaryStatRow.ICON_FOR["akademis"])
	assert_eq(s.skill_chip.value.text, "+8")
	assert_eq(s.energy_chip.icon.texture, MinigameWinScreen.ENERGY_ICON)
	assert_eq(s.energy_chip.value.text, "-5")


func test_each_category_wears_its_skill_icon() -> void:
	var s := _screen()
	for cat in MinigameWinScreen.SKILL_KEY:
		s.configure(3, "", "x", cat, {"stat_delta": 6.0, "energy_delta": -7.0})
		assert_eq(s.skill_chip.icon.texture, DaySummaryStatRow.ICON_FOR[MinigameWinScreen.SKILL_KEY[cat]], cat)


func test_a_zero_stat_hides_its_chip_and_nothing_hides_the_row() -> void:
	var s := _screen()
	s.configure(3, "", "x", "Olahraga", {"stat_delta": 0.0, "energy_delta": -7.0})
	assert_false(s.skill_chip.visible, "a capped week gains nothing: no '+0' chip")
	assert_true(s.energy_chip.visible)
	assert_true(s.stat_row.visible)
	s.configure(3, "", "x", "Olahraga", {})
	assert_false(s.stat_row.visible, "standalone play reports nothing, so no stat row")


func test_no_speaker_hides_the_splash() -> void:
	var s := _screen()
	s.configure(1, "", "x", "Akademis", {})
	assert_false(s.splash.visible)
	assert_eq(_filled(s), 1)


func test_the_screen_is_authored_and_themed() -> void:
	var s := _screen()
	assert_eq(s.layer, 999, "above every minigame layer, like the result popup")
	assert_eq(s.process_mode, Node.PROCESS_MODE_ALWAYS)
	var want := {
		"Root/Card": &"MinigameWinCard", "Root/Bubble/Panel": &"MinigameWinBubble",
		"Root/Bubble/Panel/Line": &"MinigameWinLine",
		"Root/Card/Layout/ButtonRow/LobbyButton": &"SecondaryButtonL",
		"Root/Card/Layout/ButtonRow/LanjutButton": &"PrimaryButtonL",
	}
	for path in want:
		var n := s.get_node_or_null(path) as Control
		assert_true(n != null, "missing " + path)
		if n != null:
			assert_eq(n.theme_type_variation, want[path], path)
	assert_eq(s.lobby_button.text, "LOBBY")
	assert_eq(s.lanjut_button.text, "LANJUT")
	assert_eq(s.root.mouse_filter, Control.MOUSE_FILTER_STOP, "nothing reaches the minigame")
	for path in ["Root/Blur", "Root/Splash", "Root/Bubble"]:
		assert_eq((s.get_node(path) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, path)
	assert_eq(s.blur.material.resource_path, "res://Scenes/SchoolSimulation/event_dialogue_blur_material.tres")
	assert_eq(s.splash.material.resource_path, "res://Scripts/Shaders/illustration_grade_cutout.tres")
	var tail := s.get_node("Root/Bubble/Tail") as TextureRect
	assert_eq(tail.texture.resource_path, "res://Assets/Images/Shop/UI/chat_bubble_tail.svg")
	assert_true(tail.flip_h and tail.flip_v, "the tail points up-left at the speaker")
	assert_eq(s.star_row.get_child_count(), 3)
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameWinScreen.gd")
	assert_false(src.contains(".new("), "the screen is fully authored")
	var scene := FileAccess.get_file_as_string(_SCREEN)
	for kind in ["theme_override_colors", "theme_override_font_sizes", "theme_override_fonts", "theme_override_styles"]:
		assert_false(scene.contains(kind), "no " + kind + " in MinigameWinScreen.tscn")


## Measured off minigamewinscreen_mockup.jpeg (spec section 3): every piece
## hangs off the bottom edge.
func test_every_piece_hangs_off_the_bottom_edge() -> void:
	var s := _screen()
	var want := {
		"Root/Splash": Vector4(20, -1933, -72, -176),
		"Root/Bubble": Vector4(50, -1022, -50, -878),
		"Root/Card": Vector4(0, -828, 0, 0),
	}
	for path in want:
		var c := s.get_node(path) as Control
		assert_eq(Vector4(c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom), Vector4(0, 1, 1, 1), path)
		assert_eq(Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom), want[path], path)


## On a 20:9 phone the whole composition keeps its distance from the bottom
## edge; only the blurred minigame above it grows. Root is moved into a frame
## of each size (layout_frame stands up Control-rooted scenes only).
func test_on_a_tall_phone_the_composition_rides_the_bottom_edge() -> void:
	for screen in [Vector2(1080, 1920), Vector2(1080, 2400)]:
		var s := _screen()
		var frame := Control.new()
		frame.size = screen
		frame.theme = load(_THEME)
		s.remove_child(s.root)
		frame.add_child(s.root)
		Engine.get_main_loop().root.add_child(frame)
		track(frame)
		preload("res://tests/layout_frame.gd").settle(s.root)
		assert_eq(s.card.get_global_rect().end.y, screen.y, "card meets the bottom at %s" % screen)
		assert_eq(s.card.get_global_rect().position.y, screen.y - 828, "card height at %s" % screen)
		assert_eq(s.bubble.get_global_rect().end.y, screen.y - 878, "bubble at %s" % screen)
		assert_eq(s.splash.get_global_rect().end.y, screen.y - 176, "splash at %s" % screen)
```

Also add `"res://Scenes/Minigames/UI/MinigameWinScreen.tscn": ["Root/Splash"],` to `CUTOUTS` in `tests/test_illustration_ao.gd` (and `30` → `31`, "thirty" → "thirty-one" in that assert and comment) and to `GRADED` in `tests/test_look_layer.gd`.

- [ ] **Step 2: Run red.** No-op `script_patch` on the three tests; `Run: test_run(suite="minigame_win_screen", session_id=<WT>)`, `illustration_ao`, `look_layer`. Expected: FAIL (scene missing).
- [ ] **Step 3: Script** — `Scripts/Minigames/UI/MinigameWinScreen.gd` (play() and the reveal land in Task 8; this task ships `configure`, `arm_buttons`, `_choose`):

```gdscript
@tool
class_name MinigameWinScreen
extends CanvasLayer

## The won-minigame screen (2026-09-25 minigame-win-screen spec; mockup
## minigamewinscreen_mockup.jpeg). BaseMinigame shows it over the minigame,
## which keeps running, blurred, behind it. A loss keeps MinigameResultPopup.
##
## Everything is authored in MinigameWinScreen.tscn: configure() only sets
## textures, text, visibility and the stars, and play() runs the reveal in
## REVEAL_ORDER, waits for LOBBY or LANJUT and returns which.

## Emitted once, with &"lobby" or &"lanjut", when an armed button is pressed.
signal exited(choice: StringName)

## The reveal, in order: the big box, the speaker, the line, the stats, the
## stars, the buttons. play() walks it; the suite pins it.
const REVEAL_ORDER: Array[StringName] = [&"card", &"splash", &"bubble", &"stats", &"stars", &"buttons"]
## Which Daily Results icon (DaySummaryStatRow.ICON_FOR) each category's skill chip wears.
const SKILL_KEY := {"Akademis": "akademis", "SeniBudaya": "seni_budaya", "Olahraga": "olahraga"}
## The energy chip's icon: the mockup's lightning.
const ENERGY_ICON: Texture2D = preload("res://Assets/Images/StudentCard/stat_energy.png")
## Tint that turns star.png into an unearned silhouette; BaseMinigame's
## popup_star_empty_color default, so both result cards dim alike.
const EMPTY_STAR_COLOR := Color(0.28, 0.28, 0.32)

@onready var root: Control = $Root
@onready var blur: ColorRect = $Root/Blur
@onready var splash: TextureRect = $Root/Splash
@onready var bubble: Control = $Root/Bubble
@onready var line_label: Label = $Root/Bubble/Panel/Line
@onready var card: PanelContainer = $Root/Card
@onready var star_row: HBoxContainer = $Root/Card/Layout/StarRow
@onready var stat_row: HBoxContainer = $Root/Card/Layout/StatRow
@onready var skill_chip: MinigameWinStat = $Root/Card/Layout/StatRow/SkillChip
@onready var energy_chip: MinigameWinStat = $Root/Card/Layout/StatRow/EnergyChip
@onready var button_row: HBoxContainer = $Root/Card/Layout/ButtonRow
@onready var lobby_button: Button = $Root/Card/Layout/ButtonRow/LobbyButton
@onready var lanjut_button: Button = $Root/Card/Layout/ButtonRow/LanjutButton
@onready var fireworks: ConfettiFireworks = $Root/ConfettiFireworks
@onready var confetti: RewardParticles = $Root/ResultConfetti

## Stars earned, 0-3, from configure().
var _star_count: int = 0
## True once the buttons have been revealed; presses before that are ignored.
var _armed: bool = false


func _ready() -> void:
	lobby_button.pressed.connect(_choose.bind(&"lobby"))
	lanjut_button.pressed.connect(_choose.bind(&"lanjut"))


## Dress the screen. `speaker_path` "" shows no splash. `shown` is what the
## host reported: {"stat_delta", "energy_delta"}, either may be absent; a zero
## or absent stat hides its chip, and two hidden chips hide the row.
func configure(stars: int, speaker_path: String, line: String, category: String, shown: Dictionary) -> void:
	_star_count = clampi(stars, 0, 3)
	_armed = false
	splash.texture = load(speaker_path) if speaker_path != "" and ResourceLoader.exists(speaker_path) else null
	splash.visible = splash.texture != null
	line_label.text = line
	var i := 0
	for star in star_row.get_children():
		(star as ResultStar).set_filled(i < _star_count, null, null, Color.WHITE, EMPTY_STAR_COLOR)
		i += 1
	var skill_icon: Texture2D = DaySummaryStatRow.ICON_FOR.get(SKILL_KEY.get(category, ""), null)
	var stat_delta := float(shown.get("stat_delta", 0.0))
	var energy_delta := float(shown.get("energy_delta", 0.0))
	skill_chip.set_stat(skill_icon, stat_delta)
	skill_chip.visible = skill_icon != null and not is_zero_approx(stat_delta)
	energy_chip.set_stat(ENERGY_ICON, energy_delta)
	energy_chip.visible = not is_zero_approx(energy_delta)
	stat_row.visible = skill_chip.visible or energy_chip.visible


## Let LOBBY and LANJUT answer. The reveal's last step calls it.
func arm_buttons() -> void:
	_armed = true


func _choose(choice: StringName) -> void:
	if not _armed:
		return
	_armed = false
	exited.emit(choice)
```

- [ ] **Step 4: Scene** — `Scenes/Minigames/UI/MinigameWinScreen.tscn` (hand-written):

```
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/Minigames/UI/MinigameWinScreen.gd" id="1_win"]
[ext_resource type="Material" path="res://Scenes/SchoolSimulation/event_dialogue_blur_material.tres" id="2_blur"]
[ext_resource type="Material" path="res://Scripts/Shaders/illustration_grade_cutout.tres" id="3_cut"]
[ext_resource type="Texture2D" path="res://Assets/Images/Shop/UI/chat_bubble_tail.svg" id="4_tail"]
[ext_resource type="PackedScene" path="res://Scenes/Minigames/UI/ResultStar.tscn" id="5_star"]
[ext_resource type="PackedScene" path="res://Scenes/Minigames/UI/MinigameWinStat.tscn" id="6_stat"]
[ext_resource type="PackedScene" path="res://Scenes/Minigames/UI/ConfettiFireworks.tscn" id="7_fw"]
[ext_resource type="PackedScene" path="res://Scenes/Minigames/UI/ResultConfetti.tscn" id="8_conf"]

[node name="MinigameWinScreen" type="CanvasLayer"]
process_mode = 3
layer = 999
script = ExtResource("1_win")

[node name="Root" type="Control" parent="."]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Blur" type="ColorRect" parent="Root"]
material = ExtResource("2_blur")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2

[node name="Splash" type="TextureRect" parent="Root"]
material = ExtResource("3_cut")
layout_mode = 1
anchors_preset = -1
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 20.0
offset_top = -1933.0
offset_right = -72.0
offset_bottom = -176.0
mouse_filter = 2
expand_mode = 1
stretch_mode = 5

[node name="Bubble" type="Control" parent="Root"]
layout_mode = 1
anchors_preset = -1
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 50.0
offset_top = -1022.0
offset_right = -50.0
offset_bottom = -878.0
mouse_filter = 2

[node name="Panel" type="PanelContainer" parent="Root/Bubble"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
theme_type_variation = &"MinigameWinBubble"

[node name="Line" type="Label" parent="Root/Bubble/Panel"]
layout_mode = 2
theme_type_variation = &"MinigameWinLine"
text = "Terima kasih, Guru!"
horizontal_alignment = 1
vertical_alignment = 1
uppercase = true

[node name="Tail" type="TextureRect" parent="Root/Bubble"]
layout_mode = 1
offset_left = 238.0
offset_top = -58.0
offset_right = 292.0
offset_bottom = 2.0
mouse_filter = 2
texture = ExtResource("4_tail")
expand_mode = 1
flip_h = true
flip_v = true

[node name="Card" type="PanelContainer" parent="Root"]
layout_mode = 1
anchors_preset = -1
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -828.0
grow_vertical = 0
theme_type_variation = &"MinigameWinCard"

[node name="Layout" type="VBoxContainer" parent="Root/Card"]
layout_mode = 2
theme_override_constants/separation = 56

[node name="StarRow" type="HBoxContainer" parent="Root/Card/Layout"]
layout_mode = 2
theme_override_constants/separation = 36
alignment = 1

[node name="Star1" parent="Root/Card/Layout/StarRow" instance=ExtResource("5_star")]
custom_minimum_size = Vector2(258, 258)
layout_mode = 2

[node name="Star2" parent="Root/Card/Layout/StarRow" instance=ExtResource("5_star")]
custom_minimum_size = Vector2(258, 258)
layout_mode = 2

[node name="Star3" parent="Root/Card/Layout/StarRow" instance=ExtResource("5_star")]
custom_minimum_size = Vector2(258, 258)
layout_mode = 2

[node name="StatRow" type="HBoxContainer" parent="Root/Card/Layout"]
layout_mode = 2
theme_override_constants/separation = 100
alignment = 1

[node name="SkillChip" parent="Root/Card/Layout/StatRow" instance=ExtResource("6_stat")]
layout_mode = 2

[node name="EnergyChip" parent="Root/Card/Layout/StatRow" instance=ExtResource("6_stat")]
layout_mode = 2

[node name="ButtonRow" type="HBoxContainer" parent="Root/Card/Layout"]
layout_mode = 2
theme_override_constants/separation = 64
alignment = 1

[node name="LobbyButton" type="Button" parent="Root/Card/Layout/ButtonRow"]
custom_minimum_size = Vector2(400, 0)
layout_mode = 2
theme_type_variation = &"SecondaryButtonL"
text = "LOBBY"

[node name="LanjutButton" type="Button" parent="Root/Card/Layout/ButtonRow"]
custom_minimum_size = Vector2(400, 0)
layout_mode = 2
theme_type_variation = &"PrimaryButtonL"
text = "LANJUT"

[node name="ResultConfetti" parent="Root" instance=ExtResource("8_conf")]
position = Vector2(540, -20)

[node name="ConfettiFireworks" parent="Root" instance=ExtResource("7_fw")]
layout_mode = 1
```

- [ ] **Step 5: Scan and run green.** `filesystem_manage(op="scan")`; no-op `script_patch` on `MinigameWinScreen.gd`; `Run: test_run(suite="minigame_win_screen", session_id=<WT>)`, `illustration_ao`, `look_layer`, `script_documentation`, `viewport_editability`. Expected: PASS. If the tall-phone test's card top is off because the card's content is taller than 828, lower `Layout`'s separation (layout constant) until the content fits — the rect assertions stay.
- [ ] **Step 6: Commit** `feat(minigame): the win screen scene`.

---

### Task 8: The reveal and the two exits

**Files:**
- Modify: `Scripts/Minigames/UI/MinigameWinScreen.gd`
- Test: `tests/test_minigame_win_screen.gd`

**Interfaces:**
- Consumes: `MinigameResultPopup.STAR_POP_SCALES`, `MinigameResultPopup.STAR_HOLD_TIMES`, `MinigameResultPopup.CONFETTI_STAR_THRESHOLD`, `ResultStar.celebrate(index)`, `ConfettiFireworks.fire_burst(index)`, `RewardParticles.fire()`, `RewardFeedback.play(&"minigame_win", self)`, `Juice.pop_in`, `Juice.stagger_in`.
- Produces: `func play() -> StringName` (coroutine; frees the screen); consts `CARD_RISE_TIME`, `SPLASH_GAP`, `SPLASH_RISE_TIME`, `SPLASH_RISE_PX`, `BUBBLE_GAP`, `STAT_STAGGER`, `STAT_COUNT_TIME`, `FADE_OUT_TIME`.

- [ ] **Step 1: Write the failing tests** — append:

```gdscript
# ── the reveal and the exits ─────────────────────────────────────────────────

func test_the_reveal_runs_in_the_asked_order() -> void:
	assert_eq(MinigameWinScreen.REVEAL_ORDER,
		[&"card", &"splash", &"bubble", &"stats", &"stars", &"buttons"] as Array[StringName],
		"box, then speaker, then line; stats; stars; buttons (owner's order, 2026-09-25)")
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameWinScreen.gd")
	assert_true(src.contains("for step in REVEAL_ORDER"), "play() walks the order, it does not restate it")


## Every piece play() reveals starts hidden, so nothing flashes on before its
## turn; the buttons are dead until the last step arms them.
func test_before_the_reveal_everything_waits() -> void:
	var s := _screen()
	s.configure(3, _CITRA, "x", "Akademis", {"stat_delta": 8.0, "energy_delta": -5.0})
	s.hide_for_reveal()
	for n in [s.blur, s.card, s.splash, s.bubble, s.skill_chip.icon_box, s.energy_chip.icon_box, s.lobby_button, s.lanjut_button]:
		assert_eq(n.modulate.a, 0.0, "%s waits for its turn" % n.name)
	for star in s.star_row.get_children():
		assert_eq(star.modulate.a, 0.0, "%s waits for its turn" % star.name)


func test_the_buttons_answer_only_once_armed() -> void:
	var s := _screen()
	s.configure(3, "", "x", "Akademis", {})
	var got: Array = []
	s.exited.connect(func(c: StringName): got.append(c))
	s.lanjut_button.pressed.emit()
	assert_eq(got, [], "a press mid-reveal is ignored")
	s.arm_buttons()
	s.lobby_button.pressed.emit()
	s.lanjut_button.pressed.emit()
	assert_eq(got, [&"lobby"], "the first armed press answers, once")
```

- [ ] **Step 2: Run red.** No-op `script_patch` on the test; `Run: test_run(suite="minigame_win_screen", session_id=<WT>)`. Expected: FAIL (`hide_for_reveal` missing, source scan).
- [ ] **Step 3: Implement** — add to `MinigameWinScreen.gd` after `EMPTY_STAR_COLOR`:

```gdscript
## Seconds the card takes to rise into place while the blur fades in.
const CARD_RISE_TIME := 0.35
## Pause after the card lands before the speaker starts.
const SPLASH_GAP := 0.12
## Seconds the speaker takes to fade in while rising SPLASH_RISE_PX.
const SPLASH_RISE_TIME := 0.30
## How far the speaker rises as it fades in, px.
const SPLASH_RISE_PX := 60.0
## Pause after the speaker before the bubble pops.
const BUBBLE_GAP := 0.12
## Gap between the two stat chips starting their reveal.
const STAT_STAGGER := 0.15
## Seconds each chip's number counts from 0 to its delta.
const STAT_COUNT_TIME := 0.5
## Seconds the screen takes to fade away after a choice.
const FADE_OUT_TIME := 0.25
```

and these functions:

```gdscript
## Every piece the reveal brings in, hidden and waiting. play() calls it
## first; a test calls it to check nothing shows before its turn.
func hide_for_reveal() -> void:
	for n in [blur, card, splash, bubble, lobby_button, lanjut_button,
			skill_chip.icon_box, energy_chip.icon_box, skill_chip.value, energy_chip.value]:
		n.modulate.a = 0.0
	for star in star_row.get_children():
		star.modulate.a = 0.0
		star.scale = Vector2(0.3, 0.3)
		star.pivot_offset = star.custom_minimum_size / 2.0


## Run the reveal in REVEAL_ORDER, wait for LOBBY or LANJUT, fade out, free
## this screen, and return the choice. Callers must await it.
func play() -> StringName:
	hide_for_reveal()
	for step in REVEAL_ORDER:
		await _reveal(step)
	var choice: StringName = await exited
	var out := create_tween()
	out.tween_property(root, "modulate:a", 0.0, FADE_OUT_TIME)
	await out.finished
	queue_free()
	return choice


func _reveal(step: StringName) -> void:
	match step:
		&"card":
			var rest_y := card.position.y
			card.position.y = rest_y + card.size.y
			card.modulate.a = 1.0
			var rise := create_tween().set_parallel(true)
			rise.tween_property(blur, "modulate:a", 1.0, CARD_RISE_TIME)
			rise.tween_property(card, "position:y", rest_y, CARD_RISE_TIME) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			await rise.finished
			if not Engine.is_editor_hint():
				RewardFeedback.play(&"minigame_win", self)
		&"splash":
			await get_tree().create_timer(SPLASH_GAP).timeout
			if splash.visible:
				var rest_y := splash.position.y
				splash.position.y = rest_y + SPLASH_RISE_PX
				var rise := create_tween().set_parallel(true)
				rise.tween_property(splash, "modulate:a", 1.0, SPLASH_RISE_TIME)
				rise.tween_property(splash, "position:y", rest_y, SPLASH_RISE_TIME) \
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
				await rise.finished
		&"bubble":
			await get_tree().create_timer(BUBBLE_GAP).timeout
			var pop := Juice.pop_in(bubble)
			if pop != null:
				await pop.finished
		&"stats":
			var chips: Array = [skill_chip, energy_chip].filter(func(c): return c.visible)
			for i in chips.size():
				if i < chips.size() - 1:
					chips[i].reveal(STAT_COUNT_TIME)
					await get_tree().create_timer(STAT_STAGGER).timeout
				else:
					await chips[i].reveal(STAT_COUNT_TIME)
		&"stars":
			await _land_stars()
		&"buttons":
			Juice.stagger_in([lobby_button, lanjut_button])
			arm_buttons()


## MinigameResultPopup's escalating ladder: each star pops a little harder
## than the last, an earned one blooms and fires its firework, and a full
## house rains confetti.
func _land_stars() -> void:
	var index := 0
	for star in star_row.get_children():
		var pop_scale: float = MinigameResultPopup.STAR_POP_SCALES[mini(index, MinigameResultPopup.STAR_POP_SCALES.size() - 1)]
		var tw := create_tween().set_parallel(true)
		tw.tween_property(star, "modulate:a", 1.0, 0.15)
		tw.tween_property(star, "scale", Vector2(pop_scale, pop_scale), 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished
		star.celebrate(index)
		if index < _star_count and not Engine.is_editor_hint():
			fireworks.fire_burst(index)
		await get_tree().create_timer(
			MinigameResultPopup.STAR_HOLD_TIMES[mini(index, MinigameResultPopup.STAR_HOLD_TIMES.size() - 1)]).timeout
		var settle := create_tween()
		settle.tween_property(star, "scale", Vector2.ONE, 0.1) \
			.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		await settle.finished
		index += 1
	if _star_count >= MinigameResultPopup.CONFETTI_STAR_THRESHOLD and not Engine.is_editor_hint():
		confetti.fire()
```

(In `MinigameWinStat.reveal`, `value.modulate.a = 1.0` already brings the number back on its turn.)

- [ ] **Step 4: Run green.** No-op `script_patch` on `MinigameWinScreen.gd`; `Run: test_run(suite="minigame_win_screen", session_id=<WT>)`, `script_documentation`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(minigame): the win screen's staged reveal and its two exits`.

---

### Task 9: BaseMinigame shows the win screen

**Files:**
- Modify: `Scripts/Minigames/UI/BaseMinigame.gd` (exports block near `result_popup_scene`, `_show_result_overlay`)
- Test: `tests/test_minigame_single_result.gd`

**Interfaces:**
- Consumes: `MinigameWinScreen.configure(...)`, `.play() -> StringName`, `EventDialogueCatalog.WIN_LINE_STUDENT`.
- Produces: `@export var win_screen_scene: PackedScene`; `var host_context: Dictionary` (keys `category`, `speaker`, `line`); `var result_reporter: Callable` — called `result_reporter.call(is_win: bool, score: int, max_score: int) -> Dictionary`; `var result_exit: StringName` (`&"lanjut"` default).

- [ ] **Step 1: Write the failing tests** — in `tests/test_minigame_single_result.gd` replace `_popup_count` with a two-card counter and add tests:

```gdscript
## How many result cards of `script_name` the minigame holds.
func _cards(mg: Node, script_name: String) -> int:
	var found := 0
	for child in mg.get_children():
		var s: Script = child.get_script() as Script
		if s != null and str(s.resource_path).contains(script_name):
			found += 1
	return found


## Either result card: the win screen on a win, the popup on a loss.
func _popup_count(mg: Node) -> int:
	return _cards(mg, "MinigameResultPopup") + _cards(mg, "MinigameWinScreen")


func test_a_win_shows_the_win_screen_and_not_the_popup() -> void:
	var mg := _stood_up()
	mg.set("is_game_active", true)
	mg.call("win_game")
	assert_eq(_cards(mg, "MinigameWinScreen"), 1, "a win ends on the win screen")
	assert_eq(_cards(mg, "MinigameResultPopup"), 0)


func test_a_loss_keeps_the_popup() -> void:
	var mg := _stood_up()
	mg.set("is_game_active", true)
	mg.call("abandon_game")
	assert_eq(_cards(mg, "MinigameResultPopup"), 1, "a loss keeps the old card")
	assert_eq(_cards(mg, "MinigameWinScreen"), 0)


## The stats are applied when the result is decided, once, and the win screen
## shows what the host reported.
func test_the_reporter_runs_once_before_the_card() -> void:
	var mg := _stood_up()
	var calls: Array = []
	mg.set("result_reporter", func(won: bool, _s: int, _m: int) -> Dictionary:
		calls.append(won)
		return {"stat_delta": 8.0, "energy_delta": -5.0})
	mg.set("host_context", {"category": "Akademis", "speaker": "res://Assets/Images/SplashArtMurid/splash_citra.png", "line": "Terima kasih, Guru!"})
	mg.set("is_game_active", true)
	mg.call("win_game")
	mg.call("win_game")
	assert_eq(calls, [true], "reported once, as a win")
	var screen: MinigameWinScreen = null
	for child in mg.get_children():
		if child is MinigameWinScreen:
			screen = child
	assert_true(screen != null)
	if screen != null:
		assert_eq(screen.skill_chip.value.text, "+8")
		assert_eq(screen.splash.texture.resource_path, "res://Assets/Images/SplashArtMurid/splash_citra.png")


func test_a_loss_is_reported_too() -> void:
	var mg := _stood_up()
	var calls: Array = []
	mg.set("result_reporter", func(won: bool, _s: int, _m: int) -> Dictionary:
		calls.append(won)
		return {})
	mg.set("is_game_active", true)
	mg.call("abandon_game")
	assert_eq(calls, [false])


func test_standalone_play_shows_no_stats() -> void:
	var mg := _stood_up()
	mg.set("is_game_active", true)
	mg.call("win_game")
	for child in mg.get_children():
		if child is MinigameWinScreen:
			assert_false(child.stat_row.visible, "nothing was applied, so nothing is shown")
```

- [ ] **Step 2: Run red.** No-op `script_patch` on the test; `Run: test_run(suite="minigame_single_result", session_id=<WT>)`. Expected: the new tests FAIL (still the popup; unknown properties).
- [ ] **Step 3: Implement** — in `BaseMinigame.gd`, after the `result_popup_scene` export:

```gdscript
## The won-minigame screen (2026-09-25 win-screen spec). A loss keeps
## result_popup_scene; null shows result_popup_scene for a win too.
@export var win_screen_scene: PackedScene = preload("res://Scenes/Minigames/UI/MinigameWinScreen.tscn")
## What the host screen tells the win screen: {"category", "speaker", "line"}.
## Empty when the minigame runs on its own (debug launcher, F6).
var host_context: Dictionary = {}
## Set by the host before start. Called once, when the result is decided, as
## result_reporter.call(is_win, score, max_score): it applies the result and
## returns what the win screen shows, {"stat_delta", "energy_delta"}.
var result_reporter: Callable = Callable()
## The win screen's answer, &"lanjut" or &"lobby". A loss leaves &"lanjut".
var result_exit: StringName = &"lanjut"
```

and in `_show_result_overlay`, replace from `var popup: MinigameResultPopup = result_popup_scene.instantiate()` through `await popup.play()` with:

```gdscript
	var shown: Dictionary = {}
	if result_reporter.is_valid():
		shown = result_reporter.call(is_win, mg_score, mg_max_score)

	if is_win and win_screen_scene != null:
		var screen: MinigameWinScreen = win_screen_scene.instantiate()
		add_child(screen)
		screen.configure(stars, str(host_context.get("speaker", "")),
			str(host_context.get("line", EventDialogueCatalog.WIN_LINE_STUDENT)),
			str(host_context.get("category", mg_category)), shown)
		result_exit = await screen.play()
	else:
		var popup: MinigameResultPopup = result_popup_scene.instantiate()
		add_child(popup)
		popup.configure(is_win, stars, mg_score, mg_max_score,
			_get_active_tutorial_title(), mg_category, stat_delta, energy_delta, mood_delta,
			{ ...the existing style dictionary, unchanged... })
		await popup.play()
```

(keep the existing style dictionary literal verbatim inside the `else`). Update the function's doc comment: "Show the win screen (win) or the result card (loss)…" and note the reporter.

- [ ] **Step 4: Run green.** No-op `script_patch` on `BaseMinigame.gd`; `Run: test_run(suite="minigame_single_result", session_id=<WT>)`, `minigame_result_popup`, `minigame_star_rubric`, `minigame_overlays`, `script_documentation`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(minigame): a win ends on the win screen`.

---

### Task 10: SchoolDay reports the result and honours LOBBY

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` (state vars, `_play_minigame`, `_show_event_dialogue`, new helpers)
- Modify: `docs/superpowers/DEBT.md` (`## Known bugs and gaps`)
- Test: `tests/test_school_day.gd`

**Interfaces:**
- Consumes: `BaseMinigame.host_context / result_reporter / result_exit`, `EventDialogueCatalog.win_speaker_path`, `win_line_for`, `pick_featured`, `StudentManager.record_minigame_result(...) -> Array[Dictionary]`.
- Produces: `static func roster_average(results: Array, key: String) -> float`; `func _report_minigame_result(won: bool, score: int, max_score: int, category: String, game_name: String, day_name: String) -> Dictionary`; `func _win_context(category: String, day_name: String) -> Dictionary`; `func _leave_week_after_today() -> void`; vars `_last_featured: StudentData`, `_minigame_recorded: bool`.

- [ ] **Step 1: Write the failing tests** — append to `tests/test_school_day.gd`:

```gdscript
# ── the win screen's wiring (2026-09-25 spec, sections 3-4) ─────────────────

func _body(src: String, header: String) -> String:
	var at := src.find(header)
	if at == -1:
		return ""
	var next := src.find("\nfunc ", at + header.length())
	return src.substr(at, (next if next != -1 else src.length()) - at)


func test_the_win_screen_shows_the_roster_average_rounded() -> void:
	var school_day = load(_SCHOOL_DAY_SCRIPT)
	var results := [
		{"student_name": "A", "deltas": {"stat_delta": 8.0, "energy_delta": -3.0}},
		{"student_name": "B", "deltas": {"stat_delta": 10.0, "energy_delta": -6.0}},
		{"student_name": "C", "deltas": {"stat_delta": 0.0, "energy_delta": -6.0}},
	]
	assert_eq(school_day.roster_average(results, "stat_delta"), 6.0)
	assert_eq(school_day.roster_average(results, "energy_delta"), -5.0)
	assert_eq(school_day.roster_average([], "stat_delta"), 0.0, "an empty roster averages to nothing")


func test_the_minigame_is_told_who_thanks_and_how_to_report() -> void:
	var body := _body(FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT), "func _play_minigame(")
	var reporter := body.find("result_reporter = ")
	var context := body.find("host_context = ")
	var start := body.find("start_minigame(")
	assert_true(reporter != -1 and context != -1, "SchoolDay hands the minigame both")
	assert_true(reporter < start and context < start, "before the minigame starts")


## The stats are applied exactly once: by the reporter when it ran, else
## (a minigame without BaseMinigame's hook) after the result as before.
func test_the_result_is_recorded_once() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	var report := _body(src, "func _report_minigame_result(")
	assert_true(report.contains("record_minigame_result(") and report.contains("_minigame_recorded = true"))
	var play := _body(src, "func _play_minigame(")
	assert_true(play.contains("if student_manager and not _minigame_recorded:"),
		"the old record after the result only runs when the reporter did not")


## LOBBY leaves the week. Today's decay and roll already happened, and
## skip_to_results() starts at current_day, so today must be stepped past
## first or it is decayed and rolled twice.
func test_lobby_steps_past_today_before_skipping() -> void:
	var src := FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT)
	var leave := _body(src, "func _leave_week_after_today(")
	var step := leave.find("current_day += 1")
	var skip := leave.find("skip_to_results()")
	assert_true(step != -1 and skip != -1 and step < skip, "step past today, then skip")
	var play := _body(src, "func _play_minigame(")
	assert_true(play.contains("&\"lobby\"") and play.contains("_leave_week_after_today()"),
		"the minigame's LOBBY answer leads there")


## The student who asked before the minigame is the one who thanks after it.
func test_the_dialogue_remembers_its_featured_student() -> void:
	var dlg := _body(FileAccess.get_file_as_string(_SCHOOL_DAY_SCRIPT), "func _show_event_dialogue(")
	var reset := dlg.find("_last_featured = null")
	var keep := dlg.find("_last_featured = featured")
	assert_true(reset != -1 and keep != -1 and reset < keep,
		"cleared on entry (a skipped line leaves nobody), set once picked")
```

- [ ] **Step 2: Run red.** No-op `script_patch` on the test; `Run: test_run(suite="school_day", session_id=<WT>)`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement** in `SchoolDay.gd`:

State, after `var current_minigame: Node = null`:

```gdscript
## The student the last EventDialogue featured, so the one who asked before
## a minigame is the one who thanks after it. Null when the line was skipped.
var _last_featured: StudentData = null
## True once this minigame's result was applied through its result_reporter.
var _minigame_recorded: bool = false
```

In `_show_event_dialogue`, first line of the body: `_last_featured = null`; after `var featured: StudentData = EventDialogueCatalog.pick_featured(...)`: `_last_featured = featured`.

In `_play_minigame`, after `current_minigame.set_anchors_and_offsets_preset(...)` and the two signal connects:

```gdscript
	_minigame_recorded = false
	var game_name = _scene_name(game_scene)
	var day_name = DAYS[current_day]
	if "result_reporter" in current_minigame:
		current_minigame.result_reporter = _report_minigame_result.bind(category, game_name, day_name)
	if "host_context" in current_minigame:
		current_minigame.host_context = _win_context(category, day_name)
```

After `var won: bool = await _minigame_result` remove the now-duplicate `var game_name` / `var day_name` lines (declared above) and guard the record:

```gdscript
	if student_manager and not _minigame_recorded:
		student_manager.record_minigame_result(day_name, category, game_name, won, mg_score, mg_max_score)
```

Before `current_minigame.queue_free()`, read the answer: `var exit_choice: StringName = current_minigame.get("result_exit") if "result_exit" in current_minigame else &"lanjut"`; at the very end of `_play_minigame` (after the day screen fades back in):

```gdscript
	_last_featured = null
	if exit_choice == &"lobby":
		_leave_week_after_today()
```

New helpers, after `_show_event_dialogue`:

```gdscript
## The minigame's result_reporter (2026-09-25 win-screen spec): applies the
## result to the roster now, before the win screen opens, and returns the
## roster's average skill and energy change for it to show.
func _report_minigame_result(won: bool, score: int, max_score: int,
		category: String, game_name: String, day_name: String) -> Dictionary:
	if student_manager == null:
		return {}
	var results: Array = student_manager.record_minigame_result(day_name, category, game_name, won, score, max_score)
	_minigame_recorded = true
	return {
		"stat_delta": roster_average(results, "stat_delta"),
		"energy_delta": roster_average(results, "energy_delta"),
	}


## The mean of one delta across record_minigame_result()'s per-student
## results, rounded: the class's result, which the day summary breaks down.
static func roster_average(results: Array, key: String) -> float:
	if results.is_empty():
		return 0.0
	var total := 0.0
	for r in results:
		total += float((r as Dictionary).get("deltas", {}).get(key, 0.0))
	return roundf(total / results.size())


## Who thanks the player if this minigame is won, and what they say. The
## dialogue's featured student when there was one; with the line skipped,
## one picked by the same rule the dialogue uses.
func _win_context(category: String, day_name: String) -> Dictionary:
	var featured: StudentData = _last_featured
	if featured == null and student_manager:
		featured = EventDialogueCatalog.pick_featured(student_manager.students, category)
	var speaker := EventDialogueCatalog.win_speaker_path(category, featured, day_name, randf())
	return {"category": category, "speaker": speaker, "line": EventDialogueCatalog.win_line_for(speaker)}


## The win screen's LOBBY: leave the week now. Today's decay and roll have
## already run, and skip_to_results() starts at current_day, so step past
## today first; the rest of the week then resolves with the grade's skip
## odds and ends on the weekly report, as the Skip button's does.
func _leave_week_after_today() -> void:
	current_day += 1
	skip_to_results()
```

- [ ] **Step 4: DEBT.** Under `## Known bugs and gaps` in `docs/superpowers/DEBT.md` add: "**SchoolDay's dev Skip mid-day decays today twice.** `skip_to_results()` (key O, `SkipButton`) starts at `current_day`, which `_run_single_day` has already decayed and rolled, so a skip pressed during a day's event or minigame runs that day's decay and roll again. The win screen's LOBBY steps past today first (`_leave_week_after_today`); the key does not."
- [ ] **Step 5: Run green.** No-op `script_patch` on `SchoolDay.gd`; `Run: test_run(suite="school_day", session_id=<WT>)`, `event_dialogue`, `minigame_weekly_cap`, `script_documentation`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(school-day): apply the minigame result before the win screen, honour LOBBY`.

---

### Task 11: Look at it

**Files:** none tracked (screenshots to the scratchpad).

- [ ] **Step 1: Run the game in the worktree editor** (`project_run`, `session_id=<WT>`), seed with `DebugManager._seed_playtest_state()` through a game eval (Debug > General > ⚡ Seed Playtest State).
- [ ] **Step 2: The win screen.** In one game eval: `DebugManager._launch_minigame_standalone("res://Scenes/Minigames/Olahraga/MainBola.tscn")`; on `DebugManager.active_minigame` set `host_context = {"category": "Olahraga", "speaker": "res://Assets/Images/SplashArtMurid/splash_citra.png", "line": "Terima kasih, Guru!"}` and `result_reporter = func(w, s, m): return {"stat_delta": 8.0, "energy_delta": -5.0}`; call `win_game()`. Capture once mid-reveal (stats counting) and once settled with `Engine.time_scale` frozen (0.02 while particles fly), at full size. Compare against `minigamewinscreen_mockup.jpeg`: splash, bubble, card, stars, stats, buttons where the spec's table puts them. Fix only rect/constant mismatches (layout constants), re-run `minigame_win_screen`.
- [ ] **Step 3: EventDialogue on a Kamis.** Game eval: instance `EventDialogue.tscn` over the current scene, `open(EventDialogueCatalog.entry("BuatBatik"), <a StudentData named Thea with splash_thea.png>, 3, 6, "Kamis")`; capture; Thea wears batik at the mockup's height.
- [ ] **Step 4: The book-clock badge.** Instance `Scenes/SchoolSimulation/BookClockWidget.tscn` in the running game; capture its calendar at full size: the week text sits on the yellow calendar's page. If it spills, move `Header/Calendar/Text`'s anchors in `BookClockWidget.tscn` — through a text edit made while no editor has that scene open (it was never opened in this worktree's editor), then `book_clock_phases`.
- [ ] **Step 5: A back button.** Capture one back control on a light and one on a dark screen (Inventory, SchoolDay's week-end Kembali); the dark red arrow reads on both.
- [ ] **Step 6:** Stop the game; `git status` — revert `Assets/Audio/default_bus_layout.tres` if the run rewrote it. Send the win-screen capture to the user with SendUserFile.

---

### Task 12: Docs and the full suite

**Files:**
- Modify: `CLAUDE.md` (the loop paragraph; the suite count line), `docs/superpowers/CHANGELOG.md`

- [ ] **Step 1: CLAUDE.md.** In the loop paragraph, after the EventDialogue sentence, add: "A won minigame ends on `MinigameWinScreen` (speaker, stat count-up, stars, LOBBY/LANJUT over the blurred minigame; LOBBY skips the rest of the week); a loss keeps `MinigameResultPopup`." Keep the file under its 23,000-character budget (`wc -c CLAUDE.md`).
- [ ] **Step 2: CHANGELOG.** Newest-first entry `## 2026-09-25 — Minigame win screen, day outfits, icon refresh` with one bullet per spec section.
- [ ] **Step 3: Restart the worktree editor** (fresh process for the long run), then the full run: `Run: test_run(session_id=<WT>)` with no suite. Expected: all pass. The bridge may drop after the reply; the reply counts.
- [ ] **Step 4:** Update CLAUDE.md's "N suites, M tests (date)" line with the run's totals.
- [ ] **Step 5:** `git status`: `git checkout --` `Assets/Audio/default_bus_layout.tres` and `Assets/Theme/kejartes_theme.tres` if the run rewrote them without content change (diff first; the bake must match Task 5's).
- [ ] **Step 6: Commit** `docs: the minigame win screen in the loop, changelog`.
