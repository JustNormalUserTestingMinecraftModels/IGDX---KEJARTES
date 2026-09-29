@tool
extends McpTestSuite

## The minigame mobile layout contract (spec
## docs/superpowers/specs/2026-09-29-minigame-mobile-layout-design.md, 4, 6
## and 7): BaseMinigame's wiring and, task by task, each game's scene. Must
## be @tool; no test here may be a coroutine.

const BASE := "res://Scripts/Minigames/UI/BaseMinigame.gd"
const LayoutFrame := preload("res://tests/layout_frame.gd")
const PG := "res://Scenes/Minigames/Akademis/PilihanGanda.tscn"


func suite_name() -> String:
	return "minigame_layout"


func test_the_card_shows_once_per_session_and_only_when_enabled() -> void:
	var seen := {}
	assert_true(BaseMinigame.should_show_how_to(true, seen, "res://a.tres"))
	seen["res://a.tres"] = true
	assert_false(BaseMinigame.should_show_how_to(true, seen, "res://a.tres"), "seen this session")
	assert_true(BaseMinigame.should_show_how_to(true, seen, "res://b.tres"), "another game")
	assert_false(BaseMinigame.should_show_how_to(false, {}, "res://a.tres"), "setting off")
	assert_false(BaseMinigame.should_show_how_to(true, {}, ""), "a game with no card")


func test_the_countdown_runs_outside_the_tutorial_branch() -> void:
	var src := FileAccess.get_file_as_string(BASE)
	var body := src.substr(src.find("func activate_minigame"))
	body = body.substr(0, body.find("\nfunc ", 1))
	var tut_if := body.find("if should_show_how_to(")
	var countdown := body.find("await _play_countdown()")
	assert_true(tut_if != -1 and countdown != -1, "both steps are in activate_minigame")
	var branch_end := body.find("\n\tawait _play_countdown()")
	assert_true(branch_end != -1, "the countdown sits at the function's own indent, after the if")


func test_forget_session_clears_the_seen_cards() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/GameState.gd")
	assert_contains(src, "var seen_minigame_how_to: Dictionary = {}")
	var forget := src.substr(src.find("func forget_session"))
	forget = forget.substr(0, forget.find("\nfunc ", 1))
	assert_contains(forget, "seen_minigame_how_to = {}")


func test_the_old_tutorial_strings_are_gone() -> void:
	var src := FileAccess.get_file_as_string(BASE)
	for gone: String in ["tutorial_title", "tutorial_instructions",
			"_get_active_tutorial_title", "_get_active_tutorial_instructions"]:
		assert_false(src.contains(gone), gone + " is retired by MinigameHowTo")


## `node` sits under a SafeAreaMargin.
func _under_safe(node: Node) -> bool:
	var p := node.get_parent() if node != null else null
	while p != null and not (p is SafeAreaMargin):
		p = p.get_parent()
	return p != null


func _scene(path: String) -> Node:
	var root := (load(path) as PackedScene).instantiate()
	track(root)
	return root


func test_pilihan_ganda_is_laid_out_in_three_bands() -> void:
	var root := _scene(PG)
	var header := root.get_node_or_null("%MinigameHeader")
	var tray := root.get_node_or_null("%MinigameTray")
	assert_true(_under_safe(header), "the strip is inside the safe area")
	assert_true(_under_safe(tray), "the tray is inside the safe area")
	var grid := root.get_node_or_null("%ChoicesGrid")
	assert_true(grid != null and grid.get_parent() == tray, "the answers live in the tray")
	assert_eq(String(root.how_to.resource_path), "res://Resources/Minigames/HowTo/PilihanGanda.tres")


func test_pilihan_ganda_answers_are_in_thumb_reach() -> void:
	var frame := track(LayoutFrame.stand_up(PG, Vector2(1080, 1920))) as Control
	var tray := frame.get_child(0).get_node("%MinigameTray") as Control
	assert_true(tray.get_global_rect().position.y >= 1920.0 * 0.45,
		"the tray starts in the bottom 55% of the frame")


func test_pilihan_ganda_no_longer_writes_the_badge() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/PilihanGanda.gd")
	assert_false(src.contains("Pertanyaan %d dari %d"), "the long badge rewrite is gone")
	assert_contains(src, "set_progress(")


const KALK_GAMES: Array[String] = ["res://Scenes/Minigames/Akademis/Password.tscn",
	"res://Scenes/Minigames/Akademis/Variabel.tscn"]


func test_the_calculator_games_share_one_layout() -> void:
	for path: String in KALK_GAMES:
		var root := _scene(path)
		assert_true(_under_safe(root.get_node_or_null("%MinigameHeader")), path + " strip")
		var tray := root.get_node_or_null("%MinigameTray")
		assert_true(_under_safe(tray), path + " tray")
		var kirim := root.get_node_or_null("%BtnKirim") as Button
		assert_true(kirim != null and kirim.get_parent().get_parent() == tray,
			path + ": Hapus/Kirim ride in the tray")
		assert_eq(kirim.theme_type_variation, &"PrimaryButtonM", path + ": Kirim is mint, tray-sized")
		assert_true(root.get_node_or_null("HeaderRow") == null, path + ": the old header row is gone")


