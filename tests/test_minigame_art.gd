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
		assert_true(src.contains("corner_radius_top_left = 24"),
			p + " card needs the radius_md corner")
		assert_true(src.contains("theme_type_variation = &\"H2Label\""),
			p + " TextLabel needs the H2Label heading variation")
		assert_false(src.contains("theme_override_font_sizes/font_size = 42"),
			p + " must drop the static 42px TextLabel override")

func test_menjodohkan_has_no_placeholder_card_art() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/Menjodohkan.tscn")
	assert_false(src.contains("Kiper"),
		"Menjodohkan.tscn still references a Kiper meme placeholder")
