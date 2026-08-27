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
			"bgm_menu", "bgm_lobby", "bgm_simulation", "bgm_result"]:
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
