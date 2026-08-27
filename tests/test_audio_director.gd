@tool
extends McpTestSuite

func suite_name() -> String:
	return "audio_director"

var _director: Node


func setup() -> void:
	# Instantiate a fresh copy rather than poking the live autoload, so
	# volume changes in these tests do not leak into the running game.
	var scene: PackedScene = load("res://Scenes/Audio/audio_director.tscn")
	_director = scene.instantiate()
	Engine.get_main_loop().root.add_child(_director)
	track(_director)


func teardown() -> void:
	if is_instance_valid(_director):
		_director.queue_free()
	_director = null


func test_required_buses_exist() -> void:
	for bus in ["Master", "BGM", "SFX"]:
		assert_true(AudioServer.get_bus_index(bus) >= 0,
			"audio bus must exist: " + bus)


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
			"bgm_titlescreen", "bgm_simulation", "bgm_result_win"]:
		assert_true(names.has(slot), "must expose export slot: " + slot)


func test_play_sfx_with_empty_slot_is_silent_not_a_crash() -> void:
	# Slots are null until the user drops in audio. This must never error.
	_director.play_sfx(&"tap")
	_director.play_sfx(&"confirm")
	assert_true(true, "play_sfx on an unassigned slot must not crash")


func test_play_sfx_with_unknown_id_is_survivable() -> void:
	_director.play_sfx(&"tidak_ada_suara_ini")
	assert_true(true, "unknown sfx id must not crash")


func test_bus_volume_roundtrips() -> void:
	_director.set_bus_volume(&"SFX", 0.5)
	assert_true(absf((_director.get_bus_volume(&"SFX")) - (0.5)) <= 0.01, "volume set then read must match")


func test_bus_volume_clamps_to_valid_range() -> void:
	_director.set_bus_volume(&"SFX", 5.0)
	assert_true(absf((_director.get_bus_volume(&"SFX")) - (1.0)) <= 0.01, "clamps high")
	_director.set_bus_volume(&"SFX", -3.0)
	assert_true(absf((_director.get_bus_volume(&"SFX")) - (0.0)) <= 0.01, "clamps low")


func test_muted_bus_reports_zero_not_negative_infinity() -> void:
	_director.set_bus_volume(&"BGM", 0.0)
	assert_true(absf((_director.get_bus_volume(&"BGM")) - (0.0)) <= 0.01, "a fully muted bus reads back as 0.0, not -inf or NaN")


func test_sfx_voices_are_pooled_and_reused() -> void:
	# Firing many taps in a row must not spawn unbounded players.
	for i in range(60):
		_director.play_sfx(&"tap")
	var players := 0
	for child in _director.get_children():
		if child is AudioStreamPlayer:
			players += 1
	assert_true(players <= 20,
		"sfx pool must be bounded, found %d players" % players)


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
	var before: int = _director.get_volume_save_count()
	for i in range(50):
		_director.set_bus_volume(&"SFX", float(i) / 50.0)
	var immediately_after: int = _director.get_volume_save_count()
	assert_true(immediately_after - before <= 2,
		"50 rapid changes must coalesce, not write synchronously; got %d saves before the debounce window even elapsed"
			% (immediately_after - before))

	# The coalesced write must actually land once the 0.4s debounce window
	# passes -- a debounce that silently DROPPED the save (e.g. a stray
	# early return) would still pass the assertion above.
	await Engine.get_main_loop().create_timer(0.5).timeout
	var after: int = _director.get_volume_save_count()
	assert_true(after - before == 1,
		"50 rapid changes must coalesce into exactly 1 save once the debounce window elapses, got %d"
			% (after - before))


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


func test_every_bgm_slot_is_filled_in_the_shipped_scene() -> void:
	# _director is instantiated from the real audio_director.tscn (see
	# setup()), so this asserts the SHIPPED scene's actual state -- a slot
	# that's real code but an empty assignment (like bgm_simulation once
	# was) is exactly what this catches and the loop-setting tests do not.
	for slot in ["bgm_titlescreen", "bgm_introcutscene", "bgm_simulation",
			"bgm_result_win", "bgm_result_lose", "bgm_minigame_olahraga",
			"bgm_minigame_senibudaya_batik", "bgm_minigame_senibudaya_menari"]:
		assert_true(_director.get(slot) != null,
			"shipped scene must fill single-track bgm slot: " + slot)
	for slot in ["bgm_lobby_playlist", "bgm_minigame_akademis"]:
		var arr: Array = _director.get(slot)
		assert_true(not arr.is_empty(),
			"shipped scene must fill array bgm slot: " + slot)


