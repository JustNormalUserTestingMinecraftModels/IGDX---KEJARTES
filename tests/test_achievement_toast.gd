@tool
extends McpTestSuite

## The unlock banner autoload (spec:
## docs/superpowers/specs/2026-09-17-achievements-design.md): its authored
## scene, its queue, and its registration.

const TOAST := "res://Scenes/Achievements/AchievementToast.tscn"


func suite_name() -> String:
	return "achievement_toast"


func test_scene_contract() -> void:
	var toast := (load(TOAST) as PackedScene).instantiate() as CanvasLayer
	track(toast)
	assert_eq(toast.layer, 120)
	assert_eq(toast.process_mode, Node.PROCESS_MODE_ALWAYS)
	var banner := toast.get_node_or_null("Banner") as Panel
	assert_true(banner != null)
	if banner:
		assert_eq(banner.theme_type_variation, &"AchievementToastPanel")
		assert_eq(banner.anchor_left, 0.5, "centred on the top edge")
	assert_true(toast.get_node_or_null("Banner/Icon") is TextureRect)
	assert_true(toast.get_node_or_null("Banner/Title") is Label)


func test_enqueue_while_showing_only_queues() -> void:
	var toast := (load(TOAST) as PackedScene).instantiate()
	track(toast)
	toast._busy = true
	toast.enqueue("grade_7")
	toast.enqueue("grade_8")
	assert_eq(toast._queue, ["grade_7", "grade_8"] as Array[String])


func test_autoloads_registered() -> void:
	assert_eq(ProjectSettings.get_setting("autoload/Achievements"), "*res://Scripts/Achievements/Achievements.gd")
	assert_eq(ProjectSettings.get_setting("autoload/AchievementToast"), "*res://Scenes/Achievements/AchievementToast.tscn")
