@tool
extends McpTestSuite

## StudentList (Task 13). Migrates the 4 hardcoded Murid cards' theme
## overrides to variations, and extracts the 20 near-identical inline
## sticky-note subtrees (4 students x 5 days) into one StickyNote.tscn
## component, instanced per day.
##
## Technique notes carried over from Tasks 9-12:
##  * This suite must itself be @tool or the runner reports the class as
##    abstract/broken.
##  * The runner calls `suite.call(name)` WITHOUT awaiting, so no test
##    here may be a coroutine.
##  * Control has no get_theme_*_override_list() in Godot 4.6; the
##    _collect_overrides helper below is copied verbatim from
##    tests/test_main_menu.gd, which walks get_property_list() and
##    cross-checks the per-name has_theme_*_override() APIs.
##  * ThemeDB's project-theme fallback does not populate for a scene
##    instantiated under the editor's own root, so the baked theme is
##    assigned explicitly before the scene enters the tree.
##  * Touch-target checks read get_combined_minimum_size() synchronously
##    (Task 9/10's established fix) rather than `.size` after an
##    `await process_frame`, which the runner's non-awaited test call
##    convention cannot support.
##  * StudentList.gd is NOT @tool. Empirically verified here: this
##    scene's runtime setup (_setup_students/_setup_tutorial, both
##    called from _ready()) reads the GameState autoload and builds the
##    tutorial panel dynamically. Godot only runs a plain (non-@tool)
##    script's lifecycle callbacks (_ready, _process, ...) inside an
##    actually-running game tree; while the editor is merely open
##    (which is the MCP test runner's context), _ready() never fires
##    for a non-@tool script no matter who calls add_child() on it —
##    this matches Task 12's identical finding for StudentCard, whose
##    tutorial-panel code this scene's tutorial system is copied from.
##    Confirmed by test_scene_instantiates below: card_nodes-dependent
##    structure (StickyNotesContainer instances, Belum/Sudah visibility)
##    comes straight from the .tscn's authored defaults, not from
##    anything _setup_students() would have written, and no GameState
##    autoload error is thrown despite _setup_students() referencing it.
##    Since every assertion this suite needs (overrides, variations,
##    StickyNote wiring, routing, no-Color()-literals) is either
##    .tscn-authored structure or a source-text scan, @tool gating
##    would add gating overhead for zero additional test coverage, so
##    it is deliberately omitted — matching StudentCard's precedent.

const _SCENE_PATH := "res://Scenes/StudentList/StudentList.tscn"
const _SCRIPT_PATH := "res://Scripts/StudentList/StudentList.gd"
const _STICKYNOTE_SCRIPT_PATH := "res://Scripts/StudentList/StickyNote.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
## Stands the list up and settles its Containers in the same frame.
const LayoutFrame := preload("res://tests/layout_frame.gd")


func suite_name() -> String:
	return "student_list"


var _list: Control


## One StudentList for the whole suite, built in suite_setup() and freed in
## suite_teardown(): every test only reads it, and building it 61 times with
## no frame between floods the editor's MessageQueue on a full run
## (CLAUDE.md, "A full test_run drops the bridge"; 2026-09-30).
func suite_setup(_ctx: Dictionary) -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	_list = scene.instantiate()
	_list.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_list)


func suite_teardown() -> void:
	if is_instance_valid(_list):
		_list.free()
	_list = null


# ------------------------------------------------ behavioral contract net

func test_still_routes_to_atur_jadwal() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/AturJadwal/AturJadwal.tscn"),
		"student_list must still route to AturJadwal")


func test_debug_tutorial_bypass_skips_the_student_list_tutorial() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("if GameState.tutorials_bypassed or tutorial_shown:"),
		"the debug menu's master tutorial-bypass flag must skip this screen's tutorial too")


# ------------------------------------------------------- standard four

func test_scene_instantiates() -> void:
	assert_true(_list != null, "scene must instantiate")
	assert_true(_list.is_inside_tree(), "scene must enter the tree cleanly")
	for i in range(1, 5):
		assert_true(_list.get_node_or_null("CardContainer/Murid%d" % i) != null,
			"missing student card Murid%d" % i)


func test_scene_has_no_theme_overrides() -> void:
	# The whole point of centralization: this scene must be styled
	# entirely by the project theme. Dynamically-built tutorial/page-dot
	# nodes never exist in this suite's context (see header note on
	# _ready() not firing for a non-@tool script here), so this walk
	# only covers the .tscn-authored tree — which is exactly what must
	# be override-free for this task.
	var offenders: Array[String] = []
	_collect_overrides(_list, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on: " + ", ".join(offenders))


## Copied verbatim from tests/test_main_menu.gd / test_student_card.gd.
func _collect_overrides(node: Node, out: Array[String]) -> void:
	if node is Control:
		var c := node as Control
		var flagged := false
		for prop in c.get_property_list():
			var pname: String = prop.name
			if pname.begins_with("theme_override_colors/"):
				if c.has_theme_color_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_font_sizes/"):
				if c.has_theme_font_size_override(pname.get_slice("/", 1)):
					flagged = true
					break
			elif pname.begins_with("theme_override_styles/"):
				if c.has_theme_stylebox_override(pname.get_slice("/", 1)):
					flagged = true
					break
		if flagged:
			out.append(node.name)
	for child in node.get_children():
		_collect_overrides(child, out)


func test_no_hardcoded_colors_remain_in_the_scripts() -> void:
	var re := RegEx.create_from_string("Color\\s*\\(")
	for path in [_SCRIPT_PATH, _STICKYNOTE_SCRIPT_PATH]:
		var src := FileAccess.get_file_as_string(path)
		assert_eq(re.search_all(src).size(), 0,
			path + " must read colors from DesignTokens, not Color() literals")


func test_interactive_controls_meet_the_minimum_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	var paths := [
		"CardContainer/Murid1/CardButton", "%LeftArrow", "%RightArrow",
	]
	for p in paths:
		var b := _list.get_node_or_null(p) as Control
		assert_true(b != null, "missing control: " + p)
		var h := b.get_combined_minimum_size().y
		var w := b.get_combined_minimum_size().x
		# CardButton fills the whole card (anchors_preset 15, no intrinsic
		# minimum size of its own) -- its actual tap area is the card's
		# full rect, so only measure the nav arrows here for real intent.
		if p == "CardContainer/Murid1/CardButton":
			continue
		assert_true(minf(h, w) >= float(tokens.touch_target_min),
			"%s is %dx%d px, below the %d px minimum touch target"
				% [p, int(w), int(h), tokens.touch_target_min])


# ------------------------------------------------------ migration checks

func test_header_and_status_badges_use_theme_variations() -> void:
	var header := _list.get_node_or_null("%HeaderLabel") as Label
	assert_true(header != null, "missing HeaderLabel")
	assert_eq(header.theme_type_variation, &"H1Label", "HeaderLabel variation")

	for i in range(1, 5):
		var belum := _list.get_node_or_null("CardContainer/Murid%d/Paper/Belum" % i) as Button
		assert_true(belum != null, "missing Murid%d/Belum" % i)
		# Their own styles since the 2026-09-14 lobby-style-buttons pass, which
		# turned DangerButton/SuccessButton Lobby brown: the red and green are
		# the information these badges carry.
		assert_eq(belum.theme_type_variation, &"RosterStatusBelum", "Murid%d/Belum variation" % i)

		var sudah := _list.get_node_or_null("CardContainer/Murid%d/Paper/Sudah" % i) as Button
		assert_true(sudah != null, "missing Murid%d/Sudah" % i)
		assert_eq(sudah.theme_type_variation, &"RosterStatusSudah", "Murid%d/Sudah variation" % i)

		var nama := _list.get_node_or_null("CardContainer/Murid%d/Paper/Nama" % i) as Label
		assert_true(nama != null, "missing Murid%d/Nama" % i)
		assert_eq(nama.theme_type_variation, &"H2Label", "Murid%d/Nama variation" % i)


## These nav arrows are on the L size step (160px tall), whose variation uses
## font_h1 (64) rather than font_title (36) -- hence the L suffix on the name.
func test_nav_arrows_use_theme_variation() -> void:
	for name in ["LeftArrow", "RightArrow"]:
		var b := _list.get_node_or_null("%" + name) as Button
		assert_true(b != null, "missing " + name)
		assert_eq(b.theme_type_variation, &"SecondaryButtonL", name + " variation")


func test_sticky_notes_are_stickynote_instances_wired_per_day() -> void:
	var required_days = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]
	for i in range(1, 5):
		var container := _list.get_node_or_null(
			"CardContainer/Murid%d/Paper/StickyNotesContainer" % i)
		assert_true(container != null, "missing StickyNotesContainer on Murid%d" % i)
		for day in required_days:
			var note := container.get_node_or_null(day)
			assert_true(note is StickyNote,
				"Murid%d/StickyNotesContainer/%s must be a StickyNote instance" % [i, day])
			if note is StickyNote:
				assert_eq(note.name, day,
					"Murid%d/%s node name" % [i, day])


