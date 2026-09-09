@tool
extends McpTestSuite

## Student card redesign (2026-08-28). Pins the contract of the new layout:
## imported art, pill geometry over the painted tracks, icon clusters, and
## the bio panel. Suite is @tool and no test is a coroutine, per the runner
## constraints documented in test_lobby.gd.

const _ART := "res://Assets/Images/StudentCard/"

const _EXPECTED_ART: Array[String] = [
	"card_bg.png", "pill_fill.png", "trait_button.png", "icon_info.png",
	"stat_akademis.png", "stat_senibudaya.png", "stat_olahraga.png",
	"stat_mood.png", "stat_energy.png",
]


func suite_name() -> String:
	return "student_card_layout"


func test_every_redesign_texture_is_imported() -> void:
	for file_name in _EXPECTED_ART:
		var path := _ART + file_name
		assert_true(ResourceLoader.exists(path), "missing art: " + path)


func test_card_background_is_the_full_design_size() -> void:
	var tex: Texture2D = load(_ART + "card_bg.png")
	assert_eq(tex.get_width(), 1080, "card_bg must be 1080 wide")
	assert_eq(tex.get_height(), 1920, "card_bg must be 1920 tall")


const _BIO := {
	"Marcel": ["Laki - Laki", "20 September"],
	"Doni":   ["Laki - Laki", "9 Maret"],
	"Andi":   ["Laki - Laki", "25 Januari"],
	"Citra":  ["Perempuan", "17 Desember"],
	"Shinta": ["Perempuan", "4 Juni"],
	"Thea":   ["Perempuan", "15 Mei"],
}


func test_roster_carries_gender_and_birth_date() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/StudentCard/student_card.gd")
	for student_name in _BIO.keys():
		var gender: String = _BIO[student_name][0]
		var born: String = _BIO[student_name][1]
		assert_true(src.contains('"jenis_kelamin": "%s"' % gender),
			"student_card.gd must declare jenis_kelamin %s for %s" % [gender, student_name])
		assert_true(src.contains('"tanggal_lahir": "%s"' % born),
			"student_card.gd must declare tanggal_lahir %s for %s" % [born, student_name])


## ReportCard never hardcodes student data -- it reads
## GameState.approved_students live (report_card.gd:52), which
## student_card.gd populates directly from its own student_data_list
## entries (student_card.gd:1421). So the new bio fields reach ReportCard
## automatically once they exist on student_card.gd's dictionaries; this
## pins that the propagation path itself stays intact.
func test_report_card_still_reads_approved_students_live() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/ReportCard/report_card.gd")
	assert_true(src.contains("student_data_list = GameState.approved_students"),
		"report_card.gd must keep reading the live roster, not a hardcoded copy")


const _SCENES := [
	"res://Scenes/StudentCard/student_card.tscn",
	"res://Scenes/ReportCard/report_card.tscn",
]


## The measured pill offsets in StudentCardView assume the card is exactly
## the texture's own 1080x1920. A card of any other width stretches the
## painted tracks out from under the fills that sit on them.
func test_every_card_is_exactly_the_texture_size() -> void:
	for scene_path in _SCENES:
		var scene: Node = (load(scene_path) as PackedScene).instantiate()
		for i in range(1, 7):
			var card := scene.get_node_or_null("KertasMurid%d" % i) as Control
			assert_true(card != null, "%s missing KertasMurid%d" % [scene_path, i])
			assert_eq(card.size.x, 1080.0,
				"%s KertasMurid%d width" % [scene_path, i])
			assert_eq(card.size.y, 1920.0,
				"%s KertasMurid%d height" % [scene_path, i])
		scene.free()


func test_cards_use_the_new_background() -> void:
	for scene_path in _SCENES:
		var src := FileAccess.get_file_as_string(scene_path)
		assert_true(src.contains("Assets/Images/StudentCard/card_bg.png"),
			scene_path + " must reference the new card background")
		assert_false(src.contains("paper_placeholder.jpg"),
			scene_path + " must no longer reference the placeholder paper")


