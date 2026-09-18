@tool
extends McpTestSuite

## The claim celebration (spec:
## docs/superpowers/specs/2026-09-17-achievement-claim-celebration-design.md):
## its authored scene, its shaders and theme variations, and the screen that
## opens it.

const POPUP := "res://Scenes/Achievements/AchievementClaimPopup.tscn"


func suite_name() -> String:
	return "achievement_claim_popup"


func _popup() -> Control:
	var p := (load(POPUP) as PackedScene).instantiate() as Control
	track(p)
	return p


func test_scene_contract() -> void:
	var p := _popup()
	assert_eq(p.mouse_filter, Control.MOUSE_FILTER_STOP, "a tap anywhere reaches the popup")
	var blur := p.get_node("Blur") as ColorRect
	assert_eq(blur.material.resource_path, "res://Scenes/Koperasi/shop_hub_blur_material.tres")
	var glow := p.get_node("Safe/UI/Glow") as ColorRect
	assert_true((glow.material as ShaderMaterial).shader.resource_path.ends_with("achievement_glow.gdshader"))
	var icon := p.get_node("Safe/UI/Icon") as TextureRect
	assert_eq(icon.material.resource_path, "res://Assets/Images/Achievements/icon_outline_material.tres")
	assert_eq((p.get_node("Safe/UI/Headline") as Label).text, "SELAMAT, ANDA MENDAPATKAN")
	assert_eq((p.get_node("Safe/UI/Headline") as Label).theme_type_variation, &"AchievementClaimHeadlineLabel")
	assert_eq((p.get_node("Safe/UI/Title") as Label).theme_type_variation, &"AchievementClaimTitleLabel")
	var hint := p.get_node("Safe/UI/Hint") as Label
	assert_eq(hint.text, "tekan dimana saja untuk menutup")
	assert_eq(hint.anchor_top, 1.0, "the hint rides the bottom edge")
	assert_true(p.get_node("Confetti") is RewardParticles)


func test_open_fills_icon_and_title() -> void:
	var p := _popup()
	p.icon = p.get_node("Safe/UI/Icon")
	p.title_label = p.get_node("Safe/UI/Title")
	p.content = p.get_node("Safe/UI")
	p.confetti = p.get_node("Confetti")
	p.open(AchievementCatalog.get_entry("three_star_akademis"))
	assert_eq(p.title_label.text, "Cap-cip-cup kembang kuncup!")
	assert_eq(p.icon.texture.resource_path, AchievementCatalog.icon_path("three_star_akademis"))


func test_glow_shader_is_additive_and_animated() -> void:
	var code := (load("res://Scripts/Shaders/achievement_glow.gdshader") as Shader).code
	assert_true(code.contains("blend_add"))
	assert_true(code.contains("TIME"))
	assert_true(code.contains("ray_count"))


func test_factory_builds_the_claim_labels() -> void:
	var t := DesignTokens.load_default()
	var theme := ThemeFactory.build(t)
	for name in ["AchievementClaimHeadlineLabel", "AchievementClaimTitleLabel"]:
		assert_eq(theme.get_type_variation_base(name), &"Label")
		assert_eq(theme.get_color("font_outline_color", name), t.event_warning_ink)
		assert_gt(theme.get_constant("outline_size", name), 0)
		assert_eq(theme.get_font("font", name), t.font_display)
	assert_eq(theme.get_type_variation_base("AchievementClaimHintLabel"), &"Label")


func test_close_twice_is_idempotent() -> void:
	var p := _popup()
	Engine.get_main_loop().root.add_child(p)
	var closed_count := [0]
	p.closed.connect(func() -> void: closed_count[0] += 1)
	p.close()
	assert_true(p._closing, "first close starts fading out")
	var tween_count_after_first := p.get_tree().get_processed_tweens().size()
	p.close()
	assert_eq(p.get_tree().get_processed_tweens().size(), tween_count_after_first, "second close does not start another tween")
	assert_eq(closed_count[0], 0, "closed has not fired yet (tween still running)")


func test_screen_opens_the_popup_on_claim() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Achievements/achievements_screen.gd")
	assert_true(src.contains("claim_popup_scene.instantiate()"))
	assert_true(src.contains(".open(AchievementCatalog.get_entry(id))"))
