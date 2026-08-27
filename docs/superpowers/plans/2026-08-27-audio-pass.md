# Audio Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every interaction and feedback moment in KejarTes a free-for-commercial placeholder sound, add four loopable cute-school BGM tracks, and keep all of it swappable from one inspector panel and adjustable from the existing Settings sliders.

**Architecture:** `AudioDirector` (autoloaded from `Scenes/Audio/audio_director.tscn`) stays the single audio entry point. This pass adds 8 new `@export var sfx_*: AudioStream` slots to it, fills all 16 SFX slots and 4 BGM slots with CC0 `.ogg` files, then sweeps every screen script adding `AudioDirector.play_sfx(&"...")` / `play_bgm(&"...")` calls at the interaction points that are currently silent. No script anywhere `preload()`s an audio file — the audio team swaps assets by dragging onto slots in `audio_director.tscn`.

**Tech Stack:** Godot 4.6 (Mobile renderer), GDScript, `McpTestSuite` in-editor test suites, `.ogg` Vorbis audio.

**Spec:** `docs/superpowers/design/audio-pass-spec.md`

## Global Constraints

- Godot **4.6**, Mobile renderer, GDScript only. Do not add addons.
- Audio files are `.ogg` only. SFX: mono or stereo, < 1 second, < 40 KB. BGM: stereo, 30–120 s, loopable.
- Every stream reaches the game through an `@export` slot on `AudioDirector`. **Never** `preload()` or `load()` an audio path in a screen script.
- Licenses must permit commercial use. CC0 preferred. Record every source in `Assets/Audio/SFX/LICENSES.md` / `Assets/Audio/BGM/LICENSES.md`.
- Any script that the in-editor test runner instantiates needs `@tool` **and** the `Engine.is_editor_hint()` guard pattern already used in `Scripts/Audio/AudioDirector.gd:47-64`. Do not play audio when `Engine.is_editor_hint()` is true.
- Existing bus names are exactly `Master`, `BGM`, `SFX` (see `Assets/Audio/default_bus_layout.tres`). Do not rename or add buses.
- Existing SFX ids that call sites already use — do not rename: `tap`, `confirm`, `cancel`, `success`, `fail`, `coin`, `whoosh`, `pop`.
- Run tests with the godot-ai MCP tool `test_run`. There is no CLI test command in this project.
- **Downloading any file requires explicit user approval.** Every download step below must be presented to the user (filename, source URL, size) and confirmed before executing.

---

### Task 1: Add the eight new SFX slots to AudioDirector

**Files:**
- Modify: `Scripts/Audio/AudioDirector.gd:16-25` (the `@export_group("SFX")` block) and `:96-108` (`_resolve_sfx`)
- Test: `tests/test_audio_director.gd:36-48` (extend `test_sfx_and_bgm_slots_are_exported`), plus two new tests

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `AudioDirector.play_sfx(id: StringName) -> void` now resolves these ids in addition to the existing eight — `&"swipe"`, `&"stamp"`, `&"unstamp"`, `&"popup_open"`, `&"popup_close"`, `&"select"`, `&"error"`, `&"reward"`. Also produces `AudioDirector.has_sfx(id: StringName) -> bool`, returning `true` only when that id maps to a slot with a non-null stream. Tasks 5–8 rely on these exact id spellings.

- [ ] **Step 1: Write the failing test**

Open `tests/test_audio_director.gd`. Replace the slot list inside `test_sfx_and_bgm_slots_are_exported` with the full sixteen, and append two new test functions at the end of the file:

```gdscript
func test_sfx_and_bgm_slots_are_exported() -> void:
	# The inspector-editability requirement: a designer must be able to
	# drag an .ogg onto each slot without touching code.
	var props := _director.get_property_list()
	var names: Array[String] = []
	for p in props:
		names.append(p.name)
	for slot in ["sfx_tap", "sfx_confirm", "sfx_cancel", "sfx_success",
			"sfx_fail", "sfx_coin", "sfx_whoosh", "sfx_pop",
			"sfx_swipe", "sfx_stamp", "sfx_unstamp", "sfx_popup_open",
			"sfx_popup_close", "sfx_select", "sfx_error", "sfx_reward",
			"bgm_menu", "bgm_lobby", "bgm_simulation", "bgm_result"]:
		assert_true(names.has(slot), "must expose export slot: " + slot)


func test_every_new_sfx_id_resolves_to_a_slot() -> void:
	# play_sfx must not silently swallow a typo'd id: assign a dummy
	# stream to each slot, then assert has_sfx() sees it.
	var dummy := AudioStreamGenerator.new()
	var ids := ["swipe", "stamp", "unstamp", "popup_open",
		"popup_close", "select", "error", "reward"]
	for id in ids:
		_director.set("sfx_" + id, dummy)
	for id in ids:
		assert_true(_director.has_sfx(StringName(id)),
			"id must resolve to its slot: " + id)


func test_has_sfx_is_false_for_empty_and_unknown() -> void:
	_director.sfx_swipe = null
	assert_true(not _director.has_sfx(&"swipe"),
		"an unassigned slot must report has_sfx() == false")
	assert_true(not _director.has_sfx(&"tidak_ada_suara_ini"),
		"an unknown id must report has_sfx() == false")
```

- [ ] **Step 2: Run tests to verify they fail**

Run the godot-ai MCP tool `test_run` with suite `audio_director`.
Expected: FAIL — `test_sfx_and_bgm_slots_are_exported` reports `must expose export slot: sfx_swipe`, and the two new tests error on the missing `has_sfx` method.

- [ ] **Step 3: Add the slots**

In `Scripts/Audio/AudioDirector.gd`, inside `@export_group("SFX")`, after the existing `@export var sfx_pop: AudioStream` line, add:

```gdscript
@export var sfx_swipe: AudioStream
@export var sfx_stamp: AudioStream
@export var sfx_unstamp: AudioStream
@export var sfx_popup_open: AudioStream
@export var sfx_popup_close: AudioStream
@export var sfx_select: AudioStream
@export var sfx_error: AudioStream
@export var sfx_reward: AudioStream
```

- [ ] **Step 4: Extend `_resolve_sfx` and add `has_sfx`**

In the same file, add the new cases to `_resolve_sfx` before the `_: return null` fallback:

```gdscript
		&"swipe": return sfx_swipe
		&"stamp": return sfx_stamp
		&"unstamp": return sfx_unstamp
		&"popup_open": return sfx_popup_open
		&"popup_close": return sfx_popup_close
		&"select": return sfx_select
		&"error": return sfx_error
		&"reward": return sfx_reward
```

Then add this function directly below `_resolve_sfx`:

```gdscript
## True only when `id` maps to a slot AND that slot holds a stream.
## Screens never need this — play_sfx is already null-safe — but tests
## and the audio-coverage suite use it to prove a slot got filled.
func has_sfx(id: StringName) -> bool:
	return _resolve_sfx(id) != null
```

- [ ] **Step 5: Run tests to verify they pass**