## The painted tracks are at fixed pixel positions in the card art, so the
## fills must land exactly on them.
const _EXPECTED_PILLS := {
	"Akademis1": Rect2(284, 763, 211, 67),
	"Akademis2": Rect2(284, 888, 211, 67),
	"Akademis3": Rect2(284, 1014, 211, 67),
	"Kepribadian1": Rect2(716, 762, 211, 67),
	"Kepribadian2": Rect2(717, 888, 211, 67),
}


func test_pill_rects_match_the_painted_tracks() -> void:
	for bar_name in _EXPECTED_PILLS.keys():
		assert_true(StudentCardView.PILL_RECTS.has(bar_name),
			"PILL_RECTS must cover " + bar_name)
		assert_eq(StudentCardView.PILL_RECTS[bar_name], _EXPECTED_PILLS[bar_name],
			"PILL_RECTS[%s] must sit on the painted track" % bar_name)


## The pill shows no text at all in the new design -- the icon beside it
## says which stat it is.
func test_bars_carry_no_text_children() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/StudentCardView.gd")
	assert_false(src.contains('val_lbl.text = "%d / %d"'),
		"the value readout must be gone from the redesigned pill")
	assert_true(src.contains('variation = &"StatPill"'),
		"card bars must opt into the StatPill variation")


## Behavioural companion to the source scan above. StudentCardView.gd:161
## sets `bar.variation = &"StatPill"` at RUNTIME, after the bar has already
## gone through _ready() with the default "StatBar" family -- which force-
## sets self_modulate to white for that family (see StatBar._apply_tint()).
## A `variation` setter that only wrote theme_type_variation left
## self_modulate stuck at that earlier white and the pill rendered blank --
## this reproduces the exact sequence StudentCardView performs and would
## have caught it.
##
## The expected colour is the ON-DARK accent, not the light-chrome one:
## StatPill's background is a StyleBoxEmpty, so what sits behind the fill is
## the dark track painted into card_bg.png. Pairing a light-chrome accent
## with that dark ground is what made these bars read muddy.
func test_switching_variation_at_runtime_rederives_the_tint() -> void:
	var bar := StatBar.new()
	bar.category = "Olahraga"
	Engine.get_main_loop().root.add_child(bar)
	track(bar)
	# Default family, as _ready() left it.
	assert_eq(bar.self_modulate, Color.WHITE,
		"sanity check: the default StatBar family starts self_modulate white")

	bar.variation = &"StatPill"

	var tokens := DesignTokens.load_default()
	assert_eq(bar.self_modulate, tokens.cat_olahraga_on_dark,
		"switching to StatPill at runtime must re-derive self_modulate from the category")
	assert_eq(bar.theme_type_variation, &"StatPill",
		"switching to StatPill at runtime must still update theme_type_variation")


## The icon replaces the bar's old name label, and with the magnifier gone
## it is also the only thing the player can tap for information -- so it
## has to clear the touch minimum on its own.
##
## A source scan, not a live instantiation: build_icon_clusters only runs
## from populate(), which student_card.gd's _ready() calls -- and
## student_card.gd is deliberately not @tool, so _ready() never fires just
## from instantiating the scene in a test (see student_card's suite header
## for the precedent). Every other test in this suite that needs to check
## StudentCardView's behaviour uses the same technique.
func test_icon_clusters_exist_and_meet_the_touch_target() -> void:
	var tokens := DesignTokens.load_default()
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/StudentCardView.gd")

	assert_true(src.contains("func build_icon_clusters("),
		"StudentCardView must build a tappable icon cluster per stat")

	var size_line := ""
	for line in src.split("\n"):
		if line.strip_edges().begins_with("const _ICON_SIZE"):
			size_line = line
			break
	assert_true(size_line != "", "_ICON_SIZE constant must exist")
	var icon_size := size_line.get_slice("=", 1).strip_edges().trim_suffix(".0").to_float()
	assert_true(icon_size >= float(tokens.touch_target_min),
		"icon cluster is %d px, below the %d px minimum"
			% [int(icon_size), tokens.touch_target_min])

	# Scoped to the _STAT_ICONS block specifically -- "Akademis1": also
	# appears in PILL_RECTS and build_stat_bars' values dict, so a bare
	# src.contains() would still pass even if _STAT_ICONS lost an entry.
	var stat_icons_start := src.find("const _STAT_ICONS")
	assert_true(stat_icons_start != -1, "_STAT_ICONS constant must exist")
	var stat_icons_end := src.find("}", stat_icons_start)
	var stat_icons_block := src.substr(stat_icons_start, stat_icons_end - stat_icons_start)
	for bar_name in ["Akademis1", "Akademis2", "Akademis3", "Kepribadian1", "Kepribadian2"]:
		assert_true(stat_icons_block.contains('"%s": "stat_' % bar_name),
			"_STAT_ICONS must map an icon for " + bar_name)


