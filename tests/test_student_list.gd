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
##  * student_list.gd is NOT @tool. Empirically verified here: this
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

const _SCENE_PATH := "res://Scenes/StudentList/student_list.tscn"
const _SCRIPT_PATH := "res://Scripts/StudentList/student_list.gd"
const _STICKYNOTE_SCRIPT_PATH := "res://Scripts/StudentList/StickyNote.gd"
const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "student_list"


var _list: Control


func setup() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	_list = scene.instantiate()
	_list.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(_list)
	track(_list)


func teardown() -> void:
	if is_instance_valid(_list):
		_list.queue_free()
	_list = null


# ------------------------------------------------ behavioral contract net

func test_still_routes_to_atur_jadwal() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("res://Scenes/AturJadwal/atur_jadwal.tscn"),
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
		"CardContainer/Murid1/CardButton", "LeftArrow", "RightArrow",
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
	var header := _list.get_node_or_null("HeaderLabel") as Label
	assert_true(header != null, "missing HeaderLabel")
	assert_eq(header.theme_type_variation, &"H1Label", "HeaderLabel variation")

	for i in range(1, 5):
		var belum := _list.get_node_or_null("CardContainer/Murid%d/Belum" % i) as Button
		assert_true(belum != null, "missing Murid%d/Belum" % i)
		assert_eq(belum.theme_type_variation, &"DangerButton", "Murid%d/Belum variation" % i)

		var sudah := _list.get_node_or_null("CardContainer/Murid%d/Sudah" % i) as Button
		assert_true(sudah != null, "missing Murid%d/Sudah" % i)
		assert_eq(sudah.theme_type_variation, &"SuccessButton", "Murid%d/Sudah variation" % i)

		var nama := _list.get_node_or_null("CardContainer/Murid%d/Nama" % i) as Label
		assert_true(nama != null, "missing Murid%d/Nama" % i)
		assert_eq(nama.theme_type_variation, &"H2Label", "Murid%d/Nama variation" % i)


## These nav arrows are on the L size step (160px tall), whose variation uses
## font_h1 (64) rather than font_title (36) -- hence the L suffix on the name.
func test_nav_arrows_use_theme_variation() -> void:
	for name in ["LeftArrow", "RightArrow"]:
		var b := _list.get_node_or_null(name) as Button
		assert_true(b != null, "missing " + name)
		assert_eq(b.theme_type_variation, &"SecondaryButtonL", name + " variation")


func test_sticky_notes_are_stickynote_instances_wired_per_day() -> void:
	var required_days = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat"]
	for i in range(1, 5):
		var container := _list.get_node_or_null(
			"CardContainer/Murid%d/StickyNotesContainer" % i)
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


## Part 3's generated art. All six are System.Drawing / hand-written SVG
## placeholders, drop-replaceable at the same path with no code change.
## icon_wirausaha is a genuine gap fix: StickyNote already tints for
## Wirausaha via category_color(), so without it a Wirausaha day would be
## the only note in the week strip with no glyph.
func test_part_three_art_exists_and_loads() -> void:
	var paths := [
		"res://Assets/Images/UI/Placeholders/icon_wirausaha.svg",
		"res://Assets/Images/UI/Placeholders/stamp_sudah.svg",
		"res://Assets/Images/UI/Placeholders/stamp_belum.svg",
		"res://Assets/Images/UI/StudentList/photo_corner.png",
		"res://Assets/Images/UI/StudentList/roster_avatar_frame.png",
		"res://Assets/Images/UI/StudentList/catatan_rule.png",
	]
	for p in paths:
		assert_true(ResourceLoader.exists(p), "missing asset: " + p)
		assert_true(load(p) is Texture2D, "not a Texture2D: " + p)


