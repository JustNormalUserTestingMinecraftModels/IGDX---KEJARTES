@tool
extends McpTestSuite

## ActivityRow is the Penjadwalan popup's repeated row: icon, a pill of
## preview numbers, and the outlined category name. These tests pin its
## structure and its theming, because the popup builds five of them and a
## silent styling failure would be invisible until someone opened the game.
##
## Suite is @tool and no test is a coroutine, per the runner constraints
## documented in test_lobby.gd.

const _SCENE_PATH := "res://Scenes/AturJadwal/ActivityRow.tscn"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "activity_row"


var _row: Button


func setup() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	_row = scene.instantiate()
	_row.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_row)
	track(_row)


func teardown() -> void:
	if is_instance_valid(_row):
		_row.queue_free()
	_row = null


func test_scene_instantiates_as_a_button() -> void:
	assert_true(_row != null, "ActivityRow.tscn must load")
	assert_true(_row is Button, "the whole row must be tappable, so its root is a Button")


func test_row_meets_the_minimum_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	assert_true(_row.custom_minimum_size.y >= float(tokens.touch_target_min),
		"a row must be at least touch_target_min tall")


func test_row_has_the_nodes_the_script_reaches_for() -> void:
	for path in ["Container/Icon", "Container/Pill", "Container/Pill/Chips", "NameLabel"]:
		assert_true(_row.get_node_or_null(path) != null,
			"ActivityRow.tscn must declare the node: " + path)


func test_name_label_uses_the_outlined_variation() -> void:
	var label := _row.get_node_or_null("NameLabel") as Label
	assert_true(label != null, "NameLabel must exist")
	assert_eq(label.theme_type_variation, &"PreviewRowLabel",
		"the category name is white-on-art, so it needs the row label's outlined variation")


func test_pill_uses_the_preview_pill_variation() -> void:
	var pill := _row.get_node_or_null("Container/Pill") as PanelContainer
	assert_true(pill != null, "Pill must exist")
	assert_eq(pill.theme_type_variation, &"PreviewPill",
		"a skill row's pill must wear the PreviewPill variation, not a theme_override")


func test_theme_declares_the_new_variations() -> void:
	var theme: Theme = load(_THEME_PATH)
	for variation in ["PreviewPill", "PreviewChipLabel"]:
		assert_true(theme.get_type_list().has(variation),
			"the baked theme must declare " + variation + " -- did you forget to rebake?")


## Declaring the type is not enough. Without a base_type Godot never matches
## the variation to a PanelContainer, so the node silently falls back to the
## engine's default panel and the pill renders as translucent black.
func test_preview_pill_is_bound_to_panel_container() -> void:
	var theme: Theme = load(_THEME_PATH)
	assert_eq(theme.get_type_variation_base("PreviewPill"), &"PanelContainer",
		"PreviewPill must declare PanelContainer as its base_type, like every other panel variation")


## The end-to-end check the base_type test exists to protect: a real
## PanelContainer wearing the variation must resolve OUR stylebox, not the
## engine default (which is StyleBoxFlat with bg_color 0.1,0.1,0.1,0.6).
func test_preview_pill_resolves_the_designed_stylebox() -> void:
	var probe := PanelContainer.new()
	probe.theme = load(_THEME_PATH)
	probe.theme_type_variation = &"PreviewPill"
	Engine.get_main_loop().root.add_child(probe)
	track(probe)
	var resolved := probe.get_theme_stylebox("panel")
	var expected := (load(_THEME_PATH) as Theme).get_stylebox("panel", "PreviewPill")
	assert_true(resolved == expected,
		"a PreviewPill PanelContainer must resolve the theme's own stylebox, not Godot's default panel")


func test_scene_has_no_theme_overrides() -> void:
	# The project rule: styling flows from the theme, never from per-node
	# overrides. Layout-only constants (separation, margin_*) are exempt.
	var src := FileAccess.get_file_as_string(_SCENE_PATH)
	for line in src.split("\n"):
		if not line.begins_with("theme_override_"):
			continue
		var is_layout := line.begins_with("theme_override_constants/separation") \
			or line.begins_with("theme_override_constants/margin")
		assert_true(is_layout, "unexpected theme override in ActivityRow.tscn: " + line)


func test_refresh_writes_the_skill_gain_into_a_chip() -> void:
	var student := {"hobby_category": "Akademik", "name": "Uji"}
	_row.category = "Akademis"
	_row.refresh(student, 7, 50.0)
	var chips := _row.get_node("Container/Pill/Chips")
	assert_true(chips.get_child_count() >= 1, "refresh must populate at least one chip")


