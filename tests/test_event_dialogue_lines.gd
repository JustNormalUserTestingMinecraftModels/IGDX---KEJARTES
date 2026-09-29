@tool
extends McpTestSuite

## Every EventDialogueLines pool (2026-09-29 dialogue-variations spec): who
## has one, how many lines it holds, the language rules each line keeps, and
## that a win line fits two lines of the win bubble.
##
## Must be @tool, and no test here may be a coroutine.

const _THEME := "res://Assets/Theme/kejartes_theme.tres"
const _WIN_SCREEN := "res://Scenes/Minigames/UI/MinigameWinScreen.tscn"
const _STUDENTS := ["Marcel", "Doni", "Andi", "Citra", "Shinta", "Thea"]
const _STUDENT_EVENTS := ["les_akademis", "Badminton", "Menjodohkan", "Variabel",
	"PilihanGanda", "Password", "BuatBatik", "LombaMenari"]
const _NPC_EVENTS := ["nasi_kotak", "hujan", "latihan_olahraga", "workshop_seni", "MainBola"]
const _CATEGORIES := ["Akademis", "SeniBudaya", "Olahraga"]
const _MIN_LINES := 5
## Chat spellings and loanwords KBBI does not list (spec, "Language rules").
const _BANNED := ["nggak", "gak", "ga", "udah", "dah", "aja", "pengen", "makasih",
	"gimana", "workshop", "ngerjain", "nyelesaiin", "bikinin", "asik", "gue", "lu"]


func suite_name() -> String:
	return "event_dialogue_lines"


func _assert_pool(pool: Variant, what: String) -> void:
	assert_true(pool is Array, what + " has a pool")
	if not pool is Array:
		return
	assert_true((pool as Array).size() >= _MIN_LINES, "%s has %d lines, needs %d" % [what, pool.size(), _MIN_LINES])
	var seen := {}
	for line in pool:
		assert_false(seen.has(line), what + " repeats: " + str(line))
		seen[line] = true


## [what, line, is_student, is_win] for every line in every pool.
func _every_line() -> Array:
	var out: Array = []
	for key in EventDialogueLines.STUDENT_LINES:
		for who in EventDialogueLines.STUDENT_LINES[key]:
			for l in EventDialogueLines.STUDENT_LINES[key][who]:
				out.append(["%s/%s" % [key, who], str(l), true, false])
	for key in EventDialogueLines.NPC_LINES:
		for l in EventDialogueLines.NPC_LINES[key]:
			out.append([key, str(l), false, false])
	for who in EventDialogueLines.WIN_STUDENT_LINES:
		for cat in EventDialogueLines.WIN_STUDENT_LINES[who]:
			for l in EventDialogueLines.WIN_STUDENT_LINES[who][cat]:
				out.append(["win/%s/%s" % [who, cat], str(l), true, true])
	for cat in EventDialogueLines.WIN_TEACHER_LINES:
		for l in EventDialogueLines.WIN_TEACHER_LINES[cat]:
			out.append(["win/guru/" + cat, str(l), false, true])
	return out


# ── coverage ─────────────────────────────────────────────────────────────────

func test_every_student_has_a_pool_for_every_event() -> void:
	for key in _STUDENT_EVENTS:
		for who in _STUDENTS:
			_assert_pool(EventDialogueLines.STUDENT_LINES.get(key, {}).get(who), "%s/%s" % [key, who])


func test_every_npc_event_and_the_narrator_have_a_pool() -> void:
	for key in _NPC_EVENTS:
		_assert_pool(EventDialogueLines.NPC_LINES.get(key), key)


func test_every_student_has_a_win_pool_per_category() -> void:
	for who in _STUDENTS:
		for cat in _CATEGORIES:
			_assert_pool(EventDialogueLines.WIN_STUDENT_LINES.get(who, {}).get(cat), "win/%s/%s" % [who, cat])


func test_both_teachers_have_a_win_pool() -> void:
	for cat in ["Olahraga", "SeniBudaya"]:
		_assert_pool(EventDialogueLines.WIN_TEACHER_LINES.get(cat), "win/guru/" + cat)


func test_pools_only_name_real_events() -> void:
	for key in EventDialogueLines.STUDENT_LINES:
		assert_eq(EventDialogueCatalog.entry(key).get("speaker", ""), EventDialogueCatalog.SPEAKER_STUDENT, key)
	for key in EventDialogueLines.NPC_LINES:
		assert_true(EventDialogueCatalog.has_entry(key), key)
		assert_ne(EventDialogueCatalog.entry(key).get("speaker", ""), EventDialogueCatalog.SPEAKER_STUDENT, key)


# ── language ─────────────────────────────────────────────────────────────────

func test_every_line_is_plain_ascii() -> void:
	for row in _every_line():
		var line: String = row[1]
		var clean := true
		for i in line.length():
			if line.unicode_at(i) > 0x7E:
				clean = false
				break
		assert_true(clean, "%s: non-ASCII in %s" % [row[0], line])


func test_no_line_uses_a_banned_form() -> void:
	var rx := RegEx.create_from_string("(?i)\\b(" + "|".join(_BANNED) + ")\\b")
	for row in _every_line():
		var hit := rx.search(row[1])
		assert_true(hit == null, "%s: '%s' in %s" % [row[0], hit.get_string() if hit else "", row[1]])


func test_students_never_name_themselves_and_mom_always_names_the_child() -> void:
	for row in _every_line():
		if row[2]:
			assert_false(str(row[1]).contains("{nama}"), "%s: %s" % [row[0], row[1]])
	for l in EventDialogueLines.NPC_LINES.get("nasi_kotak", []):
		assert_true(str(l).contains("{nama}"), "nasi_kotak: " + str(l))


func test_every_choice_line_asks() -> void:
	for key in EventDialogueCatalog.ENTRIES:
		if EventDialogueCatalog.entry(key)["mode"] != EventDialogueCatalog.MODE_CHOICE:
			continue
		var pools: Array = [EventDialogueLines.NPC_LINES.get(key, [])]
		pools.append_array(EventDialogueLines.STUDENT_LINES.get(key, {}).values())
		for pool in pools:
			for l in pool:
				assert_true(str(l).ends_with("?"), "%s: %s" % [key, l])


# ── fit ──────────────────────────────────────────────────────────────────────

func test_event_lines_fit_the_box() -> void:
	for row in _every_line():
		if not row[3]:
			assert_true(str(row[1]).length() <= EventDialogueCatalog.MAX_EVENT_LINE_CHARS,
				"%s is %d chars: %s" % [row[0], str(row[1]).length(), row[1]])


func test_win_lines_wrap_to_two_lines_of_the_bubble() -> void:
	var theme := ResourceLoader.load(_THEME, "Theme", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var font := theme.get_font("font", "MinigameWinLine")
	var size := theme.get_font_size("font_size", "MinigameWinLine")
	var box := theme.get_stylebox("panel", "MinigameWinBubble")
	var screen := (load(_WIN_SCREEN) as PackedScene).instantiate()
	var bubble := screen.get_node("Root/Bubble") as Control
	var width := 1080.0 - bubble.offset_left + bubble.offset_right - box.content_margin_left - box.content_margin_right
	screen.free()
	var limit := font.get_height(size) * 2.0 + 1.0
	for row in _every_line():
		if row[3]:
			var h := font.get_multiline_string_size(str(row[1]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, width, size).y
			assert_true(h <= limit, "%s wraps past 2 lines: %s" % [row[0], row[1]])
