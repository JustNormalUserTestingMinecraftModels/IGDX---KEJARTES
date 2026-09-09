@tool
extends McpTestSuite

## The quirk/persona detail modal, extracted from the verbatim copies in
## report_card.gd and student_card.gd.
##
## The one thing that genuinely varies per instance is the header accent --
## brand_primary for a quirk, cat_istirahat for a persona -- so these tests
## pin that mapping as well as the node contract.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "trait_detail_popup"


const SCENE_PATH := "res://Scenes/UI/TraitDetailPopup.tscn"


## The scene is added to the tree so its @onready vars resolve, matching
## the established pattern in tests/test_day_summary.gd. TraitDetailPopup is
## a CanvasLayer (no .theme property of its own); none of the assertions
## here depend on resolved visual styling.
func _make() -> TraitDetailPopup:
	var popup: TraitDetailPopup = load(SCENE_PATH).instantiate()
	Engine.get_main_loop().root.add_child(popup)
	track(popup)
	return popup


func test_scene_exists_and_instantiates() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	assert_not_null(_make())


func test_scene_supplies_every_node_the_script_binds() -> void:
	var popup := _make()
	for path in ["Scrim", "Scrim/Card", "Scrim/Card/Layout/Header",
			"Scrim/Card/Layout/Header/Row/GlyphIcon",
			"Scrim/Card/Layout/Header/Row/Titles/KindLabel",
			"Scrim/Card/Layout/Header/Row/Titles/NameLabel",
			"Scrim/Card/Layout/Header/Row/CloseButton",
			"Scrim/Card/Layout/Body/BodyLayout/EffectLabel",
			"Scrim/Card/Layout/Body/BodyLayout/DescriptionLabel"]:
		assert_not_null(popup.get_node_or_null(path), "missing node: %s" % path)


func test_header_uses_the_theme_variation_not_a_runtime_stylebox() -> void:
	var popup := _make()
	var header: PanelContainer = popup.get_node("Scrim/Card/Layout/Header")
	assert_eq(header.theme_type_variation, &"TraitPopupHeader")
	assert_false(header.has_theme_stylebox_override("panel"),
		"the accent must come from self_modulate, not a stylebox override")


func test_quirk_and_persona_get_their_own_accent() -> void:
	var tokens := DesignTokens.load_default()
	var quirk := _make()
	quirk.configure("quirk", "Kutu Buku", "Suka membaca.")
	assert_eq(quirk.get_node("Scrim/Card/Layout/Header").self_modulate,
		tokens.brand_primary)
	assert_eq(quirk.get_node("Scrim/Card/Layout/Header/Row/Titles/KindLabel").text, "QUIRK")

	var persona := _make()
	persona.configure("persona", "Tekun", "Belajar terus.")
	assert_eq(persona.get_node("Scrim/Card/Layout/Header").self_modulate,
		tokens.cat_istirahat)
	assert_eq(persona.get_node("Scrim/Card/Layout/Header/Row/Titles/KindLabel").text, "PERSONA")


## The header glyph was the literal emoji "⚡" / "🌟" set as a Label's TEXT
## until 2026-09-09 -- emoji as UI iconography, which this project bans,
## and which also made the glyph depend on the device's emoji font. It is a
## TextureRect fed real PNGs now. Asserted by comparing the two kinds'
## textures rather than pinning a path, so renaming the art is free but
## quietly serving one glyph for both traits is not.
func test_each_trait_kind_gets_its_own_glyph_texture() -> void:
	var quirk := _make()
	quirk.configure("quirk", "Kutu Buku", "Suka membaca.")
	var quirk_tex: Texture2D = quirk.get_node(
		"Scrim/Card/Layout/Header/Row/GlyphIcon").texture
	assert_not_null(quirk_tex, "the quirk header must get a glyph texture")

	var persona := _make()
	persona.configure("persona", "Tekun", "Belajar terus.")
	var persona_tex: Texture2D = persona.get_node(
		"Scrim/Card/Layout/Header/Row/GlyphIcon").texture
	assert_not_null(persona_tex, "the persona header must get a glyph texture")
	assert_true(quirk_tex != persona_tex,
		"quirk and persona must not share one glyph")


## "EFEK GAMEPLAY:" used to be a prefix glued onto the front of the
## description, which is why it could only ever wear the body face. It is
## its own display-font heading now, and the description is just the
## description. The 💡 that opened the old prefix went with it.
func test_the_gameplay_effect_heading_is_its_own_display_label() -> void:
	var popup := _make()
	popup.configure("quirk", "Kutu Buku", "Suka membaca.")

	# Asserted as the VARIATION, not as a resolved font. This popup is a
	# CanvasLayer with no theme of its own, so get_theme_font() here walks
	# up to the root Window and returns the engine default rather than the
	# project theme -- it would fail whatever the label wore. The variation
	# is the real contract: TitleLabel is on test_theme_factory.gd's
	# DISPLAY_ROSTER, which pins it to the display face in the bake.
	var heading: Label = popup.get_node("Scrim/Card/Layout/Body/BodyLayout/EffectLabel")
	assert_contains(heading.text, "EFEK GAMEPLAY")
	assert_eq(heading.theme_type_variation, &"TitleLabel",
		"the heading must wear a display-roster variation, not the body face")

	var body: Label = popup.get_node("Scrim/Card/Layout/Body/BodyLayout/DescriptionLabel")
	assert_eq(body.text, "Suka membaca.",
		"the description must no longer carry the heading as a prefix")
	assert_false(body.text.contains("💡"),
		"the emoji prefix must be gone")


func test_neither_screen_builds_a_trait_popup_by_hand() -> void:
	for path in ["res://Scripts/ReportCard/report_card.gd",
			"res://Scripts/StudentCard/student_card.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_contains(src, "TraitDetailPopup", "%s should use the scene" % path)
		assert_false(src.contains("_close_trait_popup"),
			"%s still owns the hand-rolled popup teardown" % path)
		assert_false(src.contains("StyleBoxFlat.new("),
			"%s builds a stylebox in code -- use the TraitPopupHeader variation" % path)


func test_scene_has_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	var text := FileAccess.get_file_as_string(SCENE_PATH)
	for line in text.split("\n"):
		if line.begins_with("theme_override_") and not line.begins_with("theme_override_constants/"):
			offenders.append(line)
	assert_true(offenders.is_empty(), "theme overrides in the scene file:\n" + "\n".join(offenders))
