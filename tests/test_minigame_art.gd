@tool
extends McpTestSuite

## Art-wiring scan for the three minigames whose placeholder meme JPGs were
## replaced on 2026-09-09 (PilihanGanda, Menjodohkan, BuatBatik). Pure
## source-text and asset-existence checks -- instantiates nothing, needs no
## scene open. See docs/superpowers/specs/2026-09-09-minigame-art-and-quiz-
## chrome-design.md.

func suite_name() -> String:
	return "minigame_art"

## The five batik canvas phases: fase1 is the blank cloth, fase2..5 are the
## results of the Pencil / Canting / Pewarna / Kompor steps.
const _BATIK_PHASES: Array[String] = [
	"res://Assets/Images/Textures/batik_fase1.png",
	"res://Assets/Images/Textures/batik_fase2.png",
	"res://Assets/Images/Textures/batik_fase3.png",
	"res://Assets/Images/Textures/batik_fase4.png",
	"res://Assets/Images/Textures/batik_fase5.png",
]

## The four BuatBatik tool icons, in tool0..tool3 order.
const _BATIK_TOOLS: Array[String] = [
	"res://Assets/Images/Textures/batik_tool_pencil.png",
	"res://Assets/Images/Textures/batik_tool_canting.png",
	"res://Assets/Images/Textures/batik_tool_pewarna.png",
	"res://Assets/Images/Textures/batik_tool_kompor.png",
]

## Illustrated question art replacing the five photo JPGs.
const _QUIZ_IMAGES: Array[String] = [
	"res://Assets/Images/monas.png",
	"res://Assets/Images/borobudur.png",
	"res://Assets/Images/komodo.png",
	"res://Assets/Images/wayang.png",
	"res://Assets/Images/bhineka_tunggal_ika.png",
]

func test_new_art_imports_as_texture2d() -> void:
	for group in [_BATIK_PHASES, _BATIK_TOOLS, _QUIZ_IMAGES]:
		for path in group:
			assert_true(ResourceLoader.exists(path), "missing imported art: " + path)
			var tex := load(path) as Texture2D
			assert_true(tex != null, path + " did not import as a Texture2D")

func test_buatbatik_wires_the_new_art() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn")
	for group in [_BATIK_PHASES, _BATIK_TOOLS]:
		for path in group:
			assert_true(src.contains(path), "BuatBatik.tscn must reference " + path)

func test_buatbatik_has_no_placeholder_art() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn")
	for stale in ["Kiper", "DiagonalRight", "komodo_dragon", "borobudur_temple"]:
		assert_false(src.contains(stale),
			"BuatBatik.tscn still references the placeholder " + stale)

func test_buatbatik_tool_slots_use_rounded_panels() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn")
	assert_eq(src.count("[node name=\"Bg\" type=\"Panel\""), 4,
		"all four tool slots need a Panel background that can carry a rounded StyleBox")
	assert_false(src.contains("[node name=\"Bg\" type=\"ColorRect\""),
		"no tool slot may keep its placeholder ColorRect background")

## Every BuatBatik export and the art it must point at. Guards the mapping
## itself rather than mere presence: a swapped tool0/tool1, or fase3 landing
## on layer2, leaves every path still present in the file and would otherwise
## pass unnoticed. The Downloads numbering skipped 2, so pewarna comes from
## Tool3.png and kompor from Tool4.png -- easy to transpose by hand.
const _BATIK_WIRING: Dictionary = {
	"tool0_texture": "res://Assets/Images/Textures/batik_tool_pencil.png",
	"tool1_texture": "res://Assets/Images/Textures/batik_tool_canting.png",
	"tool2_texture": "res://Assets/Images/Textures/batik_tool_pewarna.png",
	"tool3_texture": "res://Assets/Images/Textures/batik_tool_kompor.png",
	"canvas_cloth_texture": "res://Assets/Images/Textures/batik_fase1.png",
	"layer0_pattern_texture": "res://Assets/Images/Textures/batik_fase2.png",
	"layer1_pattern_texture": "res://Assets/Images/Textures/batik_fase3.png",
	"layer2_pattern_texture": "res://Assets/Images/Textures/batik_fase4.png",
	"layer3_pattern_texture": "res://Assets/Images/Textures/batik_fase5.png",
}

