@tool
extends McpTestSuite

## The Amplop Coklat level select (spec:
## docs/superpowers/specs/2026-09-25-amplop-level-select-design.md): a fan
## of three brown envelopes, one per grade, a briefing card for the centred
## one, and an open-envelope confirmation that sets the grade and wipes into
## the intro cutscene.
##
## Must be @tool, and no test here may be a coroutine.

const LS := preload("res://Scripts/LevelSelect/level_select.gd")
const STUDENT_CARD := preload("res://Scripts/StudentCard/student_card.gd")

const _SCRIPT_PATH := "res://Scripts/LevelSelect/level_select.gd"


func suite_name() -> String:
	return "level_select"


# ── Data ─────────────────────────────────────────────────────────────────────

## Weeks and target must be read from Balance.gd, never hardcoded literals.
func test_weeks_and_target_come_from_balance() -> void:
	assert_eq(LS.weeks_for(7), Balance.JUMLAH_MINGGU_KELAS_7, "wk7")
	assert_eq(LS.weeks_for(8), Balance.JUMLAH_MINGGU_KELAS_8, "wk8")
	assert_eq(LS.weeks_for(9), Balance.JUMLAH_MINGGU_KELAS_9, "wk9")
	assert_eq(LS.target_for(7), int(Balance.TARGET_KENAIKAN_KELAS_7), "t7")
	assert_eq(LS.target_for(8), int(Balance.TARGET_KENAIKAN_KELAS_8), "t8")
	assert_eq(LS.target_for(9), int(Balance.TARGET_KENAIKAN_KELAS_9), "t9")


## Every grade has a difficulty word, a gauge fill, a tag and a brief line.
func test_difficulty_map_covers_all_grades() -> void:
	for g in LS.GRADES:
		assert_true(LS.DIFFICULTY_WORD.has(g), "word for %d" % g)
		assert_true(LS.DIFFICULTY_FILL.has(g), "fill for %d" % g)
		assert_true(LS.TAG_TEXT.has(g), "tag for %d" % g)
		assert_true(LS.BRIEF_FLAVOR.has(g), "brief flavour for %d" % g)
	assert_eq(LS.DIFFICULTY_WORD[7], "santai", "kelas 7 is santai")
	assert_eq(LS.DIFFICULTY_WORD[8], "menantang", "kelas 8 is menantang")
	assert_eq(LS.DIFFICULTY_WORD[9], "susah", "kelas 9 is susah")


## The screen must not re-type balance numbers as literals.
func test_source_reads_balance_constants() -> void:
	var src := FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_true(src.contains("Balance.JUMLAH_MINGGU_KELAS_"), "reads weeks from Balance")
	assert_true(src.contains("Balance.TARGET_KENAIKAN_KELAS_"), "reads target from Balance")


## The pupil count is the roster StudentCard really approves, not a copy.
func test_roster_size_is_student_cards_own_count() -> void:
	for g in LS.GRADES:
		assert_eq(LS.roster_size_for(g), STUDENT_CARD.max_approve_for(g),
			"kelas %d roster matches StudentCard" % g)
	assert_eq([LS.roster_size_for(7), LS.roster_size_for(8), LS.roster_size_for(9)],
		[2, 3, 4], "2/3/4 pupils by grade")
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/student_card.gd")
	assert_true(src.contains("MAX_APPROVE = max_approve_for("),
		"StudentCard reads its own count from the shared function")


# ── AmplopCard ───────────────────────────────────────────────────────────────

const CARD := preload("res://Scripts/LevelSelect/AmplopCard.gd")
const _CARD_SCENE := "res://Scenes/LevelSelect/AmplopCard.tscn"


## A card stood up under the editor root, freed after the test.
func _card() -> Control:
	var card := (load(_CARD_SCENE) as PackedScene).instantiate() as Control
	Engine.get_main_loop().root.add_child(card)
	track(card)
	return card


## Data-drive knobs live on the CARD ROOT as @exports (child overrides drop on save).
func test_amplop_card_exposes_root_exports() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/LevelSelect/AmplopCard.gd")
	for prop in ["grade", "tab_text", "envelope_texture", "flap_texture",
			"seal_texture", "interactive"]:
		assert_true(src.contains("@export var %s" % prop), "exports %s" % prop)
	assert_true(src.contains("signal picked"), "has picked signal")


## The card scene instances cleanly, carries its script and draws the
## envelope art from Assets/Images/LevelSelect.
func test_amplop_card_scene_instantiates() -> void:
	var card := _card()
	assert_true(card.get_script() == CARD, "carries AmplopCard.gd")
	for n in ["Bob/Body", "Bob/Flap", "Bob/Seal", "Bob/Tab", "Bob/Pupils", "HitButton"]:
		assert_true(card.get_node_or_null(n) != null, "has " + n)
	var body := card.get_node("Bob/Body") as TextureRect
	assert_true(body.texture != null
		and body.texture.resource_path.begins_with("res://Assets/Images/LevelSelect/"),
		"the body wears the level-select envelope art")


## The tab shows tab_text, and the pupils stay hidden until the envelope opens.
func test_amplop_card_applies_its_exports() -> void:
	var card := _card()
	card.tab_text = "Kelas 9"
	assert_eq((card.get_node("Bob/Tab") as Button).text, "Kelas 9", "tab text applied")
	assert_false((card.get_node("Bob/Pupils") as Control).visible,
		"pupils hide until open()")
	card.interactive = false
	assert_eq((card.get_node("HitButton") as Control).mouse_filter,
		Control.MOUSE_FILTER_IGNORE, "a non-interactive card ignores taps")


## open() shows exactly `portraits.size()` pupils and reseal() hides them again.
func test_amplop_card_open_shows_the_roster_and_reseals() -> void:
	var card := _card()
	var tex := load("res://Assets/Images/MuridPotrait/Andi.png") as Texture2D
	var tw: Tween = card.open([tex, tex, tex])
	tw.kill()
	var pupils := card.get_node("Bob/Pupils") as Control
	assert_true(pupils.visible, "open() shows the pupils")
	var shown := 0
	for p in pupils.get_children():
		if (p as Control).visible:
			shown += 1
	assert_eq(shown, 3, "three pupils for a three-pupil roster")
	card.reseal()
	assert_false(pupils.visible, "reseal() hides them")
	assert_eq((card.get_node("Bob/Seal") as Control).scale, Vector2.ONE, "the seal is back")
	assert_eq((card.get_node("Bob/Flap") as Control).scale, Vector2.ONE, "the flap is closed")