func test_stickynote_scene_has_no_theme_overrides() -> void:
	var scene: PackedScene = load("res://Scenes/StudentList/StickyNote.tscn")
	var note := scene.instantiate()
	note.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(note)
	var offenders: Array[String] = []
	_collect_overrides(note, offenders)
	assert_eq(offenders.size(), 0,
		"found theme_override_* on StickyNote: " + ", ".join(offenders))
	note.queue_free()


func test_motion_is_wired() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Juice.stagger_in(card_nodes)"),
		"the visible cards must stagger in")
	assert_true(src.contains("Juice.stagger_in(sticky_container.get_children()"),
		"each card's five notes must stagger in when the card opens")


## Part 3's generated art. These are System.Drawing / hand-written SVG
## placeholders, drop-replaceable at the same path with no code change.
##
## The category and specialty glyphs are deliberately NOT in this list
## any more: they were swapped to the team's authored StudentCard stat_*
## art, pinned by test_the_small_icons_are_the_teams_authored_art.
func test_part_three_art_exists_and_loads() -> void:
	var paths := [
		"res://Assets/Images/UI/Placeholders/stamp_sudah.svg",
		"res://Assets/Images/UI/Placeholders/stamp_belum.svg",
		"res://Assets/Images/UI/StudentList/photo_corner.png",
		"res://Assets/Images/UI/StudentList/roster_avatar_frame.png",
		"res://Assets/Images/UI/StudentList/catatan_rule.png",
		# 2026-09-29 MURIDMU RosterCard Task 1 groundwork: six hand-written
		# placeholders for the week header band, the photo paperclip, the
		# catatan pencil, the empty-note "+" and calendar glyphs, and the
		# empty note's dashed frame. Nothing wires to them yet.
		"res://Assets/Images/UI/StudentList/torn_band.svg",
		"res://Assets/Images/UI/StudentList/paperclip.svg",
		"res://Assets/Images/UI/StudentList/pencil.svg",
		"res://Assets/Images/UI/StudentList/icon_add.svg",
		"res://Assets/Images/UI/StudentList/icon_calendar.svg",
		"res://Assets/Images/UI/StudentList/sticky_empty_frame.svg",
	]
	for p in paths:
		assert_true(ResourceLoader.exists(p), "missing asset: " + p)
		assert_true(load(p) is Texture2D, "not a Texture2D: " + p)


## RosterAvatar is @tool, so unlike StudentList.gd its _ready DOES fire
## when the suite adds it to the editor root -- the ring tint below is
## applied state, not an authored default.
func test_roster_avatar_tints_its_ring_from_state_tokens() -> void:
	var packed: PackedScene = load("res://Scenes/StudentList/RosterAvatar.tscn")
	assert_true(packed != null, "RosterAvatar.tscn must exist")
	var tokens := DesignTokens.load_default()

	var done: RosterAvatar = packed.instantiate()
	done.is_scheduled = true
	Engine.get_main_loop().root.add_child(done)
	track(done)
	assert_eq(done.get_node("Ring").self_modulate, tokens.state_success,
		"a scheduled student's ring must read state_success")

	var todo: RosterAvatar = packed.instantiate()
	todo.is_scheduled = false
	Engine.get_main_loop().root.add_child(todo)
	track(todo)
	assert_eq(todo.get_node("Ring").self_modulate, tokens.state_danger,
		"an unscheduled student's ring must read state_danger")


func test_roster_avatar_uses_ghost_button_and_clears_touch_minimum() -> void:
	var packed: PackedScene = load("res://Scenes/StudentList/RosterAvatar.tscn")
	var a: RosterAvatar = packed.instantiate()
	Engine.get_main_loop().root.add_child(a)
	track(a)
	assert_eq(a.theme_type_variation, &"GhostButton",
		"the avatar is baked art behind a transparent button")
	var tokens := DesignTokens.load_default()
	var m := a.get_combined_minimum_size()
	assert_true(minf(m.x, m.y) >= float(tokens.touch_target_min),
		"avatar must clear the touch minimum, got %s" % m)


## Grow/lift/ring read for the current avatar (2026-09-29 avatar bounce
## pass). Both this and the inactive test below run entirely in the
## editor, where RosterAvatar's own is_editor_hint() guard makes every
## is_current change land instantly on its target values -- exactly what
## a real bounce settles on, just without waiting out the Tween.
func test_roster_avatar_current_state_grows_lifts_and_rings() -> void:
	var packed: PackedScene = load("res://Scenes/StudentList/RosterAvatar.tscn")
	var a: RosterAvatar = packed.instantiate()
	Engine.get_main_loop().root.add_child(a)
	track(a)
	a.is_current = true
	var tokens := DesignTokens.load_default()
	assert_eq(a.scale, Vector2(RosterAvatar.ACTIVE_SCALE, RosterAvatar.ACTIVE_SCALE),
		"the current avatar grows to ACTIVE_SCALE")
	assert_eq(a.position.y, -RosterAvatar.ACTIVE_LIFT_PX, "and lifts ACTIVE_LIFT_PX up")
	assert_eq(a.modulate.a, 1.0, "and reads at full opacity")
	assert_eq(a.get_node("Highlight").modulate.a, 1.0, "the sunflower glow ring shows")
	assert_eq(a.get_node("Highlight").self_modulate, tokens.accent_sunflower, "tinted accent_sunflower")
	assert_eq(a.get_node("Border").modulate.a, 1.0, "the brand border shows")
	assert_eq(a.get_node("Border").self_modulate, tokens.brand_primary, "tinted brand_primary")