## Maps every `[ext_resource ... id="X"]` line in a .tscn to its res:// path.
func _ext_resource_ids(src: String) -> Dictionary:
	var out := {}
	for raw in src.split("\n"):
		if not raw.begins_with("[ext_resource"):
			continue
		var path_at := raw.find("path=\"")
		# Leading space matters: a bare `id="` also matches inside `uid="`.
		var id_at := raw.find(" id=\"")
		if path_at == -1 or id_at == -1:
			continue
		var path_end := raw.find("\"", path_at + 6)
		var id_end := raw.find("\"", id_at + 5)
		out[raw.substr(id_at + 5, id_end - id_at - 5)] = raw.substr(path_at + 6, path_end - path_at - 6)
	return out

func test_buatbatik_wiring_maps_each_export_to_the_right_art() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn")
	var ids := _ext_resource_ids(src)
	for prop in _BATIK_WIRING:
		var needle: String = prop + " = ExtResource(\""
		var at := src.find(needle)
		assert_true(at != -1, "BuatBatik.tscn has no " + prop + " assignment")
		if at == -1:
			continue
		var id_start := at + needle.length()
		var id_end := src.find("\"", id_start)
		var res_id := src.substr(id_start, id_end - id_start)
		assert_eq(ids.get(res_id, ""), _BATIK_WIRING[prop],
			prop + " must point at " + str(_BATIK_WIRING[prop]))

func test_menjodohkan_cards_are_rounded_and_use_heading_text() -> void:
	for p in ["res://Scenes/Minigames/Akademis/QuestionCard.tscn",
			"res://Scenes/Minigames/Akademis/AnswerCard.tscn"]:
		var src := FileAccess.get_file_as_string(p)
		# 2026-09-30: the rounded card box moved into the theme (MinigameCard,
		# MinigameAnswerCard); the pin is now that the card wears one.
		assert_true(src.contains("theme_type_variation = &\"MinigameCard\"")
			or src.contains("theme_type_variation = &\"MinigameAnswerCard\""),
			p + " card needs a rounded kit card variation")
		# 2026-09-21: the two cards left H2Label (48) for the minigame type
		# ladder's own rung, MinigameQuestionLabel (64 = font_h1). The pin
		# stays -- the card's text must still reach its size through a
		# variation, just the one built for it.
		assert_true(src.contains("theme_type_variation = &\"MinigameQuestionLabel\""),
			p + " TextLabel needs the MinigameQuestionLabel variation")
		assert_false(src.contains("theme_override_font_sizes/font_size = 42"),
			p + " must drop the static 42px TextLabel override")

func test_menjodohkan_has_no_placeholder_card_art() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/Menjodohkan.tscn")
	assert_false(src.contains("Kiper"),
		"Menjodohkan.tscn still references a Kiper meme placeholder")

## 2026-09-30 (minigame hierarchy, B2): the scene's three hand-authored
## blue-rimmed StyleBoxFlats gave way to the theme. The answers are the
## lipped MinigameChoiceButton, rounded at radius_button like every button.
func test_pilihanganda_answer_buttons_are_rounded_rects() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/PilihanGanda.tscn")
	assert_false(src.contains("StyleBoxFlat"), "the answers author no box of their own")
	assert_false(src.contains("choice_btn_normal_texture"),
		"the meme placeholder texture export is gone")
	var theme := load("res://Assets/Theme/kejartes_theme.tres") as Theme
	var box := theme.get_stylebox("normal", "MinigameChoiceButton") as StyleBoxFlat
	assert_true(box != null and box.corner_radius_top_left > 0,
		"answer buttons are rounded rectangles")

