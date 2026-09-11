@tool
extends McpTestSuite

## The end-of-grade report: RunResultRow (one row template) here, and the
## RunResult screen itself in the tests appended by the next task.

const _ROW_PATH := "res://Scenes/EndGame/RunResultRow.tscn"


func suite_name() -> String:
	return "run_result"



func test_the_row_template_loads() -> void:
	var row = load(_ROW_PATH).instantiate()
	var ok := row != null
	row.free()
	assert_true(ok, "RunResultRow.tscn instantiates")


func test_the_row_has_icon_name_and_value() -> void:
	var row = load(_ROW_PATH).instantiate()
	var icon = row.get_node_or_null("Row/IconRect")
	var has_all := icon is TextureRect \
		and row.get_node_or_null("Row/NameLabel") != null \
		and row.get_node_or_null("Row/ValueLabel") != null
	row.free()
	assert_true(has_all, "a texture icon, a name label and a value label")


func test_the_icon_is_a_texture_not_a_glyph() -> void:
	var row = load(_ROW_PATH).instantiate()
	var icon = row.get_node_or_null("Row/IconRect")
	var is_texture_rect := icon is TextureRect
	var has_default: bool = is_texture_rect and icon.texture != null
	row.free()
	assert_true(is_texture_rect, "IconRect is a TextureRect, never a Label")
	assert_true(has_default, "the template ships with a stand-in texture")


func test_set_row_swaps_the_icon_texture() -> void:
	var row = load(_ROW_PATH).instantiate()
	row._ready()
	var wanted: Texture2D = load(
		"res://Assets/Images/UI/Placeholders/icon_uang.svg")
	row.set_row("Uang dari wirausaha", 0.0, "G", wanted)
	var landed: Texture2D = row.get_node("Row/IconRect").texture
	row.free()
	assert_true(landed == wanted, "set_row writes the icon through")


func test_set_row_writes_the_name_and_the_final_value() -> void:
	var row = load(_ROW_PATH).instantiate()
	row._ready()
	row.set_row("Minigame selesai", 7.0)
	var name_text: String = row.get_node("Row/NameLabel").text
	var value_text: String = row.get_node("Row/ValueLabel").text
	row.free()
	assert_eq(name_text, "Minigame selesai", "the name lands")
	assert_eq(value_text, "0", "the value starts at zero, ready to count up")


func test_set_row_keeps_the_suffix() -> void:
	var row = load(_ROW_PATH).instantiate()
	row._ready()
	row.set_row("Uang wirausaha", 1500.0, "G")
	var target: float = row.target_value
	var suffix: String = row.value_suffix
	row.free()
	assert_eq(target, 1500.0, "target stored")
	assert_eq(suffix, "G", "suffix stored")


# ────────────────────────── the row's name has to read on the row's own card

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
## WCAG 2.x AA, the floor for text at body size.
const _AA_BODY_TEXT := 4.5


## The name shipped as ResultBodyLabel: cream text_on_brand, made for a dark
## ground, on the near-white Card -- all six names barely showed (live
## screenshot, 2026-09-11). Compares what the game draws: the Label's own
## variation chain against the Card's own fill, both from the baked theme.
func test_the_row_name_contrasts_with_its_card() -> void:
	var seen := _resolve_row_name()
	assert_true(seen["ground_is_flat"],
		"the Card must be a flat fill for its colour to be measured")
	var ratio := _contrast(seen["ink"], seen["ground"])
	assert_true(ratio >= _AA_BODY_TEXT,
		"the row name is %.2f:1 on its card; body text needs %.1f:1"
		% [ratio, _AA_BODY_TEXT])


## It also shipped at the 22px caption step, the size EventBodyLabel and
## CatatanLabel were each raised from after being called unreadable on a
## phone. A figure's name says what the number means, so it gets body text.
func test_the_row_name_is_at_least_body_size() -> void:
	var seen := _resolve_row_name()
	var body := DesignTokens.load_default().font_body_size
	assert_true(seen["size"] >= body,
		"the row name is %dpx; a phone needs at least the %dpx body size"
		% [seen["size"], body])


## A variation the bake does not declare raises no error: Godot quietly falls
## back to the plain Label, so the row drops its own size and ink with nothing
## to say so. That fallback happens to be dark body text, which is why the
## two tests above cannot see it.
func test_the_row_name_wears_a_variation_the_bake_declares() -> void:
	var seen := _resolve_row_name()
	assert_true(seen["declared"],
		"NameLabel's variation '%s' is not in the baked theme -- rebake?"
		% seen["variation"])


