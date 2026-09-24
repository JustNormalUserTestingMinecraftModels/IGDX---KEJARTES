@tool
extends McpTestSuite

## ActivityTile is one tile of the Penjadwalan picker (2026-09-24 visual
## polish, D9-D14): a watermark behind crisp text, arrow meters for the
## effect, a Favorit ribbon, and a selected state. These pin its structure,
## its z-order, and that refresh() draws what ActivityPreview says.
##
## Suite is @tool and no test is a coroutine, per the runner constraints.

const _SCENE_PATH := "res://Scenes/AturJadwal/ActivityTile.tscn"
const _METER_PATH := "res://Scenes/AturJadwal/EffectMeter.tscn"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "activity_tile"


var _tile: ActivityTile


func setup() -> void:
	_tile = (load(_SCENE_PATH) as PackedScene).instantiate() as ActivityTile
	_tile.theme = ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	Engine.get_main_loop().root.add_child(_tile)
	track(_tile)


func teardown() -> void:
	if is_instance_valid(_tile):
		_tile.queue_free()
	_tile = null


func _marcel() -> Dictionary:
	return {"hobby_category": "Akademik", "name": "Marcel"}


func test_the_tile_is_one_tappable_button() -> void:
	assert_true(_tile is Button, "the whole tile is the tap target")
	assert_eq(_tile.theme_type_variation, &"PickerTileButton",
		"the Button draws nothing itself; the Sheet panel draws the tile")
	var tokens := DesignTokens.load_default()
	assert_true(_tile.custom_minimum_size.y >= float(tokens.touch_target_min),
		"a tile is at least touch_target_min tall")


func test_the_tile_has_the_nodes_the_script_reaches_for() -> void:
	for path in ["Sheet", "Watermark", "Content/Lines/NameLabel",
			"Content/Lines/GainRow/GainMeter", "Content/Lines/GainRow/GainValue",
			"Content/Lines/NeedsRow/EnergyMeter", "Content/Lines/NeedsRow/MoodMeter",
			"FavoritRibbon", "CheckBadge"]:
		assert_true(_tile.get_node_or_null(path) != null, "ActivityTile.tscn must declare " + path)


## The mockup hit exactly this bug: the watermark drew over the labels.
## Tree order is draw order, so it must come before the text.
func test_the_watermark_draws_behind_the_text() -> void:
	var mark := _tile.get_node("Watermark")
	var content := _tile.get_node("Content")
	assert_true(mark.get_index() < content.get_index(),
		"Watermark must sit before Content so the text draws above it")
	assert_true(_tile.get_node("Sheet").get_index() < mark.get_index(),
		"and above the tile's own panel")
	assert_true(absf((mark as CanvasItem).modulate.a - _tile.watermark_alpha) < 0.001,
		"the watermark's strength comes from the watermark_alpha knob")


func test_the_ribbon_and_check_draw_above_everything() -> void:
	var content_i := _tile.get_node("Content").get_index()
	assert_true(_tile.get_node("FavoritRibbon").get_index() > content_i, "ribbon on top")
	assert_true(_tile.get_node("CheckBadge").get_index() > content_i, "check on top")


func test_selected_swaps_to_the_gold_ring_and_shows_the_check() -> void:
	var sheet := _tile.get_node("Sheet") as Panel
	var check := _tile.get_node("CheckBadge") as CanvasItem
	assert_eq(sheet.theme_type_variation, &"PickerTile", "a resting tile")
	assert_false(check.visible, "no check until selected")
	_tile.selected = true
	assert_eq(sheet.theme_type_variation, &"PickerTileSelected", "the gold ring")
	assert_true(check.visible, "the check badge shows")
	_tile.selected = false
	assert_eq(sheet.theme_type_variation, &"PickerTile", "deselecting restores the tile")
	assert_false(check.visible, "and hides the check")


func test_a_favourite_skill_tile_shows_arrows_the_gain_and_the_ribbon() -> void:
	_tile.category = "Akademis"
	_tile.refresh(_marcel(), 7)
	var meter := _tile.get_node("Content/Lines/GainRow/GainMeter") as EffectMeter
	assert_eq(meter.shown_count(), ActivityPreview.gain_arrows("Akademis", _marcel(), 7),
		"the gain arrows are ActivityPreview's count")
	var value := _tile.get_node("Content/Lines/GainRow/GainValue") as Label
	assert_eq(value.text, "+%d" % int(ActivityPreview.skill_gain("Akademis", _marcel(), 7)),
		"D11: the exact gain rides beside the arrows")
	assert_true((_tile.get_node("FavoritRibbon") as CanvasItem).visible, "the favourite's ribbon")
	var energy := _tile.get_node("Content/Lines/NeedsRow/EnergyMeter") as EffectMeter
	assert_eq(energy.shown_count(), ActivityPreview.energy_arrows("Akademis", _marcel()),
		"energy arrows are ActivityPreview's count")


