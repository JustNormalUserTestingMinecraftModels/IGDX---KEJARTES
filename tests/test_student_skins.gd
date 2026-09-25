@tool
extends McpTestSuite

## The skin catalog and its session state (spec:
## docs/superpowers/specs/2026-09-18-skin-system-design.md): every path the
## catalog names exists, the default entry is today's art, the resolvers fall
## back to the roster dict, and equipping obeys the lock.

var _saved_equipped: Dictionary
var _saved_overrides: Dictionary


func suite_name() -> String:
	return "student_skins"


func setup() -> void:
	_saved_equipped = GameState.equipped_skins.duplicate()
	_saved_overrides = GameState.skin_unlock_overrides.duplicate()
	GameState.equipped_skins = {}
	GameState.skin_unlock_overrides = {}


func teardown() -> void:
	GameState.equipped_skins = _saved_equipped
	GameState.skin_unlock_overrides = _saved_overrides


func _andi() -> Dictionary:
	return {
		"name": "Andi", "id": 3,
		"splash": "res://Assets/Images/SplashArtMurid/splash_andi.png",
		"portrait": "res://Assets/Images/MuridPotrait/Andi.png",
	}


func test_every_student_has_default_then_skin1() -> void:
	assert_eq(StudentSkins.NAMES.size(), 6)
	for n in StudentSkins.NAMES:
		assert_eq(StudentSkins.skins_for(n), ["default", "skin1"] as Array[String], n)


func test_every_catalog_path_exists() -> void:
	for n in StudentSkins.NAMES:
		for id in StudentSkins.skins_for(n):
			for layer in StudentSkins.LAYERS:
				var p := StudentSkins.layer_path(n, id, layer)
				assert_true(ResourceLoader.exists(p), "%s/%s/%s missing: %s" % [n, id, layer, p])


func test_default_entry_is_todays_art() -> void:
	assert_eq(StudentSkins.layer_path("Thea", "default", "splash"), "res://Assets/Images/SplashArtMurid/splash_thea.png")
	assert_eq(StudentSkins.layer_path("Thea", "default", "portrait"), "res://Assets/Images/MuridPotrait/Thea.png")
	assert_eq(StudentSkins.layer_path("Thea", "default", "face_base"), "res://Assets/Images/MuridPotrait/Thea/thea_base.png")
	assert_eq(StudentSkins.layer_path("Thea", "default", "hand"), "res://Assets/Images/MuridPotrait/TanganItems/Thea_Table.png")


func test_skin1_paths_follow_the_skins_folder() -> void:
	assert_eq(StudentSkins.layer_path("Andi", "skin1", "splash"), "res://Assets/Images/Skins/Andi/splash_andi_skin1.png")
	assert_eq(StudentSkins.layer_path("Andi", "skin1", "hand"), "res://Assets/Images/Skins/Andi/andi_table_skin1.png")


func test_unknown_name_and_id() -> void:
	assert_eq(StudentSkins.skins_for("Murid1"), [] as Array[String])
	assert_false(StudentSkins.has_skin("Andi", "skin9"))
	assert_eq(StudentSkins.layer_path("Andi", "skin9", "splash"), "")
	assert_eq(StudentSkins.bust_center("Murid1"), StudentSkins.FALLBACK_BUST_CENTER)


func test_resolvers_fall_back_to_the_dict_when_default() -> void:
	var s := _andi()
	assert_eq(StudentSkins.splash_for(s), s["splash"])
	assert_eq(StudentSkins.portrait_for(s), s["portrait"])
	assert_eq(StudentSkins.face_base_for("Andi"), "")
	assert_eq(StudentSkins.hand_for("Andi"), "")
	var stranger := {"name": "Murid1", "splash": "res://x.png", "portrait": "res://y.png"}
	assert_eq(StudentSkins.splash_for(stranger), "res://x.png")


func test_equipped_skin_wins_and_dict_is_untouched() -> void:
	var s := _andi()
	assert_true(GameState.equip_skin("Andi", "skin1"))
	assert_eq(StudentSkins.splash_for(s), "res://Assets/Images/Skins/Andi/splash_andi_skin1.png")
	assert_eq(StudentSkins.portrait_for(s), "res://Assets/Images/Skins/Andi/andi_portrait_skin1.png")
	assert_eq(StudentSkins.face_base_for("Andi"), "res://Assets/Images/Skins/Andi/andi_base_skin1.png")
	assert_eq(StudentSkins.hand_for("Andi"), "res://Assets/Images/Skins/Andi/andi_table_skin1.png")
	assert_eq(s["splash"], "res://Assets/Images/SplashArtMurid/splash_andi.png", "the roster dict keeps its base art")