func test_the_pill_no_longer_takes_input() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/StudentCardView.gd")
	assert_true(src.contains("bar.mouse_filter = Control.MOUSE_FILTER_IGNORE"),
		"the pill must be inert; the icon cluster carries the tap")
	assert_false(src.contains("icon_magnify"),
		"the magnifying glass is replaced by the stat icons")


## Source scan, not live instantiation: build_bio_panel only runs from
## populate(), which student_card.gd's _ready() calls -- and student_card.gd
## is deliberately not @tool, so _ready() never fires just from
## instantiating the scene in a test (same reasoning as
## test_icon_clusters_exist_and_meet_the_touch_target above).
func test_bio_panel_renders_the_three_rows() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/StudentCardView.gd")
	assert_true(src.contains("func build_bio_panel("),
		"StudentCardView must build a bio panel")
	for heading in ["Nama:", "Jenis Kelamin:", "Tanggal Lahir:"]:
		assert_true(src.contains('"%s"' % heading),
			"BioPanel must show the row " + heading)


## The panel is painted into the card art; the text must land inside it.
## Checks the geometry is actually WIRED, not just that the constant
## exists: all four offsets must derive from BIO_PANEL_RECT with
## _BIO_PADDING applied, and populate() must actually call build_bio_panel
## -- a source scan can't run the layout, so it checks the ingredients are
## connected instead.
func test_bio_panel_sits_inside_the_painted_panel() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/StudentCardView.gd")
	assert_true(src.contains("const BIO_PANEL_RECT := Rect2(120, 300, 489, 367)"),
		"BIO_PANEL_RECT must match the painted panel's measured interior")

	var panel_start := src.find("func build_bio_panel(")
	assert_true(panel_start != -1, "build_bio_panel must exist")
	var panel_end := src.find("\nstatic func", panel_start + 1)
	var panel_body := src.substr(panel_start, panel_end - panel_start)
	for offset_line in ["panel.offset_left = BIO_PANEL_RECT.position.x + _BIO_PADDING",
			"panel.offset_top = BIO_PANEL_RECT.position.y + _BIO_PADDING",
			"panel.offset_right = BIO_PANEL_RECT.end.x - _BIO_PADDING",
			"panel.offset_bottom = BIO_PANEL_RECT.end.y - _BIO_PADDING"]:
		assert_true(panel_body.contains(offset_line),
			"build_bio_panel must derive every offset from BIO_PANEL_RECT and _BIO_PADDING: "
				+ offset_line)

	assert_true(src.contains("build_bio_panel(card, student)"),
		"populate() must call build_bio_panel, or the bio panel never renders")


## The redesign's bio panel and icon clusters replace what these four
## labels used to show; the nodes themselves are removed from every card
## in both scenes, not just hidden at runtime.
func test_superseded_labels_are_removed_from_the_scenes() -> void:
	for scene_path in _SCENES:
		var src := FileAccess.get_file_as_string(scene_path)
		for i in range(1, 7):
			for label_name in ["Nama", "Profil", "Kepribadian", "Akademis"]:
				assert_false(src.contains('[node name="%s" type="Label" parent="KertasMurid%d"' % [label_name, i]),
					"%s must not declare KertasMurid%d/%s" % [scene_path, i, label_name])


## Every card carries the "Sifat Pasif:" heading above its two trait
## pills, so the pills don't float unlabelled the way they used to.
func test_every_card_has_the_sifat_pasif_heading() -> void:
	for scene_path in _SCENES:
		var src := FileAccess.get_file_as_string(scene_path)
		for i in range(1, 7):
			assert_true(src.contains('[node name="SifatPasifLabel" type="Label" parent="KertasMurid%d"' % i),
				"%s missing KertasMurid%d/SifatPasifLabel" % [scene_path, i])


