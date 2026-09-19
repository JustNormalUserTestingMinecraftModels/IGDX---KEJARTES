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


# ----- Bubble -----

const _BUBBLE_SCENE := "res://Scenes/Lobby/StudentChatBubble.tscn"


func _make_bubble() -> StudentChatBubble:
	var b := (load(_BUBBLE_SCENE) as PackedScene).instantiate() as StudentChatBubble
	b.theme = load(_THEME_PATH)
	Engine.get_main_loop().root.add_child(b)
	return b


func test_flip_rule_is_left_half_of_screen() -> void:
	assert_true(StudentChatBubble.flip_for(200.0, 1080.0))
	assert_false(StudentChatBubble.flip_for(800.0, 1080.0))


func test_tip_mirrors_with_flip() -> void:
	var b := _make_bubble()
	assert_eq(b.tip_local(false), Vector2(532, 274))
	assert_eq(b.tip_local(true), Vector2(28, 274))
	b.queue_free()


func test_placement_puts_tip_on_anchor_when_room() -> void:
	var p := StudentChatBubble.placement(Vector2(700, 400), Vector2(532, 274), Vector2(560, 274), Rect2(0, 0, 1080, 1920), 24.0)
	assert_eq(p, Vector2(168, 126))


func test_placement_clamps_inside_bounds() -> void:
	var bounds := Rect2(0, 0, 1080, 1920)
	var top := StudentChatBubble.placement(Vector2(700, 100), Vector2(532, 274), Vector2(560, 274), bounds, 24.0)
	assert_eq(top.y, 24.0, "clamped below the top margin")
	var left := StudentChatBubble.placement(Vector2(300, 400), Vector2(532, 274), Vector2(560, 274), bounds, 24.0)
	assert_eq(left.x, 24.0, "clamped right of the left margin")


func test_show_line_flips_tail_and_sets_pivot_and_text() -> void:
	var b := _make_bubble()
	b.show_line("Halo, Pak!", Vector2(300, 600), true)
	var tail := b.get_node("Tail") as TextureRect
	assert_true(tail.flip_h)
	assert_eq(tail.position.x, 28.0)
	assert_eq(b.pivot_offset, b.tip_local(true))
	assert_eq(b.get_text(), "Halo, Pak!")
	assert_eq(b.get_state(), StudentChatBubble.State.SHOWING)
	assert_true(b.is_busy())
	b.show_line("Halo, Pak!", Vector2(800, 600), false)
	assert_false(tail.flip_h)
	assert_eq(tail.position.x, 488.0)
	b.queue_free()


func test_dismiss_starts_hiding() -> void:
	var b := _make_bubble()
	b.show_line("Halo, Pak!", Vector2(300, 600), true)
	b.dismiss()
	assert_eq(b.get_state(), StudentChatBubble.State.HIDING)
	assert_true(b.is_busy())
	b.queue_free()


func test_fresh_bubble_is_idle_and_hidden() -> void:
	var b := _make_bubble()
	assert_eq(b.get_state(), StudentChatBubble.State.IDLE)
	assert_false(b.is_busy())
	assert_eq(b.modulate.a, 0.0)
	b.queue_free()


func test_every_line_fits_three_lines_of_the_bubble() -> void:
	var tokens := load(_TOKENS_PATH) as DesignTokens
	var font: Font = tokens.font_body_bold
	var size := tokens.font_title
	var width := float(StudentChatBubble.BODY_SIZE.x - 2 * tokens.space_md)
	var limit := font.get_height(size) * 3.0 + 1.0
	for line in _all_lines():
		var h := font.get_multiline_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, width, size).y
		assert_true(h <= limit, "wraps past 3 lines: %s" % line)




# ----- LobbyChatter -----

func _make_seat(x: float, who: String) -> Dictionary:
	var hit := Control.new()
	hit.position = Vector2(x, 400)
	hit.size = Vector2(300, 300)
	var anchor := Control.new()
	anchor.position = Vector2(x + 150, 500)
	return {"student": {"name": who, "personality": "Tekun", "quirk": "Kutu Buku",
		"kepribadian1": 50, "kepribadian2": 50}, "hit": hit, "anchor": anchor}


func _make_chatter(seat_count: int = 2) -> LobbyChatter:
	var root := Control.new()
	root.size = Vector2(1080, 1920)
	Engine.get_main_loop().root.add_child(root)
	var c := LobbyChatter.new()
	c.bubble = _make_bubble()
	c.bubble.reparent(root)
	root.add_child(c)
	var seats: Array = []
	for i in range(seat_count):
		var s := _make_seat(100.0 + 520.0 * i, "S%d" % i)
		root.add_child(s.hit)
		root.add_child(s.anchor)
		seats.append(s)
	c.set_seats(seats)
	return c


func _free_chatter(c: LobbyChatter) -> void:
	c.get_parent().queue_free()


func test_tap_speaks_then_spam_is_refused() -> void:
	var c := _make_chatter()
	assert_true(c.request_line(0), "first tap speaks")
	var shown := c.bubble.get_text()
	for i in range(10):
		assert_false(c.request_line(1), "spam while busy is refused")
	assert_eq(c.bubble.get_text(), shown, "the line on screen is untouched")
	_free_chatter(c)


func test_cooldown_after_bubble_finishes() -> void:
	var c := _make_chatter()
	c._on_bubble_finished()
	assert_false(c.request_line(0), "within tap_cooldown_s of the last line")
	c._idle_since_ms = Time.get_ticks_msec() - int(c.tap_cooldown_s * 1000.0) - 1
	assert_true(c.request_line(0))
	_free_chatter(c)


func test_gate_blocks_everything() -> void:
	var c := _make_chatter()
	c.can_speak = func() -> bool: return false
	assert_false(c.request_line(0))
	assert_false(c.speak_idle())
	assert_false(c.bubble.is_busy())
	_free_chatter(c)


func test_idle_delay_is_twenty_to_fifty_seconds() -> void:
	var c := LobbyChatter.new()
	assert_eq(c.idle_min_s, 20.0)
	assert_eq(c.idle_max_s, 50.0)
	for i in range(50):
		var d := c.next_idle_delay()
		assert_true(d >= 20.0 and d <= 50.0, "delay %f" % d)
	c.free()


func test_idle_speaker_differs_from_previous() -> void:
	var c := _make_chatter(2)
	for i in range(8):
		var before := c.get_last_speaker()
		c.bubble._kill_tween()
		c.bubble._set_state(StudentChatBubble.State.IDLE)
		c._idle_since_ms = -100000
		assert_true(c.speak_idle())
		assert_ne(c.get_last_speaker(), before)
	_free_chatter(c)


func test_seat_at_finds_the_tapped_face() -> void:
	var c := _make_chatter(2)
	assert_eq(c.seat_at(Vector2(200, 500)), 0)
	assert_eq(c.seat_at(Vector2(750, 500)), 1)
	assert_eq(c.seat_at(Vector2(540, 50)), -1)
	_free_chatter(c)


func test_no_seats_no_chatter() -> void:
	var c := _make_chatter(0)
	assert_false(c.speak_idle())
	assert_false(c.request_line(0))
	_free_chatter(c)