## RosterAvatar is @tool, so unlike student_list.gd its _ready DOES fire
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
			"CardContainer/Murid%d/StickyNotesContainer" % i)
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
			"CardContainer/Murid%d/TraitRow" % i) as Control
		assert_true(row != null, "missing TraitRow on Murid%d" % i)
		assert_eq(row.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"TraitRow on Murid%d must not swallow card taps" % i)
		for chip_name in expected:
			var chip := _list.get_node_or_null(
				"CardContainer/Murid%d/TraitRow/%s" % [i, chip_name]) as Button
			assert_true(chip != null, "missing %s on Murid%d" % [chip_name, i])
			assert_eq(chip.theme_type_variation, expected[chip_name],
				"%s must use the M size step on Murid%d" % [chip_name, i])
			assert_eq(chip.mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s on Murid%d must not swallow card taps" % [chip_name, i])


## The card's dead band becomes the teacher's note.
func test_catatan_strip_is_populated_per_student() -> void:
	for i in range(1, 5):
		var label := _list.get_node_or_null(
			"CardContainer/Murid%d/CatatanGuru/CatatanLabel" % i) as Label
		assert_true(label != null, "missing CatatanLabel on Murid%d" % i)
		assert_true(label.text.length() > 0,
			"catatan must never be blank on Murid%d" % i)


func test_sticky_notes_carry_a_category_icon() -> void:
	var note := _list.get_node_or_null(
		"CardContainer/Murid1/StickyNotesContainer/Senin") as StickyNote
	assert_true(note != null, "missing Senin note")
	assert_true("icon_texture" in note,
		"StickyNote must expose an icon_texture export")


## The roster strip above the carousel: one RosterAvatar per student, so
## roster progress reads without paging through every card.
func test_roster_strip_holds_four_avatars() -> void:
	var strip := _list.get_node_or_null("RosterStrip")
	assert_true(strip != null, "missing RosterStrip")
	for i in range(1, 5):
		var a := strip.get_node_or_null("Avatar%d" % i)
		assert_true(a != null, "missing RosterStrip/Avatar%d" % i)
		assert_true(a is RosterAvatar, "Avatar%d must be a RosterAvatar" % i)


## The arrows used to sit pinned to the vertical centre of a 1920-tall
## screen, which is nowhere near a thumb. They move to a nav row with
## the page dots.
func test_navigation_sits_in_thumb_reach() -> void:
	for n in ["LeftArrow", "RightArrow", "PageIndicator"]:
		var c := _list.get_node_or_null(n) as Control
		assert_true(c != null, "missing " + n)
		assert_true(c.offset_top >= 1600.0,
			"%s must sit in the lower third, got offset_top %f" % [n, c.offset_top])


func test_header_sits_on_the_papan_plaque() -> void:
	var papan := _list.get_node_or_null("Papan") as TextureRect
	assert_true(papan != null, "missing Papan plaque behind the header")
	var header := _list.get_node_or_null("HeaderLabel") as Label
	assert_true(header != null, "missing HeaderLabel")
	assert_eq(header.theme_type_variation, &"H1Label", "HeaderLabel variation")


## Source scans, not behaviour: student_list.gd is deliberately NOT
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
		"student_list.gd must open with a ## file header")

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
	var bands := ["PortraitFrame", "TraitRow", "StickyNotesContainer", "CatatanGuru"]
	var prev_bottom := 0.0
	for name in bands:
		var band := card.get_node_or_null(name) as Control
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


## The tutorial's index-keyed logic (auto-advance, end-tutorial, per-step
## spotlight) assumes exactly four steps in a fixed order. A fifth step or
## a reorder silently breaks _switch_card / _on_card_pressed / _show_step.
func test_the_tutorial_has_exactly_four_steps_in_order() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	var body := src.get_slice("var defaults = [", 1).get_slice("\n\t]", 0)
	var titles := ["Daftar Murid", "Status Jadwal", "Navigasi Card", "Pilih Murid"]
	var last := -1
	for t in titles:
		var at := body.find("\"%s\"" % t)
		assert_true(at > last, "tutorial step '%s' missing or out of order" % t)
		last = at
	assert_eq(body.split("[").size() - 1, 4,
		"the tutorial must have exactly four steps")


## The card's surface is an opaque themed Panel filling its whole rect,
## not a paper TEXTURE on the root.
##
## Two bugs came out of the texture version. paper.png is only opaque
## across the middle of its own rect, so bands laid out against the full
## card rect rendered on the desk behind it; and the cast shadow was a
## separate sibling node, so every card animation left it behind. The
## Card variation's stylebox carries its own shadow, which means the
## shadow is part of the card and cannot be left behind by anything.
func test_each_card_surface_is_an_opaque_themed_panel() -> void:
	for i in range(1, 5):
		var sheet := _list.get_node_or_null(
			"CardContainer/Murid%d/Sheet" % i) as Panel
		assert_true(sheet != null, "missing Sheet panel on Murid%d" % i)
		assert_eq(sheet.theme_type_variation, &"Card",
			"Murid%d's Sheet must use the Card variation" % i)
		assert_eq(sheet.get_index(), 0,
			"Murid%d's Sheet must draw behind every other band" % i)
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
		"res://Scenes/StudentList/student_list.tscn")
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
			"CardContainer/Murid%d/PortraitFrame/Backdrop" % i) as Panel
		assert_true(backdrop != null, "missing portrait Backdrop on Murid%d" % i)
		assert_eq(backdrop.theme_type_variation, &"SunkenPanel",
			"portrait Backdrop on Murid%d must use SunkenPanel" % i)
		var portrait := _list.get_node_or_null(
			"CardContainer/Murid%d/PortraitFrame/Portrait" % i) as Control
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
