@tool
extends McpTestSuite

## The DayStickyNote template: one reusable sticky note for the AturJadwal
## day row. Five instances live under atur_jadwal.tscn's BGHari. This suite
## instantiates the template directly and drives its three state methods.
##
## Must be @tool; no coroutine tests (the runner does not await).

func suite_name() -> String:
	return "day_sticky_note"

const _SCENE := "res://Scenes/AturJadwal/DayStickyNote.tscn"
const _SCRIPT := "res://Scripts/AturJadwal/DayStickyNote.gd"

var _note: DayStickyNote

func setup() -> void:
	_note = (load(_SCENE) as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(_note)
	track(_note)

# ---- structure --------------------------------------------------------

func test_scene_tree_shape() -> void:
	assert_true(_note is DayStickyNote, "root must be a DayStickyNote")
	for p in ["Shadow", "BackIcon", "Paper", "Paper/DayLabel",
			  "Paper/SubjectLabel", "Paper/FlavorLabel", "Paper/Lock",
			  "Paper/WashiTape", "Paper/AturHint"]:
		assert_true(_note.get_node_or_null(p) != null, "missing node: " + p)
	assert_true(_note.get_node("Paper") is TextureButton, "Paper must be a TextureButton")
	var shadow := _note.get_node("Shadow") as TextureRect
	assert_true(shadow.material is ShaderMaterial, "Shadow needs the soft_shadow ShaderMaterial")

func test_z_order_puts_paper_in_front() -> void:
	assert_true(_note.get_node("Shadow").get_index() < _note.get_node("BackIcon").get_index(),
		"Shadow must be behind BackIcon")
	assert_true(_note.get_node("BackIcon").get_index() < _note.get_node("Paper").get_index(),
		"BackIcon must be behind Paper")

func test_no_theme_overrides() -> void:
	var offenders: Array[String] = []
	_collect_overrides(_note, offenders)
	assert_eq(offenders.size(), 0, "theme_override_* on: " + ", ".join(offenders))

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

func test_script_has_no_color_literals() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	var re := RegEx.create_from_string("Color\\s*\\(")
	assert_eq(re.search_all(src).size(), 0, "read colours from DesignTokens, not Color()")

func test_script_is_documented() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.begins_with("@tool"), "must be @tool")
	assert_true(src.contains("class_name DayStickyNote"), "needs class_name")
	assert_true(src.contains("## "), "needs a ## header")

# ---- dictionaries match ActivityRow's wording ------------------------

func test_display_names_cover_all_five_categories() -> void:
	var expected := {
		"Akademis": "Akademik", "SeniBudaya": "Seni Budaya", "Olahraga": "Atletik",
		"Wirausaha": "Wirausaha", "Istirahat": "Libur",
	}
	assert_eq(DayStickyNote.DISPLAY_NAMES, expected, "DISPLAY_NAMES drifted from the ActivityRow wording")

func test_flavor_words_cover_all_five_categories() -> void:
	for c in ["Akademis", "SeniBudaya", "Olahraga", "Wirausaha", "Istirahat"]:
		assert_true(DayStickyNote.FLAVOR_WORDS.has(c), "no flavour word for " + c)
		assert_true(String(DayStickyNote.FLAVOR_WORDS[c]).length() > 0, c + " flavour word is empty")

func test_icon_exports_are_populated() -> void:
	for c in ["Akademis", "SeniBudaya", "Olahraga", "Wirausaha", "Istirahat"]:
		assert_true(_note.category_icons.has(c), "category_icons missing " + c)
		assert_true(_note.category_icons[c] is Texture2D, c + " icon is not a Texture2D")
	assert_true(_note.holiday_icon is Texture2D, "holiday_icon is not a Texture2D")

# ---- behaviour ------------------------------------------------------

