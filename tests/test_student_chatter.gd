@tool
extends McpTestSuite

## Student chatter in the Lobby (2026-09-19 spec): the line catalog and its
## shuffle-bag picker, the StudentChatBubble's placement/flip/FSM, the
## LobbyChatter's spam guard, idle timer and gate, and loby.tscn's wiring.
## @tool, and no test here is a coroutine: tweens are started but never
## awaited, so only synchronous state (text, position, pivot, busy) is read.

const _THEME_PATH := "res://Assets/Theme/kejartes_theme.tres"
const _TOKENS_PATH := "res://Assets/Theme/design_tokens.tres"


func suite_name() -> String:
	return "student_chatter"


# ----- Theme -----

## The bake on disk, bypassing the resource cache: a rebake earlier in the
## same editor session would otherwise be invisible to load().
func _baked_theme() -> Theme:
	return ResourceLoader.load(_THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme


func test_bubble_variation_is_a_card_panel() -> void:
	var theme := _baked_theme()
	var tokens := load(_TOKENS_PATH) as DesignTokens
	assert_eq(theme.get_type_variation_base("StudentChatBubble"), &"PanelContainer")
	var box := theme.get_stylebox("panel", "StudentChatBubble") as StyleBoxFlat
	assert_true(box != null, "StudentChatBubble has a flat panel")
	if box:
		assert_eq(box.bg_color, tokens.surface_card)


func test_text_variation_is_bold_body_title_size() -> void:
	var theme := _baked_theme()
	var tokens := load(_TOKENS_PATH) as DesignTokens
	assert_eq(theme.get_type_variation_base("StudentChatText"), &"Label")
	assert_eq(theme.get_font("font", "StudentChatText"), tokens.font_body_bold)
	assert_eq(theme.get_font_size("font_size", "StudentChatText"), tokens.font_title)
	assert_eq(theme.get_color("font_color", "StudentChatText"), tokens.text_primary)


# ----- Catalog -----

const _PERSONALITIES := ["Aktif", "Tekun", "Kreatif", "Santai", "Seni Dalam Kesunyian"]
const _QUIRKS := ["Kutu Buku", "Penyendiri", "Semangat Juang", "Penasaran", "Biang Onar", "Pekerja Keras"]


func _all_lines() -> Array:
	var out: Array = []
	for pool in StudentChatterCatalog.PERSONALITY_LINES.values():
		out.append_array(pool)
	for pool in StudentChatterCatalog.QUIRK_LINES.values():
		out.append_array(pool)
	for pool in StudentChatterCatalog.STATE_LINES.values():
		out.append_array(pool)
	out.append_array(StudentChatterCatalog.GENERIC_LINES)
	return out


func test_every_trait_has_eight_lines() -> void:
	for p in _PERSONALITIES:
		assert_true(StudentChatterCatalog.PERSONALITY_LINES.get(p, []).size() >= 8, "personality %s" % p)
	for q in _QUIRKS:
		assert_true(StudentChatterCatalog.QUIRK_LINES.get(q, []).size() >= 8, "quirk %s" % q)
	for s in [&"LELAH", &"BETE", &"SENANG"]:
		assert_true(StudentChatterCatalog.STATE_LINES.get(s, []).size() >= 6, "state %s" % s)
	assert_true(StudentChatterCatalog.GENERIC_LINES.size() >= 6)


func test_every_line_is_short_and_emoji_free() -> void:
	for line in _all_lines():
		var s := str(line)
		assert_true(s.strip_edges() != "", "empty line")
		assert_true(s.length() <= StudentChatterCatalog.MAX_LINE_CHARS, "too long (%d): %s" % [s.length(), s])
		for i in range(s.length()):
			var c := s.unicode_at(i)
			assert_false(c >= 0x1F000 or (c >= 0x2600 and c <= 0x27BF), "emoji in: %s" % s)


func test_personality_falls_back_to_persona() -> void:
	assert_eq(StudentChatterCatalog.personality_of({"personality": "Tekun"}), "Tekun")
	assert_eq(StudentChatterCatalog.personality_of({"persona": "Persona Aktif"}), "Aktif")
	assert_eq(StudentChatterCatalog.personality_of({"persona": "Persona Pendiam"}), "Seni Dalam Kesunyian")
	assert_eq(StudentChatterCatalog.personality_of({}), "")


func test_state_thresholds_and_energy_wins() -> void:
	# kepribadian1 = mood, kepribadian2 = energy
	assert_eq(StudentChatterCatalog.state_for({"kepribadian1": 50, "kepribadian2": 50}), &"")
	assert_eq(StudentChatterCatalog.state_for({"kepribadian1": 50, "kepribadian2": 30}), &"LELAH")
	assert_eq(StudentChatterCatalog.state_for({"kepribadian1": 30, "kepribadian2": 50}), &"BETE")
	assert_eq(StudentChatterCatalog.state_for({"kepribadian1": 75, "kepribadian2": 50}), &"SENANG")
	assert_eq(StudentChatterCatalog.state_for({"kepribadian1": 10, "kepribadian2": 10}), &"LELAH")
	assert_eq(StudentChatterCatalog.state_for({}), &"")


func test_trait_pool_mixes_personality_and_quirk() -> void:
	var s := {"personality": "Kreatif", "quirk": "Penasaran"}
	var pool := StudentChatterCatalog.trait_pool(s)
	assert_eq(pool.size(), StudentChatterCatalog.PERSONALITY_LINES["Kreatif"].size() + StudentChatterCatalog.QUIRK_LINES["Penasaran"].size())
	assert_eq(StudentChatterCatalog.trait_pool({}), StudentChatterCatalog.GENERIC_LINES)


# ----- Picker -----

func test_bag_cycles_without_repeats() -> void:
	var picker := StudentChatterPicker.new()
	picker.rng.seed = 7
	var pool := ["a", "b", "c", "d", "e"]
	var seen := {}
	for i in range(pool.size()):
		seen[picker.draw("k", pool)] = true
	assert_eq(seen.size(), pool.size(), "a full bag says every line once")


func test_bag_boundary_never_repeats() -> void:
	var picker := StudentChatterPicker.new()
	var pool := ["a", "b", "c"]
	for seed in range(40):
		picker.rng.seed = seed
		var last := ""
		for i in range(12):
			var line := picker.draw("k%d" % seed, pool)
			assert_ne(line, last, "same line twice in a row (seed %d)" % seed)
			last = line


func test_pick_uses_state_pool_sometimes_and_trait_pool_otherwise() -> void:
	var picker := StudentChatterPicker.new()
	picker.rng.seed = 3
	var tired := {"name": "X", "personality": "Tekun", "quirk": "Kutu Buku", "kepribadian1": 50, "kepribadian2": 5}
	var state_hits := 0
	for i in range(100):
		if picker.pick(tired) in StudentChatterCatalog.STATE_LINES[&"LELAH"]:
			state_hits += 1
	assert_true(state_hits > 20 and state_hits < 60, "about 40%% state lines, got %d" % state_hits)
	var fine := {"name": "Y", "personality": "Tekun", "quirk": "Kutu Buku", "kepribadian1": 50, "kepribadian2": 50}
	var pool := StudentChatterCatalog.trait_pool(fine)
	for i in range(20):
		assert_true(picker.pick(fine) in pool)