func test_equip_refuses_unknown_and_locked() -> void:
	assert_false(GameState.equip_skin("Andi", "skin9"))
	GameState.set_all_skins_locked(true)
	assert_true(GameState.all_skins_locked())
	assert_false(GameState.is_skin_unlocked("Andi", "skin1"))
	assert_true(GameState.is_skin_unlocked("Andi", "default"), "default never locks")
	assert_false(GameState.equip_skin("Andi", "skin1"))
	assert_eq(GameState.equipped_skin("Andi"), "default")


func test_locking_all_unequips_a_worn_skin() -> void:
	GameState.equip_skin("Citra", "skin1")
	GameState.set_all_skins_locked(true)
	assert_eq(GameState.equipped_skin("Citra"), "default")
	GameState.set_all_skins_locked(false)
	assert_false(GameState.all_skins_locked())
	assert_true(GameState.equip_skin("Citra", "skin1"))


func test_equip_emits_skin_changed() -> void:
	var got: Array = []
	var cb := func(n: String) -> void: got.append(n)
	GameState.skin_changed.connect(cb)
	GameState.equip_skin("Doni", "skin1")
	GameState.equip_skin("Doni", "skin1")
	GameState.skin_changed.disconnect(cb)
	assert_eq(got, ["Doni"], "emits once; re-equipping the worn skin is silent")


func test_bridge_uses_the_skin() -> void:
	GameState.equip_skin("Andi", "skin1")
	var sd := GameState.student_data_from_dict(_andi())
	assert_eq(sd.splash_path, "res://Assets/Images/Skins/Andi/splash_andi_skin1.png")
	assert_eq(sd.avatar_texture.resource_path, "res://Assets/Images/Skins/Andi/andi_portrait_skin1.png")


func test_forget_session_source_clears_skins() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	var body := src.substr(src.find("func forget_session"), 2000)
	assert_true(body.contains("equipped_skins = {}"))
	assert_true(body.contains("skin_unlock_overrides = {}"))


func test_grade_reset_keeps_skins() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	var body := src.substr(src.find("func reset_roster_for_new_grade"), 900)
	assert_false(body.contains("equipped_skins"), "a skin follows the character across grades")


## Every screen that draws a student from a roster dict goes through the
## resolver (a scan: most of these screens cannot be built headlessly).
func test_consumers_use_the_resolver() -> void:
	var sites := {
		"res://Scripts/AturJadwal/atur_jadwal.gd": ["StudentSkins.splash_for(", "StudentSkins.portrait_for("],
		"res://Scripts/StudentCard/StudentCardView.gd": ["StudentSkins.portrait_for("],
		"res://Scripts/StudentList/student_list.gd": ["StudentSkins.portrait_for("],
		"res://Scripts/Lobby/loby.gd": ["StudentSkins.portrait_for("],
	}
	for path in sites:
		var src := FileAccess.get_file_as_string(path)
		for needle in sites[path]:
			assert_true(src.contains(needle), "%s must call %s" % [path, needle])
		assert_false(src.contains("get(\"portrait\""), "%s still reads the raw portrait key" % path)


func test_result_screens_keep_their_own_art() -> void:
	for path in ["res://Scripts/EndGame/WinStage.gd", "res://Scripts/EndGame/WinLineup.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("StudentSkins"), path)


func test_debug_overlay_toggles_skin_locks() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Debug/DebugManager.gd")
	assert_true(src.contains("Kunci/Buka Semua Skin"))
	assert_true(src.contains("GameState.set_all_skins_locked(not GameState.all_skins_locked())"))


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


## The one resolver every screen asks: the outfit on its day, else the
## student's own (possibly skinned) splash.
func test_splash_for_day_falls_back_to_the_student_s_own() -> void:
	var own := "res://Assets/Images/Skins/Thea/splash_thea_skin1.png"
	assert_eq(StudentSkins.splash_for_day("Thea", own, "Kamis"),
		"res://Assets/Images/SplashArtMurid/Seragam/splash_thea_batik.png", "the outfit beats a skin")
	assert_eq(StudentSkins.splash_for_day("Thea", own, "Senin"), own)
	assert_eq(StudentSkins.splash_for_day("Thea", own, ""), own)


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