func test_show_scheduled_fills_text_icon_and_tint() -> void:
	_note.set_day_name("Senin")
	_note.show_scheduled("Olahraga")
	assert_eq((_note.get_node("Paper/DayLabel") as Label).text, "SENIN")
	assert_eq((_note.get_node("Paper/SubjectLabel") as Label).text, "Atletik")
	assert_eq((_note.get_node("Paper/FlavorLabel") as Label).text, "Semangat")
	assert_true((_note.get_node("Paper/SubjectLabel") as Label).visible)
	assert_true((_note.get_node("BackIcon") as TextureRect).visible)
	assert_true((_note.get_node("BackIcon") as TextureRect).texture != null)
	assert_false((_note.get_node("Paper/Lock") as Label).visible, "no lock on a normal scheduled day")
	assert_false((_note.get_node("Paper/AturHint") as Label).visible, "a scheduled day needs no hint")
	var tape := _note.get_node("Paper/WashiTape") as TextureRect
	assert_true(tape.visible, "a scheduled day wears its tape")
	assert_true(tape.self_modulate.is_equal_approx(DesignTokens.load_default().category_color("Olahraga")),
		"the tape carries the Olahraga category colour")
	_assert_paper_is_cream("scheduled")

func test_show_empty_hides_the_extras() -> void:
	_note.show_scheduled("Akademis")
	_note.show_empty()
	assert_false((_note.get_node("Paper/SubjectLabel") as Label).visible)
	assert_false((_note.get_node("Paper/FlavorLabel") as Label).visible)
	assert_false((_note.get_node("BackIcon") as TextureRect).visible)
	assert_false((_note.get_node("Paper/Lock") as Label).visible)
	assert_false((_note.get_node("Paper/WashiTape") as TextureRect).visible, "an empty day has no tape")
	var hint := _note.get_node("Paper/AturHint") as Label
	assert_true(hint.visible, "an empty day invites the tap")
	assert_true(hint.text.ends_with("Atur"), "the hint reads '+ Atur', got '%s'" % hint.text)
	_assert_paper_is_cream("empty")


## D2: the category colour moved OFF the paper, which stays untinted in every
## state -- the cream comes from paper_gradient.gdshader, fed from the tokens.
func _assert_paper_is_cream(state: String) -> void:
	var paper := _note.get_node("Paper") as TextureButton
	assert_eq(paper.self_modulate, Color.WHITE, "the %s paper must not be tinted" % state)
	var mat := paper.material as ShaderMaterial
	assert_true(mat != null and mat.shader != null
		and mat.shader.resource_path == "res://Scripts/Shaders/paper_gradient.gdshader",
		"the paper wears paper_gradient.gdshader")
	if mat == null:
		return
	var t := DesignTokens.load_default()
	assert_eq(mat.get_shader_parameter("top_color"), t.surface_card, "light cream at the top")
	assert_eq(mat.get_shader_parameter("bottom_color"), t.surface_page, "warmer cream at the bottom")


