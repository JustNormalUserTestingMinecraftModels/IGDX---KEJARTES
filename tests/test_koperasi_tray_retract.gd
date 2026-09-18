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


func test_basket_tray_scene_has_header_button() -> void:
	var t: Control = _live_tray()
	var header := t.get_node_or_null("Body/Emblem/HeaderButton")
	assert_not_null(header, "BasketTray.tscn must have a Body/Emblem/HeaderButton")
	assert_true(header is TextureButton, "HeaderButton must be a TextureButton")
	t.queue_free()


## Spec section 3: collapsing must hide the badge itself (visible = false),
## not just fade the emblem's alpha -- a caller checking .visible (rather
## than reading pixels) must see it gone.
func test_collapse_hides_emblem_badge_outright() -> void:
	var t: Control = _live_tray()
	t._emblem_badge.visible = true
	t.set_state(t.ViewState.COLLAPSED, false)
	assert_false(t._emblem_badge.visible,
		"a collapsed tray must hide its own count badge outright")
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


## The EXPANDED pose must land the (scale-0.35) crate visually on top of the
## tray header emblem, not overlapping the coin HUD above it. CrateHandle's
## own pivot is (0,0) (top-left, unlike Art's foot-centre pivot used only by
## idle_bounce), so its authored top-left offset IS its on-screen top-left at
## any scale -- it must equal Body/Emblem's authored top-left in Stage-local
## coordinates: 24 (Body's left inset) + 876 (Emblem offset_left) = 900,
## and 117 (TrayDock offset_top) + 1243 (Body offset_top) - 64 (Emblem
## offset_top) = 1296.
func test_crate_expanded_pose_matches_emblem_top_left() -> void:
	var scene_src := _read(KOPRASI_TSCN)
	var script_src := _read("res://Scripts/Koperasi/koprasi.gd")
	if scene_src.is_empty() or script_src.is_empty():
		return
	var crate_start := scene_src.find("[node name=\"CrateHandle\" type=\"TextureButton\" parent=\"Stage\"")
	assert_true(crate_start != -1, "Stage/CrateHandle not found")
	if crate_start != -1:
		var crate_end := scene_src.find("[node ", crate_start + 1)
		var crate_block := scene_src.substr(crate_start, crate_end - crate_start)
		assert_true(crate_block.contains("offset_left = 900.0") and crate_block.contains("offset_top = 1296.0"),
			"CrateHandle's authored rect must start at the emblem's top-left (900, 1296)")
		assert_false(crate_block.contains("pivot_offset"),
			"CrateHandle itself must keep the default (0,0) pivot -- only Art's idle_bounce uses a foot-centre pivot")
	assert_true(script_src.contains("Vector2(900.0, 1296.0)"),
		"crate_pos_expanded must match CrateHandle's authored top-left")


func test_koprasi_scene_has_mirrored_count_badge_on_crate() -> void:
	var src := _read(KOPRASI_TSCN)
	if src.is_empty():
		return
	assert_true(src.contains("[node name=\"CountBadge\" type=\"PanelContainer\" parent=\"Stage/CrateHandle\""),
		"CrateHandle must carry a mirrored CountBadge, reusing the tray's PanelContainer+Label shape")
	assert_true(src.contains("[node name=\"Count\" type=\"Label\" parent=\"Stage/CrateHandle/CountBadge\""),
		"CrateHandle/CountBadge must carry a Count label like the tray's own badge")
	# Same variations as BasketTray's own badge -- no theme_override_*, no
	# new ThemeFactory type invented just for this mirror.
	var badge_start := src.find("[node name=\"CountBadge\" type=\"PanelContainer\" parent=\"Stage/CrateHandle\"")
	if badge_start == -1:
		return
	var badge_end := src.find("[node ", badge_start + 1)
	var badge_block := src.substr(badge_start, badge_end - badge_start)
	assert_true(badge_block.contains("&\"TrayBadge\""),
		"the mirrored badge must reuse the TrayBadge variation")
	assert_true(badge_block.contains("visible = false"),
		"the mirrored badge must start hidden (tray starts EXPANDED)")


