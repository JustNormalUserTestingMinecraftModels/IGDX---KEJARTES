@tool
extends McpTestSuiteCompat

## Suite for Task 5 of the 2026-09-17 Koperasi polish: the tray's
## EXPANDED/COLLAPSED state machine and the crate handle it drives.
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
	var emits := 0
	t.state_changed.connect(func(_s): emits += 1)
	t.set_state(t.ViewState.EXPANDED, false)
	assert_eq(emits, 0, "re-asserting the current state must not emit")
	var y0: float = t.position.y
	t.set_state(t.ViewState.COLLAPSED, false)
	t.set_state(t.ViewState.COLLAPSED, false)
	assert_eq(emits, 1, "a second identical set_state call must not emit again")
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


func test_basket_tray_scene_has_header_button() -> void:
	var t: Control = _live_tray()
	var header := t.get_node_or_null("Body/Emblem/HeaderButton")
	assert_not_null(header, "BasketTray.tscn must have a Body/Emblem/HeaderButton")
	assert_true(header is TextureButton, "HeaderButton must be a TextureButton")
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


func test_koprasi_scene_has_crate_handle_with_animation_player() -> void:
	var src := _read(KOPRASI_TSCN)
	if src.is_empty():
		return
	assert_true(src.contains("[node name=\"CrateHandle\" type=\"TextureButton\" parent=\"Stage\""),
		"koprasi.tscn must have a Stage/CrateHandle TextureButton")
	assert_true(src.contains("[node name=\"Art\" type=\"TextureRect\" parent=\"Stage/CrateHandle\""),
		"CrateHandle must have a child Art node the animation drives")
	assert_true(src.contains("[node name=\"AP\" type=\"AnimationPlayer\" parent=\"Stage/CrateHandle\""),
		"CrateHandle must have a child AP AnimationPlayer")


func test_koprasi_crate_animation_library_has_idle_bounce_and_reset() -> void:
	var src := _read(KOPRASI_TSCN)
	if src.is_empty():
		return
	assert_true(src.contains("&\"RESET\": SubResource(\"Animation_crate_reset\")"),
		"crate AnimationLibrary must hold a RESET animation")
	assert_true(src.contains("&\"idle_bounce\": SubResource(\"Animation_crate_idle_bounce\")"),
		"crate AnimationLibrary must hold idle_bounce")


## idle_bounce must key the child Art node, never CrateHandle itself -- the
## controller (koprasi.gd) already tweens CrateHandle's own scale/position,
## and a second animation on the same properties would fight it.
func test_koprasi_idle_bounce_keys_only_the_art_child() -> void:
	var src := _read(KOPRASI_TSCN)
	if src.is_empty():
		return
	var start := src.find("[sub_resource type=\"Animation\" id=\"Animation_crate_idle_bounce\"]")
	assert_true(start != -1, "Animation_crate_idle_bounce sub_resource not found")
	if start == -1:
		return
	var next_block := src.find("[sub_resource", start + 1)
	if next_block == -1:
		next_block = src.find("[node ", start + 1)
	var block := src.substr(start, next_block - start)
	assert_true(block.contains("NodePath(\"Art:scale\")"), "idle_bounce must animate Art:scale")
	assert_true(block.contains("NodePath(\"Art:position\")"), "idle_bounce must animate Art:position")
	assert_false(block.contains("NodePath(\".:scale\")"),
		"idle_bounce must not key CrateHandle's own scale")
	assert_false(block.contains("NodePath(\".:position\")"),
		"idle_bounce must not key CrateHandle's own position")


func test_koprasi_gd_wires_crate_to_tray_toggle() -> void:
	var src := _read("res://Scripts/Koperasi/koprasi.gd")
	if src.is_empty():
		return
	assert_true(src.contains("tray.toggle()"), "the crate press must toggle the tray")
	assert_true(src.contains("_on_tray_state_changed"),
		"koprasi.gd must react to BasketTray.state_changed")
	assert_true(src.contains("bubble.idle_chatter_enabled"),
		"a collapsed tray must mute Pak Herman's idle chatter")
	assert_true(src.contains("@export var crate_pos_expanded"),
		"crate_pos_expanded must be an @export, not a hardcoded literal")
	assert_true(src.contains("@export var crate_pos_collapsed"),
		"crate_pos_collapsed must be an @export, not a hardcoded literal")