## The tape and the hint are decoration on the Paper button; neither may take
## the tap from it.
func test_tape_and_hint_never_eat_the_tap() -> void:
	for p in ["Paper/WashiTape", "Paper/AturHint"]:
		assert_eq((_note.get_node(p) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
			p + " must let the tap through to Paper")


## The day name sits on the paper, below the tape, never on it: dark text on a
## saturated strip is exactly the contrast failure this pass removed. The tape
## is tilted to follow the art's own adhesive band, so its lower edge is
## measured along that tilt at the label's left end, where it hangs lowest.
func test_the_day_name_sits_below_the_tape() -> void:
	var tape := _note.get_node("Paper/WashiTape") as TextureRect
	var day := _note.get_node("Paper/DayLabel") as Label
	var xf := tape.get_transform()
	var bl := xf * Vector2(0.0, tape.size.y)
	var br := xf * Vector2(tape.size.x, tape.size.y)
	var edge_y := bl.y + (br.y - bl.y) * (day.position.x - bl.x) / (br.x - bl.x)
	assert_true(day.position.y >= edge_y,
		"DayLabel top %s must clear the tape's lower edge %s" % [day.position.y, edge_y])
	for p in ["Paper/SubjectLabel", "Paper/FlavorLabel", "Paper/AturHint"]:
		assert_true((_note.get_node(p) as Control).position.y >= day.position.y,
			p + " must sit below the day name")

func test_show_holiday_is_gold_locked_and_titled() -> void:
	_note.set_day_name("Rabu")
	_note.show_holiday("Kemerdekaan RI")
	assert_eq((_note.get_node("Paper/DayLabel") as Label).text, "RABU")
	assert_eq((_note.get_node("Paper/SubjectLabel") as Label).text, "Kemerdekaan RI")
	assert_eq((_note.get_node("Paper/FlavorLabel") as Label).text, "Libur Nasional")
	assert_true((_note.get_node("Paper/Lock") as Label).visible, "holiday note must show the lock")
	assert_true((_note.get_node("BackIcon") as TextureRect).visible)
	var tape := _note.get_node("Paper/WashiTape") as TextureRect
	assert_true(tape.visible, "a holiday wears its tape")
	assert_true(tape.self_modulate.is_equal_approx(DesignTokens.load_default().category_color("Libur")),
		"holiday tape must be the Libur/gold colour")
	_assert_paper_is_cream("holiday")


## D4: an empty note breathes, and the breath is a tween on the Paper -- never
## the root, whose scale play_assign_pop() owns. Tweens never run inside the
## editor, so this pins the wiring and its guards in the source.
func test_the_empty_breath_is_gated_and_scoped_to_the_paper() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT)
	assert_true(src.contains("func _start_breath"), "empty notes need a breath")
	assert_true(src.contains("tween_property(_paper, \"scale\""),
		"the breath scales the Paper, not the note root")
	assert_true(src.contains("GameSettings.reduce_motion"), "the breath honours Reduce Motion")
	var start := src.find("func _start_breath")
	assert_true(src.find("Engine.is_editor_hint()", start) > start,
		"the breath is gated behind Engine.is_editor_hint()")
	for state in ["func show_scheduled", "func show_holiday"]:
		var at := src.find(state)
		var next := src.find("\nfunc ", at + 1)
		assert_true(src.substr(at, next - at).contains("_stop_breath()"),
			state + " must stop the breath")

func test_pressed_is_re_emitted_from_the_inner_button() -> void:
	var got := [false]
	_note.pressed.connect(func(): got[0] = true)
	(_note.get_node("Paper") as BaseButton).pressed.emit()
	assert_true(got[0], "DayStickyNote must re-emit the inner Paper button's `pressed`")

## Guard for the BackIcon cumulative-drift fix. play_assign_pop early-returns
## under Engine.is_editor_hint(), so inside the editor test runner this is a
## no-op and the icon never moves (authored == authored); it becomes a real
## regression check in a non-editor run.
func test_back_icon_returns_to_its_authored_offset_after_repeated_pops() -> void:
	var authored := (_note.get_node("BackIcon") as TextureRect).position
	_note.show_scheduled("Akademis")
	_note.show_scheduled("Olahraga")
	_note.show_scheduled("Akademis")
	var now := (_note.get_node("BackIcon") as TextureRect).position
	assert_true(now.is_equal_approx(authored),
		"BackIcon drifted to %s from its authored %s after repeated pops" % [now, authored])

## Design decision #8: the state methods are repaints and must never pop.
## The assign-pop is driven from atur_jadwal.gd::_on_activity_selected on the
## single note the player just assigned, never from show_*(). So calling the
## state methods with no explicit play_assign_pop() must leave BackIcon at its
## authored offset and raise no error.
func test_state_methods_do_not_pop() -> void:
	var authored := (_note.get_node("BackIcon") as TextureRect).position
	_note.show_scheduled("Akademis")
	_note.show_scheduled("Olahraga")
	_note.show_holiday("Kemerdekaan RI")
	var now := (_note.get_node("BackIcon") as TextureRect).position
	assert_true(now.is_equal_approx(authored),
		"a state method moved BackIcon (to %s from %s) -- it must not pop" % [now, authored])

func test_touch_target_is_big_enough() -> void:
	var tokens := DesignTokens.load_default()
	var s := _note.get_combined_minimum_size()
	assert_true(minf(s.x, s.y) >= float(tokens.touch_target_min),
		"template min size %dx%d is below the %d px touch target" % [int(s.x), int(s.y), tokens.touch_target_min])
