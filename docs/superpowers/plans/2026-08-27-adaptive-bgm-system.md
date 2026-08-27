# Adaptive BGM System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `AudioDirector`'s flat "one id → one looping track" BGM model with a system that supports a shuffle-no-repeat playlist (Lobby), a fixed-order looping sequence (Akademis), true position-preserving pause/resume around minigames, and outcome-conditional track selection (win/lose, SeniBudaya variant) — then wire every scene in the game to it using the ten real audio files the user supplied.

**Architecture:** `AudioDirector` (`Scripts/Audio/AudioDirector.gd`, autoloaded from `Scenes/Audio/audio_director.tscn`) grows a third `AudioStreamPlayer` dedicated to minigame music, alongside its existing two-player (A/B) crossfade pair used for every other BGM context. The A/B pair gains a playlist mode; the minigame player gains a sequence-chaining mode. Every stream still reaches the game through an `@export` slot — no code ever loads an audio path directly.

**Tech Stack:** Godot 4.6 (Mobile renderer), GDScript, `McpTestSuite` in-editor test suites, `.mp3`/`.wav` source audio (the user's supplied files, not re-encoded).

**Spec:** `docs/superpowers/design/bgm-system-design.md`

## Global Constraints

- Godot **4.6**, Mobile renderer, GDScript only. Do not add addons.
- Every stream reaches the game through an `@export` slot on `AudioDirector`. **Never** `preload()` or `load()` a BGM path in a screen script (tests are exempt — they already load `Scenes/Audio/audio_director.tscn` directly).
- Any script the in-editor test runner instantiates needs `@tool` plus the established `Engine.is_editor_hint()` guard pattern (see `AudioDirector.gd:57-74`, `main_menu.gd`, `cut_scene.gd`, `splashscreen.gd` for the existing examples). Do not add or remove those guards except where a task explicitly says to.
- Existing bus names are exactly `Master`, `BGM`, `SFX`. Do not rename or add buses.
- Existing BGM ids that survive this pass unchanged: `&"simulation"`. Ids that are **renamed**: `&"menu"` → `&"titlescreen"`. Ids that are **retired and replaced**: `&"result"` → `&"result_win"` / `&"result_lose"`; `&"lobby"` moves from `play_bgm` to a new `play_bgm_playlist` method (same id, different method).
- Run tests with the godot-ai MCP tool `test_run`. There is no CLI test command in this project. Suite names used below: `audio_director`, `audio_coverage`, `main_menu`, `settings`, `cutscene`, `school_day`, `semester_end`, `lobby`, `student_card`, `student_list`, `atur_jadwal`, `boot_screens`.
- Five tests are **expected to fail for an environmental reason unrelated to this plan**, in every test run until the user restarts their Godot editor: `audio_director`'s `test_required_buses_exist`, `test_bus_volume_roundtrips`, `test_bus_volume_clamps_to_valid_range`, `test_volumes_persist_across_a_fresh_director`, and `settings`' `test_moving_a_slider_changes_the_bus_volume`. These fail because the long-running editor process holds a stale `AudioServer` without the `BGM`/`SFX` buses; the underlying bug is already fixed in `project.godot` and verified correct in a fresh game process. **Do not attempt to fix these. Do not call `project_run`** — the stale editor's autosave can re-corrupt `project.godot`'s bus-layout line on disk if the game is launched from it.
- No listening pass is possible in this pipeline. Every step ends with structural verification (the right call fires, the right property is set, the right file is assigned) — never a claim about how something sounds.
- Source audio lives at `C:\Users\Legion\Downloads\audio\` on the user's machine and must be copied (not moved) into the repo under `Assets/Audio/BGM/`.

---

### Task 1: Asset intake — copy files, set loop import settings, write credits

**Files:**
- Create: `Assets/Audio/BGM/titlescreen.mp3`, `introcutscene.mp3`, `loby_song1.mp3`, `loby_song2.mp3`, `loby_song3.mp3`, `loby_song4.mp3`, `schoolsimulation.mp3`, `result_win.mp3`, `result_lose.wav`, `minigame_akademis_1.wav`, `minigame_akademis_2.wav`, `minigame_akademis_3.wav`, `minigame_olahraga.mp3`, `minigame_senibudaya_batik.mp3`, `minigame_senibudaya_menari.mp3` (plus each file's auto-generated `.import` sidecar)
- Create: `Assets/Audio/BGM/CREDITS.md`
- Test: `tests/test_audio_director.gd` (new tests, appended)

**Interfaces:**
- Consumes: nothing from earlier tasks — this is the foundation task.
- Produces: fifteen real audio files on disk under `Assets/Audio/BGM/`, each with a Godot-generated `.import` sidecar whose loop setting is correct for that file's role. Tasks 2–5 assign these files to `AudioDirector` export slots and depend on the loop settings being right — a track meant to loop (titlescreen, introcutscene, schoolsimulation, result_win, result_lose, the 3 minigame single-track ids) must actually loop; a track meant to chain via the `finished` signal (the 4 lobby tracks, the 3 Akademis tracks) must **not** auto-loop, or `finished` never fires and the playlist/sequence never advances.

- [ ] **Step 1: Copy the source files into the repo under new names**

The user's files are at `C:\Users\Legion\Downloads\audio\`. Copy (not move) each into `Assets/Audio/BGM/` under the target name below — renaming as you copy avoids any later ambiguity about which file is which:

```bash
mkdir -p Assets/Audio/BGM
cp "C:/Users/Legion/Downloads/audio/titlescreen/titlescreen.mp3" Assets/Audio/BGM/titlescreen.mp3
cp "C:/Users/Legion/Downloads/audio/introcutscene/intro.mp3" Assets/Audio/BGM/introcutscene.mp3
cp "C:/Users/Legion/Downloads/audio/loby/song1.mp3" Assets/Audio/BGM/loby_song1.mp3
cp "C:/Users/Legion/Downloads/audio/loby/song2.mp3" Assets/Audio/BGM/loby_song2.mp3
cp "C:/Users/Legion/Downloads/audio/loby/song3.mp3" Assets/Audio/BGM/loby_song3.mp3
cp "C:/Users/Legion/Downloads/audio/loby/song4.mp3" Assets/Audio/BGM/loby_song4.mp3
cp "C:/Users/Legion/Downloads/audio/schoolsimulation/schoolday.mp3" Assets/Audio/BGM/schoolsimulation.mp3
cp "C:/Users/Legion/Downloads/audio/result/gamewin.mp3" Assets/Audio/BGM/result_win.mp3
cp "C:/Users/Legion/Downloads/audio/result/gameover.wav" Assets/Audio/BGM/result_lose.wav
cp "C:/Users/Legion/Downloads/audio/minigames/akademis/level1-step1.wav" Assets/Audio/BGM/minigame_akademis_1.wav
cp "C:/Users/Legion/Downloads/audio/minigames/akademis/level1-step2.wav" Assets/Audio/BGM/minigame_akademis_2.wav
cp "C:/Users/Legion/Downloads/audio/minigames/akademis/level1-step3.wav" Assets/Audio/BGM/minigame_akademis_3.wav
cp "C:/Users/Legion/Downloads/audio/minigames/olahraga/olahraga.mp3" Assets/Audio/BGM/minigame_olahraga.mp3
cp "C:/Users/Legion/Downloads/audio/minigames/senibudaya/batik.mp3" Assets/Audio/BGM/minigame_senibudaya_batik.mp3
cp "C:/Users/Legion/Downloads/audio/minigames/senibudaya/nariDangdut.mp3" Assets/Audio/BGM/minigame_senibudaya_menari.mp3
ls -la Assets/Audio/BGM/
```

Confirm all 15 files are present and non-empty (nonzero size) before continuing.

- [ ] **Step 2: Let Godot import the new files and inspect the generated sidecars**

Use the godot-ai MCP tool `filesystem_manage` with `{"op": "scan"}` to force Godot to notice the new files. Then read one `.mp3.import` file and one `.wav.import` file that Godot generated (e.g. `Assets/Audio/BGM/titlescreen.mp3.import` and `Assets/Audio/BGM/result_lose.wav.import`) to find the actual loop-related parameter keys for each importer type in this Godot version.

Godot 4.6's MP3 importer is expected to expose a simple `loop` boolean and `loop_offset` float under `[params]`, mirroring the existing `.ogg.import` sidecars already in this repo (see `Assets/Audio/SFX/tap.ogg.import` for the pattern — `loop=false` / `loop_offset=0`). Godot 4.6's WAV importer is expected to expose loop control under an `edit/loop_mode` key (a string enum — likely `"Disabled"` or `"Forward"`) rather than a plain bool, since WAV loop points are frame-based, not a simple on/off switch.

**Treat the actual generated file as the source of truth, not this expectation.** If what you read differs from the above (different key name, different value format), use what the file actually contains — report the real key names and value formats you found for both importer types in your task report, since this governs how you write Step 3.

- [ ] **Step 3: Set the loop flag correctly per file's role**

Using the real keys discovered in Step 2, edit each `.import` sidecar (or use the Godot editor's Import dock via `filesystem_manage`/editor tools if that proves more reliable than hand-editing the INI) so that:

**Loop ON** (these play forever until something else takes over):
- `titlescreen.mp3.import`
- `introcutscene.mp3.import`
- `schoolsimulation.mp3.import`
- `result_win.mp3.import`
- `result_lose.wav.import`
- `minigame_olahraga.mp3.import`
- `minigame_senibudaya_batik.mp3.import`
- `minigame_senibudaya_menari.mp3.import`

**Loop OFF** (these must fire `finished` so `AudioDirector` can chain to the next track):
- `loby_song1.mp3.import` through `loby_song4.mp3.import`
- `minigame_akademis_1.wav.import` through `minigame_akademis_3.wav.import`

After editing, reimport each changed file:

```
filesystem_manage(op="reimport", params={"paths": ["res://Assets/Audio/BGM/titlescreen.mp3", "res://Assets/Audio/BGM/introcutscene.mp3", "res://Assets/Audio/BGM/loby_song1.mp3", "res://Assets/Audio/BGM/loby_song2.mp3", "res://Assets/Audio/BGM/loby_song3.mp3", "res://Assets/Audio/BGM/loby_song4.mp3", "res://Assets/Audio/BGM/schoolsimulation.mp3", "res://Assets/Audio/BGM/result_win.mp3", "res://Assets/Audio/BGM/result_lose.wav", "res://Assets/Audio/BGM/minigame_akademis_1.wav", "res://Assets/Audio/BGM/minigame_akademis_2.wav", "res://Assets/Audio/BGM/minigame_akademis_3.wav", "res://Assets/Audio/BGM/minigame_olahraga.mp3", "res://Assets/Audio/BGM/minigame_senibudaya_batik.mp3", "res://Assets/Audio/BGM/minigame_senibudaya_menari.mp3"]})
```

- [ ] **Step 4: Write the failing test proving loop settings are correct**

Append to `tests/test_audio_director.gd`. This test loads each file directly via `load()` (tests are exempt from the "no direct audio loading" constraint) and checks the resource's actual runtime property — not the import file text, since that's what genuinely governs playback behavior regardless of which exact importer keys control it:

```gdscript
func test_bgm_loop_tracks_actually_loop() -> void:
	# Every track meant to play forever must genuinely loop at the
	# resource level. AudioStreamMP3 exposes a simple `loop` bool;
	# AudioStreamWAV exposes `loop_mode` (an enum where 0 == disabled).
	var should_loop := [
		"res://Assets/Audio/BGM/titlescreen.mp3",
		"res://Assets/Audio/BGM/introcutscene.mp3",
		"res://Assets/Audio/BGM/schoolsimulation.mp3",
		"res://Assets/Audio/BGM/result_win.mp3",
		"res://Assets/Audio/BGM/result_lose.wav",
		"res://Assets/Audio/BGM/minigame_olahraga.mp3",
		"res://Assets/Audio/BGM/minigame_senibudaya_batik.mp3",
		"res://Assets/Audio/BGM/minigame_senibudaya_menari.mp3",
	]
	for path in should_loop:
		var stream: AudioStream = load(path)
		assert_true(stream != null, "must load: " + path)
		if stream is AudioStreamMP3:
			assert_true((stream as AudioStreamMP3).loop,
				"must loop (mp3): " + path)
		elif stream is AudioStreamWAV:
			assert_true((stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED,
				"must loop (wav): " + path)
		else:
			assert_true(false, "unexpected stream type for " + path)


func test_bgm_chain_tracks_do_not_loop() -> void:
	# Playlist and sequence tracks must NOT auto-loop, or their `finished`
	# signal never fires and AudioDirector can never advance them.
	var should_not_loop := [
		"res://Assets/Audio/BGM/loby_song1.mp3",
		"res://Assets/Audio/BGM/loby_song2.mp3",
		"res://Assets/Audio/BGM/loby_song3.mp3",
		"res://Assets/Audio/BGM/loby_song4.mp3",
		"res://Assets/Audio/BGM/minigame_akademis_1.wav",
		"res://Assets/Audio/BGM/minigame_akademis_2.wav",
		"res://Assets/Audio/BGM/minigame_akademis_3.wav",
	]
	for path in should_not_loop:
		var stream: AudioStream = load(path)
		assert_true(stream != null, "must load: " + path)
		if stream is AudioStreamMP3:
			assert_true(not (stream as AudioStreamMP3).loop,
				"must NOT loop (mp3): " + path)
		elif stream is AudioStreamWAV:
			assert_true((stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED,
				"must NOT loop (wav): " + path)
		else:
			assert_true(false, "unexpected stream type for " + path)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run `test_run` with `{"suite": "audio_director", "verbose": true}`. Expected: both new tests PASS. If either fails, go back to Step 3 — the loop flag on that specific file's `.import` sidecar is still wrong; re-derive the correct key from the actual generated file rather than guessing again.

- [ ] **Step 6: Write the credits file**

Create `Assets/Audio/BGM/CREDITS.md`, folding in the source `credit.txt` the user supplied alongside the audio:

```markdown
# BGM sources

These are the user-supplied music tracks for KejarTes — real assets, not
CC0 placeholders — copied in from the user's own collection. This file
records where each one came from, for reference.

| File | Source |
|---|---|
| `titlescreen.mp3` | fiikuri — "Epic Nusantara" (free gamelan music from Indonesian), track 328513 |
| `introcutscene.mp3` | intro cutscene theme |
| `loby_song1.mp3` | lofi_nemuko, track 212393 |
| `loby_song2.mp3` | viyn — "Cotton Candy" (loop version), track 13253 |
| `loby_song3.mp3` | loby song 3 |
| `loby_song4.mp3` | loby song 4 |
| `schoolsimulation.mp3` | school day loop |
| `result_win.mp3` | sounovamusic — "Nusantara Calling", track 576659 |
| `result_lose.wav` | extenz — game over stinger |
| `minigame_akademis_1.wav` | "Loopable Music" — obscure music, level 1 step 1 |
| `minigame_akademis_2.wav` | "Loopable Music" — obscure music, level 1 step 2 |
| `minigame_akademis_3.wav` | "Loopable Music" — obscure music, level 1 step 3 |
| `minigame_olahraga.mp3` | "Loopable Music" — obscure music |
| `minigame_senibudaya_batik.mp3` | barakelana — "Candi Wening" (Javanese traditional music), track 577770 |
| `minigame_senibudaya_menari.mp3` | dance minigame theme |
```

- [ ] **Step 7: Commit**

```bash
git add Assets/Audio/BGM tests/test_audio_director.gd
git commit -m "feat(audio): intake real BGM assets with correct loop settings"
```

---

### Task 2: Titlescreen, Introcutscene, and Result music

**Files:**
- Modify: `Scripts/Audio/AudioDirector.gd` (rename `bgm_menu`→`bgm_titlescreen`, add `bgm_introcutscene`, replace `bgm_result` with `bgm_result_win`/`bgm_result_lose`, update `_resolve_bgm`)
- Modify: `Scenes/Audio/audio_director.tscn` (assign the new/renamed slots to Task 1's files)
- Modify: `Scripts/MainMenu/main_menu.gd` (id rename)
- Modify: `Scripts/UI/Settings.gd` (id rename)
- Modify: `Scripts/Splashscreen/splashscreen.gd` (new call — this screen currently plays no BGM at all)
- Modify: `Scripts/CutScene/cut_scene.gd` (single new conditional call in `show_current()`)
- Modify: `Scripts/EndGame/SemesterEnd.gd` (reorder so the win/lose outcome is known before choosing which BGM id to play)
- Test: `tests/test_audio_director.gd`, `tests/test_audio_coverage.gd`

**Interfaces:**
- Consumes: `Assets/Audio/BGM/titlescreen.mp3`, `introcutscene.mp3`, `result_win.mp3`, `result_lose.wav` from Task 1.
- Produces: `AudioDirector.play_bgm(&"titlescreen"|&"introcutscene"|&"result_win"|&"result_lose"|&"simulation")`. The `&"menu"` and `&"result"` ids no longer resolve to anything (removed from `_resolve_bgm`) — Task 3–5 never use them.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_audio_director.gd`:

```gdscript
func test_titlescreen_and_result_slots_are_exported() -> void:
	var props := _director.get_property_list()
	var names: Array[String] = []
	for p in props:
		names.append(p.name)
	for slot in ["bgm_titlescreen", "bgm_introcutscene",
			"bgm_result_win", "bgm_result_lose"]:
		assert_true(names.has(slot), "must expose export slot: " + slot)
	assert_true(not names.has("bgm_menu"), "bgm_menu must be renamed away")
	assert_true(not names.has("bgm_result"), "bgm_result must be split into win/lose")


func test_renamed_and_new_bgm_ids_resolve() -> void:
	var dummy := AudioStreamGenerator.new()
	_director.bgm_titlescreen = dummy
	_director.bgm_introcutscene = dummy
	_director.bgm_result_win = dummy
	_director.bgm_result_lose = dummy
	for id in ["titlescreen", "introcutscene", "result_win", "result_lose"]:
		assert_true(_director._resolve_bgm(StringName(id)) != null,
			"id must resolve: " + id)
	assert_true(_director._resolve_bgm(&"menu") == null,
		"retired id must not resolve: menu")
	assert_true(_director._resolve_bgm(&"result") == null,
		"retired id must not resolve: result")
```

Append to `tests/test_audio_coverage.gd` (reuses the existing `_source()` helper already defined in that file):

```gdscript
func test_title_intro_result_screens_start_their_bgm() -> void:
	var expected := {
		"res://Scripts/Splashscreen/splashscreen.gd": 'play_bgm(&"titlescreen")',
		"res://Scripts/MainMenu/main_menu.gd": 'play_bgm(&"titlescreen")',
		"res://Scripts/UI/Settings.gd": 'play_bgm(&"titlescreen")',
	}
	for path in expected:
		assert_true(_source(path).contains(expected[path]),
			"%s must call AudioDirector.%s" % [path, expected[path]])
	var cutscene_src := _source("res://Scripts/CutScene/cut_scene.gd")
	assert_true(cutscene_src.contains('play_bgm(&"introcutscene")'),
		"cut_scene.gd must play the intro track")
	assert_true(cutscene_src.contains('play_bgm(&"result_lose")'),
		"cut_scene.gd must play result_lose for the game-over retry cutscene")
	var semester_src := _source("res://Scripts/EndGame/SemesterEnd.gd")
	assert_true(semester_src.contains('play_bgm(&"result_win")'),
		"SemesterEnd.gd must play result_win on a pass")
	assert_true(semester_src.contains('play_bgm(&"result_lose")'),
		"SemesterEnd.gd must play result_lose on a fail")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run `test_run` with `{"suite": "audio_director", "verbose": true}` then `{"suite": "audio_coverage", "verbose": true}`.
Expected: FAIL — `bgm_titlescreen` etc. don't exist yet; the coverage assertions find no matching calls.

- [ ] **Step 3: Rename and add the AudioDirector slots**

In `Scripts/Audio/AudioDirector.gd`, replace the `@export_group("BGM")` block (currently lines 33-37):

```gdscript
@export_group("BGM")
@export var bgm_menu: AudioStream
@export var bgm_lobby: AudioStream
@export var bgm_simulation: AudioStream
@export var bgm_result: AudioStream
```

with:

```gdscript
@export_group("BGM")
@export var bgm_titlescreen: AudioStream
@export var bgm_introcutscene: AudioStream
@export var bgm_lobby: AudioStream
@export var bgm_simulation: AudioStream
@export var bgm_result_win: AudioStream
@export var bgm_result_lose: AudioStream
```

(`bgm_lobby` stays as a single `AudioStream` for now — Task 5 converts it to an array. Leaving it alone here keeps this task's diff focused on the slots it actually owns.)

- [ ] **Step 4: Update `_resolve_bgm`**

Replace the `_resolve_bgm` function body (currently lines 179-185):

```gdscript
func _resolve_bgm(id: StringName) -> AudioStream:
	match id:
		&"menu": return bgm_menu
		&"lobby": return bgm_lobby
		&"simulation": return bgm_simulation
		&"result": return bgm_result
		_: return null
```

with:

```gdscript
func _resolve_bgm(id: StringName) -> AudioStream:
	match id:
		&"titlescreen": return bgm_titlescreen
		&"introcutscene": return bgm_introcutscene
		&"lobby": return bgm_lobby
		&"simulation": return bgm_simulation
		&"result_win": return bgm_result_win
		&"result_lose": return bgm_result_lose
		_: return null
```

- [ ] **Step 5: Update the two existing `&"menu"` call sites**

In `Scripts/MainMenu/main_menu.gd`, find `AudioDirector.play_bgm(&"menu")` and change it to:

```gdscript
	AudioDirector.play_bgm(&"titlescreen")
```

In `Scripts/UI/Settings.gd`, find the identical call in `_ready()` and make the same change:

```gdscript
	AudioDirector.play_bgm(&"titlescreen")
```

- [ ] **Step 6: Add the Splashscreen call**

`Scripts/Splashscreen/splashscreen.gd` currently plays no BGM at all — this is the very first screen the player sees, and it never called into `AudioDirector`. In `_ready()`, after the existing `if Engine.is_editor_hint(): return` guard, add the call alongside the existing `Juice.pop_in(_title)` line:

```gdscript
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	AudioDirector.play_bgm(&"titlescreen")
	Juice.pop_in(_title)
	var tw := _hint.create_tween().set_loops()
```

- [ ] **Step 7: Add the single conditional call in `cut_scene.gd`'s `show_current()`**

`show_current()` is the one function every reveal path in this script converges on — the fresh-game intro, the after-level-select intro, and the loss-retry cutscene all call it to begin their reveal sequence. Putting one conditional call here, rather than scattering it across each entry path, is correct and safe: `play_bgm` is a no-op when the requested id is already playing, and `show_current()` runs exactly once per reveal sequence's start (subsequent panels advance through `transition_to_next()`, which does not call `show_current()` again).

Find:

```gdscript
func show_current():
	bg_cutscene.modulate.a = 1.0
	bg_cutscene.texture = cg_data[cg_index]["image"]
	_reveal(cg_data[cg_index]["text"])
```

Replace with:

```gdscript
func show_current():
	if GameState.is_game_over_cutscene:
		AudioDirector.play_bgm(&"result_lose")
	else:
		AudioDirector.play_bgm(&"introcutscene")
	bg_cutscene.modulate.a = 1.0
	bg_cutscene.texture = cg_data[cg_index]["image"]
	_reveal(cg_data[cg_index]["text"])
```

- [ ] **Step 8: Reorder `SemesterEnd.gd` so the outcome is known before choosing the BGM id**

Currently `_ready()` plays `bgm_result` unconditionally before the pass/fail outcome is computed:

```gdscript
	AudioDirector.play_bgm(&"result")

	# Calculate evaluation, then play the sequenced reveal.
	_evaluate_students()
	_play_reveal()
```

`GameState.check_semester_passed()` is a pure read (already called elsewhere in this same file, at the `_on_restart_pressed` function, with no side effects), so it's safe to call here before `_evaluate_students()`. Replace with:

```gdscript
	if GameState.check_semester_passed():
		AudioDirector.play_bgm(&"result_win")
	else:
		AudioDirector.play_bgm(&"result_lose")

	# Calculate evaluation, then play the sequenced reveal.
	_evaluate_students()
	_play_reveal()
```

- [ ] **Step 9: Assign the four files to their slots**

Load tools with `ToolSearch` query `select:mcp__godot-ai__scene_open,mcp__godot-ai__node_set_property,mcp__godot-ai__scene_save,mcp__godot-ai__filesystem_manage`.

```
scene_open(path="res://Scenes/Audio/audio_director.tscn")
node_set_property(path="AudioDirector", property="bgm_titlescreen", value="res://Assets/Audio/BGM/titlescreen.mp3")
node_set_property(path="AudioDirector", property="bgm_introcutscene", value="res://Assets/Audio/BGM/introcutscene.mp3")
node_set_property(path="AudioDirector", property="bgm_result_win", value="res://Assets/Audio/BGM/result_win.mp3")
node_set_property(path="AudioDirector", property="bgm_result_lose", value="res://Assets/Audio/BGM/result_lose.wav")
scene_save()
```

- [ ] **Step 10: Run the tests to verify they pass**

Run `test_run` with `{"suite": "audio_director", "verbose": true}`, `{"suite": "audio_coverage", "verbose": true}`, then `{"suite": "main_menu"}`, `{"suite": "settings"}`, `{"suite": "cutscene"}`, `{"suite": "semester_end"}`, `{"suite": "boot_screens"}` to confirm no regressions in the screens this task touched.
Expected: PASS on all new tests; the five known-environmental `audio_director`/`settings` failures are unrelated and expected (see Global Constraints).

- [ ] **Step 11: Commit**

```bash
git add Scripts/Audio/AudioDirector.gd Scenes/Audio/audio_director.tscn Scripts/MainMenu/main_menu.gd Scripts/UI/Settings.gd Scripts/Splashscreen/splashscreen.gd Scripts/CutScene/cut_scene.gd Scripts/EndGame/SemesterEnd.gd tests/test_audio_director.gd tests/test_audio_coverage.gd
git commit -m "feat(audio): wire titlescreen, introcutscene, and win/lose result music"
```

---

### Task 3: Dedicated minigame player, pause/resume, and single-track minigame music

**Files:**
- Modify: `Scripts/Audio/AudioDirector.gd` (new `_bgm_minigame` player, `pause_bgm`/`resume_bgm`, `play_minigame_bgm`/`stop_minigame_bgm`, 3 new single-track minigame slots)
- Modify: `Scenes/Audio/audio_director.tscn` (assign Olahraga + SeniBudaya files)
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd` (wrap `_play_minigame` for the Olahraga/SeniBudaya categories; Akademis is deferred to Task 4)
- Test: `tests/test_audio_director.gd`, `tests/test_audio_coverage.gd`

**Interfaces:**
- Consumes: `Assets/Audio/BGM/minigame_olahraga.mp3`, `minigame_senibudaya_batik.mp3`, `minigame_senibudaya_menari.mp3` from Task 1.
- Produces: `AudioDirector.pause_bgm(fade: float = -1.0) -> void`, `AudioDirector.resume_bgm(fade: float = -1.0) -> void`, `AudioDirector.play_minigame_bgm(id: StringName) -> void`, `AudioDirector.stop_minigame_bgm(fade: float = -1.0) -> void`. Task 4 extends `play_minigame_bgm` to also handle `&"minigame_akademis"` (a sequence, not a single track) — do not assume every id `play_minigame_bgm` might receive is a plain single-track lookup; Task 4 adds a branch, it does not replace this one.

- [ ] **Step 1: Write the failing tests**

The most important property this task adds is that pausing preserves playback position — a real audio stream is needed to prove that (an empty slot has no position to preserve), so this test constructs a short synthetic tone entirely in memory rather than depending on any file. Append to `tests/test_audio_director.gd`:

```gdscript
## A ~0.3s silent 16-bit mono WAV, built in memory. Used only to give
## pause/resume and playlist/sequence tests real audio to operate on,
## independent of which real asset files happen to be assigned.
static func _make_test_stream(duration_sec: float = 0.3) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	var mix_rate := 22050
	var sample_count := int(mix_rate * duration_sec)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream


func test_minigame_slots_are_exported() -> void:
	var props := _director.get_property_list()
	var names: Array[String] = []
	for p in props:
		names.append(p.name)
	for slot in ["bgm_minigame_olahraga", "bgm_minigame_senibudaya_batik",
			"bgm_minigame_senibudaya_menari", "minigame_bgm_fade"]:
		assert_true(names.has(slot), "must expose export slot: " + slot)


func test_minigame_bgm_ids_resolve() -> void:
	_director.bgm_minigame_olahraga = _make_test_stream()
	_director.bgm_minigame_senibudaya_batik = _make_test_stream()
	_director.bgm_minigame_senibudaya_menari = _make_test_stream()
	# play_minigame_bgm must not crash on any of the three single-track ids.
	_director.play_minigame_bgm(&"minigame_olahraga")
	_director.play_minigame_bgm(&"minigame_senibudaya_batik")
	_director.play_minigame_bgm(&"minigame_senibudaya_menari")
	assert_true(true, "play_minigame_bgm must not crash on known ids")


func test_pause_then_resume_preserves_playback_position() -> void:
	_director.bgm_simulation = _make_test_stream(0.3)
	_director.play_bgm(&"simulation", 0.0)
	await Engine.get_main_loop().process_frame
	# Let real time pass so the stream's playback position genuinely advances.
	await Engine.get_main_loop().create_timer(0.12).timeout
	_director.pause_bgm(0.0)
	var paused_position := _director._bgm_active.get_playback_position()
	assert_true(paused_position > 0.0,
		"sanity check: some playback must have happened before pausing")
	# Simulate time passing while paused -- position must not advance further.
	await Engine.get_main_loop().create_timer(0.05).timeout
	assert_true(absf(_director._bgm_active.get_playback_position() - paused_position) < 0.01,
		"position must not change while paused")
	_director.resume_bgm(0.0)
	assert_true(not _director._bgm_active.stream_paused,
		"resume_bgm must unset stream_paused")


func test_pause_bgm_is_a_safe_no_op_with_nothing_playing() -> void:
	_director.pause_bgm()
	_director.resume_bgm()
	assert_true(true, "pause/resume with no active bgm must not crash")
```

- [ ] **Step 2: Run the test to verify it fails**

Run `test_run` with `{"suite": "audio_director", "verbose": true}`.
Expected: FAIL — `pause_bgm`, `resume_bgm`, `play_minigame_bgm` don't exist yet; the new slots don't exist.

- [ ] **Step 3: Add the new slots**

In `Scripts/Audio/AudioDirector.gd`, add to the `@export_group("BGM")` block (after `bgm_result_lose` from Task 2):

```gdscript
@export_group("Minigame BGM")
@export var bgm_minigame_olahraga: AudioStream
@export var bgm_minigame_senibudaya_batik: AudioStream
@export var bgm_minigame_senibudaya_menari: AudioStream
```

(A separate `@export_group` here, not folded into `"BGM"`, because these don't participate in `_resolve_bgm`/`play_bgm` at all — they're looked up by a different method, `play_minigame_bgm`, and keeping them visually separate in the inspector makes that distinction clear to whoever is assigning files.)

In the `@export_group("Mixing")` block, add the new fade tuning knob after `default_bgm_fade`:

```gdscript
## Fade for pausing/resuming bgm_simulation around a minigame, and for
## minigame music itself. Deliberately quicker than default_bgm_fade so
## ducking for a minigame doesn't feel sluggish.
@export var minigame_bgm_fade: float = 0.4
```

- [ ] **Step 4: Add the dedicated minigame player**

In the state variables block (after `var _bgm_tween: Tween`), add:

```gdscript
var _bgm_minigame: AudioStreamPlayer
```

In `_ready()`, after the existing `_bgm_active = _bgm_a` line and before `_load_volumes()`, add:

```gdscript
	_bgm_minigame = _make_bgm_player()
```

(`_make_bgm_player()` already exists and routes to the `BGM` bus — reused as-is, no changes needed to that function.)

- [ ] **Step 5: Add `pause_bgm` and `resume_bgm`**

Add these two functions after `stop_bgm` (after line 176, before `_resolve_bgm`):

```gdscript
## Fades the currently-playing bgm to silence and pauses it IN PLACE --
## unlike stop_bgm, playback position is preserved. Used around a
## minigame interruption, where the school-day music must pick back up
## exactly where it left off rather than restarting. Safe no-op if
## nothing is currently playing.
func pause_bgm(fade: float = -1.0) -> void:
	if _bgm_active == null or not _bgm_active.playing:
		return
	var duration := minigame_bgm_fade if fade < 0.0 else fade
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_active, "volume_db", -60.0, duration)
	_bgm_tween.tween_callback(func() -> void: _bgm_active.stream_paused = true)


## Reverses pause_bgm: unpauses in place and fades back up. Safe no-op
## if nothing is paused.
func resume_bgm(fade: float = -1.0) -> void:
	if _bgm_active == null or not _bgm_active.stream_paused:
		return
	_bgm_active.stream_paused = false
	var duration := minigame_bgm_fade if fade < 0.0 else fade
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_active, "volume_db", 0.0, duration)
```

- [ ] **Step 6: Add `play_minigame_bgm` and `stop_minigame_bgm`**

Add these after `resume_bgm`:

```gdscript
# --------------------------------------------------------------- minigame bgm

## Single entry point for all minigame music. Always plays on the
## dedicated _bgm_minigame player (never the main A/B pair), always
## starting fresh from silence -- minigames never overlap, so there is
## no crossfade-between-minigame-tracks case to handle.
##
## &"minigame_akademis" is handled by Task 4's extension to this
## function (a looping 3-track sequence); the ids here are single,
## already-looping tracks.
func play_minigame_bgm(id: StringName) -> void:
	var stream := _resolve_minigame_bgm(id)
	if stream == null:
		return
	_bgm_minigame.stream = stream
	_bgm_minigame.volume_db = -60.0
	_bgm_minigame.play()
	var tw := create_tween()
	tw.tween_property(_bgm_minigame, "volume_db", 0.0, minigame_bgm_fade)


func _resolve_minigame_bgm(id: StringName) -> AudioStream:
	match id:
		&"minigame_olahraga": return bgm_minigame_olahraga
		&"minigame_senibudaya_batik": return bgm_minigame_senibudaya_batik
		&"minigame_senibudaya_menari": return bgm_minigame_senibudaya_menari
		_: return null


## Fades out and stops the minigame player. Unlike pause_bgm, position
## does not need to be preserved here -- a minigame always starts its
## music fresh next time, never resumes a previous minigame's track.
func stop_minigame_bgm(fade: float = -1.0) -> void:
	if not _bgm_minigame.playing:
		return
	var duration := minigame_bgm_fade if fade < 0.0 else fade
	var tw := create_tween()
	tw.tween_property(_bgm_minigame, "volume_db", -60.0, duration)
	tw.tween_callback(_bgm_minigame.stop)
```

- [ ] **Step 7: Run the tests to verify they pass**

Run `test_run` with `{"suite": "audio_director", "verbose": true}`.
Expected: PASS on all new tests, including `test_pause_then_resume_preserves_playback_position` — this is the test that proves the position-preservation property the whole minigame-interruption design depends on.

- [ ] **Step 8: Assign the three files**

```
scene_open(path="res://Scenes/Audio/audio_director.tscn")
node_set_property(path="AudioDirector", property="bgm_minigame_olahraga", value="res://Assets/Audio/BGM/minigame_olahraga.mp3")
node_set_property(path="AudioDirector", property="bgm_minigame_senibudaya_batik", value="res://Assets/Audio/BGM/minigame_senibudaya_batik.mp3")
node_set_property(path="AudioDirector", property="bgm_minigame_senibudaya_menari", value="res://Assets/Audio/BGM/minigame_senibudaya_menari.mp3")
scene_save()
```

- [ ] **Step 9: Add the minigame-id lookup helper to `SchoolDay.gd`**

`_scene_name()` (already in this file, near line 1339) returns a *display* string ("Buat Batik") — not suitable for matching. Add a separate, dedicated helper near it (after `_scene_name`'s closing line) that reads the raw scene filename instead:

```gdscript
## Maps a category + the specific minigame scene to the AudioDirector
## minigame bgm id that should play for it. Deliberately independent
## from _scene_name()'s display-text mapping above -- that text is
## presentation-only and could change without this needing to.
func _minigame_bgm_id(game_scene: PackedScene, category: String) -> StringName:
	match category:
		"Akademis":
			return &"minigame_akademis"
		"Olahraga":
			return &"minigame_olahraga"
		"SeniBudaya":
			var file_name := game_scene.resource_path.get_file()
			if file_name == "LombaMenari.tscn":
				return &"minigame_senibudaya_menari"
			return &"minigame_senibudaya_batik"
	return &""
```

(`&"minigame_akademis"` is returned here even though Task 3 doesn't yet make `play_minigame_bgm` understand it — Task 4 adds that branch. Returning the correct id now, ahead of the implementation understanding it, is fine: `_resolve_minigame_bgm`'s `_:  return null` fallback makes `play_minigame_bgm(&"minigame_akademis")` a safe no-op until Task 4 lands, exactly like every other not-yet-filled id in this codebase.)

- [ ] **Step 10: Wire `_play_minigame`**

In `Scripts/SchoolSimulation/SchoolDay.gd`, find the "Hide the day screen" section:

```gdscript
	# Hide the day screen
	var tween_out = create_tween()
	tween_out.tween_property(day_screen, "modulate:a", 0.0, 0.4)
	await tween_out.finished
	day_screen.hide()

	# Spawn minigame
```

Insert the pause + minigame-music start between `day_screen.hide()` and the `# Spawn minigame` comment:

```gdscript
	# Hide the day screen
	var tween_out = create_tween()
	tween_out.tween_property(day_screen, "modulate:a", 0.0, 0.4)
	await tween_out.finished
	day_screen.hide()

	AudioDirector.pause_bgm()
	AudioDirector.play_minigame_bgm(_minigame_bgm_id(game_scene, category))

	# Spawn minigame
```

This runs only past the cheat-skip branch's early `return` (see the `# --- Debug Cheat Interception ---` block above it in the same function) — a minigame the player never visually sees never gets its own music either, matching the existing gating for everything else in this function.

Then find the closing sequence:

```gdscript
	var tween_close = create_tween()
	tween_close.tween_property(current_minigame, "modulate:a", 0.0, 0.4)
	await tween_close.finished
	current_minigame.queue_free()
	current_minigame = null
	for child in game_container.get_children():
		child.queue_free()

	day_screen.show()
	var tween_back = create_tween()
	tween_back.tween_property(day_screen, "modulate:a", 1.0, 0.4)
	await tween_back.finished
```

Add `stop_minigame_bgm()` right before the visual fade-out starts, and `resume_bgm()` right before the day screen fades back in — so audio and visuals move together in both directions:

```gdscript
	AudioDirector.stop_minigame_bgm()
	var tween_close = create_tween()
	tween_close.tween_property(current_minigame, "modulate:a", 0.0, 0.4)
	await tween_close.finished
	current_minigame.queue_free()
	current_minigame = null
	for child in game_container.get_children():
		child.queue_free()

	day_screen.show()
	AudioDirector.resume_bgm()
	var tween_back = create_tween()
	tween_back.tween_property(day_screen, "modulate:a", 1.0, 0.4)
	await tween_back.finished
```

- [ ] **Step 11: Write the coverage test**

Append to `tests/test_audio_coverage.gd`:

```gdscript
func test_school_day_pauses_and_resumes_around_minigames() -> void:
	var src := _source("res://Scripts/SchoolSimulation/SchoolDay.gd")
	for needle in ["AudioDirector.pause_bgm()", "AudioDirector.play_minigame_bgm(",
			"AudioDirector.stop_minigame_bgm()", "AudioDirector.resume_bgm()"]:
		assert_true(src.contains(needle),
			"SchoolDay.gd must call: " + needle)
```

- [ ] **Step 12: Run the tests to verify they pass**

Run `test_run` with `{"suite": "audio_director", "verbose": true}`, `{"suite": "audio_coverage", "verbose": true}`, and `{"suite": "school_day", "verbose": true}` to confirm no regression in the function this task rewrote.
Expected: PASS on all new tests.

- [ ] **Step 13: Commit**

```bash
git add Scripts/Audio/AudioDirector.gd Scenes/Audio/audio_director.tscn Scripts/SchoolSimulation/SchoolDay.gd tests/test_audio_director.gd tests/test_audio_coverage.gd
git commit -m "feat(audio): pause/resume school-day music around Olahraga and SeniBudaya minigames"
```

---

### Task 4: Akademis fixed-sequence minigame music

**Files:**
- Modify: `Scripts/Audio/AudioDirector.gd` (`bgm_minigame_akademis: Array[AudioStream]`, sequence-chaining logic in `play_minigame_bgm`)
- Modify: `Scenes/Audio/audio_director.tscn` (assign the 3 Akademis files)
- Test: `tests/test_audio_director.gd`

**Interfaces:**
- Consumes: `Assets/Audio/BGM/minigame_akademis_1.wav`, `_2.wav`, `_3.wav` from Task 1; `_bgm_minigame`, `play_minigame_bgm`, `stop_minigame_bgm` from Task 3; `_minigame_bgm_id` (already returns `&"minigame_akademis"` for that category, from Task 3 Step 9 — no change needed in `SchoolDay.gd` for this task).
- Produces: `play_minigame_bgm(&"minigame_akademis")` now actually plays music (fixed order, looping forever) instead of silently no-op'ing.

- [ ] **Step 1: Write the failing test**

Sequence-advance logic is tested by calling the `finished`-signal handler directly rather than waiting for real playback — this keeps the test fast and deterministic. Append to `tests/test_audio_director.gd`:

```gdscript
func test_akademis_slot_is_exported() -> void:
	var props := _director.get_property_list()
	var names: Array[String] = []
	for p in props:
		names.append(p.name)
	assert_true(names.has("bgm_minigame_akademis"),
		"must expose export slot: bgm_minigame_akademis")


func test_akademis_sequence_plays_in_fixed_order_and_wraps() -> void:
	_director.bgm_minigame_akademis = [
		_make_test_stream(), _make_test_stream(), _make_test_stream()
	]
	_director.play_minigame_bgm(&"minigame_akademis")
	assert_true(_director._bgm_minigame.stream == _director.bgm_minigame_akademis[0],
		"must start at index 0")

	_director._on_minigame_bgm_finished()
	assert_true(_director._bgm_minigame.stream == _director.bgm_minigame_akademis[1],
		"must advance to index 1")

	_director._on_minigame_bgm_finished()
	assert_true(_director._bgm_minigame.stream == _director.bgm_minigame_akademis[2],
		"must advance to index 2")

	_director._on_minigame_bgm_finished()
	assert_true(_director._bgm_minigame.stream == _director.bgm_minigame_akademis[0],
		"must wrap back to index 0")


func test_akademis_sequence_restarts_at_index_zero_on_fresh_play() -> void:
	_director.bgm_minigame_akademis = [_make_test_stream(), _make_test_stream()]
	_director.play_minigame_bgm(&"minigame_akademis")
	_director._on_minigame_bgm_finished()  # now at index 1
	_director.stop_minigame_bgm(0.0)
	_director.play_minigame_bgm(&"minigame_akademis")
	assert_true(_director._bgm_minigame.stream == _director.bgm_minigame_akademis[0],
		"a fresh minigame launch must restart the sequence at index 0")


func test_non_akademis_minigame_finished_signal_is_a_no_op() -> void:
	_director.bgm_minigame_olahraga = _make_test_stream()
	_director.play_minigame_bgm(&"minigame_olahraga")
	var stream_before := _director._bgm_minigame.stream
	_director._on_minigame_bgm_finished()
	assert_true(_director._bgm_minigame.stream == stream_before,
		"finished on a non-sequence track must not change the stream")
```

- [ ] **Step 2: Run the test to verify it fails**

Run `test_run` with `{"suite": "audio_director", "verbose": true}`.
Expected: FAIL — `bgm_minigame_akademis` doesn't exist, `_on_minigame_bgm_finished` doesn't exist.

- [ ] **Step 3: Add the array slot**

In `Scripts/Audio/AudioDirector.gd`, add to the `@export_group("Minigame BGM")` block (from Task 3):

```gdscript
@export var bgm_minigame_akademis: Array[AudioStream] = []
```

- [ ] **Step 4: Add sequence state and the `finished` handler**

Add new state variables near `_bgm_minigame` (from Task 3). Note the name
`_bgm_minigame_id` deliberately does **not** match `SchoolDay.gd`'s
`_minigame_bgm_id()` helper from Task 3 Step 9 — that's a function in a
different script that computes which id to request; this is a variable
here in `AudioDirector` remembering which id is currently active. Same
concept, different files, kept distinctly named on purpose so the two
are never confused while reading either file on its own.

```gdscript
var _akademis_sequence_index: int = 0
var _bgm_minigame_id: StringName = &""
```

In `_ready()`, right after `_bgm_minigame = _make_bgm_player()` (added in Task 3), connect its `finished` signal once, persistently — not per-track, so there's no reconnect bookkeeping to get wrong:

```gdscript
	_bgm_minigame = _make_bgm_player()
	_bgm_minigame.finished.connect(_on_minigame_bgm_finished)
```

Add the handler after `stop_minigame_bgm`:

```gdscript
## Fires whenever _bgm_minigame's current track ends naturally (i.e.
## the track's loop is disabled -- see bgm_minigame_akademis' import
## settings). Only the Akademis sequence reacts to this; every other
## minigame track loops forever via its own import setting and never
## reaches here.
func _on_minigame_bgm_finished() -> void:
	if _bgm_minigame_id != &"minigame_akademis":
		return
	if bgm_minigame_akademis.is_empty():
		return
	_akademis_sequence_index = (_akademis_sequence_index + 1) % bgm_minigame_akademis.size()
	_bgm_minigame.stream = bgm_minigame_akademis[_akademis_sequence_index]
	_bgm_minigame.play()
```

- [ ] **Step 5: Extend `play_minigame_bgm` to handle the sequence id**

Replace `play_minigame_bgm`'s body (from Task 3) to track the current id and special-case the Akademis sequence:

```gdscript
func play_minigame_bgm(id: StringName) -> void:
	_bgm_minigame_id = id
	if id == &"minigame_akademis":
		if bgm_minigame_akademis.is_empty():
			return
		_akademis_sequence_index = 0
		_bgm_minigame.stream = bgm_minigame_akademis[0]
		_bgm_minigame.volume_db = -60.0
		_bgm_minigame.play()
		var tw := create_tween()
		tw.tween_property(_bgm_minigame, "volume_db", 0.0, minigame_bgm_fade)
		return

	var stream := _resolve_minigame_bgm(id)
	if stream == null:
		return
	_bgm_minigame.stream = stream
	_bgm_minigame.volume_db = -60.0
	_bgm_minigame.play()
	var tw := create_tween()
	tw.tween_property(_bgm_minigame, "volume_db", 0.0, minigame_bgm_fade)
```

- [ ] **Step 6: Run the tests to verify they pass**

Run `test_run` with `{"suite": "audio_director", "verbose": true}`.
Expected: PASS on all four new tests.

- [ ] **Step 7: Assign the three files**

```
scene_open(path="res://Scenes/Audio/audio_director.tscn")
node_set_property(path="AudioDirector", property="bgm_minigame_akademis", value=["res://Assets/Audio/BGM/minigame_akademis_1.wav", "res://Assets/Audio/BGM/minigame_akademis_2.wav", "res://Assets/Audio/BGM/minigame_akademis_3.wav"])
scene_save()
```

If `node_set_property` rejects an array of path strings for a typed `Array[AudioStream]` property, open the scene in the editor UI instead and drag the three files into the array slot in the Inspector (expand the array to size 3 first, then assign each element) — note in your report which route worked.

- [ ] **Step 8: Verify the assignment**

```bash
grep -c "AudioStream" Scenes/Audio/audio_director.tscn
```

Confirm the count increased by 3 versus before this step (each array element becomes its own `ExtResource` reference in the `.tscn`).

- [ ] **Step 9: Commit**

```bash
git add Scripts/Audio/AudioDirector.gd Scenes/Audio/audio_director.tscn tests/test_audio_director.gd
git commit -m "feat(audio): loop the three Akademis tracks in fixed sequence"
```

---

### Task 5: Lobby shuffle-no-repeat playlist

**Files:**
- Modify: `Scripts/Audio/AudioDirector.gd` (`bgm_lobby` becomes `bgm_lobby_playlist: Array[AudioStream]`, new `play_bgm_playlist`, `finished`-driven shuffle)
- Modify: `Scenes/Audio/audio_director.tscn` (assign the 4 lobby files as an array; remove the old single assignment)
- Modify: `Scripts/Lobby/loby.gd`, `Scripts/StudentCard/student_card.gd`, `Scripts/StudentList/student_list.gd`, `Scripts/AturJadwal/atur_jadwal.gd` (all four change `play_bgm(&"lobby")` → `play_bgm_playlist(&"lobby")`)
- Test: `tests/test_audio_director.gd`, `tests/test_audio_coverage.gd`

**Interfaces:**
- Consumes: `Assets/Audio/BGM/loby_song1.mp3` … `loby_song4.mp3` from Task 1.
- Produces: `AudioDirector.play_bgm_playlist(id: StringName, fade: float = -1.0) -> void`. No other task depends on this — it's the last piece of new BGM capability.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_audio_director.gd`:

```gdscript
func test_lobby_playlist_slot_is_exported_and_old_single_slot_is_gone() -> void:
	var props := _director.get_property_list()
	var names: Array[String] = []
	for p in props:
		names.append(p.name)
	assert_true(names.has("bgm_lobby_playlist"),
		"must expose export slot: bgm_lobby_playlist")
	assert_true(not names.has("bgm_lobby"),
		"single-track bgm_lobby must be replaced by the playlist array")


func test_lobby_playlist_starts_a_track_on_play() -> void:
	_director.bgm_lobby_playlist = [
		_make_test_stream(), _make_test_stream(), _make_test_stream(), _make_test_stream()
	]
	_director.play_bgm_playlist(&"lobby", 0.0)
	assert_true(_director._bgm_active.stream in _director.bgm_lobby_playlist,
		"must start on one of the playlist's tracks")


func test_lobby_playlist_never_repeats_the_immediately_previous_track() -> void:
	_director.bgm_lobby_playlist = [
		_make_test_stream(), _make_test_stream(), _make_test_stream(), _make_test_stream()
	]
	_director.play_bgm_playlist(&"lobby", 0.0)
	var previous_index := _director.bgm_lobby_playlist.find(_director._bgm_active.stream)
	for i in range(40):
		var next_index := _director._pick_playlist_index(previous_index, _director.bgm_lobby_playlist.size())
		assert_true(next_index != previous_index,
			"iteration %d: must not repeat index %d" % [i, previous_index])
		assert_true(next_index >= 0 and next_index < _director.bgm_lobby_playlist.size(),
			"index must be in range: got " + str(next_index))
		previous_index = next_index


func test_lobby_playlist_finished_signal_advances_and_avoids_repeat() -> void:
	_director.bgm_lobby_playlist = [_make_test_stream(), _make_test_stream()]
	_director.play_bgm_playlist(&"lobby", 0.0)
	var first_stream := _director._bgm_active.stream
	# Simulate the track ending naturally.
	_director._on_bgm_finished(_director._bgm_active)
	assert_true(_director._bgm_active.stream != first_stream,
		"with only 2 tracks, finishing one must switch to the other")


func test_bgm_finished_signal_is_a_no_op_outside_playlist_mode() -> void:
	_director.bgm_simulation = _make_test_stream()
	_director.play_bgm(&"simulation", 0.0)
	var stream_before := _director._bgm_active.stream
	_director._on_bgm_finished(_director._bgm_active)
	assert_true(_director._bgm_active.stream == stream_before,
		"finished on a non-playlist bgm must not change the stream")
```

- [ ] **Step 2: Run the test to verify it fails**

Run `test_run` with `{"suite": "audio_director", "verbose": true}`.
Expected: FAIL — `bgm_lobby_playlist`, `play_bgm_playlist`, `_pick_playlist_index`, `_on_bgm_finished` don't exist yet.

- [ ] **Step 3: Replace the single lobby slot with the array**

In `Scripts/Audio/AudioDirector.gd`, in the `@export_group("BGM")` block, replace:

```gdscript
@export var bgm_lobby: AudioStream
```

with:

```gdscript
@export var bgm_lobby_playlist: Array[AudioStream] = []
```

Remove the `&"lobby": return bgm_lobby` line from `_resolve_bgm` — the lobby id no longer goes through `play_bgm`/`_resolve_bgm` at all; it's exclusively a `play_bgm_playlist` id now.

- [ ] **Step 4: Add playlist state and the picker**

Add near the other state variables:

```gdscript
var _bgm_playlist_id: StringName = &""
```

Add this pure helper (kept separate from the signal handler so it's independently testable without needing a real playing stream):

```gdscript
## Uniform random pick over every index except `exclude`. count <= 1
## always returns 0 (nothing else to pick).
func _pick_playlist_index(exclude: int, count: int) -> int:
	if count <= 1:
		return 0
	var idx := randi_range(0, count - 2)
	if idx >= exclude:
		idx += 1
	return idx
```

- [ ] **Step 5: Add `play_bgm_playlist` and the shared `finished` handler**

Add `play_bgm_playlist` after `play_bgm` (it mirrors `play_bgm`'s crossfade structure, operating on the same A/B pair, but resolves against the array and marks playlist mode active):

```gdscript
## Like play_bgm, but for an array-backed id: starts on a random track,
## and (via _on_bgm_finished) keeps shuffling to a new track --
## excluding whichever just played -- indefinitely.
func play_bgm_playlist(id: StringName, fade: float = -1.0) -> void:
	var tracks := _resolve_playlist(id)
	if tracks.is_empty():
		_bgm_playlist_id = id
		_bgm_current_id = id
		return
	if id == _bgm_current_id and _bgm_active.playing:
		return

	var duration := default_bgm_fade if fade < 0.0 else fade
	var incoming := _bgm_b if _bgm_active == _bgm_a else _bgm_a
	var outgoing := _bgm_active

	incoming.stream = tracks[randi() % tracks.size()]
	incoming.volume_db = -60.0
	incoming.play()

	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween().set_parallel(true)
	_bgm_tween.tween_property(incoming, "volume_db", 0.0, duration)
	_bgm_tween.tween_property(outgoing, "volume_db", -60.0, duration)
	_bgm_tween.chain().tween_callback(outgoing.stop)

	_bgm_active = incoming
	_bgm_current_id = id
	_bgm_playlist_id = id


func _resolve_playlist(id: StringName) -> Array[AudioStream]:
	match id:
		&"lobby": return bgm_lobby_playlist
		_: return []
```

Add the shared `finished` handler after `_resolve_playlist`, and connect both A/B players to it once in `_ready()`:

```gdscript
## Fires whenever _bgm_a or _bgm_b's current track ends naturally.
## Only playlist mode reacts -- every other bgm id loops forever via
## its own import setting and never reaches here. Guarded against
## firing for a player that is no longer the active one (e.g. the
## scene moved on to a different bgm context between when this track
## started and when it naturally ended).
func _on_bgm_finished(player: AudioStreamPlayer) -> void:
	if player != _bgm_active:
		return
	if _bgm_playlist_id == &"" or _bgm_current_id != _bgm_playlist_id:
		return
	var tracks := _resolve_playlist(_bgm_playlist_id)
	if tracks.is_empty():
		return
	var previous_index := tracks.find(player.stream)
	var next_index := _pick_playlist_index(maxi(previous_index, 0), tracks.size())
	player.stream = tracks[next_index]
	player.play()
```

In `_ready()`, after `_bgm_a = _make_bgm_player()` and `_bgm_b = _make_bgm_player()`, connect both:

```gdscript
	_bgm_a = _make_bgm_player()
	_bgm_b = _make_bgm_player()
	_bgm_a.finished.connect(_on_bgm_finished.bind(_bgm_a))
	_bgm_b.finished.connect(_on_bgm_finished.bind(_bgm_b))
	_bgm_active = _bgm_a
```

- [ ] **Step 6: Run the tests to verify they pass**

Run `test_run` with `{"suite": "audio_director", "verbose": true}`.
Expected: PASS on all five new tests.

- [ ] **Step 7: Rewire the four lobby-family call sites**

In each of `Scripts/Lobby/loby.gd`, `Scripts/StudentCard/student_card.gd`, `Scripts/StudentList/student_list.gd`, `Scripts/AturJadwal/atur_jadwal.gd`, find:

```gdscript
	AudioDirector.play_bgm(&"lobby")
```

and change it to:

```gdscript
	AudioDirector.play_bgm_playlist(&"lobby")
```

- [ ] **Step 8: Write the coverage test**

Append to `tests/test_audio_coverage.gd`:

```gdscript
func test_lobby_family_screens_use_the_playlist_not_plain_play_bgm() -> void:
	for path in [
		"res://Scripts/Lobby/loby.gd",
		"res://Scripts/StudentCard/student_card.gd",
		"res://Scripts/StudentList/student_list.gd",
		"res://Scripts/AturJadwal/atur_jadwal.gd",
	]:
		var src := _source(path)
		assert_true(src.contains('play_bgm_playlist(&"lobby")'),
			path + " must start the lobby playlist")
		assert_true(not src.contains('play_bgm(&"lobby")'),
			path + " must not use the retired single-track lobby call")
```

- [ ] **Step 9: Run the tests to verify they pass**

Run `test_run` with `{"suite": "audio_coverage", "verbose": true}`, then `{"suite": "lobby"}`, `{"suite": "student_card"}`, `{"suite": "student_list"}`, `{"suite": "atur_jadwal"}` to confirm no regressions.
Expected: PASS on all.

- [ ] **Step 10: Assign the four files**

```
scene_open(path="res://Scenes/Audio/audio_director.tscn")
node_set_property(path="AudioDirector", property="bgm_lobby_playlist", value=["res://Assets/Audio/BGM/loby_song1.mp3", "res://Assets/Audio/BGM/loby_song2.mp3", "res://Assets/Audio/BGM/loby_song3.mp3", "res://Assets/Audio/BGM/loby_song4.mp3"])
scene_save()
```

Same fallback note as Task 4 Step 7: if the typed array rejects a plain list of path strings, assign via the editor's Inspector UI instead and record which route worked.

- [ ] **Step 11: Commit**

```bash
git add Scripts/Audio/AudioDirector.gd Scenes/Audio/audio_director.tscn Scripts/Lobby/loby.gd Scripts/StudentCard/student_card.gd Scripts/StudentList/student_list.gd Scripts/AturJadwal/atur_jadwal.gd tests/test_audio_director.gd tests/test_audio_coverage.gd
git commit -m "feat(audio): shuffle the four lobby tracks with no immediate repeat"
```

---

### Task 6: README update and final verification

**Files:**
- Modify: `Assets/Audio/README.md` (document the whole BGM system this plan built)
- Test: full suite, no filter

**Interfaces:**
- Consumes: the final state of every slot and method from Tasks 1-5.
- Produces: nothing later work depends on — this is the last task.

- [ ] **Step 1: Verify every claim before writing it**

Run:

```bash
grep -rn "play_bgm\|play_minigame_bgm\|pause_bgm\|resume_bgm\|stop_minigame_bgm" --include="*.gd" Scripts/ | sort
```

Read the output. Every row you write into the README's table must match an actual call site this produces — do not describe intended behavior that isn't backed by a real call.

- [ ] **Step 2: Rewrite the BGM section of `Assets/Audio/README.md`**

Replace the existing `## BGM slots` section (and the "left intentionally empty" language that is now false — every slot is filled) with:

````markdown
## BGM system

Four kinds of BGM behavior exist, chosen automatically per scene — nothing
here requires a settings toggle.

### Single looping track

Plain background music: one file, loops forever, crossfades to the next when
a new one starts.

| Slot | Plays on | Method |
|---|---|---|
| `bgm_titlescreen` | Splashscreen, MainMenu, Settings, cutscene's level-select modal | `AudioDirector.play_bgm(&"titlescreen")` |
| `bgm_introcutscene` | the narrative intro reveal (normal path) | `AudioDirector.play_bgm(&"introcutscene")` |
| `bgm_simulation` | SchoolDay | `AudioDirector.play_bgm(&"simulation")` |
| `bgm_result_win` | SemesterEnd, on a pass | `AudioDirector.play_bgm(&"result_win")` |
| `bgm_result_lose` | SemesterEnd on a fail; also the loss-retry cutscene reveal | `AudioDirector.play_bgm(&"result_lose")` |
| `bgm_minigame_olahraga` | any Olahraga minigame | `AudioDirector.play_minigame_bgm(&"minigame_olahraga")` |
| `bgm_minigame_senibudaya_batik` | the Batik minigame specifically | `AudioDirector.play_minigame_bgm(&"minigame_senibudaya_batik")` |
| `bgm_minigame_senibudaya_menari` | the dance minigame specifically | `AudioDirector.play_minigame_bgm(&"minigame_senibudaya_menari")` |

### Shuffle playlist (no immediate repeat)

| Slot | Plays on | Method |
|---|---|---|
| `bgm_lobby_playlist` (4 tracks) | Lobby, StudentCard, StudentList, AturJadwal | `AudioDirector.play_bgm_playlist(&"lobby")` |

Each track plays once, then a new one is picked at random from the
remaining three — never the one that just played. The four screens above
share this one playlist so switching between them doesn't restart the music.

### Fixed sequence, looping

| Slot | Plays on | Method |
|---|---|---|
| `bgm_minigame_akademis` (3 tracks) | any Akademis minigame | `AudioDirector.play_minigame_bgm(&"minigame_akademis")` |

Always plays in order — 1, 2, 3, 1, 2, 3... A fresh Akademis minigame launch
always restarts at track 1.

### Pause / resume around a minigame

`bgm_simulation` doesn't stop when a minigame starts — it pauses in place
(silent, position held) and resumes from exactly where it left off once the
minigame ends. This is why minigame music plays on its own dedicated player
rather than sharing the two used for everything else: `AudioDirector.pause_bgm()`
right before a minigame's music starts, `AudioDirector.resume_bgm()` right
after it stops. An in-day **event** (an announcement that doesn't launch a
minigame) never touches this — `bgm_simulation` just keeps playing straight
through it.

## Adding or swapping BGM

Single-track slots: drag a file onto the slot in `audio_director.tscn`'s
Inspector, same as any SFX slot. Array slots (`bgm_lobby_playlist`,
`bgm_minigame_akademis`): expand the array in the Inspector and drag a file
onto each element.

**One thing that matters for array slots specifically:** the files must
have their **Loop** import setting turned **off** (Import dock → uncheck/set
to Disabled → Reimport). These tracks are chained together by code — each
one plays once, and `AudioDirector` picks the next when it naturally ends.
If a file loops on its own, it never reaches that ending and the
chain/shuffle stalls on that one track forever. Every single-track slot
above is the opposite: **Loop must stay on**, or the music stops dead the
moment the file ends once.
````

- [ ] **Step 3: Run the full test suite**

Run `test_run` with no `suite` filter (all suites).
Expected: only the five known-environmental failures listed in Global Constraints. Anything else failing is a real regression from this plan — stop and fix it before proceeding.

- [ ] **Step 4: Commit**

```bash
git add Assets/Audio/README.md
git commit -m "docs(audio): document the adaptive BGM system"
```

---

## Verification checklist

- [ ] `test_run` with no filter shows only the five known-environmental failures.
- [ ] `grep -c "AudioStream" Scenes/Audio/audio_director.tscn` accounts for every single-track slot plus every array element (4 lobby + 3 akademis) — spot-check the number makes sense given what Tasks 2-5 assigned.
- [ ] Every `.import` sidecar under `Assets/Audio/BGM/` has the loop setting Task 1 intended for it (`test_bgm_loop_tracks_actually_loop` / `test_bgm_chain_tracks_do_not_loop` cover this).
- [ ] `test_pause_then_resume_preserves_playback_position` passes — this is the one property that would have silently broken the whole minigame-interruption design if the third-player approach hadn't been used.
- [ ] No screen script anywhere calls `preload()`/`load()` on a BGM path directly (the existing `test_no_screen_loads_an_audio_file_directly` coverage test, unmodified by this plan, still covers this).
- [ ] `Assets/Audio/BGM/CREDITS.md` accounts for all 15 files under `Assets/Audio/BGM/`.
- [ ] A human listening pass — nobody in this pipeline can hear audio, so smooth fades, right mood per scene, and audible balance between the three concurrent players (A/B pair + minigame player, all sharing one `BGM` bus/slider) need to be confirmed by the user directly.