func test_roster_avatar_inactive_state_shrinks_and_dims() -> void:
	var packed: PackedScene = load("res://Scenes/StudentList/RosterAvatar.tscn")
	var a: RosterAvatar = packed.instantiate()
	Engine.get_main_loop().root.add_child(a)
	track(a)
	a.is_current = true
	a.is_current = false
	assert_eq(a.scale, Vector2(RosterAvatar.INACTIVE_SCALE, RosterAvatar.INACTIVE_SCALE),
		"an inactive avatar shrinks to INACTIVE_SCALE")
	assert_eq(a.position.y, 0.0, "and drops back to rest")
	# modulate.a lives in a 32-bit Color; inactive_alpha is a plain (64-bit)
	# exported float that never round-trips through one, so 0.55 reads
	# back as 0.5500000119 -- same gotcha IdleFade's own suite documents.
	assert_true(is_equal_approx(a.modulate.a, a.inactive_alpha), "and dims to inactive_alpha")
	assert_eq(a.get_node("Highlight").modulate.a, 0.0, "the glow ring hides")
	assert_eq(a.get_node("Border").modulate.a, 0.0, "the brand border hides")


## The small state is still a legal tap target. Control.scale is part of
## the transform Godot hit-tests against, so it DOES shrink the real tap
## region along with the visual -- get_combined_minimum_size() alone (the
## sibling test above) proves nothing about that, since it never reads
## `scale`. So this multiplies the two together: get_combined_minimum_size()
## is timing-safe here (this suite's header note on why raw `.size` is
## not, without an awaited frame), and `scale` is exactly what
## _apply_current_state() just set. 150px * INACTIVE_SCALE (0.82) = 123px,
## still above touch_target_min (96px).
func test_roster_avatar_clears_touch_minimum_at_the_small_scale() -> void:
	var packed: PackedScene = load("res://Scenes/StudentList/RosterAvatar.tscn")
	var a: RosterAvatar = packed.instantiate()
	Engine.get_main_loop().root.add_child(a)
	track(a)
	a.is_current = false
	var tokens := DesignTokens.load_default()
	var effective := a.get_combined_minimum_size() * a.scale
	assert_true(minf(effective.x, effective.y) >= float(tokens.touch_target_min),
		"INACTIVE_SCALE=%s must still clear the effective touch target, got %s"
			% [RosterAvatar.INACTIVE_SCALE, effective])


## Source scan: the bounce cannot be watched running live in the editor
## (RosterCard's established finding for its own overshoots), so this
## pins the two guards and the cleanup by name instead.
func test_roster_avatar_bounce_is_guarded_and_cleaned_up() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/StudentList/RosterAvatar.gd")
	var applying := src.get_slice("func _apply_current_state(animate: bool) -> void:", 1)
	assert_true(applying.contains("Engine.is_editor_hint()") and applying.contains("GameSettings.reduce_motion"),
		"the bounce must skip both the editor and reduce_motion")
	var exiting := src.get_slice("func _exit_tree() -> void:", 1).get_slice("func _apply_schedule_tint() -> void:", 0)
	assert_true(exiting.contains("_bounce_tween.kill()"), "_exit_tree must kill the bounce tween")


## Review 2026-09-29 (round 2 -- "solve the whole vertical stack"): at the
## original ACTIVE_SCALE/padding, the active avatar's Highlight ring
## scaled past HeaderLabel's bottom and past CardContainer's top (a live
## capture caught the gold ring drawn over "MURIDMU" and clipped by the
## card's edge); moving CardContainer down to fix that then pushed the
## card's bottom past the nav arrows on a 1080x1920 phone. Pins all three
## boundaries at once, at both screen sizes tests/test_tall_screen_-
## layout.gd covers.
##
## Round 3 review: this test used to re-derive the ring's centre from the
## RESTING avatar's get_global_rect() -- wrong, because that Control sits
## at INACTIVE_SCALE with pivot_offset (75,75), and get_global_rect()'s
## `.position` is the pivot-scaled transform origin (shifted by
## pivot*(1-scale) = 13.5px at rest) while its `.size` ignores scale
## entirely, a mismatched pair that biased the derived centre. Ground
## truth instead: snap the avatar to is_current = true (the instant path
## fires here since Engine.is_editor_hint() is true in this suite) and
## read Highlight's REAL transformed rect via the avatar's own
## get_global_transform() -- Godot's own math, not a hand re-derivation.
const _MIN_CLEARANCE_PX := 8.0


func _assert_stack_clears(screen: Vector2) -> void:
	var frame := track(LayoutFrame.stand_up(_SCENE_PATH, screen)) as Control
	var list := frame.get_child(0) as Control
	var title_bottom: float = (list.get_node("%HeaderLabel") as Control).get_global_rect().end.y
	var card_rect := (list.get_node("CardContainer") as Control).get_global_rect()
	var arrow_top: float = (list.get_node("%LeftArrow") as Control).get_global_rect().position.y

	var avatar := list.get_node("%RosterStrip/Avatar1") as RosterAvatar
	avatar.is_current = true
	var highlight := avatar.get_node("Highlight") as Control
	var highlight_local := Rect2(highlight.offset_left, highlight.offset_top,
		highlight.offset_right - highlight.offset_left, highlight.offset_bottom - highlight.offset_top)
	var ring_rect: Rect2 = avatar.get_global_transform() * highlight_local

	assert_true(ring_rect.position.y - title_bottom >= _MIN_CLEARANCE_PX,
		"%s: active ring top %.1f must clear the title's bottom %.1f by %.0fpx"
			% [screen, ring_rect.position.y, title_bottom, _MIN_CLEARANCE_PX])
	assert_true(card_rect.position.y - ring_rect.end.y >= _MIN_CLEARANCE_PX,
		"%s: active ring bottom %.1f must clear the card's top %.1f by %.0fpx"
			% [screen, ring_rect.end.y, card_rect.position.y, _MIN_CLEARANCE_PX])
	assert_true(arrow_top - card_rect.end.y >= _MIN_CLEARANCE_PX,
		"%s: the card's bottom %.1f must clear the nav arrows' top %.1f by %.0fpx"
			% [screen, card_rect.end.y, arrow_top, _MIN_CLEARANCE_PX])


func test_active_avatar_ring_clears_the_title_and_the_card() -> void:
	_assert_stack_clears(Vector2(1080, 1920))


func test_active_avatar_ring_clears_the_title_and_the_card_on_a_tall_phone() -> void:
	_assert_stack_clears(Vector2(1080, 2400))


## Nav arrow idle hint (2026-09-29 avatar bounce pass): a ±4px nudge while
## there is more than one card to swipe between. StudentList sets
## `enabled` once at setup; the per-card-count gate instead rides on the
## arrow's own `visible`, which StudentList was already toggling from
## card count -- NudgeLoop only runs while enabled AND
## parent.is_visible_in_tree(), so the dynamic per-page toggling needs no
## StudentList line of its own.
func _nudge_loop(path: String) -> NudgeLoop:
	var nudge := _list.get_node_or_null(path) as NudgeLoop
	assert_true(nudge != null, "missing NudgeLoop at %s" % path)
	return nudge


func test_both_nav_arrows_carry_a_nudge_loop() -> void:
	var left := _nudge_loop("%LeftArrow/NudgeLoop")
	var right := _nudge_loop("%RightArrow/NudgeLoop")
	if left == null or right == null:
		return
	assert_false(left.enabled, "authored default is off; StudentList turns it on once at setup")
	assert_false(right.enabled, "authored default is off; StudentList turns it on once at setup")