## One row, themed and resolved the way the game draws it: it wears the BAKED
## theme and goes into the tree like test_activity_row.gd's rows, so theme
## lookup runs as it does in game. Returns plain values; track() frees the
## row after the test.
func _resolve_row_name() -> Dictionary:
	var row = load(_ROW_PATH).instantiate()
	# CACHE_MODE_IGNORE: the editor holds the startup bake in memory, so a
	# plain load() would hand back the stale copy after a rebake.
	var baked := ResourceLoader.load(_THEME_PATH, "",
		ResourceLoader.CACHE_MODE_IGNORE) as Theme
	row.theme = baked
	Engine.get_main_loop().root.add_child(row)
	track(row)
	var name_label: Label = row.get_node("Row/NameLabel")
	var variation := String(name_label.theme_type_variation)
	var card := row.get_theme_stylebox("panel") as StyleBoxFlat
	return {
		"variation": variation,
		"declared": baked.get_type_list().has(variation),
		"ink": name_label.get_theme_color("font_color"),
		"size": name_label.get_theme_font_size("font_size"),
		"ground": card.bg_color if card != null else Color.BLACK,
		"ground_is_flat": card != null,
	}


## sRGB relative luminance, per WCAG 2.x. Copied verbatim from
## tests/test_bar_contrast.gd, with _contrast() below.
static func _relative_luminance(c: Color) -> float:
	var out := 0.0
	var weights := [0.2126, 0.7152, 0.0722]
	var channels := [c.r, c.g, c.b]
	for i in 3:
		var v: float = channels[i]
		var lin: float = v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
		out += weights[i] * lin
	return out


static func _contrast(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	var hi: float = max(la, lb)
	var lo: float = min(la, lb)
	return (hi + 0.05) / (lo + 0.05)


const _SCENE_PATH := "res://Scenes/EndGame/RunResult.tscn"
const _SCRIPT_PATH := "res://Scripts/EndGame/RunResult.gd"


func test_the_screen_loads() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var ok := screen != null
	screen.free()
	assert_true(ok, "RunResult.tscn instantiates")


## A broken/non-compiling script leaves a node running a PlaceholderScript
## instead of the real one -- has_method() returns false for a method that
## is genuinely defined but unreachable through a placeholder, which is
## what test_the_screen_loads()'s bare `!= null` check cannot catch (a
## placeholder instance is still non-null). GDScript.can_instantiate() was
## tried first here but proved unreliable inside this editor's own
## test-runner process specifically -- it can still report false for a
## script that a fresh game process (verified via project_run +
## editor_manage(game_eval)) loads and instantiates correctly, so this
## checks the actually-relevant thing instead: that the instantiated
## scene's own methods are real, not placeholder stand-ins.
func test_the_script_actually_compiles() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var has_real_methods: bool = screen.has_method("_build_rows") \
		and screen.has_method("_compute_grade") \
		and screen.has_method("_apply_progression")
	screen.free()
	assert_true(has_real_methods,
		"RunResult.gd's methods are reachable, not a placeholder instance " +
		"(a parse error, e.g. an unregistered type reference, would " +
		"produce a PlaceholderScript here instead)")


func test_the_screen_has_a_backdrop_grade_card_and_rows_box() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var has_all := screen.get_node_or_null("WinStage") != null \
		and screen.get_node_or_null("BlurLayer") != null \
		and screen.get_node_or_null(
			"MarginContainer/Column/GradeCard/GradeStack/GradeBadge") != null \
		and screen.get_node_or_null("MarginContainer/Column/RowsBox") != null
	screen.free()
	assert_true(has_all, "the report's structural nodes are all present")


func test_the_rows_box_starts_empty_in_the_scene() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var count: int = screen.get_node("MarginContainer/Column/RowsBox").get_child_count()
	screen.free()
	assert_eq(count, 0, "rows are instanced from the template at runtime")


func test_it_reports_all_six_figures() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for label in ["Minigame selesai", "Minigame kalah", "Total poin minigame",
			"Barang dipakai", "Uang dari wirausaha", "Murid ikut event"]:
		assert_true(src.contains(label), "the report includes '%s'" % label)


func test_it_grades_through_run_grade() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("RunGrade.score("), "it scores the run")
	assert_true(src.contains("RunGrade.letter("), "it letters the run")
	assert_true(src.contains("GameState.run_failed"), "a failed run is honoured")


func test_it_applies_grade_progression_and_exits_to_the_menu() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("GameState.current_grade += 1"),
		"a win advances the grade")
	assert_true(src.contains("res://Scenes/MainMenu/main_menu.tscn"),
		"the run ends at the main menu")