## The info badge wears icon_info.png's own colour. Tinting it via modulate
## multiplies against the art instead of replacing it, so the amber glyph
## goes muddy rather than changing hue. Matching the mockup's green badge
## needs a different asset, not a tint.
func test_info_badge_draws_its_asset_untinted() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/StudentCardView.gd")
	assert_false(src.contains("badge.modulate"),
		"the info badge must draw icon_info.png untinted")


func test_trait_buttons_use_the_trait_pill_variation() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/StudentCardView.gd")
	assert_true(src.contains('&"TraitPill"'),
		"trait buttons must wear the TraitPill variation")
	assert_false(src.contains('"QUIRK: "'),
		"the QUIRK: prefix is dropped in the redesign")
	assert_false(src.contains('"PERSONA: "'),
		"the PERSONA: prefix is dropped in the redesign")


## Renaming a quirk detaches its gameplay effect -- StudentData.gd branches
## on the exact string -- so the redesign changes only how they are shown.
func test_trait_values_are_unchanged() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/student_card.gd")
	for quirk in ["Kutu Buku", "Semangat Juang", "Penasaran",
			"Penyendiri", "Biang Onar", "Pekerja Keras"]:
		assert_true(src.contains('"quirk": "%s"' % quirk),
			"quirk must keep its gameplay name: " + quirk)


## Card 1's trait pills on ReportCard were hand-edited out of alignment --
## ~240px high and 33px taller than the shape every other card uses. Card 1
## is the page both screens open on, so the drift was the first thing seen.
## Checked across all six cards so it cannot recur, per scene.
##
## The two scenes used to carry DIFFERENT pinned geometry, because the
## pills were moved on student_card.tscn alone to clear its Approve button
## while report_card.tscn kept the original. Shortening the painted paper
## (its bottom edge is now y=1559, down from 1716) ended that: on BOTH
## scenes the lower pill spilled past the paper's edge -- report_card's
## worst, at 1530-1629, seventy pixels of pill on bare desk. The pills are
## now one shared rect on both scenes, so there is a single geometry to
## reason about and the divergence cannot silently return.
##
## The band they live in was made by moving the three Akademis bars up 50px
## (they sit on blank paper -- nothing is painted under them), which frees
## room for SifatPasifLabel at 1318-1370 and the two 70px pills at
## 1378-1448 and 1456-1526, closing 33px clear of the paper's edge.
## Anchors are now 0 with absolute offsets: the old fractional anchors
## (0.7474, 0.786, 0.848) made every move a division and hid what row the
## pill actually landed on.
##
## Compared with a tolerance, not assert_eq: the scene stores float32, so
## an exact match against a float64 literal is not safe. Same absf() idiom
## the other suites use, since McpTestSuite has no assert_almost_eq.
const _TRAIT_PILL_GEOMETRY := {
	"KutuBuku": {
		"anchor_top": 0.0, "anchor_bottom": 0.0,
		"offset_left": -421.0, "offset_right": 421.0,
		"offset_top": 1378.0, "offset_bottom": 1448.0,
	},
	"KutuBuku2": {
		"anchor_top": 0.0, "anchor_bottom": 0.0,
		"offset_left": -421.0, "offset_right": 421.0,
		"offset_top": 1456.0, "offset_bottom": 1526.0,
	},
}

## The painted paper's bottom edge, measured off card_bg.png. Everything in
## the card's lower stack has to close above it.
const _PAPER_BOTTOM := 1559.0


func test_every_trait_pill_shares_one_geometry() -> void:
	for scene_path in _SCENES:
		var scene := load(scene_path) as PackedScene
		assert_true(scene != null, "%s failed to load" % scene_path)
		var inst := scene.instantiate()
		for i in range(1, 7):
			for pill_name in ["KutuBuku", "KutuBuku2"]:
				var pill := inst.get_node_or_null(
					"KertasMurid%d/%s" % [i, pill_name]) as Control
				assert_true(pill != null, "%s KertasMurid%d/%s missing"
					% [scene_path, i, pill_name])
				var want: Dictionary = _TRAIT_PILL_GEOMETRY[pill_name]
				for prop in want:
					assert_true(absf(pill.get(prop) - want[prop]) <= 0.01,
						"%s card %d %s.%s is %f, expected %f"
							% [scene_path, i, pill_name, prop,
								pill.get(prop), want[prop]])
		inst.free()