func test_nudge_loop_never_runs_in_the_editor_even_when_enabled() -> void:
	var parent := Control.new()
	Engine.get_main_loop().root.add_child(parent)
	track(parent)
	var nudge := NudgeLoop.new()
	parent.add_child(nudge)
	track(nudge)
	nudge.enabled = true
	assert_false(nudge.is_running(), "the editor must never see a spinning nudge Tween")
	assert_eq(parent.position.x, 0.0, "and the arrow must not have moved")


## Source scan mirrors the RosterAvatar bounce test above: the loop
## cannot be watched running live in the editor either.
func test_nudge_loop_is_guarded_and_cleaned_up() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/UI/NudgeLoop.gd")
	var applying := src.get_slice("func _apply_enabled() -> void:", 1).get_slice("func _start() -> void:", 0)
	assert_true(applying.contains("Engine.is_editor_hint()") and applying.contains("GameSettings.reduce_motion"),
		"starting the loop must skip both the editor and reduce_motion")
	assert_true(applying.contains("is_visible_in_tree()"),
		"the loop must gate on the parent's own visibility, not just `enabled`")
	assert_true(src.contains("visibility_changed.connect(_apply_enabled)"),
		"a visibility flip must re-evaluate the loop without StudentList touching `enabled` again")
	var exiting := src.get_slice("func _exit_tree() -> void:", 1).get_slice("func is_running() -> bool:", 0)
	assert_true(exiting.contains("_stop()"), "_exit_tree must stop the loop")


## The four cards are one template instanced four times now. The instance
## NAMES stay Murid1..4 because test_scene_instantiates resolves
## CardContainer/Murid%d and the tutorial's first step targets
## CardContainer -- keeping the names keeps both contracts.
func test_the_four_cards_are_rostercard_instances_under_their_old_names() -> void:
	for i in range(1, 5):
		var card := _list.get_node_or_null("CardContainer/Murid%d" % i)
		assert_true(card != null, "missing CardContainer/Murid%d" % i)
		assert_true(card is RosterCard,
			"CardContainer/Murid%d must be a RosterCard instance" % i)


## Composed from two small tables rather than a 30-entry lookup: five
## persona openers x six quirk observations.
func test_catatan_composes_persona_then_quirk() -> void:
	assert_eq(RosterCard.compose_catatan("Tekun", "Kutu Buku"),
		"Duduk paling depan, catatannya rapi. Perpustakaan sudah seperti rumah kedua.",
		"catatan must read persona opener then quirk observation")
	assert_eq(RosterCard.compose_catatan("", ""),
		"Belum ada catatan untuk murid ini.",
		"an unknown pairing must still produce a sentence")


## Five notes in one row replaces the 3+2 grid, which left a lopsided
## hole in the second row and ~330px of dead paper below it.
func test_the_week_strip_is_one_row_of_five() -> void:
	var days := ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]
	for i in range(1, 5):
		var container := _list.get_node_or_null(
			"CardContainer/Murid%d/Paper/StickyNotesContainer" % i)
		assert_true(container != null, "missing StickyNotesContainer on Murid%d" % i)
		var last_x := -1.0
		var first_y := -1.0
		for d in days:
			var note := container.get_node_or_null(d) as StickyNote
			assert_true(note != null, "missing note %s on Murid%d" % [d, i])
			if first_y < 0.0:
				first_y = note.offset_top
			assert_eq(note.offset_top, first_y,
				"%s must share the row's y on Murid%d" % [d, i])
			assert_true(note.offset_left > last_x,
				"%s must sit right of the previous note on Murid%d" % [d, i])
			last_x = note.offset_left


## The chips are display, not controls -- mouse_filter IGNORE so a tap in
## that band reaches CardButton instead of press-animating a chip that
## does nothing. So this pins the thing that actually matters: they carry
## a SIZE-STEPPED variation rather than the full-size badge. At the
## full-size badge they measured 160x290 each and three of them
## overflowed the 880px row, clipping every label.
##
## The step is M, not S: S was reported unreadable on a real handset
## (22px in a 1080-wide design space is under Material's 12sp caption
## floor once scaled down), so it was lifted to body size.
func test_trait_row_holds_three_compact_chips_that_do_not_eat_taps() -> void:
	var expected := {
		"SpecialtyChip": &"SpecialtyBadgeM",
		"PersonaChip": &"PersonaBadgeM",
		"QuirkChip": &"QuirkBadgeM",
	}
	for i in range(1, 5):
		var row := _list.get_node_or_null(
			"CardContainer/Murid%d/Paper/TraitRow" % i) as Control
		assert_true(row != null, "missing TraitRow on Murid%d" % i)
		assert_eq(row.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"TraitRow on Murid%d must not swallow card taps" % i)
		for chip_name in expected:
			var chip := _list.get_node_or_null(
				"CardContainer/Murid%d/Paper/TraitRow/%s" % [i, chip_name]) as Button
			assert_true(chip != null, "missing %s on Murid%d" % [chip_name, i])
			assert_eq(chip.theme_type_variation, expected[chip_name],
				"%s must use the M size step on Murid%d" % [chip_name, i])
			assert_eq(chip.mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s on Murid%d must not swallow card taps" % [chip_name, i])


## The card's dead band becomes the teacher's note.
func test_catatan_strip_is_populated_per_student() -> void:
	for i in range(1, 5):
		var label := _list.get_node_or_null(
			"CardContainer/Murid%d/Paper/CatatanGuru/CatatanLabel" % i) as Label
		assert_true(label != null, "missing CatatanLabel on Murid%d" % i)
		assert_true(label.text.length() > 0,
			"catatan must never be blank on Murid%d" % i)


func test_sticky_notes_carry_a_category_icon() -> void:
	var note := _list.get_node_or_null(
		"CardContainer/Murid1/Paper/StickyNotesContainer/Senin") as StickyNote
	assert_true(note != null, "missing Senin note")
	assert_true("icon_texture" in note,
		"StickyNote must expose an icon_texture export")


## The roster strip above the carousel: one RosterAvatar per student, so
## roster progress reads without paging through every card.
func test_roster_strip_holds_four_avatars() -> void:
	var strip := _list.get_node_or_null("%RosterStrip")
	assert_true(strip != null, "missing RosterStrip")
	for i in range(1, 5):
		var a := strip.get_node_or_null("Avatar%d" % i)
		assert_true(a != null, "missing RosterStrip/Avatar%d" % i)
		assert_true(a is RosterAvatar, "Avatar%d must be a RosterAvatar" % i)


## The arrows used to sit pinned to the vertical centre of a 1920-tall
## screen, which is nowhere near a thumb. They sit in a nav row with the
## page dots -- since the 2026-09-15 tall-phone pass a Bottom Wide bar in
## Safe/UI, so their offsets are bar-local and the check reads global rects.
func test_navigation_sits_in_thumb_reach() -> void:
	var frame := track(LayoutFrame.stand_up(_SCENE_PATH, Vector2(1080, 1920))) as Control
	var list := frame.get_child(0) as Control
	var cards_bottom := (list.get_node("CardContainer") as Control).get_global_rect().end.y
	for n in ["LeftArrow", "RightArrow", "PageIndicator"]:
		var c := list.get_node_or_null("%" + n) as Control
		assert_true(c != null, "missing " + n)
		if c == null:
			continue
		var top := c.get_global_rect().position.y
		assert_true(top >= 1600.0, "%s must sit in the lower third, got y %f" % [n, top])
		assert_true(top >= cards_bottom,
			"%s must sit below the cards (their bottom is %f), got y %f" % [n, cards_bottom, top])


## The header is an outlined H1Label straight on the desk, with no
## plaque behind it.
##
## There WAS a "Papan" TextureRect there, and it never once rendered as
## a plaque: whiteboard.png is a portrait 1080x1920 image and the node
## was a 700x116 strip on STRETCH_KEEP_ASPECT_CENTERED, so it fitted to
## a 65x116 sliver dead centre -- read on review as a stray icon
## clipping the title. Removed rather than restretched; H1Label is
## outlined and carries itself on the wood.
func test_the_header_has_no_plaque_behind_it() -> void:
	assert_true(_list.get_node_or_null("Papan") == null,
		"the Papan sliver must stay removed, not be restretched back in")
	var header := _list.get_node_or_null("%HeaderLabel") as Label
	assert_true(header != null, "missing HeaderLabel")
	assert_eq(header.theme_type_variation, &"H1Label", "HeaderLabel variation")
	assert_eq(header.text, "MURIDMU", "the screen is titled MURIDMU")


## Source scans, not behaviour: StudentList.gd is deliberately NOT
## @tool, so its _ready never fires in the editor and nothing it would
## populate can be asserted live. See this suite's header note.
func test_roster_strip_is_wired_to_the_carousel() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("func _sync_roster_strip"),
		"the strip must resync when the card changes")
	assert_true(src.contains("func _on_avatar_pressed"),
		"tapping an avatar must jump the carousel")
	assert_true(src.contains("_switch_card("),
		"the jump must reuse the existing carousel switch")


