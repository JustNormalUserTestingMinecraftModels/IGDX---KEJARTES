@tool
extends McpTestSuite

## Inventory screen. Suite is @tool and no test is a coroutine, per the
## runner constraints documented in test_lobby.gd.

func suite_name() -> String:
	return "inventory"

const _SCENE_PATH := "res://Scenes/Inventory/inventory.tscn"
const _SCRIPT_PATH := "res://Scripts/Inventory/inventory.gd"

func _source() -> String:
	return FileAccess.get_file_as_string(_SCRIPT_PATH)

func test_scene_loads_and_instantiates() -> void:
	assert_true(ResourceLoader.exists(_SCENE_PATH), "inventory.tscn must exist")
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	assert_true(scene != null, "inventory.tscn must instantiate")
	scene.free()

func test_back_button_returns_to_lobby_not_shop() -> void:
	var src := _source()
	assert_true(src.contains("res://Scenes/Lobby/loby.tscn"),
		"back must return to the lobby")
	assert_false(src.contains("koprasi.tscn"),
		"the inventory must not link back into the shop")

func test_uses_audio_director_not_sfx_manager() -> void:
	var src := _source()
	assert_false(src.contains("SfxManager"), "SfxManager was not imported")
	assert_true(src.contains("AudioDirector.play_sfx"), "must use AudioDirector")

func test_does_not_reference_source_project_paths() -> void:
	var src := _source()
	assert_false(src.contains("res://Scene/"), "no source-project scene paths")
	assert_false(src.contains("res://Asset/"), "no source-project asset paths")

func test_scene_has_no_source_project_resource_paths() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	assert_false(raw.contains("res://Asset/"), "scene must not reference res://Asset/")
	assert_false(raw.contains("res://Script/"), "scene must not reference res://Script/")

func test_item_icons_are_preserved_art() -> void:
	## The item icons are finished art, not placeholders. This pins that
	## they still resolve after the port.
	for item_name in ["Komik", "Raket", "Mie Instan"]:
		var item: ItemData = ItemDatabase.get_item(item_name)
		assert_true(item.icon != null, "icon preserved for: " + item_name)

func test_no_placeholder_chrome_textures() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	for placeholder in ["btn_normal", "btn_pressed", "slot_normal", "slot_selected"]:
		assert_false(raw.contains(placeholder),
			"placeholder chrome must be replaced by the theme: " + placeholder)

func test_preserved_art_is_still_referenced() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	assert_true(raw.contains("Assets/Images/Shop/"),
		"the ported art must still be referenced")

func test_no_raw_color_literals_in_script() -> void:
	## Colors come from DesignTokens, matching the rule test_lobby.gd
	## enforces for the lobby.
	var src := _source()
	assert_false(src.contains("Color(0."),
		"no hardcoded Color() literals -- use DesignTokens")

func test_script_reads_design_tokens() -> void:
	assert_true(_source().contains("DesignTokens.load_default()"),
		"styling must be sourced from DesignTokens")

func test_scene_uses_project_theme() -> void:
	var raw := FileAccess.get_file_as_string(_SCENE_PATH)
	assert_true(raw.contains("kejartes_theme.tres"),
		"the scene root must carry the project theme")

func test_use_popup_uses_the_project_scrim() -> void:
	assert_true(_source().contains("scrim_color()"),
		"the modal backdrop must use DesignTokens.scrim_color()")

func test_use_popup_animates_with_token_durations() -> void:
	assert_true(_source().contains("dur_fast"),
		"popup fades must use the token duration, not a magic number")

func test_scene_changes_specify_a_transition_style() -> void:
	assert_true(_source().contains("Transition.Style."),
		"navigation must specify this project's transition style")

func test_closing_use_popup_does_not_clear_grid_selection() -> void:
	## Regression: selected_item is shared with the grid's slot-selection
	## state (owned by _select_slot/_deselect_slot). _close_popup_animated
	## must not null it out on Cancel/OK, or the grid slot stays visually
	## selected while the Use button silently goes dead until the player
	## taps the slot again. Only _deselect_slot is allowed to clear it.
	var src := _source()
	var close_fn_start := src.find("func _close_popup_animated")
	var close_fn_end := src.find("\nfunc ", close_fn_start + 1)
	var close_fn_body := src.substr(close_fn_start, close_fn_end - close_fn_start)
	assert_false(close_fn_body.contains("selected_item = null"),
		"_close_popup_animated must not clear selected_item -- that is the grid's job")

func test_use_popup_has_a_student_strip() -> void:
	var scene := (load(_SCENE_PATH) as PackedScene).instantiate()
	var strip := scene.find_child("StudentStrip", true, false)
	assert_true(strip != null,
		"the use popup must offer a student to apply the item to")
	scene.free()

func test_use_targets_the_selected_student() -> void:
	var src := _source()
	assert_true(src.contains("_selected_student_id"),
		"the popup must track which student was picked")
	assert_true(src.contains("GameState.use_item("),
		"confirm must route through GameState.use_item")

func test_confirm_is_gated_on_a_student_selection() -> void:
	assert_true(_source().contains("popup_ok_btn.disabled"),
		"confirm stays disabled until a student is chosen")

func test_no_global_player_mood_reference() -> void:
	var src := _source()
	assert_false(src.contains("GameState.player_mood"),
		"the global stat model was not imported")
	assert_false(src.contains("GameState.player_energy"),
		"the global stat model was not imported")