const MJ := "res://Scenes/Minigames/Akademis/Menjodohkan.tscn"
const MJ_GD := "res://Scripts/Minigames/Akademis/Menjodohkan.gd"


func test_menjodohkan_answers_and_actions_live_in_the_tray() -> void:
	var root := _scene(MJ)
	var tray := root.get_node_or_null("%MinigameTray")
	assert_true(_under_safe(tray), "tray in the safe area")
	for n: String in ["BottomCarousel", "ActionRow"]:
		var c := root.get_node_or_null("Safe/Column/MinigameTray/" + n)
		assert_true(c != null, n + " rides in the tray")
	assert_true(root.get_node_or_null("HeaderVBox") == null, "title and badge row are gone")


func test_menjodohkan_text_has_no_swipe_captions_or_emoji() -> void:
	var scene := FileAccess.get_file_as_string(MJ)
	var src := FileAccess.get_file_as_string(MJ_GD)
	assert_false(scene.contains("GESER / SWIPE"))
	for glyph: String in ["🔒", "🔓", "✨", "⚪", "✅", "❌", "◀", "▶"]:
		assert_false(scene.contains(glyph) or src.contains(glyph), glyph + " is gone")


func test_menjodohkan_reports_pairs_on_the_bar() -> void:
	assert_contains(FileAccess.get_file_as_string(MJ_GD), "\"Pasangan %d/%d\"")


const BATIK := "res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn"
const BATIK_GD := "res://Scripts/Minigames/SeniBudaya/BuatBatik.gd"


func test_batik_tools_live_in_the_tray_and_the_title_is_gone() -> void:
	var root := _scene(BATIK)
	assert_true(root.get_node_or_null("Safe/Column/MinigameTray/ToolsContainer/Tool0") != null)
	for gone: String in ["TitleLabel", "InstructionLabel", "CanvasRect/ProgressStepsLabel"]:
		assert_true(root.get_node_or_null(gone) == null, gone + " is gone")
	var header := root.get_node("%MinigameHeader") as MinigameHeader
	assert_false(header.show_score, "Batik has no score pill")
	assert_true(header.segmented, "the bar reads as four steps")


func test_batik_names_the_next_step_in_the_hint() -> void:
	var src := FileAccess.get_file_as_string(BATIK_GD)
	assert_contains(src, "show_hint(")
	assert_contains(src, "\"Langkah %d/%d\"")
	for glyph: String in ["🔧", "🟨", "✅", "❌", "⬜"]:
		assert_false(src.contains(glyph), glyph + " is gone")


const BOLA := "res://Scenes/Minigames/Olahraga/MainBola.tscn"
const BOLA_GD := "res://Scripts/Minigames/Olahraga/MainBola.gd"


func test_main_bola_has_the_strip_and_the_hint_pill() -> void:
	var root := _scene(BOLA)
	assert_true(_under_safe(root.get_node_or_null("%MinigameHeader")))
	assert_true(_under_safe(root.get_node_or_null("%MinigameHintPill")))
	assert_true(root.get_node_or_null("HUDLayer") == null, "the bespoke HUD layer is gone")


func test_main_bola_speaks_indonesian() -> void:
	var src := FileAccess.get_file_as_string(BOLA_GD) + FileAccess.get_file_as_string(BOLA)
	for english: String in ["Shots Left", "Swipe Up to Shoot"]:
		assert_false(src.contains(english), english + " is gone")
	assert_contains(src, "\"Tendangan %d/%d\"")


const BADMINTON := "res://Scenes/Minigames/Olahraga/Badminton.tscn"


func test_badminton_has_the_strip_the_pill_and_a_covering_court() -> void:
	var root := _scene(BADMINTON)
	assert_true(_under_safe(root.get_node_or_null("%MinigameHeader")))
	assert_true(_under_safe(root.get_node_or_null("%MinigameHintPill")))
	assert_eq((root.get_node("Background") as TextureRect).stretch_mode,
		TextureRect.STRETCH_KEEP_ASPECT_COVERED, "the court covers, never stretches")
	assert_contains(FileAccess.get_file_as_string("res://Scripts/Minigames/Olahraga/Badminton.gd"),
		"\"Poin %d/%d\"")


const MENARI := "res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn"
const MENARI_GD := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"


func test_menari_has_the_strip_and_the_pill() -> void:
	var root := _scene(MENARI)
	assert_true(_under_safe(root.get_node_or_null("%MinigameHeader")))
	assert_true(_under_safe(root.get_node_or_null("%MinigameHintPill")))
	assert_true(root.get_node_or_null("ScoreHUD") == null, "the off-centre HUD is gone")


func test_menari_shows_lives_on_the_bar_and_warnings_in_the_pill() -> void:
	var src := FileAccess.get_file_as_string(MENARI_GD)
	assert_contains(src, "\"Nyawa %d/%d\"")
	assert_contains(src, "show_hint(miss_text(")