func test_page_dots_come_from_a_template_not_from_code() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/StudentList/PageDot.tscn"),
		"page dots must instance the PageDot template")
	assert_false(src.contains("var dot = Label.new()"),
		"the page-dot loop must not construct Labels at runtime")


func test_the_script_carries_a_file_header() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.begins_with("##"),
		"StudentList.gd must open with a ## file header")

## Three steps become four. The new one teaches the only genuinely new
## mechanic; the other three keep their targets, which still resolve
## after the relayout.
func test_tutorial_teaches_the_roster_strip() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("\"Status Jadwal\""),
		"a tutorial step must introduce the roster strip")
	assert_true(src.contains("\"RosterStrip\""),
		"that step must spotlight RosterStrip")
	assert_true(src.contains("\"CardContainer\""),
		"step 1 must still target CardContainer")
	assert_true(src.contains("\"RightArrow\""),
		"the navigation step must still target RightArrow")


## The Critical bug the final review caught: _setup_students displayed the
## name and portrait from GameState.approved_students but left the trait
## chips and catatan guru on the .tscn's authored defaults. These four
## writes are what connect the rest of the card to the real roster.
func test_setup_students_drives_every_rostercard_band() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for prop in ["specialty", "persona", "quirk", "is_scheduled"]:
		assert_true(src.contains("murid_node.%s = " % prop),
			"_setup_students must push %s onto the RosterCard instance" % prop)
	assert_true(src.contains("student_data.get(\"personality\"")
			and not src.contains("murid_node.persona = student_data.get(\"persona\""),
		"persona must come from the clean `personality` key, not the prefixed `persona`")


## The regression that killed swipe and tap-to-schedule: instancing a
## Control writes `layout_mode = 0` (Position mode), which ZEROES the
## anchors it would otherwise inherit from the sub-scene root. The four
## RosterCard instances collapsed to 0x0, so CardButton -- anchored to
## fill its parent -- fell back to its 88x60 stylebox minimum in the
## card's top-left corner and every tap outside that patch hit nothing.
## The card must fill CardContainer, or the whole screen is inert.
func test_each_card_fills_its_container() -> void:
	for i in range(1, 5):
		var card := _list.get_node_or_null("CardContainer/Murid%d" % i) as Control
		assert_true(card != null, "missing CardContainer/Murid%d" % i)
		assert_eq(card.anchor_right, 1.0,
			"Murid%d must anchor to its container's right edge, not collapse" % i)
		assert_eq(card.anchor_bottom, 1.0,
			"Murid%d must anchor to its container's bottom edge, not collapse" % i)
		var btn := card.get_node_or_null("CardButton") as Control
		assert_true(btn != null, "missing Murid%d/CardButton" % i)
		assert_eq(btn.anchor_right, 1.0, "Murid%d/CardButton must fill the card" % i)
		assert_eq(btn.anchor_bottom, 1.0, "Murid%d/CardButton must fill the card" % i)


## The trait chips are Button variations whose styleboxes are 160 tall --
## custom_minimum_size is a floor, not a cap -- so the row overran the
## week strip by 40px. Bands must not overlap, whatever the chips measure.
func test_the_card_bands_do_not_overlap() -> void:
	var card := _list.get_node_or_null("CardContainer/Murid1") as Control
	assert_true(card != null, "missing Murid1")
	# WeekHeader (MURIDMU Task 3) sits between the chips and the notes.
	var bands := ["PortraitFrame", "TraitRow", "WeekHeader", "StickyNotesContainer", "CatatanGuru"]
	var prev_bottom := 0.0
	for name in bands:
		var band := card.get_node_or_null("Paper/" + name) as Control
		assert_true(band != null, "missing band " + name)
		assert_true(band.offset_top >= prev_bottom,
			"%s starts at %f, above the previous band's bottom %f"
				% [name, band.offset_top, prev_bottom])
		prev_bottom = band.offset_bottom


## StickyNote's children were authored in absolute offsets for a 260x260
## note; the week strip instances them at 160x190, which pushed the Icon
## below the note's bottom edge and spilled both labels past its right.
## Anchored children scale with whatever size the instance is given.
func test_sticky_note_children_scale_with_the_note() -> void:
	var scene: PackedScene = load("res://Scenes/StudentList/StickyNote.tscn")
	var note := scene.instantiate()
	track(note)
	for child_name in ["DayLabel", "ActivityLabel", "Icon"]:
		var child := note.get_node_or_null(child_name) as Control
		assert_true(child != null, "missing StickyNote/" + child_name)
		assert_true(child.anchor_right > 0.0 or child.anchor_bottom > 0.0,
			"%s is pinned to absolute offsets and will not fit a resized note"
				% child_name)
	note.free()


## CATEGORY_ICONS must cover every category category_color() knows, or a
## scheduled day gets no glyph. The header comment claims it mirrors that
## key set -- this makes the claim enforceable.
func test_category_icons_cover_the_schedule_categories() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for cat in ["Akademis", "Akademik", "SeniBudaya", "Olahraga", "Istirahat", "Wirausaha", "Libur"]:
		assert_true(src.contains("\"%s\":" % cat),
			"CATEGORY_ICONS is missing the %s category" % cat)