## The pills spent three passes chasing the Aprove button around by
## nudging fractional anchors (0.786/0.848, then 0.70/0.755, then
## 0.7474/0.7865) and each pass fixed one overlap while opening another,
## because a fraction of the card's height tells you nothing about which
## row the pill lands on. Then the paper itself was shortened and the
## lower pill spilled off its bottom edge -- the failure a pinned anchor
## string structurally cannot see.
##
## So this checks the thing the user actually reported: every element of
## the card's lower stack resolves to a rect that CLOSES ABOVE the painted
## paper's bottom edge. It is scene-agnostic and survives the pills being
## moved again, which the anchor-string scan it replaces did not.
func test_the_lower_card_stack_stays_on_the_paper() -> void:
	for scene_path in _SCENES:
		var scene := load(scene_path) as PackedScene
		var inst := scene.instantiate()
		Engine.get_main_loop().root.add_child(inst)
		track(inst)
		inst.size = Vector2(1080, 1920)
		for i in range(1, 7):
			var card := inst.get_node("KertasMurid%d" % i) as Control
			for child_name in ["Akademis3", "SifatPasifLabel", "KutuBuku", "KutuBuku2"]:
				var node := card.get_node_or_null(child_name) as Control
				assert_true(node != null,
					"%s KertasMurid%d/%s missing" % [scene_path, i, child_name])
				assert_true(node.get_rect().end.y <= _PAPER_BOTTOM,
					"%s card %d: %s ends at y=%f, past the paper's edge at %f"
						% [scene_path, i, child_name, node.get_rect().end.y,
							_PAPER_BOTTOM])


## The first pass above only pinned anchor VALUES, which is exactly how it
## missed the SifatPasifLabel overlap: two literal-correct numbers can
## still resolve to overlapping screen rects. This instantiates every
## card and checks the pills' ACTUAL resolved Rect2 against their
## neighbors -- the check the source-text scan structurally cannot do.
func test_trait_pills_do_not_overlap_neighbors() -> void:
	var scene := load("res://Scenes/StudentCard/student_card.tscn") as PackedScene
	var inst := scene.instantiate()
	Engine.get_main_loop().root.add_child(inst)
	track(inst)
	inst.size = Vector2(1080, 1920)
	# In reading order down the card. Checked pairwise rather than only
	# against the pills, because the pass that moved the pills left
	# SifatPasifLabel (1330-1395) sitting 25px inside Akademis3's bar
	# (1287-1355) -- an overlap between two nodes neither of which was a
	# pill, which is exactly why the old three-way check missed it.
	#
	# The five stat bars are compared at their RUNTIME rects, not their
	# authored ones. StudentCardView.build_stat_bars rewrites all four
	# offsets from PILL_RECTS on every populate(), so whatever the .tscn
	# says about a bar's position is dead the moment the card is shown --
	# a pass that "made room" by moving the bars in the scene changed
	# nothing on screen. Reading PILL_RECTS here keeps the test measuring
	# the layout the player sees.
	var stack := ["Kepribadian1", "Kepribadian2", "Akademis1", "Akademis2",
		"Akademis3", "SifatPasifLabel", "KutuBuku", "KutuBuku2", "Aprove"]
	for i in range(1, 7):
		var card := inst.get_node("KertasMurid%d" % i)
		for a in range(stack.size()):
			for b in range(a + 1, stack.size()):
				var first := _resolved_rect(card, stack[a])
				var second := _resolved_rect(card, stack[b])
				assert_false(first.intersects(second),
					"card %d: %s overlaps %s (%s vs %s)"
						% [i, stack[a], stack[b], first, second])


## A node's rect as it will actually be drawn: PILL_RECTS for the stat
## bars the view repositions at runtime, the authored rect for everything
## else.
func _resolved_rect(card: Node, child_name: String) -> Rect2:
	if StudentCardView.PILL_RECTS.has(child_name):
		return StudentCardView.PILL_RECTS[child_name]
	return (card.get_node("%s" % child_name) as Control).get_rect()