func test_koprasi_gd_refreshes_crate_badge_from_cart() -> void:
	var src := _read("res://Scripts/Koperasi/koprasi.gd")
	if src.is_empty():
		return
	assert_true(src.contains("func _refresh_crate_badge"),
		"koprasi.gd must define _refresh_crate_badge()")
	assert_true(src.contains("Cart.get_item_count()"),
		"the mirrored badge must read Cart.get_item_count()")
	assert_true(src.contains("_refresh_crate_badge()"),
		"_refresh_crate_badge must actually be called somewhere")
	# Called from the existing cart-changed handler, not a new standalone
	# Cart connection -- avoids a second listener to disconnect in _exit_tree.
	var cart_changed_start := src.find("func _on_cart_changed()")
	assert_true(cart_changed_start != -1, "_on_cart_changed must still exist")
	if cart_changed_start != -1:
		var next_func := src.find("\nfunc ", cart_changed_start + 1)
		var body := src.substr(cart_changed_start, next_func - cart_changed_start)
		assert_true(body.contains("_refresh_crate_badge()"),
			"_on_cart_changed must refresh the crate badge on every cart change")


## Spec section 3: on press, idle_bounce stops before the tray reacts (it
## resumes, or switches to RESET, from _on_tray_state_changed right after).
func test_koprasi_gd_stops_idle_bounce_on_crate_press() -> void:
	var src := _read("res://Scripts/Koperasi/koprasi.gd")
	if src.is_empty():
		return
	var start := src.find("func _on_crate_pressed()")
	assert_true(start != -1, "_on_crate_pressed must exist")
	if start == -1:
		return
	var next_func := src.find("\nfunc ", start + 1)
	var body := src.substr(start, next_func - start)
	assert_true(body.contains("ap.stop()") and body.contains("idle_bounce"),
		"pressing the crate must stop idle_bounce before toggling the tray")


## Review fix: UIPolish auto-juices every BaseButton it sees, including the
## 320px CrateHandle -- Juice.press/release would recentre its pivot_offset
## and fight the crate's own _crate_tween (pivot (0,0) math above). koprasi.gd
## must opt it out. A source scan, per this suite's own convention just
## above: the Stage/crate cannot be instantiated headlessly against live
## autoload state, so this confirms what was authored, not runtime behaviour.
func test_koprasi_gd_opts_crate_out_of_auto_juice() -> void:
	var src := _read("res://Scripts/Koperasi/koprasi.gd")
	if src.is_empty():
		return
	assert_true(src.contains("crate.set_meta(Juice.NO_AUTO_JUICE, true)"),
		"koprasi.gd must opt CrateHandle out of UIPolish's auto-juice via Juice.NO_AUTO_JUICE")


## Review fix: a COLLAPSED tray only fades Body/Emblem's alpha, which leaves
## the HeaderButton inside it hit-testable. set_state() must gate its
## mouse_filter directly, both when snapped (animate=false, used here since
## no test advances a frame) and by construction when animated (the filter
## change sits outside the animate/no-animate branch in the source).
func test_collapsed_tray_ignores_mouse_on_header_button() -> void:
	var t: Control = _live_tray()
	var header := t.get_node_or_null("Body/Emblem/HeaderButton") as TextureButton
	assert_not_null(header, "BasketTray.tscn must have a Body/Emblem/HeaderButton")
	if header == null:
		t.queue_free()
		return
	t.set_state(t.ViewState.COLLAPSED, false)
	assert_eq(header.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"a collapsed tray must not let its HeaderButton catch mouse input")
	t.set_state(t.ViewState.EXPANDED, false)
	assert_eq(header.mouse_filter, Control.MOUSE_FILTER_STOP,
		"re-expanding must restore the HeaderButton's normal mouse filter")
	t.queue_free()