## The notes hang at one of three heights so the strip reads as
## hand-pinned. Two things have to hold: the spread must stay inside the
## strip's own band, and a given student's day must always get the SAME
## height -- a note that moves on every visit reads as a bug.
func test_sticky_notes_hang_at_three_contained_pin_heights() -> void:
	var note_src := FileAccess.get_file_as_string(
		"res://Scripts/StudentList/StickyNote.gd")
	assert_true(note_src.contains("const PIN_STEP"),
		"the pin spacing must be a named constant, not inline")
	assert_true(note_src.contains("@export_range(0, 2) var pin_slot"),
		"pin_slot must be a bounded export on the note's own root")

	# Containment: deepest slot must still finish inside the band.
	var note := preload("res://Scenes/StudentList/StickyNote.tscn").instantiate()
	var note_h: float = note.custom_minimum_size.y
	var deepest: float = 2.0 * note.PIN_STEP + note_h
	note.free()
	var card := _list.get_node_or_null("CardContainer/Murid1")
	var strip := card.get_node_or_null("Paper/StickyNotesContainer") as Control
	assert_true(strip != null, "missing StickyNotesContainer")
	var band: float = strip.offset_bottom - strip.offset_top
	assert_true(deepest <= band,
		"a bottom-slot note (%f) must stay inside the %f strip" % [deepest, band])

	# Determinism: the same student and day must hash to the same slot.
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("func _pin_slot_for("),
		"the slot must come from a named helper")
	assert_false(src.contains("randi") or src.contains("RandomNumberGenerator"),
		"pin slots must be hashed, not drawn from a RNG -- notes would " +
		"jump to a new height on every swipe back")


## Both small-icon maps -- the day notes' CATEGORY_ICONS and the trait
## chip's SPECIALTY_ICONS -- must use the team's authored art, not the
## generated placeholder set, and must agree with each other on every
## category, so a student's chip and their own day notes carry one symbol.
## Istirahat and Wirausaha have no stat of their own and wear their
## dedicated cat_*.svg category icons (UI depth pass Phase 3, Task 3).
func test_the_small_icons_are_the_teams_authored_art() -> void:
	var expected := {
		"Akademis": "res://Assets/Images/StudentCard/stat_akademis.png",
		"SeniBudaya": "res://Assets/Images/StudentCard/stat_senibudaya.png",
		"Olahraga": "res://Assets/Images/StudentCard/stat_olahraga.png",
		"Istirahat": "res://Assets/Images/UI/Icons/cat_istirahat.svg",
		"Wirausaha": "res://Assets/Images/UI/Icons/cat_wirausaha.svg",
		"Libur": "res://Assets/Images/StudentCard/stat_mood.png",
	}
	var maps := {
		_SCRIPT_PATH: "CATEGORY_ICONS",
		"res://Scripts/StudentList/RosterCard.gd": "SPECIALTY_ICONS",
	}
	for path in maps:
		var const_name: String = maps[path]
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("UI/Placeholders/icon_akademis"),
			"%s must not fall back to the placeholder glyphs" % const_name)
		for cat in expected:
			assert_true(src.contains('"%s": "%s"' % [cat, expected[cat]]),
				"%s must map %s to the team's %s" % [const_name, cat, expected[cat]])
	# And the art has to actually be there and load.
	for cat in expected:
		var p: String = expected[cat]
		assert_true(ResourceLoader.exists(p), "missing team icon: " + p)
		assert_true(load(p) is Texture2D, "not a Texture2D: " + p)


## The tutorial's index-keyed logic (auto-advance, end-tutorial, per-step
## spotlight) assumes exactly four steps in a fixed order. A fifth step or
## a reorder silently breaks _switch_card / _on_card_pressed / _show_step.
func test_the_tutorial_has_exactly_four_steps_in_order() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := src.get_slice("var defaults = [", 1).get_slice("\n\t]", 0)
	var titles := ["Muridmu", "Status Jadwal", "Navigasi Card", "Pilih Murid"]
	var last := -1
	for t in titles:
		var at := body.find("\"%s\"" % t)
		assert_true(at > last, "tutorial step '%s' missing or out of order" % t)
		last = at
	assert_eq(body.split("[").size() - 1, 4,
		"the tutorial must have exactly four steps")


## RosterCard's bands live under its inner Paper (MURIDMU Task 3), so
## StudentList must reach them by %unique name, never by a card-relative
## path that a restructure would silently break (get_node_or_null just
## returns null and the card shows its authored defaults).
func test_student_list_reads_the_card_by_unique_names() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	for unique in ["%Portrait", "%Nama", "%Belum", "%Sudah", "%StickyNotesContainer"]:
		assert_true(src.contains('get_node_or_null("%s")' % unique),
			"StudentList must read the card's %s by unique name" % unique)
	for old in ['"PortraitFrame/Portrait"', 'get_node_or_null("Nama")',
			'get_node_or_null("Belum")', 'get_node_or_null("StickyNotesContainer")']:
		assert_false(src.contains(old), "stale card path: " + old)


## The card's surface is an opaque themed Panel filling its whole rect,
## not a paper TEXTURE on the root.
##
## Two bugs came out of the texture version. paper.png is only opaque
## across the middle of its own rect, so bands laid out against the full
## card rect rendered on the desk behind it; and the cast shadow was a
## separate sibling node, so every card animation left it behind. The
## Card variation's stylebox carries its own shadow, which means the
## shadow is part of the card and cannot be left behind by anything.
##
## Since MURIDMU Task 3 the whole visible card sits inside its inner Paper
## node, so the idle breath can scale the paper and every band printed on
## it without touching the card root the carousel moves. The Sheet sits
## just above the breath's LiftShadow, behind every band.
func test_each_card_surface_is_an_opaque_themed_panel() -> void:
	for i in range(1, 5):
		var paper := _list.get_node_or_null(
			"CardContainer/Murid%d/Paper" % i) as Control
		assert_true(paper != null, "missing Paper on Murid%d" % i)
		if paper != null:
			assert_eq(paper.get_index(), 0,
				"Murid%d's Paper must draw behind every other band" % i)
		var sheet := _list.get_node_or_null(
			"CardContainer/Murid%d/Paper/Sheet" % i) as Panel
		assert_true(sheet != null, "missing Paper/Sheet panel on Murid%d" % i)
		assert_eq(sheet.theme_type_variation, &"Card",
			"Murid%d's Sheet must use the Card variation" % i)
		assert_eq(sheet.get_index(), 1,
			"Murid%d's Sheet must draw over its lift shadow and behind every band" % i)
		var lift := paper.get_node_or_null("LiftShadow") if paper != null else null
		assert_true(lift != null and lift.get_index() == 0,
			"Murid%d's LiftShadow must be Paper's first child, under the Sheet" % i)
		assert_eq(sheet.anchor_right, 1.0,
			"Murid%d's Sheet must span the full card width" % i)
		assert_eq(sheet.anchor_bottom, 1.0,
			"Murid%d's Sheet must span the full card height" % i)


## The separate shadow node and the tween plumbing that dragged it along
## are gone; the Card stylebox's own shadow replaced both.
func test_the_card_shadow_is_not_a_separate_node() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_false(src.contains("_drive_shadow"),
		"the shadow-follow helper is obsolete -- Card's stylebox owns it")
	assert_false(src.contains("card_shadow"),
		"nothing should reference a standalone shadow node any more")
	var scene := FileAccess.get_file_as_string(
		"res://Scenes/StudentList/StudentList.tscn")
	assert_false(scene.contains('name="Shadow"'),
		"CardContainer must not carry a separate Shadow node")


## The page dots are tinted via self_modulate, so the texture underneath
## has to be a filled shape. It was a hollow ring for one release and the
## dots were reported invisible on a phone.
func test_page_dot_uses_a_filled_texture() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scenes/StudentList/PageDot.tscn")
	assert_true(src.contains("page_dot.png"),
		"PageDot must use the filled dot, not the hollow avatar frame")
	assert_false(src.contains("roster_avatar_frame.png"),
		"PageDot must not reuse the hollow ring")