func test_minigame_bgm_fade_is_a_real_positive_float_in_the_shipped_scene() -> void:
	# Regression test: scene_save() once serialized this newly-added export
	# as an unset `null` before the editor had picked up its 0.4 script
	# default. Every production call site (SchoolDay.gd's pause_bgm(),
	# play_minigame_bgm(...), stop_minigame_bgm(), resume_bgm()) calls with
	# no explicit fade argument, relying on AudioDirector's
	# "minigame_bgm_fade if fade < 0.0 else fade" fallback -- a null value
	# there coerces to 0.0, silently turning every minigame pause/resume
	# fade into an instant hard cut in the real game, invisible to any test
	# that (like the ones above) always passes an explicit fade argument.
	assert_true(_director.minigame_bgm_fade != null,
		"shipped scene must not leave minigame_bgm_fade null")
	assert_true(_director.minigame_bgm_fade > 0.0,
		"shipped scene's minigame_bgm_fade must be a real positive fade, got %s"
			% _director.minigame_bgm_fade)


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
	_director.play_minigame_bgm(&"minigame_olahraga")
	assert_true(_director._bgm_minigame.stream == _director.bgm_minigame_olahraga,
		"minigame_olahraga must actually be assigned to the minigame player")
	_director.play_minigame_bgm(&"minigame_senibudaya_batik")
	assert_true(_director._bgm_minigame.stream == _director.bgm_minigame_senibudaya_batik,
		"minigame_senibudaya_batik must actually be assigned to the minigame player")
	_director.play_minigame_bgm(&"minigame_senibudaya_menari")
	assert_true(_director._bgm_minigame.stream == _director.bgm_minigame_senibudaya_menari,
		"minigame_senibudaya_menari must actually be assigned to the minigame player")


## NOTE on test technique: this suite's runner calls test methods
## synchronously (see test_juice.gd's header for the full explanation) so
## the brief's original `await Engine.get_main_loop().create_timer(...)
## .timeout` calls would return control at the first suspend point before
## any post-await assertion ever ran, scoring "0 assertions" -- verified
## empirically here (this exact draft failed that way first). Fixed with
## two techniques, both preserving the test's real intent (prove genuine
## elapsed time before pausing, and genuine non-drift while paused):
##  1. OS.delay_msec() to actually block the thread for real wall-clock
##     time. AudioServer mixes on its own thread, independent of the main
##     loop, so a stream's playback position keeps advancing across a
##     real OS-level delay even though no engine frame is processed --
##     this is NOT a no-op like a SceneTreeTimer await that never resumes.
##  2. Tween.custom_step(), the established technique from test_juice.gd,
##     to deterministically fast-forward pause_bgm's fade+pause tween
##     (and resume_bgm's fade-in tween) to completion synchronously --
##     needed because pause_bgm's `stream_paused = true` is set from a
##     tween_callback, which otherwise never fires without a processed
##     frame.
func test_pause_then_resume_preserves_playback_position() -> void:
	_director.bgm_simulation = _make_test_stream(0.3)
	_director.play_bgm(&"simulation", 0.0)
	# Let real time pass so the stream's playback position genuinely advances.
	OS.delay_msec(120)

	var before_tweens: Array = Engine.get_main_loop().get_processed_tweens()
	_director.pause_bgm(0.0)
	for tw in Engine.get_main_loop().get_processed_tweens():
		if not before_tweens.has(tw) and is_instance_valid(tw):
			tw.custom_step(1.0)

	assert_true(_director._bgm_active.stream_paused,
		"sanity check: pause_bgm must actually pause the stream")
	# Setting stream_paused doesn't silence the mixer instantaneously --
	# there is a small, fixed amount of audio-buffer latency already
	# in flight when the pause takes effect. Let that one-time latency
	# settle before taking the position snapshot the "no drift" check
	# below compares against, so the assertion measures genuine drift
	# during the pause rather than that unavoidable flush.
	OS.delay_msec(30)
	var paused_position: float = _director._bgm_active.get_playback_position()
	assert_true(paused_position > 0.0,
		"sanity check: some playback must have happened before pausing")
	# Let more real time pass while paused -- position must not advance further.
	OS.delay_msec(50)
	assert_true(absf(_director._bgm_active.get_playback_position() - paused_position) < 0.01,
		"position must not change while paused")

	var before_resume_tweens: Array = Engine.get_main_loop().get_processed_tweens()
	_director.resume_bgm(0.0)
	for tw in Engine.get_main_loop().get_processed_tweens():
		if not before_resume_tweens.has(tw) and is_instance_valid(tw):
			tw.custom_step(1.0)
	assert_true(not _director._bgm_active.stream_paused,
		"resume_bgm must unset stream_paused")


func test_pause_bgm_is_a_safe_no_op_with_nothing_playing() -> void:
	_director.pause_bgm()
	_director.resume_bgm()
	assert_true(true, "pause/resume with no active bgm must not crash")


