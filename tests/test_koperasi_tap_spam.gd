@tool
extends McpTestSuiteCompat

## Task 7 of the 2026-09-17 Koperasi polish plan: the three-layer tap-spam
## safeguard -- ChatBubble's per-event SAY_COOLDOWN (already built in Task 2),
## ShelfItem's per-slot tap lock (_locked/on_tap/on_flight_finished), and
## Cart's per-frame add cap (MAX_ADDS_PER_FRAME). Nothing here needs a scene
## open; ChatBubble and ShelfItem instances are built the same way
## test_koperasi_chat_bubble.gd and test_koperasi_tray_retract.gd do it --
## added under Engine.get_main_loop().root since McpTestSuiteCompat is not
## itself a Node -- and freed at the end of each test. Cart is the live
## autoload; every test restores it via Cart.clear().
##
## No test here is a coroutine.

const RAK_PATH := "res://Scripts/Koperasi/rakbarang_1.gd"
const ITEM_NAME := "Cilok"


func suite_name() -> String:
	return "koperasi_tap_spam"


func setup() -> void:
	Cart.clear()


func teardown() -> void:
	Cart.clear()


# ----- helpers (mirroring test_koperasi_chat_bubble.gd / test_koperasi_tray_retract.gd) -----

func _live_bubble() -> ChatBubble:
	var bubble := ChatBubble.new()

	var body := PanelContainer.new()
	body.name = "Body"
	var text := RichTextLabel.new()
	text.name = "Text"
	body.add_child(text)
	bubble.add_child(body)

	var tail := TextureRect.new()
	tail.name = "Tail"
	tail.position = Vector2(751.0, 230.0)
	tail.size = Vector2(65.0, 115.0)
	bubble.add_child(tail)

	Engine.get_main_loop().root.add_child(bubble)
	return bubble


## A ShelfItem needs a TextureButton to ghost (locked_alpha) via attach_to().
func _live_shelf_item() -> Array:
	var btn := TextureButton.new()
	Engine.get_main_loop().root.add_child(btn)
	var life := ShelfItemScript.new()
	btn.add_child(life)
	life.attach_to(btn)
	return [life, btn]

const ShelfItemScript := preload("res://Scripts/Koperasi/ShelfItem.gd")


## Array counter: a plain int captured by a lambda in GDScript is captured
## BY VALUE, so `accepted += 1` inside the closure would never be visible
## outside it. An Array is captured by reference, so append() is.
func test_bubble_cooldown_absorbs_repeat_events_same_frame() -> void:
	var bubble := _live_bubble()
	var accepted: Array = []
	bubble.state_changed.connect(func(s):
		if s == ChatBubble.State.SHOWING:
			accepted.append(s))
	for i in range(10):
		bubble.say(&"ADD")
	assert_eq(accepted.size(), 1, "cooldown should let only one SHOWING through for 10 same-frame calls")
	bubble.queue_free()


## Fix round 1: a same-frame test can never see a second SHOWING emission
## for an already-SHOWING bubble -- _set_state() early-returns on a
## same-state transition (by design, see ChatBubble.gd's header), so an
## accepted say() while already SHOWING re-tweens and re-texts but does not
## re-fire state_changed. Read the cooldown gate's own bookkeeping
## (_last_say_time) and the resulting label text instead of counting
## state_changed emissions.
func test_bubble_cooldown_lets_a_different_event_interrupt() -> void:
	var bubble := _live_bubble()
	bubble.say(&"ADD")
	assert_false(bubble._last_say_time.has(&"REMOVE"),
		"REMOVE should not have a recorded cooldown timestamp yet")
	bubble.say(&"REMOVE")
	assert_true(bubble._last_say_time.has(&"REMOVE"),
		"a different event must still pass its own cooldown gate (ADD then REMOVE, per spec)")
	assert_true(DialogueCatalog.LINES[&"REMOVE"].has(bubble._label.text),
		"the bubble should now show a REMOVE line, not the stale ADD one")
	bubble.queue_free()


## Same fix-round-1 reasoning as above: the bubble is already SHOWING after
## the first say(), so a second, accepted say() of the same event cannot be
## proven via state_changed. _pass_cooldown() unconditionally stamps
## _last_say_time[event] = now on every accepted call, so a later timestamp
## than our backdated one is direct proof the gate passed and _play() ran.
func test_bubble_accepts_same_event_again_after_cooldown_elapses() -> void:
	var bubble := _live_bubble()
	bubble.say(&"ADD")
	# Backdate the recorded time past SAY_COOLDOWN instead of waiting/awaiting
	# (no coroutine tests allowed here).
	var backdated: int = Time.get_ticks_msec() - int(ChatBubble.SAY_COOLDOWN * 1000.0) - 5
	bubble._last_say_time[&"ADD"] = backdated
	bubble.say(&"ADD")
	assert_true(int(bubble._last_say_time[&"ADD"]) > backdated,
		"a same-event say() after the cooldown window must be accepted (advances the gate's timestamp)")
	bubble.queue_free()