## The portrait sits on a rounded sunken panel rather than straight on
## the paper, so a short or transparent portrait still reads as a framed
## photo instead of floating.
func test_each_portrait_has_a_rounded_backdrop_behind_it() -> void:
	for i in range(1, 5):
		var backdrop := _list.get_node_or_null(
			"CardContainer/Murid%d/Paper/PortraitFrame/Backdrop" % i) as Panel
		assert_true(backdrop != null, "missing portrait Backdrop on Murid%d" % i)
		assert_eq(backdrop.theme_type_variation, &"SunkenPanel",
			"portrait Backdrop on Murid%d must use SunkenPanel" % i)
		var portrait := _list.get_node_or_null(
			"CardContainer/Murid%d/Paper/PortraitFrame/Portrait" % i) as Control
		assert_true(portrait != null, "missing Portrait on Murid%d" % i)
		assert_true(backdrop.get_index() < portrait.get_index(),
			"Backdrop must draw behind the portrait on Murid%d" % i)


## self_modulate MULTIPLIES the note texture, so the raw category token
## drives the paper too dark for its own dark-brown label text. The wash
## toward white is what keeps the note legible on a phone.
func test_sticky_note_tint_is_washed_before_it_is_applied() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentList/StickyNote.gd")
	assert_true(src.contains("const TINT_WASH"),
		"the wash factor must be a named constant, not inline")
	assert_true(src.contains("lerp(Color.WHITE, TINT_WASH)"),
		"the category color must be washed toward white before tinting")
	assert_false(src.contains("self_modulate = DesignTokens.load_default()"),
		"no call site may apply a raw category color to self_modulate")


# ---------------------------------------------- Task 4: week wiring / reopen
#
# StudentList is not @tool: in the editor it is a placeholder instance, so
# NEITHER its methods NOR its @onready vars are reachable from a test, full
# stop (confirmed the hard way -- calling _setup_students() on the shared
# `_list` fixture threw "Attempt to call a method on a placeholder
# instance"). So the behaviour Task 4 actually needs to prove lives on
# RosterCard instead (@tool, real instances, already proven callable/
# testable -- see tests/test_roster_card.gd's apply_week/set_front/
# initial_card_index tests) and StudentList.gd only calls it. What's left
# here is a source-text pin on the call sites, per this suite's established
# scan pattern for anything StudentList-only that can't be driven live.

func test_setup_students_delegates_the_week_to_roster_card() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("card.apply_week(day_schedules_for_student)"),
		"_apply_card_week must hand the week off to RosterCard.apply_week()")


func test_init_carousel_state_reopens_via_roster_card() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains(
			"RosterCard.initial_card_index(active_students, GameState.selected_student)"),
		"_init_carousel_state must resolve the starting card through RosterCard's static helper")


# ------------------------------------------ Task 6: the RosterDeck carousel
#
# The swipe/drag/switch moved out of StudentList.gd into RosterDeck
# (Scripts/StudentList/RosterDeck.gd, @tool), whose behaviour
# tests/test_roster_deck.gd drives directly. What StudentList still owns is
# the wiring, pinned here: the authored GhostCard and RosterDeck nodes, the
# scene connections, and the call sites -- by source, since StudentList is
# a placeholder instance in the editor (see the Task 4 note above).

## The body of StudentList.gd's `name` function, up to the next func.
func _function_body(name: String) -> String:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	return src.get_slice("func %s(" % name, 1).get_slice("
func ", 0)


## The switch is one overlapped timeline on the deck now: _switch_card no
## longer awaits a slide-out before the slide-in, and the front-card
## handoff rides the deck's signals -- off as the card leaves, on (entry
## replayed) when the deck says the new card LANDED.
func test_switch_card_wires_front_card_activation() -> void:
	var switch_body := _function_body("_switch_card")
	assert_false(switch_body.contains("await "),
		"_switch_card must not await: the deck overlaps out and in")
	assert_false(FileAccess.get_file_as_string(_SCRIPT_PATH).contains("tween_out.finished"),
		"the sequential slide-out gate is gone")
	assert_true(switch_body.contains("old_card.set_front(false)"),
		"_switch_card must turn off the card it is leaving")
	assert_true(switch_body.contains("deck.switch(old_card, new_card, direction)"),
		"_switch_card must hand the swap to the RosterDeck")
	var settled_body := _function_body("_on_deck_settled")
	assert_true(settled_body.contains("front.set_front(true)"),
		"a card that lands must be turned on (its entry replays)")
	var sprang_back: String = settled_body.get_slice("front.set_front(true)", 0)
	assert_true(sprang_back.contains("front.set_idle(not tutorial_active)"),
		"a card that only sprang back resumes its idle loops (paused while the tutorial is up)")
	assert_false(sprang_back.contains("set_front(") or sprang_back.contains("play_entry"),
		"a spring-back resumes the loops without re-arriving (no set_front, no entry replay)")
	assert_true(settled_body.get_slice("front.set_front(true)", 1).contains("front.set_idle(false)"),
		"the tutorial keeps a landed card's idle loops paused")
	assert_true(settled_body.contains("_stagger_card_notes(front)"),
		"the landed card's week re-drops on arrival")


func test_the_tutorial_still_advances_when_the_slide_lands() -> void:
	assert_true(_function_body("_on_deck_settled").contains(
			"if tutorial_active and current_step == 2:"),
		"the Navigasi Card step auto-advances once the deck lands a card")


func test_the_swipe_is_delegated_to_the_roster_deck() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("@onready var deck: RosterDeck = %RosterDeck"),
		"StudentList reaches the deck by its unique name")
	assert_true(_function_body("_on_card_gui_input").contains(
			"deck.handle_pointer(event, card_node)"),
		"every pointer event on the front card goes to the deck")
	assert_false(src.contains("card_animating"),
		"card_animating is the deck's busy now")
	assert_false(src.contains("min_swipe_distance"),
		"the swipe threshold lives on RosterDeck")
	for fn in ["_next_card", "_prev_card", "_on_avatar_pressed", "_switch_card"]:
		assert_true(_function_body(fn).contains("deck.busy"),
			"%s must respect the deck's busy guard" % fn)


## A drag's release reaches the deck before the card's Button emits
## `pressed`, so the tap gate is what keeps a drag from routing to
## AturJadwal; the tutorial lock (only step 3 may pick) stays behind it.
func test_a_tap_still_routes_and_a_drag_does_not() -> void:
	var pressed_body := _function_body("_on_card_pressed")
	assert_true(pressed_body.contains("if not deck.accepts_tap():"),
		"a drag or a busy deck must not route the card")
	assert_true(pressed_body.contains("if current_step == 3:"),
		"the tutorial still locks the pick to its final step")
	assert_true(_function_body("_on_student_selected").contains(
			"Transition.change_scene(\"res://Scenes/AturJadwal/AturJadwal.tscn\")"),
		"picking a card still routes to AturJadwal")


func test_the_deck_signals_are_wired_in_the_scene() -> void:
	var scene := FileAccess.get_file_as_string(_SCENE_PATH)
	for pair in [["picked_up", "_on_deck_picked_up"], ["thrown", "_on_deck_thrown"],
			["switched", "_on_deck_switched"], ["settled", "_on_deck_settled"]]:
		assert_true(scene.contains(
				"[connection signal=\"%s\" from=\"RosterDeck\" to=\".\" method=\"%s\"]" % pair),
			"RosterDeck.%s must be wired to %s" % pair)
		assert_true(FileAccess.get_file_as_string(_SCRIPT_PATH).contains("func %s(" % pair[1]),
			"StudentList must define %s" % pair[1])


