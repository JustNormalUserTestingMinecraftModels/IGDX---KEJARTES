@tool
extends McpTestSuiteCompat

## Suite for Task 5 of the 2026-09-17 Koperasi polish: the tray's
## EXPANDED/COLLAPSED state machine. The crate handle it used to drive
## was removed on 2026-09-22; the drag on Body is the only toggle now.
## BasketTray instances are freed after every test; none of this touches
## Cart or GameState, so nothing needs restoring.

func suite_name() -> String:
	return "koperasi_tray_retract"

const TRAY_SCENE := preload("res://Scenes/Koperasi/BasketTray.tscn")
const KOPRASI_TSCN := "res://Scenes/Koperasi/koprasi.tscn"


## McpTestSuiteCompat is not itself a Node, so an instantiated BasketTray
## needs a real place in the tree -- same pattern as
## test_koperasi_chat_bubble.gd's _live_bubble().
func _live_tray() -> Control:
	var t: Control = TRAY_SCENE.instantiate()
	Engine.get_main_loop().root.add_child(t)
	return t


func test_tray_starts_expanded() -> void:
	var t: Control = _live_tray()
	assert_true(t.is_expanded(), "a fresh tray should be expanded")
	t.queue_free()


func test_set_state_false_moves_by_exact_offset_and_emits_once() -> void:
	var t: Control = _live_tray()
	var y0: float = t.position.y
	var seen: Array = []
	t.state_changed.connect(func(s): seen.append(s))
	t.set_state(t.ViewState.COLLAPSED, false)
	assert_eq(t.position.y, y0 + t.tray_offset_collapsed,
		"COLLAPSED should move position.y by exactly tray_offset_collapsed")
	assert_eq(seen.size(), 1, "state_changed should fire exactly once")
	assert_eq(seen[0], t.ViewState.COLLAPSED, "state_changed should carry COLLAPSED")
	t.queue_free()


func test_set_state_same_state_is_a_noop() -> void:
	var t: Control = _live_tray()
	# A plain `var emits := 0` closed over by the lambda is captured BY
	# VALUE in GDScript, so `emits += 1` inside the lambda would never be
	# seen from here -- a single-element Array is captured by reference.
	var emits := [0]
	t.state_changed.connect(func(_s): emits[0] += 1)
	t.set_state(t.ViewState.EXPANDED, false)
	assert_eq(emits[0], 0, "re-asserting the current state must not emit")
	var y0: float = t.position.y
	t.set_state(t.ViewState.COLLAPSED, false)
	t.set_state(t.ViewState.COLLAPSED, false)
	assert_eq(emits[0], 1, "a second identical set_state call must not emit again")
	assert_eq(t.position.y, y0 + t.tray_offset_collapsed,
		"the no-op call must not move the tray a second time")
	t.queue_free()


func test_toggle_flips_is_expanded() -> void:
	var t: Control = _live_tray()
	assert_true(t.is_expanded())
	t.toggle()
	assert_false(t.is_expanded(), "toggle() from EXPANDED should land on COLLAPSED")
	t.toggle()
	assert_true(t.is_expanded(), "toggle() from COLLAPSED should land back on EXPANDED")
	t.queue_free()


## Frames never advance inside a test (no await allowed), so an animated
## set_state() cannot be checked by reading position afterwards -- that would
## pass even if nothing were wired up. Instead this checks the tween that
## set_state() itself creates: it must exist, be running, and target the
## correct value.
func test_animated_set_state_creates_a_tween_to_the_right_target() -> void:
	var t: Control = _live_tray()
	var y0: float = t.position.y
	t.set_state(t.ViewState.COLLAPSED, true)
	assert_true(is_instance_valid(t._tray_tween), "set_state(animate=true) must create a tween")
	assert_true(t._tray_tween.is_valid() and t._tray_tween.is_running(),
		"the tween must be running immediately after set_state()")
	# Nothing has stepped yet -- the animated call must not have snapped the
	# position the way animate=false would.
	assert_eq(t.position.y, y0, "an animated set_state must not move the tray on the same frame")
	t.queue_free()


func test_state_changed_signal_declared() -> void:
	var t: Control = _live_tray()
	assert_true(t.has_signal("state_changed"), "BasketTray must declare state_changed")
	t.queue_free()


## The emblem in the tray's top-right corner -- its basket icon, its count
## badge and the HeaderButton inside it -- was removed on 2026-09-21. Three
## tests here existed only to keep that button and badge honest across a
## collapse; with the node gone they are replaced by one that pins its
## absence, so nothing quietly puts an invisible button back.
func test_the_tray_has_no_corner_emblem_or_header_button() -> void:
	var t: Control = _live_tray()
	assert_true(t.get_node_or_null("Body/Emblem") == null,
		"the corner emblem must be gone")
	assert_true(t.get_node_or_null("Body/Emblem/HeaderButton") == null,
		"and with it the toggle button it contained")
	t.queue_free()


# ── koprasi.tscn / koprasi.gd -- text scans, per project convention: the
#    Stage cannot be instantiated headlessly against live autoload state, so
#    these confirm what was authored rather than runtime behaviour. ────────

func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "%s missing" % path)
	if f == null:
		return ""
	return f.get_as_text()