func test_akademis_slot_is_exported() -> void:
	var props := _director.get_property_list()
	var names: Array[String] = []
	for p in props:
		names.append(p.name)
	assert_true(names.has("bgm_minigame_akademis"),
		"must expose export slot: bgm_minigame_akademis")


func test_akademis_sequence_plays_in_fixed_order_and_wraps() -> void:
	# NOTE: must be assigned through a locally-typed Array[AudioStream]
	# rather than a bare `[...]` literal. _director is statically typed
	# as Node (AudioDirector.gd has no class_name), so the assignment
	# below goes through Object.set()'s dynamic property path rather
	# than a compiler-typed setter; that path requires the Array value
	# itself to already carry AudioStream typed-array metadata, which a
	# bare untyped literal does not have -- it fails at runtime with
	# "Invalid assignment of property ... with value of type 'Array'"
	# even though every element is a valid AudioStream.
	var tracks: Array[AudioStream] = [
		_make_test_stream(), _make_test_stream(), _make_test_stream()
	]
	_director.bgm_minigame_akademis = tracks
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
	# See the typed-local note in test_akademis_sequence_plays_in_fixed_order_and_wraps.
	var tracks: Array[AudioStream] = [_make_test_stream(), _make_test_stream()]
	_director.bgm_minigame_akademis = tracks
	_director.play_minigame_bgm(&"minigame_akademis")
	_director._on_minigame_bgm_finished()  # now at index 1
	_director.stop_minigame_bgm(0.0)
	_director.play_minigame_bgm(&"minigame_akademis")
	assert_true(_director._bgm_minigame.stream == _director.bgm_minigame_akademis[0],
		"a fresh minigame launch must restart the sequence at index 0")


func test_non_akademis_minigame_finished_signal_is_a_no_op() -> void:
	_director.bgm_minigame_olahraga = _make_test_stream()
	_director.play_minigame_bgm(&"minigame_olahraga")
	var stream_before: AudioStream = _director._bgm_minigame.stream
	_director._on_minigame_bgm_finished()
	assert_true(_director._bgm_minigame.stream == stream_before,
		"finished on a non-sequence track must not change the stream")


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
	# See the typed-local note in test_akademis_sequence_plays_in_fixed_order_and_wraps.
	var tracks: Array[AudioStream] = [
		_make_test_stream(), _make_test_stream(), _make_test_stream(), _make_test_stream()
	]
	_director.bgm_lobby_playlist = tracks
	_director.play_bgm_playlist(&"lobby", 0.0)
	assert_true(_director._bgm_active.stream in _director.bgm_lobby_playlist,
		"must start on one of the playlist's tracks")


func test_lobby_playlist_never_repeats_the_immediately_previous_track() -> void:
	# See the typed-local note in test_akademis_sequence_plays_in_fixed_order_and_wraps.
	var tracks: Array[AudioStream] = [
		_make_test_stream(), _make_test_stream(), _make_test_stream(), _make_test_stream()
	]
	_director.bgm_lobby_playlist = tracks
	_director.play_bgm_playlist(&"lobby", 0.0)
	var previous_index: int = _director.bgm_lobby_playlist.find(_director._bgm_active.stream)
	for i in range(40):
		var next_index: int = _director._pick_playlist_index(previous_index, _director.bgm_lobby_playlist.size())
		assert_true(next_index != previous_index,
			"iteration %d: must not repeat index %d" % [i, previous_index])
		assert_true(next_index >= 0 and next_index < _director.bgm_lobby_playlist.size(),
			"index must be in range: got " + str(next_index))
		previous_index = next_index


func test_lobby_playlist_finished_signal_advances_and_avoids_repeat() -> void:
	# See the typed-local note in test_akademis_sequence_plays_in_fixed_order_and_wraps.
	var tracks: Array[AudioStream] = [_make_test_stream(), _make_test_stream()]
	_director.bgm_lobby_playlist = tracks
	_director.play_bgm_playlist(&"lobby", 0.0)
	var first_stream: AudioStream = _director._bgm_active.stream
	# Simulate the track ending naturally.
	_director._on_bgm_finished(_director._bgm_active)
	assert_true(_director._bgm_active.stream != first_stream,
		"with only 2 tracks, finishing one must switch to the other")


func test_bgm_finished_signal_is_a_no_op_outside_playlist_mode() -> void:
	_director.bgm_simulation = _make_test_stream()
	_director.play_bgm(&"simulation", 0.0)
	var stream_before: AudioStream = _director._bgm_active.stream
	_director._on_bgm_finished(_director._bgm_active)
	assert_true(_director._bgm_active.stream == stream_before,
		"finished on a non-playlist bgm must not change the stream")