## PageLabel is NOT empty -- student_card.gd:717 sets its text every page turn
## ("page_label.text = str(index + 1) + "/" + str(kertas_murid.size())"), so
## it renders "1/6" etc. at runtime. It genuinely overlapped the Persona
## trait pill on screen. That overlap was previously missed because
## PageLabel is a child of the scene ROOT while the KertasMurid cards sit at
## a -70,-254 offset within that root -- comparing PageLabel's root-space
## offsets against the cards' card-local offsets made the overlap vanish on
## paper while it was plainly visible on screen. Do not repeat that
## comparison; always use global rects when checking this label against
## card content.
##
## PageLabel now sits centred between the two page arrows (root offsets
## x 20-140 and x 800-920, y 1516-1636). This instantiates the scene and
## checks the label's resolved global rect against the trait pill it used
## to clip, in both student_card.tscn and report_card.tscn.
func test_page_label_sits_between_the_arrows() -> void:
	for scene_path in [
		"res://Scenes/StudentCard/student_card.tscn",
		"res://Scenes/ReportCard/report_card.tscn",
	]:
		var scene := load(scene_path) as PackedScene
		var inst := scene.instantiate()
		Engine.get_main_loop().root.add_child(inst)
		track(inst)
		inst.size = Vector2(1080, 1920)
		var page_label := inst.get_node("PageLabel") as Control
		var card := inst.get_node("KertasMurid1") as Control
		var kutu2 := card.get_node("KutuBuku2") as Control
		assert_false(page_label.get_global_rect().intersects(kutu2.get_global_rect()),
			"%s: PageLabel overlaps KutuBuku2 (%s vs %s)"
				% [scene_path, page_label.get_global_rect(), kutu2.get_global_rect()])


## Both of the card's top boxes are painted into card_bg.png -- the identity
## panel on the left, the portrait frame on the right -- and only the
## portrait carries a node, the TextureRect that draws the student's photo
## into it. Two faults were reported together and they share a cause:
##
## 1. The two boxes closed on different rows (the portrait's border ended
##    at y=660, the identity panel's at y=669), so a pair meant to read as
##    a matched set was 9px out. The art now ends both at 669, and the
##    TextureRect follows the repaint to offset_bottom 665, its interior.
## 2. The TextureRect used STRETCH_KEEP_ASPECT_CENTERED, so a portrait
##    whose aspect did not match the frame letterboxed inside it and let
##    the frame's painted interior show through around the photo -- read
##    on screen as the portrait "not fully sized with the box". It is now
##    STRETCH_KEEP_ASPECT_COVERED (6), which fills the frame and clips.
##
## Pinned as resolved geometry rather than as .tscn text so it holds for
## every card on both scenes at once.
func test_the_portrait_fills_a_frame_matched_to_the_identity_panel() -> void:
	# The identity panel's painted interior, measured off card_bg.png.
	var panel_bottom := 666.0
	for scene_path in _SCENES:
		var scene := load(scene_path) as PackedScene
		var inst := scene.instantiate()
		Engine.get_main_loop().root.add_child(inst)
		track(inst)
		inst.size = Vector2(1080, 1920)
		for i in range(1, 7):
			var portrait := inst.get_node_or_null(
				"KertasMurid%d/TextureRect" % i) as TextureRect
			assert_true(portrait != null,
				"%s KertasMurid%d/TextureRect missing" % [scene_path, i])
			assert_eq(portrait.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
				"%s card %d: the portrait must COVER its frame, not letterbox in it"
					% [scene_path, i])
			assert_true(absf(portrait.get_rect().end.y - 665.0) <= 1.0,
				"%s card %d: the portrait ends at y=%f, not the repainted frame's 665"
					% [scene_path, i, portrait.get_rect().end.y])
			assert_true(absf(portrait.get_rect().end.y - panel_bottom) <= 2.0,
				"%s card %d: the portrait box (ends %f) and the identity panel "
					% [scene_path, i, portrait.get_rect().end.y]
					+ "(ends %f) must close on the same row" % panel_bottom)
