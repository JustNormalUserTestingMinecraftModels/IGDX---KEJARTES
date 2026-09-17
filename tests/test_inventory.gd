@tool
extends McpTestSuiteCompat

## Inventory screen: 3-zone portrait layout, theme-driven (no per-node
## StyleBoxFlat overrides), routes to ItemDetailSheet + ApplyItemScreen.
## @tool, no coroutine tests.

func suite_name() -> String:
	return "inventory"

const _SCENE := "res://Scenes/Inventory/inventory.tscn"
const _SCRIPT := "res://Scripts/Inventory/inventory.gd"
const _THEME := "res://Assets/Theme/kejartes_theme.tres"

func _src() -> String:
	return FileAccess.get_file_as_string(_SCRIPT)

func _raw() -> String:
	return FileAccess.get_file_as_string(_SCENE)

func test_scene_loads_and_instantiates() -> void:
	assert_true(ResourceLoader.exists(_SCENE), "inventory.tscn must exist")
	var s := (load(_SCENE) as PackedScene).instantiate()
	assert_true(s != null, "must instantiate")
	s.free()

func test_three_zone_layout_present() -> void:
	var s := (load(_SCENE) as PackedScene).instantiate()
	for n in ["Header", "FilterRow", "Grid", "ToastLabel"]:
		assert_not_null(s.find_child(n, true, false), "missing " + n)
	s.free()

func test_sidebar_and_old_modals_are_gone() -> void:
	var s := (load(_SCENE) as PackedScene).instantiate()
	for n in ["Sidebar", "DetailPanel", "UsePopup", "CategoryList"]:
		assert_true(s.find_child(n, true, false) == null, n + " must be gone")
	s.free()

func test_four_category_tabs_and_a_selector_thumb_present() -> void:
	var s := (load(_SCENE) as PackedScene).instantiate()
	for n in ["TabSemua", "TabBuku", "TabOlahraga", "TabMakanan"]:
		var b = s.find_child(n, true, false)
		assert_true(b != null and b is Button, "missing tab " + n)
	assert_not_null(s.find_child("Thumb", true, false), "selector thumb present")
	s.free()

func test_scene_has_no_styleboxflat_overrides() -> void:
	var raw := _raw()
	assert_false(raw.contains("SubResource(\"StyleBoxFlat"),
		"chrome comes from the theme, not per-node StyleBoxFlat subresources")
	assert_false(raw.contains("Color(0."), "no raw colour literals in the scene")

func test_script_has_no_runtime_chrome() -> void:
	var src := _src()
	for gone in ["_apply_category_style", "_style_all_category_buttons",
			"_build_student_strip", "_open_use_popup", "_spawn_floating_stat_pops",
			"_apply_png_panel_overrides"]:
		assert_false(src.contains(gone), "removed: " + gone)
	assert_false(src.contains("theme_override"), "no theme_override in script")
	assert_false(src.contains("Color(0."), "colours from DesignTokens only")

func test_script_routes_to_sheet_and_apply_screen() -> void:
	var src := _src()
	assert_contains(src, "detail_sheet_scene", "opens the detail sheet")
	assert_contains(src, "apply_screen_scene", "opens the apply screen")
	assert_contains(src, "ItemDetailSheet.tscn", "preloads the sheet scene")
	assert_contains(src, "ApplyItemScreen.tscn", "preloads the apply scene")

func test_back_returns_to_lobby_with_a_transition_style() -> void:
	var src := _src()
	assert_contains(src, "res://Scenes/Lobby/loby.tscn", "back goes to the lobby")
	assert_contains(src, "Transition.Style.", "navigation names a transition style")
	assert_false(src.contains("koprasi.tscn"), "must not link back into the shop")

func test_uses_audio_director() -> void:
	assert_contains(_src(), "AudioDirector.play_sfx", "uses AudioDirector")
	assert_false(_src().contains("SfxManager"), "no SfxManager")

func test_item_icons_preserved() -> void:
	for item_name in ["Komik", "Raket", "Mie Instan"]:
		assert_not_null(ItemDatabase.get_item(item_name).icon, "icon kept: " + item_name)

func test_no_global_player_stat_refs() -> void:
	var src := _src()
	assert_false(src.contains("GameState.player_mood"), "no global mood")
	assert_false(src.contains("GameState.player_energy"), "no global energy")

## Boohong, the face every button label wears, has no single guillemet: its
## cmap sends "‹" (and "›", "‚") to its apostrophe glyph and "«"/"»" to its
## double quote. "‹ Kembali" therefore shipped as "' KEMBALI", on desktop and
## Android alike (2026-09-15). The chevron is an SVG texture beside the word.
func test_back_button_draws_its_chevron_as_an_svg_icon() -> void:
	var s := (load(_SCENE) as PackedScene).instantiate()
	var back := s.get_node("MainColumn/Header/HeaderCol/Row/BackButton") as Button
	assert_not_null(back.icon, "the back chevron must be a texture on the button")
	if back.icon != null:
		assert_true(back.icon.resource_path.ends_with(".svg"),
			"the chevron must be an SVG texture, not %s" % back.icon.resource_path)
	assert_eq(back.icon_alignment, HORIZONTAL_ALIGNMENT_LEFT,
		"the chevron leads the word; centred, the text would draw over it")
	s.free()

## Guards the label itself. Resolved through the bake the way the game
## resolves it, no character may draw as the font's quote mark.
func test_back_button_text_draws_no_character_as_a_quote_mark() -> void:
	var s := (load(_SCENE) as PackedScene).instantiate()
	var back := s.get_node("MainColumn/Header/HeaderCol/Row/BackButton") as Button
	var theme := ResourceLoader.load(_THEME, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var variation := String(back.theme_type_variation)
	var font := theme.get_font("font", variation)
	var size := theme.get_font_size("font_size", variation)
	var ts := TextServerManager.get_primary_interface()
	var rid: RID = font.get_rids()[0]
	var quotes := [ts.font_get_glyph_index(rid, size, "'".unicode_at(0), 0),
		ts.font_get_glyph_index(rid, size, "\"".unicode_at(0), 0)]
	for i in back.text.length():
		var c := back.text.unicode_at(i)
		if c == "'".unicode_at(0) or c == "\"".unicode_at(0):
			continue
		assert_false(quotes.has(ts.font_get_glyph_index(rid, size, c, 0)),
			"\"%s\" in \"%s\" draws as a quote mark in %s"
			% [char(c), back.text, font.get_font_name()])
	s.free()