func test_refresh_builds_two_chips_for_libur() -> void:
	var student := {"hobby_category": "Akademik", "name": "Uji"}
	_row.category = "Istirahat"
	_row.refresh(student, 7, 0.0)
	var chips := _row.get_node("Container/Pill/Chips")
	assert_eq(chips.get_child_count(), 2,
		"Libur shows an energy chip and a mood chip")


## Rebuilding must not accumulate. Opening the popup five times used to be
## enough to stack fifteen stale chips behind the live ones.
func test_refresh_is_idempotent() -> void:
	var student := {"hobby_category": "Akademik", "name": "Uji"}
	_row.category = "Istirahat"
	_row.refresh(student, 7, 0.0)
	var after_first := _row.get_node("Container/Pill/Chips").get_child_count()
	_row.refresh(student, 7, 0.0)
	_row.refresh(student, 7, 0.0)
	assert_eq(_row.get_node("Container/Pill/Chips").get_child_count(), after_first,
		"refresh must clear old chips before adding new ones")


## Geometry pinned to the mockup's scanlines (penjadwalan_mockup.png, 1080x1920).
## Each row is ONE bordered container 141px tall; the icon draws on its grey and
## a darker pill is inset to the right. The name label overlaps the container's
## bottom edge and hangs into the 39px band beneath, so the row is 180 total.
const _ROW_HEIGHT := 180.0
const _CONTAINER_HEIGHT := 141.0
const _ICON_REGION := 214.0
const _PILL_RIGHT_INSET := 17.0
const _PILL_V_INSET := 23.0


func test_row_is_a_fixed_height_band() -> void:
	assert_eq(_row.custom_minimum_size.y, _ROW_HEIGHT,
		"the row's height is fixed at the mockup's 180px")
	assert_true(not (_row.size_flags_vertical & Control.SIZE_EXPAND),
		"the row must not expand vertically, or its parent VBox stretches it out of proportion")


func test_row_is_one_bordered_container() -> void:
	var box := _row.get_node_or_null("Container") as Panel
	assert_true(box != null, "the row must hold its contents in a single Container panel")
	assert_eq(box.theme_type_variation, &"PreviewRow",
		"the container wears the bordered-grey PreviewRow variation")
	assert_eq(box.offset_bottom, _CONTAINER_HEIGHT, "the container is 141px tall")
	assert_eq(box.anchor_right, 1.0, "the container spans the row's full width")
	assert_true(_row.get_node_or_null("IconBox") == null,
		"the old detached IconBox is gone -- the icon now draws on the container")


func test_icon_sits_inside_the_container_left_region() -> void:
	var icon := _row.get_node_or_null("Container/Icon") as TextureRect
	assert_true(icon != null, "Icon must live inside the Container")
	assert_true(icon.offset_right <= _ICON_REGION,
		"the icon must stay inside the 214px region left of the pill")


func test_pill_is_inset_into_the_container() -> void:
	var pill := _row.get_node_or_null("Container/Pill") as PanelContainer
	assert_true(pill != null, "Pill must live inside the Container")
	assert_eq(pill.offset_left, _ICON_REGION, "the pill starts where the icon region ends")
	assert_eq(pill.offset_right, -_PILL_RIGHT_INSET, "the pill is inset from the container's right edge")
	assert_eq(pill.offset_top, _PILL_V_INSET, "the pill is inset from the container's top")
	assert_eq(pill.offset_bottom, -_PILL_V_INSET, "the pill is inset from the container's bottom")


## The bar was 281x1 px: size_flags_vertical defaulted to SHRINK_BEGIN (0)
## and its minimum size is (1,1), so it collapsed into a hairline across the
## pill's top instead of filling behind the number.
func test_stat_bar_fills_the_pill_vertically() -> void:
	var bar := _row.get_node_or_null("Container/Pill/StatBar") as StatBar
	assert_true(bar != null, "skill rows keep their StatBar")
	assert_true(bar.size_flags_vertical & Control.SIZE_FILL,
		"the StatBar must fill its parent vertically, or it collapses to a 1px line")


func test_name_label_overlaps_the_container_bottom() -> void:
	var label := _row.get_node_or_null("NameLabel") as Label
	assert_true(label != null, "NameLabel must exist")
	assert_eq(label.theme_type_variation, &"PreviewRowLabel",
		"the row label has its own bigger, harder-rimmed variation")
	assert_true(label.offset_top < -(_ROW_HEIGHT - _CONTAINER_HEIGHT),
		"the label starts above the container's bottom edge, overlapping it as in the mockup")
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT,
		"the mockup right-aligns the name under the pill's right edge")


