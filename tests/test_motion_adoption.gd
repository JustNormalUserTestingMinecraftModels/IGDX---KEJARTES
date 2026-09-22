@tool
extends McpTestSuite

## Motion polish adoption (2026-09-22, premium-look PR 5).
##
## Juice.gd is complete and token-driven; this pass adopts it, it does not
## extend it. Two things worth pinning, because both are easy to get wrong in
## a way that looks fine on the screen you are testing:
##
##   1. An entrance must not be driven from _ready() in the editor. pop_in
##      starts a node at zero alpha and 0.82 scale, so a layout suite that
##      stands the screen up would measure a tile that has not arrived.
##   2. An entrance must not touch a property some other system already owns.
##      Koperasi's shelf buttons carry AFFORDABILITY in modulate.a -- the
##      exact property pop_in tweens to 1.0 -- so an entrance there would
##      quietly un-dim every item the player cannot afford. That is a
##      gameplay signal, not a cosmetic one, which is why Koperasi is
##      deliberately left out of this pass.
##
## Must be @tool, and no test here may be a coroutine.

func suite_name() -> String:
	return "motion_adoption"


## Screens that gained an entrance, and the function that plays it.
const ENTRANCES := {
	"res://Scripts/Koperasi/shop_hub.gd": "play_entrance",
	"res://Scripts/Skins/SkinSelect.gd": "play_rail_entrance",
}


func test_each_entrance_is_a_named_function_not_an_inline_ready_block() -> void:
	for script_path in ENTRANCES:
		var src := FileAccess.get_file_as_string(script_path)
		assert_true(src.contains("func %s(" % ENTRANCES[script_path]),
			"%s must expose %s so a test can drive it deliberately"
				% [script_path, ENTRANCES[script_path]])
		assert_true(src.contains("Juice.stagger_in"),
			"%s should use the shared, token-driven vocabulary" % script_path)


## The editor gate. Without it, every layout suite that stands one of these
## screens up measures mid-entrance rects.
func test_the_shop_hub_entrance_does_not_fire_in_the_editor() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Koperasi/shop_hub.gd")
	# The indented CALL, not the first mention of the name -- the comment
	# above the gate names it too, and matching that would pass vacuously.
	var at := src.find("\n\t\tplay_entrance()")
	assert_true(at != -1, "shop_hub must call its entrance from _ready")
	if at == -1:
		return
	var before := src.substr(0, at)
	assert_true(before.ends_with("if not Engine.is_editor_hint():"),
		"the automatic call must sit directly under the editor gate, or a "
			+ "layout suite measures a tile that has not arrived")


## SkinSelect's own open() already returns early under the editor hint before
## it animates anything, so the rail entrance inherits that gate.
func test_the_skin_select_entrance_sits_after_the_editor_guard() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Skins/SkinSelect.gd")
	var guard := src.find("if Engine.is_editor_hint() or not is_inside_tree():")
	var call_at := src.find("\tplay_rail_entrance()")
	assert_true(guard != -1, "open() must keep its editor guard")
	assert_true(call_at != -1, "open() must play the rail entrance")
	assert_true(guard < call_at,
		"the entrance must sit after the guard that returns in the editor")


## The hazard that kept Koperasi out. If someone later adds an entrance to the
## shelf, this fails and says why.
func test_the_shelf_keeps_affordability_in_the_alpha_no_entrance_writes() -> void:
	var shelf := FileAccess.get_file_as_string("res://Scripts/Koperasi/ShelfItem.gd")
	assert_true(shelf.contains("_button.modulate.a = dim_alpha if dim else 1.0"),
		"this test exists because dimming rides on modulate.a; re-check it if that moved")

	for script_path in ["res://Scripts/Koperasi/koprasi.gd",
			"res://Scripts/Koperasi/rakbarang_1.gd"]:
		var src := FileAccess.get_file_as_string(script_path)
		assert_false(src.contains("Juice.pop_in") or src.contains("Juice.stagger_in"),
			"%s must not pop_in the shelf: pop_in tweens modulate.a to 1.0, which "
				% script_path + "would un-dim every item the player cannot afford")