func test_the_roster_deck_is_an_authored_node() -> void:
	var deck := _list.get_node_or_null("RosterDeck")
	assert_true(deck is RosterDeck, "StudentList must carry a RosterDeck node")
	assert_true(deck != null and deck.unique_name_in_owner, "reached as %RosterDeck")


## The next file peeking out behind the front one: an authored,
## surface_sunken paper panel at the peek pose, drawn behind every card,
## and inert to touch so the card above it keeps every tap.
func test_the_ghost_card_is_an_authored_inert_peek() -> void:
	var ghost := _list.get_node_or_null("CardContainer/GhostCard") as Panel
	assert_true(ghost != null, "CardContainer must carry a GhostCard Panel")
	if ghost == null:
		return
	assert_eq(ghost.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the ghost ignores the mouse")
	assert_eq(ghost.get_index(), 0, "the ghost draws behind every card")
	assert_eq(ghost.theme_type_variation, &"SunkenPanel", "surface_sunken paper, from the theme")
	assert_true(ghost.modulate.a > 0.0 and ghost.modulate.a < 1.0, "half-seen, behind the stack")
	assert_true(absf(ghost.rotation_degrees - 4.0) < 0.01, "tilted 4 degrees")
	assert_eq(ghost.scale, Vector2(0.9, 0.9), "set back at 0.9")
	assert_eq(ghost.offset_left, 34.0, "shifted 34px, peeking out on the right")
	var deck := _list.get_node_or_null("RosterDeck") as RosterDeck
	assert_true(deck != null and deck.ghost == ghost,
		"the deck resolves %GhostCard as the card its drag trails")


## Jumping via an avatar throws like the paging arrows: a later student
## comes off the stack leftward (-1, as Next), an earlier one rightward.
func test_avatar_jump_throws_like_next_and_prev() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("var direction := -1 if index > current_card_index else 1"),
		"jumping to a later student throws left, as Next does")
	assert_true(src.contains("_switch_card(index, direction)"),
		"the jump reuses the carousel's own switch")


## The tutorial holds the front card's idle loops (breath, "tap me" glow)
## paused: _ready pauses them once the cards exist, a landed or sprung-back
## card stays paused while it is up, and _end_tutorial resumes them.
func test_the_tutorial_pauses_the_front_cards_idle_loops() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var helper := src.get_slice("func _set_front_idle(on: bool) -> void:", 1).get_slice("\nfunc ", 0)
	assert_true(helper.contains("card_nodes[current_card_index].set_idle(on)"),
		"the helper drives the front card's idle loops")
	var ready_body := src.get_slice("func _ready():", 1).get_slice("\nfunc ", 0)
	assert_true(ready_body.contains("_set_front_idle(not tutorial_active)"),
		"_ready pauses the front card's loops when the tutorial is up, after the cards exist")
	var settled := src.get_slice("func _on_deck_settled(", 1).get_slice("\nfunc ", 0)
	assert_true(settled.contains("front.set_idle(not tutorial_active)"),
		"a sprung-back card must not resume its loops under the tutorial")
	assert_true(settled.contains("if tutorial_active:\n\t\tfront.set_idle(false)"),
		"a landed card must not run its loops under the tutorial")
	var ending := src.get_slice("func _end_tutorial():", 1).get_slice("\nfunc ", 0)
	assert_true(ending.contains("_set_front_idle(true)"),
		"ending the tutorial resumes the front card's loops")


# ------------------------------------------- the tutorial on the shared panel
#
# 2026-10-01 tutorial unification. The tutorial card used to be a PanelContainer,
# three Labels and two separators built at runtime, its arrow was clamped with a
# hard-coded 320px picture, and a tap on the card before the last step was
# dropped without a sound. It is now TutorialPanel.tscn, mounted into the
# overlay and seated inside the screen's Safe/UI, and that tap is answered.

## The shared card's own script, for the answer every screen shares.
const _PANEL_SCRIPT_PATH := "res://Scripts/UI/TutorialPanel.gd"


func test_the_tutorial_card_is_the_shared_panel_not_a_runtime_build() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(_function_body("_build_tutorial_panel").contains(
			"TutorialPanel.mount(tutorial_panel_scene, color_rect, click_area)"),
		"the card is the shared TutorialPanel scene, mounted in the overlay")
	for gone: String in ["PanelContainer.new(", "VBoxContainer.new(", "Label.new(",
			"HSeparator.new(", "_tutorial_title_label", "_tutorial_body_label"]:
		assert_false(src.contains(gone), "StudentList.gd still carries %s" % gone)
	assert_true(src.contains(
			'@export var tutorial_panel_scene: PackedScene = preload("res://Scenes/UI/TutorialPanel.tscn")'),
		"the scene is an export, so it can be swapped in the inspector")


func test_every_step_goes_through_the_panel_with_its_number_and_count() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(_function_body("_show_step").contains(
			"_tutorial_panel.show_step(step.title, step.text, prompt, index + 1, tutorial_steps.size())"),
		"each step fills the card via show_step with its 1-based number and the step count")
	assert_false(src.contains("(%d/%d)"),
		"the panel's pill is the step counter; a title prefix would count the steps twice")


func test_the_card_and_arrow_are_seated_inside_the_screens_safe_ui() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("@onready var tutorial_safe_ui: Control = $Safe/UI"),
		"the bounds are the screen's own Safe/UI")
	assert_true(_list.get_node_or_null("Safe/UI") is Control, "and the scene has one")
	var seating := _function_body("_position_tutorial_panel")
	assert_true(seating.contains(
			"TutorialPanel.place_step(_tutorial_panel, tutorial_safe_ui, color_rect, _step_targets, _tutorial_arrow)"),
		"the card and the arrow are seated by the shared placement")
	assert_false(seating.contains("get_viewport_rect"), "with no raw viewport math")


## A tap on the card before the last step used to fall through to the bare
## `return`, so the card looked dead. The Navigasi Card step wants the right
## arrow; the tap is answered, and the pick is still locked to the final step.
func test_a_card_tap_before_the_last_step_is_answered_not_dropped() -> void:
	var pressed := _function_body("_on_card_pressed")
	assert_true(pressed.contains("else:\n\t\t\t_reject_tutorial_tap()\n\t\treturn"),
		"any tap in the tutorial that is not the final pick is answered, then refused")
	assert_true(pressed.contains("if current_step == 3:"), "the pick stays locked to the last step")
	var reject := _function_body("_reject_tutorial_tap")
	assert_true(reject.contains("_targets_for_step(current_step)"),
		"the answer goes to the control the current step wants")
	assert_true(reject.contains("TutorialPanel.answer_wrong_tap(targets[0])"),
		"that control shakes and its sibling buttons dim")
	assert_true(_function_body("_targets_for_step").contains("right_arrow if right_arrow else left_arrow"),
		"at the Navigasi Card step the control wanted is the right arrow")
	var answer := FileAccess.get_file_as_string(_PANEL_SCRIPT_PATH) \
		.get_slice("func answer_wrong_tap(", 1).get_slice("\nstatic func ", 0)
	assert_true(answer.contains('AudioDirector.play_sfx(&"error")'), "with the error cue")
	assert_true(answer.contains("Juice.shake(target)"), "and a shake on the target")
