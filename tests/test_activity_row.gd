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
	## CACHE_MODE_IGNORE is required because the editor caches the theme
	## from startup, so a plain load() reads the stale bake. Without it,
	## tests fail after rebaking even though the real bake is correct.
	## Because each call returns a fresh Theme instance, a test that needs
	## object identity (e.g. comparing StyleBoxes with ==) must load once
	## into a local variable and reuse it, not call load() again.
	_row.theme = ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
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
	var theme: Theme = ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	for variation in ["PreviewPill", "PreviewChipLabel"]:
		assert_true(theme.get_type_list().has(variation),
			"the baked theme must declare " + variation + " -- did you forget to rebake?")


## Declaring the type is not enough. Without a base_type Godot never matches
## the variation to a PanelContainer, so the node silently falls back to the
## engine's default panel and the pill renders as translucent black.
func test_preview_pill_is_bound_to_panel_container() -> void:
	var theme: Theme = ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	assert_eq(theme.get_type_variation_base("PreviewPill"), &"PanelContainer",
		"PreviewPill must declare PanelContainer as its base_type, like every other panel variation")


## The end-to-end check the base_type test exists to protect: a real
## PanelContainer wearing the variation must resolve OUR stylebox, not the
## engine default (which is StyleBoxFlat with bg_color 0.1,0.1,0.1,0.6).
func test_preview_pill_resolves_the_designed_stylebox() -> void:
	var theme := ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var probe := PanelContainer.new()
	probe.theme = theme
	probe.theme_type_variation = &"PreviewPill"
	Engine.get_main_loop().root.add_child(probe)
	track(probe)
	var resolved := probe.get_theme_stylebox("panel")
	var expected := theme.get_stylebox("panel", "PreviewPill")
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
	# Widened on 2026-09-10: the reference runs its bars nearly the full
	# width of the sheet, and the old 214px icon gutter plus a 17px right
	# inset left the bar noticeably short of it. The top inset grew instead,
	# to clear the label that now sits above the bar rather than below it.
	var icon := _row.get_node_or_null("Container/Icon") as TextureRect
	assert_true(icon != null, "the icon must exist to gutter against")
	assert_true(pill.offset_left > icon.offset_right,
		"the bar must start clear of the icon")
	assert_true(pill.offset_left < _ICON_REGION,
		"the bar was widened past the old 214px gutter")
	assert_true(pill.offset_right > -_PILL_RIGHT_INSET,
		"the bar reaches nearer the container's right edge than it used to")
	assert_true(pill.offset_top > _PILL_V_INSET,
		"the bar sits lower now, clearing the label above it")


## The bar was 281x1 px: size_flags_vertical defaulted to SHRINK_BEGIN (0)
## and its minimum size is (1,1), so it collapsed into a hairline across the
## pill's top instead of filling behind the number.
func test_stat_bar_fills_the_pill_vertically() -> void:
	var bar := _row.get_node_or_null("Container/Pill/StatBar") as StatBar
	assert_true(bar != null, "skill rows keep their StatBar")
	assert_true(bar.size_flags_vertical & Control.SIZE_FILL,
		"the StatBar must fill its parent vertically, or it collapses to a 1px line")


## The label used to hang off the container's bottom edge, right-aligned
## under the pill. The 2026-09-10 reference puts it above its bar and
## left-aligned with it, which is also what makes the bar readable as a
## measure rather than a decorated strip.
func test_name_label_sits_above_its_bar() -> void:
	var label := _row.get_node_or_null("NameLabel") as Label
	assert_true(label != null, "NameLabel must exist")
	assert_eq(label.theme_type_variation, &"PreviewRowLabel",
		"the row label has its own variation")
	var pill := _row.get_node_or_null("Container/Pill") as PanelContainer
	assert_true(pill != null, "Pill must exist")
	assert_true(label.offset_bottom <= pill.offset_top,
		"the label must clear the bar, not overlap it")
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT,
		"label and bar share a left edge, as in the reference")
	assert_eq(label.offset_left, pill.offset_left,
		"label and bar must start at the same x or the row looks ragged")


## Rows with no target (Wirausaha, Libur) keep the same node tree but swap
## the track for the ghost variation: same silhouette, alpha ramped, so
## the row reads as empty rather than as missing. Until 2026-09-10 they
## used PreviewPillFlat and drew nothing at all, which was fine on the old
## dark slab and collapsed the row once the sheet went cream.
func test_non_skill_rows_take_the_ghost_track_and_drop_the_bar() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	var flat := scene.instantiate() as ActivityRow
	flat.is_skill_row = false
	flat.theme = ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	Engine.get_main_loop().root.add_child(flat)
	track(flat)
	var pill := flat.get_node_or_null("Container/Pill") as PanelContainer
	assert_true(pill != null, "the Pill node still exists on a non-skill row")
	assert_eq(pill.theme_type_variation, &"PreviewTrackGhost",
		"a non-skill row's track must be the ghost variation, not empty")
	assert_true(flat.get_node_or_null("Container/Pill/StatBar") == null,
		"a non-skill row has no target, so no StatBar")
	flat.queue_free()


