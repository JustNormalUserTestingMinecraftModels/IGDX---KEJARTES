@tool
extends McpTestSuite

## The shared in-run score readout.
##
## Before 2026-09-04 each minigame styled its own bare ScoreLabel at runtime
## with five theme_override_* calls, so the score looked different in every
## game and carried no icon at all. This is the one template they all mount.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "minigame_score_hud"


const HUD_PATH := "res://Scenes/Minigames/UI/MinigameScoreHUD.tscn"
const ICON_SKOR := "res://Assets/Images/UI/Placeholders/icon_skor.svg"


func _make() -> Node:
	var node: Node = load(HUD_PATH).instantiate()
	Engine.get_main_loop().root.add_child(node)
	track(node)
	return node


func test_the_scene_carries_every_node_the_script_binds() -> void:
	var hud := _make()
	for path in ["Panel/Row/Icon", "Panel/Row/ValueLabel", "Panel/Row/TargetLabel",
			"Panel/Row/ComboChip", "BurstSlot"]:
		assert_true(hud.has_node(path), "%s is an authored node" % path)


func test_setup_installs_the_icon_and_the_target() -> void:
	var hud := _make()
	hud.setup(load(ICON_SKOR), 5)
	assert_true(hud.icon.texture != null, "the icon is set")
	assert_true(hud.target_label.text.contains("5"), "the target reads out")


func test_set_score_updates_the_value() -> void:
	var hud := _make()
	hud.setup(load(ICON_SKOR), 5)
	hud.set_score(3)
	assert_eq(hud.value_label.text, "3", "the value tracks the score")


func test_the_combo_chip_hides_below_the_display_threshold() -> void:
	var hud := _make()
	hud.set_combo(1)
	assert_false(hud.combo_chip.visible, "a combo of one is not a combo")
	hud.set_combo(3)
	assert_true(hud.combo_chip.visible, "three in a row is worth showing")
	assert_true(hud.combo_chip_label.text.contains("3"), "and reads out the count")


func test_the_escape_hatch_leaves_the_target_alone() -> void:
	var hud := _make()
	hud.setup(load(ICON_SKOR), 7)
	hud.set_label_text("7 - 6")
	assert_eq(hud.value_label.text, "7 - 6",
		"Badminton's two-sided score goes through verbatim")
	assert_true(hud.target_label.text.contains("7"), "and the target is untouched")


## Regression: the root Control never propagated Panel's minimum size to a
## VBoxContainer parent (Menjodohkan/PilihanGanda/Password/Variabel mount the
## HUD this way), so it was allocated zero height there, and a non-Container
## mount (Badminton/LombaMenari) stayed at literal zero size too, since a
## bare Control outside a Container is never auto-clamped to its minimum.
func test_setup_grows_a_zero_sized_non_container_mount_to_fit_its_content() -> void:
	var hud := _make()
	hud.position = Vector2(390, 40)
	assert_eq(hud.size, Vector2.ZERO, "authored at zero size, like Badminton's mount")
	hud.setup(load(ICON_SKOR), 5)
	assert_true(hud.size.x > 0 and hud.size.y > 0,
		"setup() must grow a Container-less mount to its real content size")


func test_the_hud_reports_a_real_minimum_size_for_container_parents() -> void:
	var hud := _make()
	hud.setup(load(ICON_SKOR), 5)
	var min_size: Vector2 = hud.get_combined_minimum_size()
	assert_true(min_size.x > 0 and min_size.y > 0,
		"a VBoxContainer mount needs a nonzero minimum to not be allocated zero height")


func test_the_hud_adds_no_theme_overrides() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameScoreHUD.gd")
	assert_false(src.contains("add_theme_"), "chrome comes from the theme variations")


func test_no_public_method_is_a_coroutine() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/UI/MinigameScoreHUD.gd")
	for fn in ["setup", "set_score", "set_combo", "set_label_text"]:
		var body: String = src.split("func %s(" % fn)[1].split("\nfunc ")[0]
		assert_false(body.contains("await "), "%s() must be callable from _process" % fn)


## Every minigame scene that keeps a score, and must therefore mount the shared
## HUD rather than styling a bare ScoreLabel of its own.
const SCORING_MINIGAME_SCENES := [
	"res://Scenes/Minigames/Olahraga/MainBola.tscn",
	"res://Scenes/Minigames/Olahraga/Badminton.tscn",
	"res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn",
	"res://Scenes/Minigames/Akademis/Menjodohkan.tscn",
	"res://Scenes/Minigames/Akademis/PilihanGanda.tscn",
	"res://Scenes/Minigames/Akademis/Password.tscn",
	"res://Scenes/Minigames/Akademis/Variabel.tscn",
]

const SCORING_MINIGAME_SCRIPTS := [
	"res://Scripts/Minigames/Olahraga/MainBola.gd",
	"res://Scripts/Minigames/Olahraga/Badminton.gd",
	"res://Scripts/Minigames/SeniBudaya/LombaMenari.gd",
	"res://Scripts/Minigames/Akademis/Menjodohkan.gd",
	"res://Scripts/Minigames/Akademis/PilihanGanda.gd",
	"res://Scripts/Minigames/Akademis/Password.gd",
	"res://Scripts/Minigames/Akademis/Variabel.gd",
]


func test_every_scoring_minigame_mounts_the_shared_hud() -> void:
	for path in SCORING_MINIGAME_SCENES:
		var src := FileAccess.get_file_as_string(path)
		assert_true(src.contains("MinigameScoreHUD.tscn"),
			"%s instances the shared HUD" % path)


func test_no_scoring_minigame_still_styles_a_score_label_at_runtime() -> void:
	for path in SCORING_MINIGAME_SCRIPTS:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("score_label.add_theme_"),
			"%s no longer styles its score at runtime" % path)
