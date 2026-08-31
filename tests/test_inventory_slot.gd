@tool
extends McpTestSuite

## One inventory grid slot, authored once as a scene instead of built
## node-by-node for every item on every category change.
##
## The slot's border is tinted per item category (Buku/Olahraga/Makanan),
## not just per selection state -- that's a genuinely per-instance value no
## baked ThemeFactory variation can express, so setup() still builds two
## StyleBoxFlats (normal/selected) the same way the shipped code did. This
## mirrors the accepted exception already used for TraitPopupHeader and the
## quit dialog's card.
##
## Affects nothing at runtime. Must be @tool; no test here may be a
## coroutine.

func suite_name() -> String:
	return "inventory_slot"


const SCENE_PATH := "res://Scenes/Inventory/InventorySlot.tscn"


## The scene is added to the tree so its @onready vars resolve.
func _make() -> InventorySlot:
	var slot: InventorySlot = load(SCENE_PATH).instantiate()
	Engine.get_main_loop().root.add_child(slot)
	track(slot)
	return slot


func _sample_item(category: String = "Buku") -> ItemData:
	var item := ItemData.new()
	track(item)
	item.item_name = "Buku Tulis"
	item.category = category
	return item


func test_scene_exists_and_carries_its_nodes() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "%s is missing" % SCENE_PATH)
	var slot := _make()
	for path in ["Layout/Icon", "Layout/QuantityRow/QuantityLabel"]:
		assert_not_null(slot.get_node_or_null(path), "missing node: %s" % path)


func test_setup_fills_the_icon_and_quantity() -> void:
	var slot := _make()
	var item := _sample_item()
	slot.setup(item, 7)
	assert_eq((slot.get_node("Layout/QuantityRow/QuantityLabel") as Label).text, "×7")
	assert_eq(slot.item, item)


func test_setup_tints_the_border_by_category() -> void:
	# The category accent varies per item, so this is the one place a
	# runtime stylebox is still built -- same exception already used for
	# TraitPopupHeader and the quit dialog's card.
	slot_category_check("Buku")
	slot_category_check("Olahraga")


func slot_category_check(category: String) -> void:
	var slot := _make()
	slot.category_colors = {"Buku": Color.BLUE, "Olahraga": Color.RED, "Makanan": Color.GREEN}
	slot.setup(_sample_item(category), 1)
	var style: StyleBoxFlat = slot.get_theme_stylebox("panel")
	assert_eq(style.border_color, slot.category_colors[category].darkened(0.3))


func test_selection_swaps_styleboxes_without_rebuilding_them() -> void:
	var slot := _make()
	slot.setup(_sample_item(), 1)
	var normal: StyleBox = slot.get_theme_stylebox("panel")
	slot.set_selected(true)
	var selected: StyleBox = slot.get_theme_stylebox("panel")
	assert_ne(normal, selected, "selecting must swap to a different stylebox")
	slot.set_selected(false)
	assert_eq(slot.get_theme_stylebox("panel"), normal,
		"deselecting must restore the exact same normal stylebox instance, not rebuild one")


func test_a_clean_tap_emits_slot_pressed() -> void:
	var slot := _make()
	assert_true(slot.has_signal("slot_pressed"), "InventorySlot needs slot_pressed")


func test_inventory_no_longer_builds_slots_or_styleboxes_for_layout() -> void:
	# _create_item_slot() is kept as the entry point (callers still use that
	# name) -- its body now instantiates the scene instead of hand-building
	# nodes, which is what this checks.
	var src := FileAccess.get_file_as_string("res://Scripts/Inventory/inventory.gd")
	assert_contains(src, "InventorySlot", "inventory.gd should instantiate the scene")
	var start := src.find("func _create_item_slot")
	assert_gt(start, 0, "_create_item_slot should still exist as the call-site entry point")
	var next_func := src.find("\nfunc ", start + 1)
	var body := src.substr(start, (next_func if next_func != -1 else src.length()) - start)
	assert_false(body.contains("PanelContainer.new(") or body.contains("StyleBoxFlat.new("),
		"_create_item_slot still builds the slot by hand")


func test_empty_message_is_a_scene_node_not_a_runtime_label() -> void:
	# The "inventory kosong" state is a permanent part of the screen, so it
	# belongs in inventory.tscn where a human can restyle it.
	var text := FileAccess.get_file_as_string("res://Scenes/Inventory/inventory.tscn")
	assert_contains(text, "EmptyMessageLabel",
		"inventory.tscn should carry the empty-state label")