## The mockup's rows are one bordered grey container with a darker pill inset
## into it. These pin the four surfaces that produces, including base_type --
## a variation without one silently falls back to the engine default, which is
## exactly the bug that made the pills invisible before.
func test_preview_row_is_an_unstroked_cream_panel() -> void:
	var tokens := DesignTokens.load_default()
	var theme: Theme = ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	assert_eq(theme.get_type_variation_base("PreviewRow"), &"Panel",
		"PreviewRow must declare Panel as its base_type")
	# Until 2026-09-10 this asserted a brown fill and a 3px stroke. The
	# cream pass removed both: the card behind the row, the row's own slab,
	# the pill inside it and the bar made four surfaces per row. Recolouring
	# that stack cream was not enough -- a row that paints anything reads as
	# a box -- so the row now draws nothing and the hairlines between rows
	# do the dividing.
	var sb := theme.get_stylebox("panel", "PreviewRow")
	assert_true(sb is StyleBoxEmpty, "the cream row draws no surface of its own")


func test_preview_pill_uses_the_sampled_fill() -> void:
	var tokens := DesignTokens.load_default()
	var theme: Theme = ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var sb := theme.get_stylebox("panel", "PreviewPill") as StyleBoxFlat
	assert_true(sb != null, "PreviewPill/panel must be a StyleBoxFlat")
	assert_eq(sb.bg_color, tokens.preview_pill_fill,
		"the inset pill is #363636 in the mockup, not the old near-black surface_overlay")


## Wirausaha and Libur have no inset pill -- their chips sit straight on the
## container's grey. They wear this variation so the code path stays single.
func test_preview_pill_flat_draws_nothing() -> void:
	var theme: Theme = ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	assert_eq(theme.get_type_variation_base("PreviewPillFlat"), &"PanelContainer",
		"PreviewPillFlat must declare PanelContainer as its base_type")
	assert_true(theme.get_stylebox("panel", "PreviewPillFlat") is StyleBoxEmpty,
		"PreviewPillFlat must draw no panel at all")


## Until 2026-09-10 this label was cream with a chunky near-black rim,
## sized font_h2 and overlapping a dark brown row -- correct then. On the
## cream sheet that rendered as an outlined white smear, so it is now
## quiet dark text sitting above its bar. The bar is the loud element in
## the row; its name is not.
func test_preview_row_label_is_quiet_dark_text() -> void:
	var tokens := DesignTokens.load_default()
	var theme: Theme = ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	assert_eq(theme.get_type_variation_base("PreviewRowLabel"), &"Label",
		"PreviewRowLabel must declare Label as its base_type")
	assert_eq(theme.get_font_size("font_size", "PreviewRowLabel"), tokens.font_body_size,
		"the label sits a step below the numbers, not above them")
	assert_eq(theme.get_color("font_color", "PreviewRowLabel"), tokens.text_secondary,
		"row labels are quiet dark text on the cream sheet")
	assert_eq(theme.get_constant("outline_size", "PreviewRowLabel"), 0,
		"a rim exists to separate text from busy art; on cream it only smears")


## The mockup's rows carry a hard dark shadow just below their bottom border, and
## the inset pill has a soft dark edge rather than a stroke. Without them the
## surfaces read as flat decals on the card instead of raised/inset panels.
## The row used to carry a 3px stroke and a hard drop shadow, both
## sampled from the 2026-08-29 mockup. The 2026-09-10 cream pass removed
## both -- depth now comes from the track inset into the row, not from
## chrome around it. This asserts the removal so a future rebake cannot
## quietly reintroduce either.
func test_preview_row_carries_no_stroke_or_shadow() -> void:
	var theme: Theme = ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var sb := theme.get_stylebox("panel", "PreviewRow")
	assert_true(sb is StyleBoxEmpty,
		"an empty stylebox has no stroke and no shadow by construction")
	# The pressed sibling is where the row does get a surface -- and it
	# must not reintroduce the chrome the resting row shed.
	var pressed := theme.get_stylebox("panel", "PreviewRowPressed") as StyleBoxFlat
	assert_true(pressed != null, "PreviewRowPressed must be a StyleBoxFlat")
	assert_eq(pressed.shadow_size, 0, "the pressed row casts no drop shadow")


func test_preview_pill_has_a_soft_edge_not_a_stroke() -> void:
	var tokens := DesignTokens.load_default()
	var theme: Theme = ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var sb := theme.get_stylebox("panel", "PreviewPill") as StyleBoxFlat
	assert_true(sb != null, "PreviewPill/panel must be a StyleBoxFlat")
	assert_eq(sb.border_width_top, 0,
		"the pill's dark edge is a shadow, not a border -- a stroke reads wrong")
	assert_eq(sb.shadow_color, tokens.preview_pill_shadow_color,
		"the pill's shadow color must match preview_pill_shadow_color exactly")
	assert_eq(sb.shadow_size, tokens.preview_pill_shadow_size,
		"the pill's shadow size must match preview_pill_shadow_size exactly")
	assert_eq(sb.shadow_offset, tokens.preview_pill_shadow_offset,
		"the pill's shadow offset must match preview_pill_shadow_offset exactly")


## The pill corner radius moved from radius_sm to radius_md in the mockup-rescale
## plan (Task 3) so the pill's corners read as round as the container's -- that
## change shipped with no test, so a regression back to radius_sm would pass silently.
func test_preview_pill_corner_radius_matches_the_container() -> void:
	var tokens := DesignTokens.load_default()
	var theme: Theme = ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var sb := theme.get_stylebox("panel", "PreviewPill") as StyleBoxFlat
	assert_eq(sb.corner_radius_top_left, tokens.radius_md,
		"the pill's corners must be as round as the row container's")