func test_cart_adds_capped_per_frame() -> void:
	var data: ItemData = ItemDatabase.get_item(ITEM_NAME)
	var added: Array = []
	var handler := func(name: String): added.append(name)
	Cart.item_added.connect(handler)
	for i in range(10):
		Cart.add_item(data)
	Cart.item_added.disconnect(handler)
	var qty: int = int(Cart.cart[ITEM_NAME]["quantity"])
	assert_eq(qty, Cart.MAX_ADDS_PER_FRAME, "10 same-frame adds should stack only up to the cap")
	assert_eq(added.size(), Cart.MAX_ADDS_PER_FRAME,
		"a dropped add must not emit item_added")


## Fix round 2: add_item() must report the drop so a caller that already
## spent state (rakbarang_1.gd's taken slot / tray hold / flight) can undo
## it, instead of the drop being silently invisible to the caller.
func test_add_item_returns_false_once_the_frame_cap_is_hit() -> void:
	var data: ItemData = ItemDatabase.get_item(ITEM_NAME)
	var results: Array = []
	for i in range(4):
		results.append(Cart.add_item(data))
	assert_eq(results, [true, true, true, false],
		"the 4th same-frame add should be refused once MAX_ADDS_PER_FRAME (3) is hit")
	var emitted: Array = []
	var handler := func(name: String): emitted.append(name)
	Cart.item_added.connect(handler)
	Cart.add_item(data)
	Cart.item_added.disconnect(handler)
	assert_eq(emitted.size(), 0, "a refused add must not emit item_added")


## The slot/hold must still be taken BEFORE Cart.add_item() (so the
## cart_changed refresh it triggers empties the right slot and hides the
## right held unit -- test_koperasi_tray.gd and test_shop_weekly_stock.gd
## pin that ordering). A dropped add (Cart's per-frame cap) must instead be
## rolled back: untake the slot, release the tray hold, refresh shelf
## visibility, and report the flight as finished without ever spawning it.
func test_rakbarang_press_handler_rolls_back_a_refused_add() -> void:
	var src := FileAccess.get_file_as_string(RAK_PATH)
	var body := _body(src, "func _on_barang_pressed(")
	var take_at := body.find("_taken_slots.append(index)")
	var hold_at := body.find("tray.hold_for_landing(")
	var add_at := body.find("if not Cart.add_item(item):")
	assert_true(take_at >= 0 and hold_at >= 0 and add_at >= 0,
		"the handler must take the slot, hold the tray unit, then branch on Cart.add_item()")
	assert_true(take_at < add_at and hold_at < add_at,
		"the slot/hold must be taken BEFORE Cart.add_item() is called")
	var rollback := body.substr(add_at, body.length() - add_at)
	assert_true(rollback.contains("_taken_slots.erase(index)"),
		"a refused add must un-take the slot")
	assert_true(rollback.contains("tray.release_hold("),
		"a refused add must release the tray hold")
	assert_true(rollback.contains("_refresh_shelf_visibility()"),
		"a refused add must refresh shelf visibility after rolling back")
	assert_true(rollback.contains(".on_flight_finished()"),
		"a refused add must still report the flight as finished")


const _TRAY_SCENE := "res://Scenes/Koperasi/BasketTray.tscn"

## BasketTray.release_hold() is hold_for_landing()'s inverse: it must undo
## exactly one held unit (not clear the whole line) and re-refresh so a
## slot rolled back this way doesn't sit hidden forever. Uses the real
## scene (like test_basket_tray.gd) rather than a bare BasketTray.new(),
## since release_hold() calls refresh(), which touches the authored
## Body/EmptyState etc. nodes that a bare node would not have.
func test_basket_tray_release_hold_undoes_one_unit() -> void:
	var packed: PackedScene = load(_TRAY_SCENE)
	var tray = packed.instantiate()
	Engine.get_main_loop().root.add_child(tray)
	tray.hold_for_landing(ITEM_NAME)
	tray.hold_for_landing(ITEM_NAME)
	assert_eq(int(tray._held.get(ITEM_NAME, 0)), 2, "two holds should be recorded")
	tray.release_hold(ITEM_NAME)
	assert_eq(int(tray._held.get(ITEM_NAME, 0)), 1, "release_hold() should undo exactly one unit")
	tray.release_hold(ITEM_NAME)
	assert_false(tray._held.has(ITEM_NAME), "the last release_hold() should erase the entry")
	tray.queue_free()


func test_cart_clear_resets_the_per_frame_budget() -> void:
	var data: ItemData = ItemDatabase.get_item(ITEM_NAME)
	for i in range(Cart.MAX_ADDS_PER_FRAME):
		Cart.add_item(data)
	assert_eq(int(Cart.cart[ITEM_NAME]["quantity"]), Cart.MAX_ADDS_PER_FRAME,
		"budget should be exhausted after MAX_ADDS_PER_FRAME adds")
	Cart.clear()
	Cart.add_item(data)
	assert_eq(int(Cart.cart[ITEM_NAME]["quantity"]), 1,
		"clear() should start a fresh per-frame budget, in the same frame")