## Rows with no target (Wirausaha, Libur) keep the same node tree but draw no
## inset pill -- their chips sit straight on the container's grey.
func test_non_skill_rows_flatten_the_pill_and_drop_the_bar() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	var flat := scene.instantiate() as ActivityRow
	flat.is_skill_row = false
	flat.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(flat)
	track(flat)
	var pill := flat.get_node_or_null("Container/Pill") as PanelContainer
	assert_true(pill != null, "the Pill node still exists on a non-skill row")
	assert_eq(pill.theme_type_variation, &"PreviewPillFlat",
		"a non-skill row's pill must draw nothing")
	assert_true(flat.get_node_or_null("Container/Pill/StatBar") == null,
		"a non-skill row has no target, so no StatBar")
	flat.queue_free()


## The mockup's rows are one bordered grey container with a darker pill inset
## into it. These pin the four surfaces that produces, including base_type --
## a variation without one silently falls back to the engine default, which is
## exactly the bug that made the pills invisible before.
func test_preview_row_is_a_bordered_panel() -> void:
	var tokens := DesignTokens.load_default()
	var theme: Theme = load(_THEME_PATH)
	assert_eq(theme.get_type_variation_base("PreviewRow"), &"Panel",
		"PreviewRow must declare Panel as its base_type")
	var sb := theme.get_stylebox("panel", "PreviewRow") as StyleBoxFlat
	assert_true(sb != null, "PreviewRow/panel must be a StyleBoxFlat")
	assert_eq(sb.bg_color, tokens.preview_row_fill, "row container fill comes from the token")
	assert_eq(sb.border_color, tokens.preview_row_border, "row container border comes from the token")
	assert_true(sb.border_width_top >= 1, "the mockup's rows carry a visible purple border")


func test_preview_pill_uses_the_sampled_fill() -> void:
	var tokens := DesignTokens.load_default()
	var theme: Theme = load(_THEME_PATH)
	var sb := theme.get_stylebox("panel", "PreviewPill") as StyleBoxFlat
	assert_true(sb != null, "PreviewPill/panel must be a StyleBoxFlat")
	assert_eq(sb.bg_color, tokens.preview_pill_fill,
		"the inset pill is #363636 in the mockup, not the old near-black surface_overlay")


## Wirausaha and Libur have no inset pill -- their chips sit straight on the
## container's grey. They wear this variation so the code path stays single.
func test_preview_pill_flat_draws_nothing() -> void:
	var theme: Theme = load(_THEME_PATH)
	assert_eq(theme.get_type_variation_base("PreviewPillFlat"), &"PanelContainer",
		"PreviewPillFlat must declare PanelContainer as its base_type")
	assert_true(theme.get_stylebox("panel", "PreviewPillFlat") is StyleBoxEmpty,
		"PreviewPillFlat must draw no panel at all")


func test_preview_row_label_is_big_and_outlined() -> void:
	var tokens := DesignTokens.load_default()
	var theme: Theme = load(_THEME_PATH)
	assert_eq(theme.get_type_variation_base("PreviewRowLabel"), &"Label",
		"PreviewRowLabel must declare Label as its base_type")
	assert_eq(theme.get_font_size("font_size", "PreviewRowLabel"), tokens.font_h2,
		"the mockup's row labels are noticeably larger than CardSectionLabel's 36px")
	assert_eq(theme.get_color("font_color", "PreviewRowLabel"), tokens.text_on_brand,
		"row labels are white")
	assert_eq(theme.get_color("font_outline_color", "PreviewRowLabel"), tokens.preview_row_border,
		"the label's dark rim is the same purple as the row border")
	assert_true(theme.get_constant("outline_size", "PreviewRowLabel") >= 6,
		"the mockup's label rim is chunkier than CardSectionLabel's 4px")


## The mockup's rows carry a hard dark shadow just below their bottom border, and
## the inset pill has a soft dark edge rather than a stroke. Without them the
## surfaces read as flat decals on the card instead of raised/inset panels.
func test_preview_row_border_and_shadow_match_the_mockup() -> void:
	var theme: Theme = load(_THEME_PATH)
	var sb := theme.get_stylebox("panel", "PreviewRow") as StyleBoxFlat
	assert_true(sb != null, "PreviewRow/panel must be a StyleBoxFlat")
	assert_eq(sb.border_width_top, 3, "the mockup's row border is 3px, not 4")
	assert_true(sb.shadow_size > 0, "the row casts a drop shadow onto the card")
	assert_true(sb.shadow_offset.y > 0, "that shadow falls below the row, as in the mockup")


func test_preview_pill_has_a_soft_edge_not_a_stroke() -> void:
	var theme: Theme = load(_THEME_PATH)
	var sb := theme.get_stylebox("panel", "PreviewPill") as StyleBoxFlat
	assert_true(sb != null, "PreviewPill/panel must be a StyleBoxFlat")
	assert_eq(sb.border_width_top, 0,
		"the pill's dark edge is a shadow, not a border -- a stroke reads wrong")
	assert_true(sb.shadow_size > 0, "the pill's edge is a soft shadow")