func test_it_plays_the_report_bgm_and_the_grade_stings() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("play_bgm(&\"run_result\")"), "report BGM")
	assert_true(src.contains("play_sfx(&\"stamp\")"), "the letter slams")
	assert_true(src.contains("play_sfx(&\"coin\")"), "the money row chimes")
	assert_true(src.contains("play_sfx(&\"reward\")"), "an A-band grade rewards")
	assert_true(src.contains("play_sfx(&\"fail\")"), "a D grade stings")


func test_the_report_uses_texture_icons_not_emoji() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Assets/Images/UI/Placeholders/icon_uang.svg"),
		"the rows reference real icon assets")
	for glyph in ["🎮", "💰", "⭐", "🎒", "🎪"]:
		assert_false(src.contains(glyph),
			"no emoji glyph is used as an icon")


func test_no_theme_overrides_in_the_scene() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var offenders: Array[String] = []
	_collect_overrides(screen, offenders)
	screen.free()
	assert_eq(offenders.size(), 0, "no theme_override_*: %s" % str(offenders))


func test_progression_delegates_roster_reset_to_gamestate() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("reset_roster_for_new_grade"),
		"the grade-advance branch must call GameState.reset_roster_for_new_grade()")
	assert_false(src.contains("student[\"kepribadian1\"] = 80.0"),
		"the inline mood/energy reset must move into GameState")


## Copied verbatim from tests/test_main_menu.gd.
func _collect_overrides(node: Node, out: Array[String]) -> void:
	if node is Control:
		var c := node as Control
		var flagged := false
		for prop in c.get_property_list():
			var pname: String = prop.name
			if pname.begins_with("theme_override_colors/"):
				if c.has_theme_color_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_font_sizes/"):
				if c.has_theme_font_size_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_styles/"):
				if c.has_theme_stylebox_override(pname.get_slice("/", 1)):
					flagged = true
					break
		if flagged:
			out.append(node.name)
	for child in node.get_children():
		_collect_overrides(child, out)


# ──────────────────────────────── the win stage shared with EndCutscene

const _BLUR_SHADER := "res://Scripts/Shaders/blur.gdshader"
const _CUTSCENE_SCRIPT := "res://Scripts/EndGame/EndCutscene.gd"
## The line EndCutscene dresses the stage with, verbatim -- see
## test_end_cutscene.gd's copy. Same call, same inputs, same frame.
const _DRESS_CALL := "win_stage.dress(GameState.run_failed, WinStage.names_of(GameState.approved_students))"


## RunResult opens on the very frame EndCutscene just blurred, so the swap
## between them is invisible: the same WinStage scene, the same shader, the
## same lod, the same darkness. If any of those drift, the hand-off becomes
## a visible cut.
func test_the_backdrop_is_the_same_blurred_cg_the_cutscene_ended_on() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var layer = screen.get_node_or_null("BlurLayer")
	var is_rect: bool = layer is ColorRect
	var shader_path := ""
	if is_rect and layer.material is ShaderMaterial:
		shader_path = layer.material.shader.resource_path
	var order: Array[String] = []
	for c in screen.get_children():
		order.append(String(c.name))
	screen.free()
	assert_true(is_rect, "BlurLayer is an authored ColorRect")
	assert_eq(shader_path, _BLUR_SHADER,
		"it reuses the same blur shader EndCutscene exits through")
	assert_true(order.find("WinStage") < order.find("BlurLayer"),
		"the win stage draws first, so the shader samples it")
	assert_true(order.find("BlurLayer") < order.find("MarginContainer"),
		"and the report UI draws after it, so the UI stays sharp")


## The Scrim is gone on purpose: at 0.72 alpha it was far darker than the
## blur, so keeping it would leave RunResult visibly darker than the frame
## EndCutscene hands over. The blur's own darkness is the dim now.
func test_the_scrim_no_longer_double_darkens_the_backdrop() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	# Resolve to a bool BEFORE freeing: a freed Object reference compares
	# equal to null in GDScript, so holding the node across screen.free()
	# would make this assertion pass whether or not the Scrim was there.
	var has_scrim: bool = screen.get_node_or_null("Scrim") != null
	screen.free()
	assert_false(has_scrim,
		"Scrim must be gone -- the blur layer's darkness is the only dim, "
		+ "otherwise the two screens cannot match")