## 2026-09-21: the scene's raw `font` export went away with the type ladder.
## The display face still reaches this screen, but through variations that
## DISPLAY_ROSTER pins in tests/test_theme_factory.gd -- MinigameBadgeLabel on
## the card's "Soal N/M" chip and MinigameChoiceButton on the answers. The
## question itself is deliberately body-face: it is body copy, not a heading.
func test_pilihanganda_uses_the_display_font() -> void:
	var scene := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/PilihanGanda.tscn")
	assert_true(scene.contains("QuestionCard.tscn"),
		"the badge that carries the display face lives on the shared card")
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/PilihanGanda.gd")
	assert_true(src.contains("MinigameChoiceButton"),
		"the answer buttons must take the display-face choice variation")

## Since 2026-09-30 there is one chrome path (the theme), so the press feel
## is wired once, at the top level of _wire_choice_btn.
func test_choice_buttons_animate_on_both_style_paths() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/PilihanGanda.gd")
	assert_false(src.contains("_make_choice_shadow"),
		"the per-button shadow Panel is superseded by the lipped face")
	assert_true(src.contains("func _wire_choice_btn(btn: Button) -> void:"),
		"every answer button goes through one wiring function")
	assert_true(src.contains("
	btn.button_down.connect(_on_choice_btn_down.bind(btn))"),
		"press wiring sits at the function's top level")
	assert_true(src.contains("
	btn.pivot_offset = Vector2("),
		"the pivot is set once for the press squash")

func test_flash_keeps_white_ink_on_the_coloured_fill() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/PilihanGanda.gd")
	var at := src.find("func _flash_button_box")
	assert_true(at != -1, "_flash_button_box should exist")
	if at == -1:
		return
	var next_func := src.find("\nfunc ", at + 10)
	var body := src.substr(at, next_func - at) if next_func > at else src.substr(at)
	assert_true(body.contains("font_disabled_color"),
		"choice buttons are disabled before the flash lands, so the flash must "
		+ "set font_disabled_color as well or the dark resting ink survives")

func test_every_question_image_resolves() -> void:
	for data_path in ["res://Assets/Data/pilihanganda_questions.json",
			"res://Assets/Data/menjodohkan_questions.json"]:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(data_path))
		assert_true(parsed is Array, data_path + " must parse as a JSON Array")
		if parsed is Array:
			for entry in parsed:
				var img: String = str(entry.get("image", ""))
				if img != "":
					assert_true(ResourceLoader.exists(img),
						data_path + " points at a missing image: " + img)

func test_no_placeholder_quiz_photos_remain() -> void:
	var stale := ["monas_monument", "borobudur_temple", "komodo_dragon",
			"wayang_kulit", "garuda_pancasila"]
	for p in ["res://Assets/Data/pilihanganda_questions.json",
			"res://Assets/Data/menjodohkan_questions.json",
			"res://Scripts/Minigames/Akademis/PilihanGanda.gd"]:
		var src := FileAccess.get_file_as_string(p)
		for stale_name in stale:
			assert_false(src.contains(stale_name), p + " still references " + stale_name)

## The flash is two theme variations since 2026-09-30; the guard against a
## transposed green/red stays, read from the bake.
func test_pilihanganda_flash_styles_are_not_transposed() -> void:
	var theme := load("res://Assets/Theme/kejartes_theme.tres") as Theme
	var rest := (theme.get_stylebox("normal", "MinigameChoiceButton") as StyleBoxFlat).bg_color
	var right := (theme.get_stylebox("normal", "MinigameChoiceButtonCorrect") as StyleBoxFlat).bg_color
	var wrong := (theme.get_stylebox("normal", "MinigameChoiceButtonWrong") as StyleBoxFlat).bg_color
	assert_true(rest.r > 0.85 and rest.g > 0.85 and rest.b > 0.8,
		"the resting answer button stays a light cream card")
	assert_true(right.g > right.r and right.g > right.b,
		"the correct-answer flash resolves to the green fill")
	assert_true(wrong.r > wrong.g and wrong.r > wrong.b,
		"the wrong-answer flash resolves to the red fill")

func test_quiz_labels_use_ink_that_reads_on_the_wood_table() -> void:
	# 2026-09-21: the counter is no longer a loose label on the wood table --
	# it is the card's "Soal N/M" badge, cream on the brand_primary chip at
	# 6.9:1. The pale-blue failure this pinned cannot recur by construction,
	# so the assertion moves to the arrangement that guarantees it.
	var pg := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/PilihanGanda.tscn")
	assert_true(pg.contains("QuestionCard.tscn"),
		"the counter must sit on the card, not bare on the wood table")
	var pg_gd := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/PilihanGanda.gd")
	assert_true(pg_gd.contains('find_child("BadgeLabel"'),
		"the counter must be driven as the card's badge")
	var mj := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/Menjodohkan.tscn")
	assert_false(mj.contains("Color(0.4, 0.7, 1, 1)"),
		"Menjodohkan's answer header must not go back to the pale blue")
	assert_false(mj.contains("Color(1, 0.7, 0.3, 1)"),
		"Menjodohkan's question header must not go back to the pale orange")

## LombaMenari's backdrop. It borrowed Gawang.jpg -- MainBola's football goal
## -- as a placeholder until the festival art arrived on 2026-09-10. See
## docs/superpowers/specs/2026-09-10-minigame-sky-and-paper-fixes-design.md §6.
const _MENARI_SCENE := "res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn"
const _MENARI_BACKDROP := "res://Assets/Images/Textures/budaya_background.jpg"

func test_lomba_menari_backdrop_imports() -> void:
	assert_true(ResourceLoader.exists(_MENARI_BACKDROP), "missing imported art: " + _MENARI_BACKDROP)
	assert_true(load(_MENARI_BACKDROP) is Texture2D, _MENARI_BACKDROP + " did not import as a Texture2D")

func test_lomba_menari_wires_the_festival_backdrop_not_the_football_goal() -> void:
	var src := FileAccess.get_file_as_string(_MENARI_SCENE)
	var ids := _ext_resource_ids(src)
	var needle := "background_texture = ExtResource(\""
	var at := src.find(needle)
	assert_true(at != -1, "LombaMenari.tscn has no background_texture assignment")
	if at != -1:
		var id_start := at + needle.length()
		var res_id := src.substr(id_start, src.find("\"", id_start) - id_start)
		assert_eq(ids.get(res_id, ""), _MENARI_BACKDROP,
			"background_texture must point at the festival backdrop")
	assert_false(src.contains("Gawang.jpg"),
		"LombaMenari.tscn still references MainBola's football goal")

func test_lomba_menari_backdrop_shows_in_the_editor_and_covers_tall_screens() -> void:
	var scene: Node = (load(_MENARI_SCENE) as PackedScene).instantiate()
	track(scene)
	var bg := scene.get_node_or_null("Background") as TextureRect
	assert_true(bg != null, "LombaMenari needs its Background TextureRect")
	if bg == null:
		return
	assert_true(bg.texture != null and bg.texture.resource_path == _MENARI_BACKDROP,
		"the Background node must carry the art itself, so the 2D editor shows it")
	assert_eq(bg.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"a taller phone must crop the sides, not stretch the art")

## Which picture each BuatBatik tool shows, keyed by the tool's NODE NAME.
## _ready() shuffles the four slots -- finding the order is the puzzle -- so a
## picture dealt by slot index lands on the wrong tool (fixed 2026-09-10).
const _BATIK_TOOL_ART: Dictionary = {
	"Tool0": "res://Assets/Images/Textures/batik_tool_pencil.png",
	"Tool1": "res://Assets/Images/Textures/batik_tool_canting.png",
	"Tool2": "res://Assets/Images/Textures/batik_tool_pewarna.png",
	"Tool3": "res://Assets/Images/Textures/batik_tool_kompor.png",
}
const _BATIK_SCENE := "res://Scenes/Minigames/SeniBudaya/BuatBatik.tscn"
const _BATIK_SCRIPT := "res://Scripts/Minigames/SeniBudaya/BuatBatik.gd"

## Each tool's authored picture, read by tool name, in whatever order the
## slots currently sit.
func _batik_art_by_tool(tools: Node) -> Dictionary:
	var out := {}
	for tool in tools.get_children():
		var tex_rect := tool.get_node_or_null("ToolTextureRect") as TextureRect
		out[str(tool.name)] = tex_rect.texture.resource_path if tex_rect != null and tex_rect.texture != null else ""
	return out

func test_each_batik_tool_carries_its_own_picture_through_a_shuffle() -> void:
	var root: Node = (load(_BATIK_SCENE) as PackedScene).instantiate()
	track(root)
	var tools := root.get_node("Safe/Column/MinigameTray/ToolsContainer")
	assert_eq(_batik_art_by_tool(tools), _BATIK_TOOL_ART,
		"each tool slot must author its own picture in the scene")
	# Reorder the slots the way _ready()'s shuffle does.
	var kids := tools.get_children()
	kids.reverse()
	for i in range(kids.size()):
		tools.move_child(kids[i], i)
	assert_eq(_batik_art_by_tool(tools), _BATIK_TOOL_ART,
		"a picture must travel with its tool when the slots are reordered")

func test_batik_export_overrides_match_by_tool_name_not_slot() -> void:
	var src := FileAccess.get_file_as_string(_BATIK_SCRIPT)
	assert_false(src.contains("tool_texs[i]"),
		"a picture dealt by slot index lands on the wrong tool after the shuffle")
	assert_true(src.contains("\"Tool0\": tool0_texture"),
		"export overrides must be matched to a tool by its node name")
	assert_false(src.contains("tex_rect.name = \"ToolTextureRect\""),
		"the tool picture is authored in the scene now, not built at runtime")

func test_batik_tools_carry_no_emoji() -> void:
	var root: Node = (load(_BATIK_SCENE) as PackedScene).instantiate()
	track(root)
	for tool in root.get_node("Safe/Column/MinigameTray/ToolsContainer").get_children():
		assert_true(tool.get_node_or_null("IconLabel") == null,
			"%s still carries an emoji IconLabel; its picture is authored now" % tool.name)
	assert_false(FileAccess.get_file_as_string(_BATIK_SCRIPT).contains("func _get_tool_icon"),
		"_get_tool_icon() only ever returned emoji, and nothing called it")

## Each picture must fill its part of the slot once the scene is loaded back. A
## TextureRect left in position mode (layout_mode = 0) is saved WITHOUT its
## anchors, so it reloads as a zero-size rect and the tool shows no picture
## at all -- which the texture-path check above cannot see (2026-09-10).
func test_each_batik_picture_fills_its_slot() -> void:
	var root: Node = (load(_BATIK_SCENE) as PackedScene).instantiate()
	track(root)
	for tool in root.get_node("Safe/Column/MinigameTray/ToolsContainer").get_children():
		var tex_rect := tool.get_node_or_null("ToolTextureRect") as TextureRect
		assert_true(tex_rect != null, "%s has no ToolTextureRect" % tool.name)
		if tex_rect == null:
			continue
		var anchors := Vector4(tex_rect.anchor_left, tex_rect.anchor_top,
			tex_rect.anchor_right, tex_rect.anchor_bottom)
		# Since 2026-09-30 (minigame hierarchy B4) the picture fills the card
		# above its name: anchored down to TOOL_NAME_SPLIT, inset 16 px.
		assert_eq(anchors, Vector4(0, 0, 1, 0.7),
			"%s's picture must be anchored over its name, got %s" % [tool.name, anchors])
		var offsets := Vector4(tex_rect.offset_left, tex_rect.offset_top,
			tex_rect.offset_right, tex_rect.offset_bottom)
		assert_eq(offsets, Vector4(16, 16, -16, 0),
			"%s's picture must sit 16 px inside its card, got %s" % [tool.name, offsets])
