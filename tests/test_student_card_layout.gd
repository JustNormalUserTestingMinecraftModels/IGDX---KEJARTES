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
