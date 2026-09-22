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
## Android alike (2026-09-15). The arrow is a texture beside the word, never a
## character.
##
## The format is not the point -- it was an .svg chevron until 2026-09-22 and
## is now the shared UI/Nav/return_button.png, one picture across all twelve
## back controls (tests/test_back_controls.gd pins that invariant). So this
## asserts it is a real asset, not which extension it wears.
func test_back_button_draws_its_arrow_as_a_texture_icon() -> void:
	var s := (load(_SCENE) as PackedScene).instantiate()
	var back := s.get_node("MainColumn/Header/HeaderCol/Row/BackButton") as Button
	assert_not_null(back.icon, "the back arrow must be a texture on the button")
	if back.icon != null:
		assert_true(back.icon.resource_path.begins_with("res://Assets/"),
			"the arrow must be a real asset, not %s" % back.icon.resource_path)
	assert_eq(back.icon_alignment, HORIZONTAL_ALIGNMENT_LEFT,
		"the arrow leads the word; centred, the text would draw over it")
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


## Measured live 2026-09-22: HeaderCol is two rows, not one. `Row` (back
## button, spacer, coin pill) is 1024x96 at y 0 with BackButton 277 wide at
## x 0 and CoinPill 79 wide at x 945 -- 668 px of free space between them --
## and TitleLabel is a separate row at y 114.
##
## So the header's minimum width is max(Row, TitleLabel), NOT the sum that
## DEBT.md measured on 2026-09-15 before 431cc5d moved the title onto its own
## line. That is why the back arrow could grow the row and cost the header
## nothing. If a later change puts the title back inside Row, the widths start
## summing again -- this goes red before the screen clips.
func test_the_header_title_is_its_own_row_not_in_the_button_row() -> void:
	var s := (load(_SCENE) as PackedScene).instantiate()
	var col := s.get_node_or_null("MainColumn/Header/HeaderCol")
	assert_not_null(col, "HeaderCol must exist")
	var row := s.get_node_or_null("MainColumn/Header/HeaderCol/Row")
	assert_not_null(row, "the button row must exist")
	var title := s.get_node_or_null("MainColumn/Header/HeaderCol/TitleLabel")
	assert_not_null(title, "TitleLabel must sit directly under HeaderCol, not inside Row")
	assert_true(s.get_node_or_null("MainColumn/Header/HeaderCol/Row/TitleLabel") == null,
		"TitleLabel must not be inside Row -- the widths would start summing again")
	s.free()


## The back button and the coin pill share `Row` from opposite ends
## (SHRINK_BEGIN / SHRINK_END), which is what leaves 668 px between them; the
## 36 px arrow spends about 32 of it. This is the margin that makes Inventory
## safe to swap, so it is worth pinning rather than shrugging at.
func test_the_back_button_and_coin_pill_hold_opposite_ends_of_the_row() -> void:
	var s := (load(_SCENE) as PackedScene).instantiate()
	var back := s.get_node_or_null("MainColumn/Header/HeaderCol/Row/BackButton") as Control
	var pill := s.get_node_or_null("MainColumn/Header/HeaderCol/Row/CoinPill") as Control
	assert_not_null(back, "BackButton must exist")
	assert_not_null(pill, "CoinPill must exist")
	if back == null or pill == null:
		s.free()
		return
	assert_eq(back.size_flags_horizontal, 0,
		"BackButton must shrink to the row's start, not expand into the gap")
	assert_eq(pill.size_flags_horizontal, Control.SIZE_SHRINK_END,
		"CoinPill must shrink to the row's end, so the two never meet")
	s.free()