## Color components (btn.modulate) are 32-bit floats; a GDScript float
## literal like 0.6 is a 64-bit double. Comparing them with assert_eq's exact
## `!=` fails on the truncation (0.6 as float32 != 0.6 as double) even
## though the value is functionally correct -- compare with a tolerance
## instead. This suite has no assert_almost_eq, so roll a tiny local one.
func _nearly(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func test_shelf_item_on_tap_locks_and_second_tap_is_refused() -> void:
	var pair := _live_shelf_item()
	var life = pair[0]
	var btn: TextureButton = pair[1]
	assert_true(life.on_tap(), "first tap should succeed and lock the slot")
	assert_false(life.on_tap(), "a second tap while locked must be refused")
	assert_true(_nearly(btn.modulate.a, life.locked_alpha),
		"a locked slot should ghost to locked_alpha")
	life._unlock()
	assert_true(_nearly(btn.modulate.a, 1.0), "_unlock() should restore full alpha")
	assert_true(life.on_tap(), "after _unlock(), a new tap should succeed again")
	btn.queue_free()


func test_shelf_item_on_flight_finished_unlocks() -> void:
	var pair := _live_shelf_item()
	var life = pair[0]
	var btn: TextureButton = pair[1]
	life.on_tap()
	life.on_flight_finished()
	assert_false(life._locked, "on_flight_finished() should clear the lock")
	assert_true(_nearly(btn.modulate.a, 1.0), "on_flight_finished() should restore full alpha")
	btn.queue_free()


## Fix round 2: _unlock() (and the on_tap() ghost) must compose with the
## affordability dim recorded by set_dimmed(), not always snap back to full
## opacity -- otherwise an item that goes unaffordable mid-flight (or was
## unaffordable when tapped) reads as buyable again the instant the lock
## lifts, letting the player cart it.
func test_unlock_restores_dim_when_item_is_unaffordable() -> void:
	var pair := _live_shelf_item()
	var life = pair[0]
	var btn: TextureButton = pair[1]
	life.set_dimmed(true)
	assert_true(_nearly(btn.modulate.a, life.dim_alpha),
		"set_dimmed(true) should dim the button")
	life.on_tap()
	assert_true(_nearly(btn.modulate.a, life.locked_alpha),
		"on_tap() should still ghost to locked_alpha while locked")
	life.on_flight_finished()
	assert_true(_nearly(btn.modulate.a, life.dim_alpha),
		"unlocking an unaffordable item must restore the dim, not full alpha")
	btn.queue_free()


func test_unlock_restores_full_alpha_when_item_is_affordable() -> void:
	var pair := _live_shelf_item()
	var life = pair[0]
	var btn: TextureButton = pair[1]
	life.set_dimmed(false)
	life.on_tap()
	life.on_flight_finished()
	assert_true(_nearly(btn.modulate.a, 1.0),
		"unlocking an affordable item should restore full alpha")
	btn.queue_free()


func test_rakbarang_press_handler_checks_on_tap_and_reports_flight_finished() -> void:
	var src := FileAccess.get_file_as_string(RAK_PATH)
	var body := _body(src, "func _on_barang_pressed(")
	assert_true(body.contains(".on_tap()"),
		"the press handler must gate on ShelfItem.on_tap() (shelf debounce)")
	assert_true(src.contains(".on_flight_finished()"),
		"the flight's completion (and its early-return paths) must call on_flight_finished()")


## Fix round 2 (item 4): the taken-slot check must come BEFORE the
## on_tap() lock, so a dead tap on an already-taken/sold slot always
## reaches Herman even while the slot happens to be locked -- gating it
## behind on_tap() first let a lock refusal swallow shelf_dead_tap.
func test_taken_slot_check_precedes_the_on_tap_lock() -> void:
	var src := FileAccess.get_file_as_string(RAK_PATH)
	var body := _body(src, "func _on_barang_pressed(")
	var taken_at := body.find("_taken_slots.has(index)")
	var lock_at := body.find(".on_tap()")
	assert_true(taken_at >= 0 and lock_at >= 0,
		"both the taken-slot check and the on_tap() lock must be present")
	assert_true(taken_at < lock_at,
		"the taken-slot check (shelf_dead_tap) must run before the on_tap() lock")


## The text of one function: from `signature` to the next top-level func.
## Same pattern as test_shop_weekly_stock.gd's _body().
func _body(src: String, signature: String) -> String:
	var at := src.find(signature)
	if at < 0:
		return ""
	var end := src.length()
	for marker in ["\nfunc ", "\nstatic func "]:
		var next := src.find(marker, at + 1)
		if next > 0:
			end = mini(end, next)
	return src.substr(at, end - at)