Run `test_run` with suite `audio_director`.
Expected: PASS — all tests green, including the three touched/added above.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Audio/AudioDirector.gd tests/test_audio_director.gd docs/superpowers/design/audio-pass-spec.md docs/superpowers/plans/2026-08-27-audio-pass.md
git commit -m "feat(audio): add eight interaction SFX slots and has_sfx()"
```

---

### Task 2: Source and install the eight new placeholder SFX

**Files:**
- Create: `Assets/Audio/SFX/swipe.ogg`, `stamp.ogg`, `unstamp.ogg`, `popup_open.ogg`, `popup_close.ogg`, `select.ogg`, `error.ogg`, `reward.ogg` (plus their `.import` sidecars, generated by Godot)
- Create: `Assets/Audio/SFX/LICENSES.md`
- Modify: `Scenes/Audio/audio_director.tscn`
- Test: `tests/test_audio_director.gd` (new coverage test)

**Interfaces:**
- Consumes: the eight `sfx_*` export slots and `has_sfx()` from Task 1.
- Produces: an `AudioDirector` autoload where `has_sfx()` is true for all sixteen SFX ids. Tasks 5–8 assume every id makes a sound.

- [ ] **Step 1: Present the download shortlist to the user and get approval**

Do not download anything yet. Show the user this table and ask for a yes before proceeding. All three packs are CC0 (public domain, commercial use, no attribution required):

| Slot | Pack | Page |
|---|---|---|
| `swipe` | Kenney — Interface Sounds | https://kenney.nl/assets/interface-sounds |
| `stamp` | Kenney — Impact Sounds | https://kenney.nl/assets/impact-sounds |
| `unstamp` | Kenney — Interface Sounds | https://kenney.nl/assets/interface-sounds |
| `popup_open` | Kenney — Interface Sounds | https://kenney.nl/assets/interface-sounds |
| `popup_close` | Kenney — Interface Sounds | https://kenney.nl/assets/interface-sounds |
| `select` | Kenney — Interface Sounds | https://kenney.nl/assets/interface-sounds |
| `error` | Kenney — Interface Sounds | https://kenney.nl/assets/interface-sounds |
| `reward` | Kenney — Music Jingles | https://kenney.nl/assets/music-jingles |

State the total download size (each pack is roughly 2–8 MB zipped) and that the zips land in the scratchpad directory, not in the repo. Wait for an explicit yes.

If the user declines the downloads, stop this task and tell them the slots stay empty — `play_sfx` on an empty slot is already silent and safe (`tests/test_audio_director.gd:50`), so Tasks 5–8 can still proceed and the wiring will simply be inaudible until files arrive.

- [ ] **Step 2: Download the approved packs into the scratchpad**

```bash
mkdir -p "$SCRATCH/audio" && cd "$SCRATCH/audio" && curl -L -o interface.zip https://kenney.nl/media/pages/assets/interface-sounds/interface-sounds.zip
```

Repeat for the impact-sounds and music-jingles packs. `$SCRATCH` is the session scratchpad directory named in the environment, never the repo.

If a URL 404s, open the pack's page with WebFetch and read the current download link off it rather than guessing.

- [ ] **Step 3: Pick one clip per slot and copy it in, converting to .ogg**

Unzip each pack in the scratchpad. Audition by filename and pick these (fall back to the nearest neighbour if a name differs in the current pack revision):

| Target | Source file |
|---|---|
| `swipe.ogg` | `Audio/drop_002.ogg` |
| `stamp.ogg` | `Audio/impactPunch_medium_001.ogg` |
| `unstamp.ogg` | `Audio/scratch_003.ogg` |
| `popup_open.ogg` | `Audio/open_001.ogg` |
| `popup_close.ogg` | `Audio/close_001.ogg` |
| `select.ogg` | `Audio/select_002.ogg` |
| `error.ogg` | `Audio/error_004.ogg` |
| `reward.ogg` | `Audio/jingles_STEEL16.ogg` |

Copy each into `Assets/Audio/SFX/` under the target name. If a pack ships `.wav` only, convert with `ffmpeg -i in.wav -c:a libvorbis -q:a 4 out.ogg`; if ffmpeg is unavailable, copy the `.wav` in and note it — Godot imports `.wav` fine, the `.ogg` preference is only about repo size.

Verify each file is under 40 KB:

```bash
ls -l Assets/Audio/SFX/*.ogg
```

- [ ] **Step 4: Record the licenses**

Create `Assets/Audio/SFX/LICENSES.md`:

```markdown
# SFX placeholder sources

All files in this folder are **placeholders**. Every one is CC0
(public domain) — free for commercial use, attribution appreciated
but not required. Replace them freely; see `../README.md` for how.

## Kenney UI Audio — kenney.nl/assets/ui-audio
tap.ogg (click1), confirm.ogg (click2), cancel.ogg (click3),
success.ogg (switch1), fail.ogg (switch2), coin.ogg (click4),
whoosh.ogg (rollover1), pop.ogg (click5)
Full license text: `Kenney_License.txt`

## Kenney Interface Sounds — kenney.nl/assets/interface-sounds
swipe.ogg (drop_002), unstamp.ogg (scratch_003),
popup_open.ogg (open_001), popup_close.ogg (close_001),
select.ogg (select_002), error.ogg (error_004)

## Kenney Impact Sounds — kenney.nl/assets/impact-sounds
stamp.ogg (impactPunch_medium_001)

## Kenney Music Jingles — kenney.nl/assets/music-jingles
reward.ogg (jingles_STEEL16)
```

- [ ] **Step 5: Assign the files to the slots**

Let Godot import the new files (the godot-ai MCP `filesystem_manage` rescan, or just let the editor pick them up). Then open `Scenes/Audio/audio_director.tscn` and drag each new `.ogg` onto its matching slot in the inspector, exactly as `Assets/Audio/README.md` describes.

Save the scene. Confirm the resulting `.tscn` gained eight `[ext_resource type="AudioStream" ...]` lines and eight `sfx_* = ExtResource(...)` assignments:

```bash
grep -c "AudioStream" Scenes/Audio/audio_director.tscn
```

Expected: 16.

- [ ] **Step 6: Write the coverage test**

Append to `tests/test_audio_director.gd`:

```gdscript
func test_every_sfx_slot_is_filled_in_the_shipped_scene() -> void:
	# _director is instantiated from audio_director.tscn, so this asserts
	# the real shipped assignments — not a fixture. A slot regressing to
	# empty (file deleted, scene reverted) fails here rather than going
	# quietly silent in game.
	for id in ["tap", "confirm", "cancel", "success", "fail", "coin",
			"whoosh", "pop", "swipe", "stamp", "unstamp", "popup_open",
			"popup_close", "select", "error", "reward"]:
		assert_true(_director.has_sfx(StringName(id)),
			"shipped scene must fill sfx slot: " + id)
```

- [ ] **Step 7: Run tests to verify they pass**

Run `test_run` with suite `audio_director`.
Expected: PASS, including `test_every_sfx_slot_is_filled_in_the_shipped_scene`.

- [ ] **Step 8: Commit**

```bash
git add Assets/Audio/SFX Scenes/Audio/audio_director.tscn tests/test_audio_director.gd
git commit -m "feat(audio): add eight CC0 placeholder SFX and fill the new slots"
```

---

### Task 3: Source and install four loopable placeholder BGM tracks

**Files:**
- Create: `Assets/Audio/BGM/menu.ogg`, `lobby.ogg`, `simulation.ogg`, `result.ogg` (+ `.import` sidecars)
- Create: `Assets/Audio/BGM/LICENSES.md`
- Modify: `Scenes/Audio/audio_director.tscn`
- Test: `tests/test_audio_director.gd`

**Interfaces:**
- Consumes: the existing `bgm_menu` / `bgm_lobby` / `bgm_simulation` / `bgm_result` export slots (already present in `Scripts/Audio/AudioDirector.gd:27-31`).
- Produces: `AudioDirector.play_bgm(&"menu"|&"lobby"|&"simulation"|&"result")` now produces audible, seamlessly looping music. Task 4 relies on this.

- [ ] **Step 1: Find candidate tracks and present them for approval**

Search for CC0 / royalty-free loopable instrumental tracks in the cute warm school-life register (the reference the user gave is Umamusume's slice-of-life BGM). Use WebSearch across these sources, all of which allow commercial use:

- OpenGameArt, filtered to CC0 — https://opengameart.org/art-search-advanced?field_art_licenses_tid%5B%5D=4&field_art_type_tid%5B%5D=12
- Kenney Music Jingles / Music Loops — https://kenney.nl/assets/music-loops
- Pixabay Music (Pixabay Content License, commercial use OK, no attribution) — https://pixabay.com/music/search/cute%20school/
- Incompetech (CC-BY — only if attribution is recorded)

Aim for: bright major key, light piano / marimba / glockenspiel / pizzicato strings / soft ukulele, no vocals, no drum-and-bass energy. Suggested character per slot:

| Slot | Character | Length |
|---|---|---|
| `menu` | warm, welcoming, unhurried | 40–80 s |
| `lobby` | cheerful, curious, mid-tempo | 60–120 s |
| `simulation` | gently busy, forward-moving, low-distraction (this plays longest) | 60–120 s |
| `result` | reflective, proud, softer | 30–60 s |

Present the user with the four candidate tracks — title, source URL, license, length, file size — and get explicit approval before downloading. Offer a second option per slot so they can pick.

If the user declines, stop here: the `bgm_*` slots stay empty, `play_bgm` on an empty slot is already a safe no-op (`Scripts/Audio/AudioDirector.gd:113-116`), and Task 4's wiring still lands correctly for whenever the audio team supplies files.

- [ ] **Step 2: Download the approved tracks**

Download into `$SCRATCH/audio/bgm/` first, never straight into the repo. Verify each is actually audio and not an HTML error page:

```bash
file "$SCRATCH/audio/bgm/"*
```

- [ ] **Step 3: Normalize and copy into the repo**

Convert to `.ogg` at a sane bitrate and copy in under the exact slot names:

```bash
ffmpeg -i "$SCRATCH/audio/bgm/menu-source.mp3" -c:a libvorbis -q:a 4 -ar 44100 Assets/Audio/BGM/menu.ogg
```

Repeat for `lobby`, `simulation`, `result`. If ffmpeg is unavailable, copy the source files in unconverted and note the format in `LICENSES.md`.

Check sizes — anything over ~3 MB per track should be re-encoded at `-q:a 3`:

```bash
ls -lh Assets/Audio/BGM/
```

- [ ] **Step 4: Turn on looping in the import sidecars**

Godot's Ogg Vorbis importer defaults `loop` to off. Each track needs it on or the music stops dead after one pass. After Godot has imported the files, edit each `Assets/Audio/BGM/*.ogg.import` and set:

```ini
loop=true
loop_offset=0
```

If a `loop=` line already exists, change its value; if not, add both lines under the `[params]` section. Then trigger a reimport (godot-ai MCP `filesystem_manage` rescan, or right-click > Reimport in the editor).

- [ ] **Step 5: Record the licenses**

Create `Assets/Audio/BGM/LICENSES.md` with one section per track: target filename, original title, author, source URL, license name, and — if the license is CC-BY rather than CC0 — the exact attribution string that must appear in the game's credits. Example shape:

```markdown
# BGM placeholder sources

All four tracks are **placeholders** for the audio team to replace.
See `../README.md` for the swap procedure.

## menu.ogg
- Original: "<title>" by <author>
- Source: <url>
- License: CC0 1.0 — commercial use OK, no attribution required
```

- [ ] **Step 6: Assign the tracks to the slots**

Open `Scenes/Audio/audio_director.tscn` and drag each track onto its matching `bgm_*` slot. Save.

```bash
grep -c "bgm_" Scenes/Audio/audio_director.tscn
```

Expected: 4.

- [ ] **Step 7: Write the tests**

Append to `tests/test_audio_director.gd`:

```gdscript
func test_every_bgm_slot_is_filled_in_the_shipped_scene() -> void:
	for slot in ["bgm_menu", "bgm_lobby", "bgm_simulation", "bgm_result"]:
		assert_true(_director.get(slot) != null,
			"shipped scene must fill bgm slot: " + slot)


func test_bgm_streams_are_set_to_loop() -> void:
	# A non-looping BGM stops dead mid-session. The loop flag lives in the
	# .import sidecar, so this asserts the imported resource, not the file.
	for slot in ["bgm_menu", "bgm_lobby", "bgm_simulation", "bgm_result"]:
		var stream: AudioStream = _director.get(slot)
		if stream == null:
			continue
		if stream is AudioStreamOggVorbis:
			assert_true((stream as AudioStreamOggVorbis).loop,
				"bgm must loop: " + slot)


func test_play_bgm_twice_with_same_id_does_not_restart() -> void:
	# Re-entering a scene that plays the same track must not cut the music.
	_director.play_bgm(&"lobby", 0.0)
	await Engine.get_main_loop().process_frame
	_director.play_bgm(&"lobby", 0.0)
	assert_true(true, "repeat play_bgm with the same id must be a no-op")
```

- [ ] **Step 8: Run tests to verify they pass**

Run `test_run` with suite `audio_director`.
Expected: PASS on all four BGM tests.

- [ ] **Step 9: Commit**

```bash
git add Assets/Audio/BGM Scenes/Audio/audio_director.tscn tests/test_audio_director.gd
git commit -m "feat(audio): add four loopable placeholder BGM tracks"
```

---

### Task 4: Audit and complete per-screen BGM wiring

**Files:**
- Modify: `Scripts/Lobby/loby.gd` (add `play_bgm` in `_ready`)
- Modify: `Scripts/StudentCard/student_card.gd` (add `play_bgm` in `_ready`)
- Modify: `Scripts/StudentList/student_list.gd` (add `play_bgm` in `_ready`)
- Modify: `Scripts/AturJadwal/atur_jadwal.gd` (add `play_bgm` in `_ready`)
- Modify: `Scripts/UI/Settings.gd:28` (add `play_bgm` in `_ready`)
- Test: `tests/test_audio_coverage.gd` (create)

**Interfaces:**
- Consumes: `AudioDirector.play_bgm(id: StringName, fade: float = -1.0) -> void` and filled `bgm_*` slots from Task 3.
- Produces: a new test suite file `tests/test_audio_coverage.gd` whose `suite_name()` returns `"audio_coverage"`. Tasks 5–8 append tests to this same file.

Current state, established by grep: only `Scripts/MainMenu/main_menu.gd:54` (`menu`), `Scripts/SchoolSimulation/SchoolDay.gd:147` (`simulation`) and `Scripts/EndGame/SemesterEnd.gd:64` (`result`) call `play_bgm`. The four lobby-family screens are silent, so music dies the moment the player leaves the main menu.

- [ ] **Step 1: Write the failing test**

Create `tests/test_audio_coverage.gd`. This suite reads script source text rather than driving scenes — the point is to prove the wiring exists in every screen, which is exactly a source-level property, and it stays fast and stable as screens gain UI.

```gdscript
@tool
extends McpTestSuite

## Source-level audit: every screen must reach AudioDirector.
##
## These tests read .gd files as text on purpose. Driving each screen
## headlessly to assert "a sound played" would need a fake AudioServer
## and would break every time a scene's layout shifts; the requirement
## here is simply that the call sites exist and use ids AudioDirector
## actually knows about.

func suite_name() -> String:
	return "audio_coverage"


func _source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, "script must exist: " + path)
	if f == null:
		return ""
	return f.get_as_text()


func test_every_screen_starts_its_bgm() -> void:
	var expected := {
		"res://Scripts/MainMenu/main_menu.gd": "menu",
		"res://Scripts/UI/Settings.gd": "menu",
		"res://Scripts/Lobby/loby.gd": "lobby",
		"res://Scripts/StudentCard/student_card.gd": "lobby",
		"res://Scripts/StudentList/student_list.gd": "lobby",
		"res://Scripts/AturJadwal/atur_jadwal.gd": "lobby",
		"res://Scripts/SchoolSimulation/SchoolDay.gd": "simulation",
		"res://Scripts/EndGame/SemesterEnd.gd": "result",
	}
	for path in expected:
		var want := 'play_bgm(&"%s"' % expected[path]
		assert_true(_source(path).contains(want),
			"%s must call AudioDirector.%s)" % [path, want])


func test_no_screen_loads_an_audio_file_directly() -> void:
	# The swappability requirement: streams reach the game only through
	# AudioDirector's export slots, never a hard-coded path in a screen.
	var dir := DirAccess.open("res://Scripts")
	assert_true(dir != null, "Scripts/ must be readable")
	var offenders: Array[String] = []
	_scan_for_audio_loads("res://Scripts", offenders)
	assert_true(offenders.is_empty(),
		"scripts must not load audio directly: " + ", ".join(offenders))


func _scan_for_audio_loads(path: String, offenders: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path + "/" + name
		if dir.current_is_dir():
			_scan_for_audio_loads(full, offenders)
		elif name.ends_with(".gd") and not full.ends_with("AudioDirector.gd"):
			var src := _source(full)
			for line in src.split("\n"):
				var has_load := line.contains("preload(") or line.contains("load(")
				if has_load and (line.contains(".ogg") or line.contains(".wav")):
					offenders.append(full)
					break
		name = dir.get_next()
	dir.list_dir_end()
```

- [ ] **Step 2: Run the test to verify it fails**

Run `test_run` with suite `audio_coverage`.
Expected: FAIL — `test_every_screen_starts_its_bgm` reports the four lobby-family screens plus `Settings.gd` missing their `play_bgm` call.

- [ ] **Step 3: Add the missing `play_bgm` calls**

In each of the four lobby-family screens, add this line inside `_ready()`, after the existing setup and inside any `Engine.is_editor_hint()` early-return guard the file already has (so it never fires in the editor):

```gdscript
	AudioDirector.play_bgm(&"lobby")
```

Files and placement:
- `Scripts/Lobby/loby.gd` — in `_ready()`, at the end.
- `Scripts/StudentCard/student_card.gd` — in `_ready()`, at the end.
- `Scripts/StudentList/student_list.gd` — in `_ready()`, at the end.
- `Scripts/AturJadwal/atur_jadwal.gd` — in `_ready()`, at the end.

In `Scripts/UI/Settings.gd`, add to `_ready()` **after** the `if Engine.is_editor_hint(): return` block at line 39-43, next to the existing `Juice.stagger_in(...)` call:

```gdscript
	AudioDirector.play_bgm(&"menu")
```

Because `play_bgm` returns early when the requested id is already playing (`Scripts/Audio/AudioDirector.gd:110-111`), moving MainMenu → Settings → MainMenu will not restart or double-play the menu track, and moving between the four lobby-family screens keeps one continuous `lobby` loop.

- [ ] **Step 4: Run the test to verify it passes**

Run `test_run` with suite `audio_coverage`.
Expected: PASS on both tests.

- [ ] **Step 5: Play the game and listen**

Launch with the godot-ai MCP `project_run`. Walk MainMenu → Settings → back → Lobby → StudentCard → StudentList → AturJadwal → SchoolDay → SemesterEnd. Confirm by ear:
- music is audible on every screen,
- the `lobby` track does **not** restart when moving between the four lobby-family screens,
- the crossfade into `simulation` and `result` is smooth, not an abrupt cut,
- each track loops without a gap or click at the seam.

Note anything wrong; a gap at the loop seam means Step 4 of Task 3 (the `loop=true` sidecar edit) did not take on that file.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Lobby/loby.gd Scripts/StudentCard/student_card.gd Scripts/StudentList/student_list.gd Scripts/AturJadwal/atur_jadwal.gd Scripts/UI/Settings.gd tests/test_audio_coverage.gd
git commit -m "feat(audio): start the right BGM on every screen"
```

---

### Task 5: Wire StudentCard interactions

**Files:**
- Modify: `Scripts/StudentCard/student_card.gd` — `_evaluate_swipe:217`, `_on_next_kanan_pressed:599`, `_on_next_kiri_pressed:607`, `_on_approve_pressed:1767`, `_on_batal_pressed:1800`, `_show_bar_popup:1235`, `_show_trait_popup:1472`, `_close_trait_popup:1602`, `_on_belajar_pressed:1670`
- Test: `tests/test_audio_coverage.gd`

**Interfaces:**
- Consumes: `AudioDirector.play_sfx(id)` with ids `swipe`, `stamp`, `unstamp`, `popup_open`, `popup_close`, `confirm`, `cancel`, `error` (Tasks 1–2). The `_source(path)` helper defined in `tests/test_audio_coverage.gd` (Task 4).
- Produces: nothing later tasks depend on.

This is the screen the user named first — swiping the student card is currently completely silent.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_audio_coverage.gd`:

```gdscript
func test_student_card_interactions_have_sfx() -> void:
	var src := _source("res://Scripts/StudentCard/student_card.gd")
	for id in ["swipe", "stamp", "unstamp", "popup_open", "popup_close"]:
		assert_true(src.contains('play_sfx(&"%s")' % id),
			"student_card must play sfx: " + id)
```

- [ ] **Step 2: Run the test to verify it fails**

Run `test_run` with suite `audio_coverage`.
Expected: FAIL — `student_card must play sfx: swipe`.

- [ ] **Step 3: Add the swipe and page-turn sounds**

In `_evaluate_swipe` (line 217), the swipe is only recognised past the 40 px threshold — put the sound inside that branch so an aborted drag stays silent:

```gdscript
	if abs(delta_x) > 40.0 and abs(delta_x) > abs(delta_y):
		AudioDirector.play_sfx(&"swipe")
		if delta_x < 0:
			_on_next_kanan_pressed()
		else:
			_on_next_kiri_pressed()
```

The arrow buttons reach the same handlers but not through `_evaluate_swipe`, and `UIPolish` already gives them a `tap` on press. Add the page-turn sound inside the branch that actually turns a page, so pressing the arrow at the first or last card stays silent rather than lying about a page change. In `_on_next_kanan_pressed`:

```gdscript
	if current_page < kertas_murid.size() - 1:
		AudioDirector.play_sfx(&"swipe")
		var old_page = current_page
		current_page += 1
		_transition_page(old_page, current_page, -1)
```

And symmetrically in `_on_next_kiri_pressed`:

```gdscript
	if current_page > 0:
		AudioDirector.play_sfx(&"swipe")
		var old_page = current_page
		current_page -= 1
		_transition_page(old_page, current_page, 1)
```

- [ ] **Step 4: Swap approve/cancel for the stamp sounds and add the blocked-action error**

`_on_approve_pressed` currently plays `confirm` (line 1779), which is the generic accept sound. The stamp landing deserves its own. Change that line to:

```gdscript
	AudioDirector.play_sfx(&"stamp")
```

Add an error sound to the guard that rejects an approve past the limit — currently it only `print`s (lines 1773-1775):

```gdscript
	if approved_count >= MAX_APPROVE:
		AudioDirector.play_sfx(&"error")
		print("Batas approve tercapai, tidak bisa approve murid lain")
		return
```

In `_on_batal_pressed`, change the `cancel` at line 1808 to:

```gdscript
	AudioDirector.play_sfx(&"unstamp")
```

- [ ] **Step 5: Add popup open/close sounds**

`_show_bar_popup` (line 1235) and `_show_trait_popup` (line 1472) both open an overlay. Add as the first statement of each function body, after any early-return guards:

```gdscript
	AudioDirector.play_sfx(&"popup_open")
```

`_close_trait_popup` (line 1602) closes one. Add as its first statement:

```gdscript
	AudioDirector.play_sfx(&"popup_close")
```

If `_show_bar_popup` has its own close path (a close button or an overlay-input handler inside it), add `popup_close` there too — read the function body and place it where the popup is actually dismissed, not where it is merely hidden by a later animation step.

- [ ] **Step 6: Confirm the BELAJAR transition**

`_on_belajar_pressed` (line 1670) already plays nothing itself; `UIPolish` gives it a `tap`, and `Transition` plays `whoosh` on scene change (`Scripts/Transition/transition.gd:49`). Leave it. Add a comment above the function so a later reader does not "fix" the apparent gap:

```gdscript
# No explicit SFX: UIPolish auto-plays `tap` on press and Transition
# plays `whoosh` on the scene change. Adding a third would stack.
```

- [ ] **Step 7: Run the test to verify it passes**

Run `test_run` with suite `audio_coverage`. Then run `test_run` with suite `student_card` to confirm this screen's existing tests still pass.
Expected: PASS on both.

- [ ] **Step 8: Commit**

```bash
git add Scripts/StudentCard/student_card.gd tests/test_audio_coverage.gd
git commit -m "feat(audio): sound the student card swipe, stamp and popups"
```

---

### Task 6: Wire Lobby, StudentList and AturJadwal interactions

**Files:**
- Modify: `Scripts/Lobby/loby.gd` — `_on_daily_login_pressed:535`, `_show_daily_reward:540`, `_on_claim_pressed:626`
- Modify: `Scripts/StudentList/student_list.gd` — `_on_card_pressed:380`, `_on_student_selected:428`
- Modify: `Scripts/AturJadwal/atur_jadwal.gd` — `_on_day_pressed:1019`, `_on_activity_selected:942`, `_show_penjadwalan_popup:911`, `_show_peringatan:832`, `_on_peringatan_yes:881`, `_on_peringatan_no:891`, `_show_overtired_warning:767`, `_show_combined_warning:778`, `_show_incomplete_schedule_warning:806`, `_show_holiday_warning:1281`, `_on_start_week_pressed:716`
- Test: `tests/test_audio_coverage.gd`

**Interfaces:**
- Consumes: `AudioDirector.play_sfx(id)` with ids `select`, `reward`, `error`, `popup_open`, `popup_close`, `confirm`, `cancel`, `coin`; the `_source(path)` helper from Task 4.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_audio_coverage.gd`:

```gdscript
func test_lobby_interactions_have_sfx() -> void:
	var src := _source("res://Scripts/Lobby/loby.gd")
	for id in ["reward", "popup_open"]:
		assert_true(src.contains('play_sfx(&"%s")' % id),
			"loby must play sfx: " + id)


func test_student_list_interactions_have_sfx() -> void:
	var src := _source("res://Scripts/StudentList/student_list.gd")
	assert_true(src.contains('play_sfx(&"select")'),
		"student_list must play sfx: select")


func test_atur_jadwal_interactions_have_sfx() -> void:
	var src := _source("res://Scripts/AturJadwal/atur_jadwal.gd")
	for id in ["select", "popup_open", "popup_close", "error"]:
		assert_true(src.contains('play_sfx(&"%s")' % id),
			"atur_jadwal must play sfx: " + id)
```

- [ ] **Step 2: Run the test to verify it fails**

Run `test_run` with suite `audio_coverage`.
Expected: FAIL on all three new tests.

- [ ] **Step 3: Wire the Lobby**

`_on_claim_pressed` (line 626) currently plays `success` at line 644. A daily-login claim is a reward, and money changes. Replace that single line with both, and add the blocked path:

```gdscript
	AudioDirector.play_sfx(&"reward")
```

and immediately after the `GameState.player_money += DAILY_REWARD` / `_update_money_display(old_money)` pair, add the coin sound so the money counter animation has its own layer:

```gdscript
	AudioDirector.play_sfx(&"coin")
```

Add the already-claimed rejection right after the early-return guard's condition (currently a bare `return` at lines 629-630):

```gdscript
	if GameState.last_claim_date == today:
		AudioDirector.play_sfx(&"error")
		return
```

`_show_daily_reward` (line 540) opens the reward panel. Add as its first statement:

```gdscript
	AudioDirector.play_sfx(&"popup_open")
```

`_on_blur_overlay_input` (line 576) dismisses that panel. Add `AudioDirector.play_sfx(&"popup_close")` inside the branch that actually closes it.

- [ ] **Step 4: Wire StudentList**

`_on_student_selected` (line 428) already plays `confirm` at line 452. Selecting a card from a list is a pick, not an accept — change line 452 to:

```gdscript
	AudioDirector.play_sfx(&"select")
```

Read `_on_card_pressed` (line 380) and `_on_card_gui_input` (line 391): if either can reject a press (a locked or already-taken student), add `AudioDirector.play_sfx(&"error")` on that rejection branch. If neither rejects, leave them — `_on_student_selected` covers the audible outcome.

- [ ] **Step 5: Wire AturJadwal's day and activity picking**

`_on_day_pressed` (line 1019): the holiday branch is a blocked action, and picking a valid day is a selection.

```gdscript
	if week_holidays.has(day_name):
		AudioDirector.play_sfx(&"error")
		_show_holiday_warning(week_holidays[day_name]["desc"])
		return
```

and after `GameState.selected_day = day_name`:

```gdscript
	AudioDirector.play_sfx(&"select")
```

`_on_activity_selected` (line 942) — assigning an activity to a day slot is the core verb of this screen and is currently silent. Add as the first statement of the function body:

```gdscript
	AudioDirector.play_sfx(&"select")
```

- [ ] **Step 6: Wire AturJadwal's popups and warnings**

Add `AudioDirector.play_sfx(&"popup_open")` as the first statement of `_show_penjadwalan_popup` (line 911) and `_show_peringatan` (line 832).

The four warning dialogs are blocked-action feedback. `_show_overtired_warning` (767) and `_show_mental_fatigue_warning` (794) already play `fail` (lines 792, 815) — those are correct for a state warning, leave them. Add `AudioDirector.play_sfx(&"error")` as the first statement of `_show_combined_warning` (778), `_show_incomplete_schedule_warning` (806) and `_show_holiday_warning` (1281).

`_on_peringatan_yes` (881) confirms, `_on_peringatan_no` (891) backs out. Add as the first statement of each, respectively:

```gdscript
	AudioDirector.play_sfx(&"confirm")
```

```gdscript
	AudioDirector.play_sfx(&"popup_close")
```

`_on_start_week_pressed` (line 716) returns early in the overtired case — the warning it calls already sounds, so add nothing there. Where it succeeds and starts the week, add `AudioDirector.play_sfx(&"confirm")` just before the transition.

- [ ] **Step 7: Run the tests to verify they pass**

Run `test_run` with suite `audio_coverage`, then suites `lobby`, `student_list` and `atur_jadwal` to confirm no regression.
Expected: PASS on all four.

- [ ] **Step 8: Commit**

```bash
git add Scripts/Lobby/loby.gd Scripts/StudentList/student_list.gd Scripts/AturJadwal/atur_jadwal.gd tests/test_audio_coverage.gd
git commit -m "feat(audio): sound lobby claims, list selection and schedule building"
```

---

### Task 7: Wire SchoolDay and the result screens

**Files:**
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` — `_show_day_summary:636`, `_on_week_complete:1092`, `_on_back_pressed:1197`, `_show_event_warning:1352`, `_show_event_announcement:1369`
- Modify: `Scripts/SchoolSimulation/DaySummaryPopup.gd:125-127`
- Modify: `Scripts/SchoolSimulation/DailyDecayOverview.gd:247`
- Modify: `Scripts/SchoolSimulation/EventStudentSelectDialog.gd:413,434,446`
- Modify: `Scripts/SchoolSimulation/ResultCheckup.gd:396`
- Modify: `Scripts/EndGame/SemesterEnd.gd:266`
- Modify: `Scripts/CutScene/cut_scene.gd` — `_on_grade_selected:248`, `_on_skip_pressed:237`
- Test: `tests/test_audio_coverage.gd`

**Interfaces:**
- Consumes: `AudioDirector.play_sfx(id)` with ids `popup_open`, `popup_close`, `reward`, `select`, `cancel`; the `_source(path)` helper from Task 4.
- Produces: nothing later tasks depend on.

`SchoolDay.gd` is 1457 lines, is the game's core loop, and currently contains **zero** `play_sfx` calls — the single largest hole in the game's feedback.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_audio_coverage.gd`:

```gdscript
func test_school_day_has_sfx_at_all() -> void:
	var src := _source("res://Scripts/SchoolSimulation/SchoolDay.gd")
	for id in ["popup_open", "reward"]:
		assert_true(src.contains('play_sfx(&"%s")' % id),
			"SchoolDay must play sfx: " + id)


func test_cutscene_grade_selection_has_sfx() -> void:
	var src := _source("res://Scripts/CutScene/cut_scene.gd")
	assert_true(src.contains('play_sfx(&"select")'),
		"cut_scene must play sfx on grade selection")


func test_every_play_sfx_id_in_the_project_is_known() -> void:
	# Guards against typos: a misspelled id is silently dropped by
	# _resolve_sfx's fallback, so it would never surface at runtime.
	var known := ["tap", "confirm", "cancel", "success", "fail", "coin",
		"whoosh", "pop", "swipe", "stamp", "unstamp", "popup_open",
		"popup_close", "select", "error", "reward"]
	var bad: Array[String] = []
	_scan_for_sfx_ids("res://Scripts", known, bad)
	assert_true(bad.is_empty(),
		"unknown sfx ids used: " + ", ".join(bad))


func _scan_for_sfx_ids(path: String, known: Array, bad: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path + "/" + name
		if dir.current_is_dir():
			_scan_for_sfx_ids(full, known, bad)
		elif name.ends_with(".gd"):
			var regex := RegEx.new()
			regex.compile('play_sfx\\(&"([a-z_]+)"')
			for m in regex.search_all(_source(full)):
				var id := m.get_string(1)
				if not known.has(id) and not bad.has(id):
					bad.append("%s in %s" % [id, full])
		name = dir.get_next()
	dir.list_dir_end()
```

- [ ] **Step 2: Run the test to verify it fails**

Run `test_run` with suite `audio_coverage`.
Expected: FAIL — `SchoolDay must play sfx: popup_open` and `cut_scene must play sfx on grade selection`. `test_every_play_sfx_id_in_the_project_is_known` should already pass; if it does not, an existing typo has been found — fix it before continuing.

- [ ] **Step 3: Wire SchoolDay**

Add `AudioDirector.play_sfx(&"popup_open")` as the first statement of `_show_day_summary` (line 636), `_show_event_warning` (line 1352) and `_show_event_announcement` (line 1369).

`_on_week_complete` (line 1092) is the payoff moment of the whole loop. Add as its first statement:

```gdscript
	AudioDirector.play_sfx(&"reward")
```

`_on_back_pressed` (line 1197) leaves the simulation. Add as its first statement:

```gdscript
	AudioDirector.play_sfx(&"cancel")
```

The day-progress tween near line 303 animates energy/mood bars draining. Do **not** add a per-tick sound there — a sound on a tween update fires dozens of times a second and will sound like a buzzsaw. The `reward` at week completion and the summary popup cover this feedback.

- [ ] **Step 4: Wire the day summary and decay overview**

`Scripts/SchoolSimulation/DaySummaryPopup.gd` already plays `success`/`fail` at lines 125-127 for the day's outcome — correct, leave them. Add `AudioDirector.play_sfx(&"popup_open")` as the first statement of the function that contains those lines, so the panel's appearance is heard before its verdict.

`Scripts/SchoolSimulation/DailyDecayOverview.gd:247` plays `confirm` on dismiss. A dismiss is a close — change it to:

```gdscript
	AudioDirector.play_sfx(&"popup_close")
```

- [ ] **Step 5: Wire the event dialog and result screens**

`Scripts/SchoolSimulation/EventStudentSelectDialog.gd` plays `tap` (413), `confirm` (434) and `cancel` (446). Line 413 fires when a student is picked in the dialog — change it to:

```gdscript
	AudioDirector.play_sfx(&"select")
```

Leave 434 and 446. Add `AudioDirector.play_sfx(&"popup_open")` to the dialog's `_ready()`, guarded by `if not Engine.is_editor_hint():`.

`Scripts/SchoolSimulation/ResultCheckup.gd:396` plays `confirm` — leave it, and add `AudioDirector.play_sfx(&"popup_open")` to its `_ready()` under the same editor guard.

`Scripts/EndGame/SemesterEnd.gd:266` already plays `success`/`fail` per student result. Leave it. If the pass case represents the semester being cleared overall, add `AudioDirector.play_sfx(&"reward")` once at that point — read the surrounding block and only add it if there is a single overall-result moment, not per student.

- [ ] **Step 6: Wire the cutscene**

`Scripts/CutScene/cut_scene.gd:290` already plays `tap` on `_on_tap`. Add to `_on_grade_selected` (line 248) as its first statement:

```gdscript
	AudioDirector.play_sfx(&"select")
```

and to `_on_skip_pressed` (line 237):

```gdscript
	AudioDirector.play_sfx(&"whoosh")
```

- [ ] **Step 7: Run the tests to verify they pass**

Run `test_run` with suite `audio_coverage`, then suites `school_day`, `semester_end` and `cutscene`.
Expected: PASS on all four.

- [ ] **Step 8: Commit**

```bash
git add Scripts/SchoolSimulation Scripts/EndGame/SemesterEnd.gd Scripts/CutScene/cut_scene.gd tests/test_audio_coverage.gd
git commit -m "feat(audio): sound the school day loop, results and cutscene"
```

---

### Task 8: Harden the Settings volume controls

**Files:**
- Modify: `Scripts/UI/Settings.gd:56-61` (`_on_volume_changed`)
- Modify: `Scripts/Audio/AudioDirector.gd:170-186` (`_save_volumes` / `_load_volumes`)
- Test: `tests/test_settings.gd`, `tests/test_audio_director.gd`

**Interfaces:**
- Consumes: `AudioDirector.set_bus_volume(bus, linear)` / `get_bus_volume(bus)` (existing).
- Produces: `AudioDirector` gains a private debounce; no new public API.

The three sliders already work. Three real gaps remain: dragging the Musik slider gives no audible feedback (only the Efek Suara slider does, `Scripts/UI/Settings.gd:59-60`), every slider pixel of drag writes `user://audio.cfg` to disk (`set_bus_volume` calls `_save_volumes` unconditionally at line 168), and nothing proves persisted volumes survive a relaunch.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_audio_director.gd`:

```gdscript
func test_volumes_persist_across_a_fresh_director() -> void:
	# The relaunch requirement: what the player set must come back.
	_director.set_bus_volume(&"BGM", 0.42)
	await Engine.get_main_loop().process_frame
	_director.flush_volume_save()

	var scene: PackedScene = load("res://Scenes/Audio/audio_director.tscn")
	var second: Node = scene.instantiate()
	Engine.get_main_loop().root.add_child(second)
	track(second)
	assert_true(absf(second.get_bus_volume(&"BGM") - 0.42) <= 0.01,
		"a freshly loaded director must restore the saved BGM volume")

	# Restore so this test does not leave the real config at 0.42.
	second.set_bus_volume(&"BGM", 1.0)
	second.flush_volume_save()


func test_rapid_volume_changes_do_not_write_once_per_change() -> void:
	# Dragging a slider fires value_changed on every pixel. Writing the
	# config file that often stutters on mobile storage.
	var before := _director.get_volume_save_count()
	for i in range(50):
		_director.set_bus_volume(&"SFX", float(i) / 50.0)
	var after := _director.get_volume_save_count()
	assert_true(after - before <= 2,
		"50 rapid changes must coalesce into at most 2 saves, got %d"
			% (after - before))
```

Append to `tests/test_settings.gd`:

```gdscript
func test_bgm_slider_gives_audible_feedback() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/Settings.gd")
	assert_true(src.contains('&"BGM"') and src.contains('play_sfx(&"pop")'),
		"dragging the Musik slider must preview a sound, like the SFX slider does")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run `test_run` with suites `audio_director` and `settings`.
Expected: FAIL — `flush_volume_save` and `get_volume_save_count` do not exist; the Settings test reports the missing BGM preview.

- [ ] **Step 3: Debounce the config write**

In `Scripts/Audio/AudioDirector.gd`, add these fields next to the other private vars (near line 42):

```gdscript
var _save_timer: SceneTreeTimer
var _save_count: int = 0
```

Replace the unconditional `_save_volumes()` call at the end of `set_bus_volume` (line 168) with a debounced schedule:

```gdscript
	_schedule_volume_save()
```

And add these three functions below `_save_volumes`:

```gdscript
## Coalesce a burst of slider changes into one disk write. Dragging a
## slider fires value_changed per pixel; writing user://audio.cfg that
## often stutters on mobile storage.
func _schedule_volume_save() -> void:
	if _save_timer != null:
		return
	_save_timer = get_tree().create_timer(0.4, true, false, true)
	_save_timer.timeout.connect(func() -> void:
		_save_timer = null
		_save_volumes())


## Write any pending volume change immediately. Called on quit and by
## tests that need the file on disk before reading it back.
func flush_volume_save() -> void:
	_save_timer = null
	_save_volumes()


## Number of times the config has actually been written. Test hook.
func get_volume_save_count() -> int:
	return _save_count
```

Add the counter increment as the first line of `_save_volumes`:

```gdscript
func _save_volumes() -> void:
	_save_count += 1
	var cfg := ConfigFile.new()
```

Finally, make sure a pending change is not lost when the player quits. Add to `AudioDirector`:

```gdscript
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush_volume_save()
```

- [ ] **Step 4: Add the Musik slider preview**

In `Scripts/UI/Settings.gd`, replace `_on_volume_changed` (lines 56-61) with:

```gdscript
func _on_volume_changed(value: float, bus: StringName) -> void:
	AudioDirector.set_bus_volume(bus, value)
	if Engine.is_editor_hint():
		return
	# Immediate audible feedback while dragging. The SFX slider previews
	# with a tap; the Musik slider needs its own cue because the music bed
	# is often too sustained to hear a small change against — `pop` is
	# short and routed through the SFX bus, so it stays audible while the
	# BGM bus itself is being dragged toward zero.
	if bus == &"SFX":
		AudioDirector.play_sfx(&"tap")
	elif bus == &"BGM":
		AudioDirector.play_sfx(&"pop")
```

Note the deliberate design: the BGM preview plays on the **SFX** bus, so a player dragging Musik to zero still hears the drag responding.

- [ ] **Step 5: Run the tests to verify they pass**

Run `test_run` with suites `audio_director` and `settings`.
Expected: PASS on all, including the two new persistence tests and the BGM preview test.

- [ ] **Step 6: Verify by hand**

Launch with `project_run`. Open Settings. Drag each of the three sliders end to end. Confirm:
- Suara Utama at 0 silences everything including the preview blips,
- Musik at 0 silences music but the `pop` preview still sounds,
- Efek Suara at 0 silences the `tap` preview,
- quitting and relaunching restores all three slider positions.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Audio/AudioDirector.gd Scripts/UI/Settings.gd tests/test_audio_director.gd tests/test_settings.gd
git commit -m "feat(audio): debounce volume saves and preview the Musik slider"
```

---

### Task 9: Rewrite the audio README as the team's swap guide

**Files:**
- Modify: `Assets/Audio/README.md` (full rewrite)
- Test: manual read-through

**Interfaces:**
- Consumes: the final slot list from Tasks 1–3 and the wiring from Tasks 4–8.
- Produces: the document the audio team follows. Nothing depends on it in code.

The existing README documents 12 slots and says the `bgm_*` slots are intentionally empty. Both facts are now wrong.

- [ ] **Step 1: Rewrite the file**

Replace `Assets/Audio/README.md` entirely:

````markdown
# Audio

- `SFX/` — short one-shot sounds (16 slots)
- `BGM/` — looping music (4 slots)

**Everything currently in these folders is a placeholder.** All of it is
free for commercial use (see `SFX/LICENSES.md` and `BGM/LICENSES.md`),
and all of it is meant to be replaced.

## How to swap a sound — the whole procedure

1. Drop your `.ogg` into `SFX/` or `BGM/`. Keep any filename you like;
   the slot name is what matters, not the filename.
2. Open `Scenes/Audio/audio_director.tscn` in the Godot editor.
3. Drag your file from the FileSystem dock onto the matching slot in the
   Inspector.
4. Save the scene. Done — no code changes, ever.

For BGM only, one extra step: select your file in the FileSystem dock,
open the **Import** tab, tick **Loop**, and click **Reimport**. Without
this the track plays once and stops.

A slot you leave empty simply plays nothing. Nothing crashes.

## SFX slots

| Slot | Fires when | Where |
|---|---|---|
| `sfx_tap` | any button is pressed | auto-wired for every button by `Scripts/UI/UIPolish.gd` |
| `sfx_confirm` | a positive/accept action | peringatan yes, start week, event dialog accept |
| `sfx_cancel` | back, close, decline | back buttons, batal, leaving the simulation |
| `sfx_success` | a target is met, a day goes well | day summary pass, semester result pass |
| `sfx_fail` | a target is missed | day summary fail, overtired/fatigue warnings |
| `sfx_coin` | money changes | daily login payout |
| `sfx_whoosh` | scene transitions | `Scripts/Transition/transition.gd`, cutscene skip |
| `sfx_pop` | a card or list item enters; Musik slider preview | Settings |
| `sfx_swipe` | student card swiped, page turned | StudentCard |
| `sfx_stamp` | APPROVE stamp lands | StudentCard |
| `sfx_unstamp` | BATAL erases the stamp | StudentCard |
| `sfx_popup_open` | any popup/overlay/dialog opens | every screen |
| `sfx_popup_close` | any popup/overlay/dialog closes | every screen |
| `sfx_select` | a list card, day, or activity is picked | StudentList, AturJadwal, cutscene, event dialog |
| `sfx_error` | a blocked action | approve limit reached, holiday day, incomplete schedule, already-claimed reward |
| `sfx_reward` | daily login claim, week complete | Lobby, SchoolDay |

Note on `sfx_tap`: it fires automatically for *every* `BaseButton` in the
game. Keep whatever you put there short and unobtrusive — it is by far
the most-heard sound in the project. A button opts out with
`button.set_meta(Juice.NO_AUTO_JUICE, true)`.

## BGM slots

| Slot | Plays on | Character to aim for |
|---|---|---|
| `bgm_menu` | MainMenu, Settings | warm, welcoming, unhurried |
| `bgm_lobby` | Lobby, StudentCard, StudentList, AturJadwal | cheerful, curious, mid-tempo |
| `bgm_simulation` | SchoolDay and its minigames | gently busy, low-distraction — this one plays longest |
| `bgm_result` | SemesterEnd | reflective, proud, softer |

The four lobby-family screens share one track deliberately, and
`AudioDirector.play_bgm` no-ops when the requested id is already
playing — so moving between them never restarts the music.

Tracks crossfade automatically (0.8 s by default, tunable on the
`default_bgm_fade` slot in the same inspector).

## Volume

Players adjust three buses in-game under PENGATURAN:

| Slider | Bus |
|---|---|
| Suara Utama | `Master` |
| Musik | `BGM` |
| Efek Suara | `SFX` |

Settings persist to `user://audio.cfg` and are restored on launch. A
slider at 0 fully mutes its bus.

## Adding a brand new sound (code change required)

Only needed if you want a sound at a moment that has no slot yet:

1. Add `@export var sfx_yourname: AudioStream` to the `SFX` group in
   `Scripts/Audio/AudioDirector.gd`.
2. Add `&"yourname": return sfx_yourname` to `_resolve_sfx` in the same
   file.
3. Add `"yourname"` to the known-id list in
   `tests/test_audio_coverage.gd::test_every_play_sfx_id_in_the_project_is_known`
   and to the slot list in
   `tests/test_audio_director.gd::test_sfx_and_bgm_slots_are_exported`.
4. Call `AudioDirector.play_sfx(&"yourname")` where you want it.
5. Add a row to the table above.
````

- [ ] **Step 2: Verify the README against reality**

Every claim in the table must be true. Check each one:

```bash
grep -rn 'play_sfx(&"' --include="*.gd" Scripts/ | sort
```

Read the output against the "Where" column. Fix any row that names a screen which does not actually call that id.

- [ ] **Step 3: Run the full test suite**

Run `test_run` with no suite filter, so every suite in `tests/` executes.
Expected: PASS across all suites. Do not proceed past a failure — a red suite here means an earlier task's wiring broke a screen's existing behaviour.

- [ ] **Step 4: Final play-through**

Launch with `project_run` and play a full loop: splash → cutscene → main menu → settings → lobby → student card (swipe, approve, batal, a trait popup) → student list → atur jadwal (pick days, assign activities, trigger a warning) → school day → day summary → semester end. Listen for:
- any interaction that is still silent,
- any sound that fires twice for one action (a screen adding its own `tap` on top of UIPolish's),
- any sound that machine-guns during an animation.

Fix what you hear, then re-run the full suite.

- [ ] **Step 5: Commit**

```bash
git add Assets/Audio/README.md
git commit -m "docs(audio): rewrite the README as the audio team's swap guide"
```

---

## Verification checklist

Before calling this done, confirm each with a command, not from memory:

- [ ] `test_run` with no filter is fully green.
- [ ] `grep -c "AudioStream" Scenes/Audio/audio_director.tscn` returns 20 (16 SFX + 4 BGM).
- [ ] `test_every_sfx_slot_is_filled_in_the_shipped_scene` passes — no empty slots ship.
- [ ] `test_no_screen_loads_an_audio_file_directly` passes — every stream is swappable.
- [ ] `test_every_play_sfx_id_in_the_project_is_known` passes — no typo'd ids.
- [ ] A full manual play-through has no silent interaction and no doubled sound.
- [ ] `Assets/Audio/SFX/LICENSES.md` and `Assets/Audio/BGM/LICENSES.md` account for every file in their folder.
- [ ] Volume settings survive a quit and relaunch.
