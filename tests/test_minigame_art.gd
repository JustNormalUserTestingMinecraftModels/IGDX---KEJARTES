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

func test_pilihanganda_answer_buttons_are_rounded_rects() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/PilihanGanda.tscn")
	for prop in ["answer_btn_normal_style", "answer_btn_correct_style", "answer_btn_wrong_style"]:
		assert_true(src.contains(prop + " = SubResource("),
			prop + " must be authored as a StyleBox in the scene")
	assert_true(src.contains("corner_radius_top_left = 24"),
		"answer buttons must be rounded rectangles, not the theme's default pill")
	assert_false(src.contains("choice_btn_normal_texture = ExtResource"),
		"the meme placeholder texture must be cleared")

func test_pilihanganda_uses_the_display_font() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/PilihanGanda.tscn")
	assert_true(src.contains("Boohong.otf"),
		"the scene must set its font export to the Boohong display face for heading text")

func test_choice_buttons_animate_on_both_style_paths() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Minigames/Akademis/PilihanGanda.gd")
	assert_false(src.contains("_make_choice_shadow"),
		"the per-button shadow Panel is superseded by the stylebox's own shadow")
	var flat_branch := src.find("if choice_btn_normal_texture == null:")
	assert_true(flat_branch != -1, "_apply_choice_btn_textures should branch on a null texture")
	var else_branch := src.find("\telse:", flat_branch)
	assert_true(else_branch > flat_branch, "the texture branch should follow the flat branch")
	if else_branch <= flat_branch:
		return
	var flat_body := src.substr(flat_branch, else_branch - flat_branch)
	for state in ["\"hover\"", "\"pressed\"", "\"disabled\""]:
		assert_true(flat_body.contains("add_theme_stylebox_override(" + state),
			"the flat path must style the " + state + " state, not just normal")
	assert_false(flat_body.contains("return"),
		"the flat path must fall through to the shared press-animation wiring")
	# One leading tab means function-body level: shared by both branches rather
	# than nested inside either, which is the regression this guards.
	assert_true(src.contains("\n\tbtn.button_down.connect(_on_choice_btn_down.bind(btn))"),
		"press wiring must sit at the function's top level so both paths reach it")
	assert_true(src.contains("\n\tbtn.pivot_offset = Vector2("),
		"pivot setup must sit at the function's top level so both paths reach it")

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

## Parses `bg_color = Color(r, g, b, a)` out of every `[sub_resource]` block,
## keyed by sub-resource id, so a test can follow a SubResource reference to
## the colour it actually resolves to.
func _sub_resource_fills(src: String) -> Dictionary:
	var out := {}
	var current := ""
	for raw in src.split("\n"):
		if raw.begins_with("[sub_resource"):
			var id_at := raw.find(" id=\"")
			if id_at == -1:
				current = ""
			else:
				var id_end := raw.find("\"", id_at + 5)
				current = raw.substr(id_at + 5, id_end - id_at - 5)
		elif raw.begins_with("["):
			current = ""
		elif current != "" and raw.begins_with("bg_color = Color("):
			var open_at := raw.find("(")
			var inner := raw.substr(open_at + 1, raw.rfind(")") - open_at - 1)
			var rgba := PackedFloat32Array()
			for part in inner.split(","):
				rgba.append(float(part.strip_edges()))
			out[current] = rgba
	return out

func test_pilihanganda_flash_styles_are_not_transposed() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/PilihanGanda.tscn")
	var fills := _sub_resource_fills(src)
	var ids := {}
	for prop in ["answer_btn_normal_style", "answer_btn_correct_style", "answer_btn_wrong_style"]:
		var needle: String = prop + " = SubResource(\""
		var at := src.find(needle)
		assert_true(at != -1, prop + " must be assigned a StyleBox sub-resource")
		if at == -1:
			continue
		var start := at + needle.length()
		ids[prop] = src.substr(start, src.find("\"", start) - start)
	assert_eq(ids.size(), 3, "all three answer-button styles must be assigned")
	var seen := {}
	for prop in ids:
		seen[ids[prop]] = true
	assert_eq(seen.size(), 3, "the three answer-button styles must be three distinct sub-resources")
	var normal: PackedFloat32Array = fills.get(ids.get("answer_btn_normal_style", ""), PackedFloat32Array())
	var correct: PackedFloat32Array = fills.get(ids.get("answer_btn_correct_style", ""), PackedFloat32Array())
	var wrong: PackedFloat32Array = fills.get(ids.get("answer_btn_wrong_style", ""), PackedFloat32Array())
	assert_eq(normal.size(), 4, "the resting style needs a bg_color")
	assert_eq(correct.size(), 4, "the correct-flash style needs a bg_color")
	assert_eq(wrong.size(), 4, "the wrong-flash style needs a bg_color")
	if normal.size() < 4 or correct.size() < 4 or wrong.size() < 4:
		return
	assert_true(normal[0] > 0.9 and normal[1] > 0.9 and normal[2] > 0.9,
		"the resting answer button must stay a near-white card")
	assert_true(correct[1] > correct[0] and correct[1] > correct[2],
		"the correct-answer flash must resolve to the green fill")
	assert_true(wrong[0] > wrong[1] and wrong[0] > wrong[2],
		"the wrong-answer flash must resolve to the red fill")

func test_quiz_labels_use_ink_that_reads_on_the_wood_table() -> void:
	var pg := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/PilihanGanda.tscn")
	assert_true(pg.contains("progress_label_color = Color(0.11764706, 0.14117648, 0.21176471, 1)"),
		"the progress label must keep the dark ink; pale blue vanished on the wood table")
	var mj := FileAccess.get_file_as_string("res://Scenes/Minigames/Akademis/Menjodohkan.tscn")
	assert_false(mj.contains("Color(0.4, 0.7, 1, 1)"),
		"Menjodohkan's answer header must not go back to the pale blue")
	assert_false(mj.contains("Color(1, 0.7, 0.3, 1)"),
		"Menjodohkan's question header must not go back to the pale orange")