func test_wirausaha_shows_coin_pips_and_cuan_not_a_range() -> void:
	_tile.category = "Wirausaha"
	_tile.refresh(_marcel(), 7)
	var meter := _tile.get_node("Content/Lines/GainRow/GainMeter") as EffectMeter
	assert_eq(meter.shown_count(), ActivityPreview.earning_pips(), "coin pips, not a range")
	var value := _tile.get_node("Content/Lines/GainRow/GainValue") as Label
	assert_eq(value.text, "Cuan", "D12: a magnitude word, never ~120-320")
	var pip := meter.get_child(0) as TextureRect
	assert_eq(pip.texture, meter.coin_texture, "the pips are coins")
	assert_false((_tile.get_node("FavoritRibbon") as CanvasItem).visible,
		"Wirausaha is never a favourite")


func test_libur_hides_the_gain_row_and_recovers_upward() -> void:
	_tile.category = "Istirahat"
	_tile.refresh(_marcel(), 7)
	assert_false((_tile.get_node("Content/Lines/GainRow") as CanvasItem).visible,
		"Libur gains no skill, so no gain row")
	var energy := _tile.get_node("Content/Lines/NeedsRow/EnergyMeter") as EffectMeter
	assert_eq((energy.get_child(0) as TextureRect).texture, energy.up_texture,
		"Libur's energy arrows point up: it recovers")
	assert_true(energy.shown_count() >= 1, "and show at least one arrow")


func test_a_study_day_costs_downward() -> void:
	_tile.category = "Olahraga"
	_tile.refresh(_marcel(), 7)
	var mood := _tile.get_node("Content/Lines/NeedsRow/MoodMeter") as EffectMeter
	assert_eq((mood.get_child(0) as TextureRect).texture, mood.down_texture,
		"a study day's mood arrows point down: it costs")


## The meter toggles three authored pips rather than building any, so the
## picker adds nothing to test_viewport_editability's ratchet.
func test_the_effect_meter_toggles_three_authored_pips() -> void:
	var meter := (load(_METER_PATH) as PackedScene).instantiate() as EffectMeter
	Engine.get_main_loop().root.add_child(meter)
	track(meter)
	assert_eq(meter.get_child_count(), ActivityPreview.MAX_ARROWS,
		"one authored pip per possible arrow")
	for n in [0, 1, 2, 3, 5]:
		meter.show_effect(n, EffectMeter.Kind.GAIN)
		assert_eq(meter.shown_count(), mini(n, ActivityPreview.MAX_ARROWS),
			"show_effect(%d) shows that many pips, capped" % n)
	var src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/EffectMeter.gd")
	assert_false(src.contains("TextureRect.new("), "no pip is built at runtime")
	var tile_src := FileAccess.get_file_as_string("res://Scripts/AturJadwal/ActivityTile.gd")
	assert_false(tile_src.contains(".new("), "the tile builds nothing at runtime")
	meter.queue_free()


## The arrows are textures because no font of ours carries arrow glyphs.
func test_the_arrow_textures_are_assigned() -> void:
	var meter := (load(_METER_PATH) as PackedScene).instantiate() as EffectMeter
	assert_true(meter.up_texture != null and meter.down_texture != null and meter.coin_texture != null,
		"EffectMeter.tscn must assign all three pip textures")
	meter.free()


func test_scene_has_no_theme_overrides() -> void:
	for path in [_SCENE_PATH, _METER_PATH]:
		var src := FileAccess.get_file_as_string(path)
		for line in src.split("\n"):
			if not line.begins_with("theme_override_"):
				continue
			var is_layout := line.begins_with("theme_override_constants/separation") \
				or line.begins_with("theme_override_constants/margin")
			assert_true(is_layout, "unexpected theme override in %s: %s" % [path, line])


func test_the_baked_theme_declares_the_picker_variations() -> void:
	var theme := ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	for v in ["PickerSheet", "PickerHeader", "PickerTitleLabel", "PickerSubtitleLabel",
			"PickerTileButton", "PickerTile", "PickerTileSelected", "PickerTileName",
			"PickerTileValue", "PickerNeedLabel", "PickerRibbon", "PickerRibbonLabel",
			"PickerNotePanel", "PickerNoteLabel", "PickerLegendLabel"]:
		assert_true(theme.get_type_list().has(v), "the baked theme must declare %s -- rebake?" % v)
	var selected := theme.get_stylebox("panel", "PickerTileSelected") as StyleBoxFlat
	var tokens := DesignTokens.load_default()
	assert_true(selected != null and selected.border_color == tokens.currency_gold,
		"the selected tile's ring is gold (D13)")