## Which picture is shown is StatCheck's verdict, passed to the shared stage
## exactly the way EndCutscene passes it. RunResult must not recompute it.
func test_the_backdrop_is_dressed_from_the_same_verdict_flag() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_false(src.contains("@export var win_backdrop"),
		"the painting moved to WinStage.tscn -- one art source for both screens")
	assert_false(src.contains("@export var lose_backdrop"), "and so did the lose CG")
	# Scoped to _dress_backdrop's own body, not the whole file: _compute_grade
	# legitimately calls check_semester_passed() to letter the run. It is only
	# the BACKDROP that must not re-decide anything -- it has to agree with the
	# frame EndCutscene just showed, which was chosen from run_failed alone.
	var from := src.find("func _dress_backdrop()")
	assert_true(from != -1, "_dress_backdrop exists")
	var to := src.find("\nfunc ", from + 1)
	var body := src.substr(from, to - from) if to != -1 else src.substr(from)
	assert_true(body.contains("GameState.run_failed"),
		"the choice comes from the flag StatCheck wrote")
	assert_false(body.contains("check_semester_passed"),
		"the backdrop must not re-decide the verdict, only mirror it")


## 25% off the old 0.4. Pinned as a literal in both screens because the whole
## point is that they are identical -- a drift shows up as a flash at the
## hand-off, which no structural test would catch.
func test_both_screens_dim_the_blur_by_the_same_amount() -> void:
	var run_src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var cut_src := FileAccess.get_file_as_string(_CUTSCENE_SCRIPT)
	assert_true(run_src.contains("@export var blur_darkness: float = 0.3"),
		"RunResult dims by 0.3")
	assert_true(cut_src.contains("@export var blur_darkness: float = 0.3"),
		"and EndCutscene ends on exactly the same 0.3")
	assert_true(run_src.contains("@export var blur_lod: float = 3.0"),
		"RunResult blurs by the same lod")
	assert_true(cut_src.contains("@export var blur_lod: float = 3.0"),
		"as EndCutscene reaches")


## RunResult's header always promised "the SAME image EndCutscene shows". It
## pointed at cg_win.jpg while EndCutscene moved on, then showed the right
## painting cropped differently and without the students. Now both screens
## instance one scene, and the art is referenced in exactly one file.
func test_both_screens_open_on_the_one_win_stage() -> void:
	var run_src := FileAccess.get_file_as_string(_SCENE_PATH)
	var cut_src := FileAccess.get_file_as_string("res://Scenes/EndGame/EndCutscene.tscn")
	var stage_src := FileAccess.get_file_as_string("res://Scenes/EndGame/WinStage.tscn")
	var stage_scene := "res://Scenes/EndGame/WinStage.tscn"
	var painting := "Assets/Images/CG/Win/win_background.png"
	assert_true(run_src.contains(stage_scene), "RunResult instances WinStage")
	assert_true(cut_src.contains(stage_scene), "and so does EndCutscene")
	assert_true(stage_src.contains(painting), "the painting is wired in WinStage.tscn")
	assert_false(run_src.contains(painting) or cut_src.contains(painting),
		"and nowhere else -- no host keeps or overrides its own copy")
	assert_false(run_src.contains("cg_win.jpg"), "the old, smaller win CG stays gone")


func test_both_screens_dress_the_stage_with_the_identical_call() -> void:
	var run_src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var cut_src := FileAccess.get_file_as_string(_CUTSCENE_SCRIPT)
	assert_true(run_src.contains(_DRESS_CALL),
		"RunResult dresses the stage from the verdict and roster")
	assert_true(cut_src.contains(_DRESS_CALL), "exactly as EndCutscene does")


func test_the_old_backdrop_node_is_gone() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	# Resolve to plain values BEFORE freeing -- see the Scrim test above.
	var has_backdrop: bool = screen.get_node_or_null("Backdrop") != null
	var first_name := String(screen.get_child(0).name)
	screen.free()
	assert_false(has_backdrop, "the cropped painting is replaced by the win stage")
	assert_eq(first_name, "WinStage", "which draws first")


## Letterboxed, the win stage puts the navy bar behind the title, where
## H1Label's dark brown vanished. The title takes the results screens' own
## light-on-dark label instead: gold display face with a dark outline, which
## reads on the bar and, on shorter screens with no bar, on the blurred
## painting.
func test_the_title_reads_over_the_letterbox_bar() -> void:
	var screen = load(_SCENE_PATH).instantiate()
	var variation := String(
		screen.get_node("MarginContainer/Column/TitleLabel").theme_type_variation)
	screen.free()
	assert_eq(variation, "ResultHeroLabel", "gold with a dark outline, not dark brown")
