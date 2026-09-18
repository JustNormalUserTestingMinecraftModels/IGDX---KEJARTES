@tool
extends McpTestSuiteCompat

## Task 2 of the 2026-09-17 Koperasi polish plan: DialogueCatalog's static
## line pools and pick logic, and ChatBubble's tiny FSM (say/say_for_item/
## say_sticky/clear_sticky) exercised on a bare instance built with a
## minimal Body/Text/Tail tree matching koprasi.tscn's authored nodes.
## Nothing here touches Cart, GameState or needs a scene open. Suite is
## @tool and no test here is a coroutine.

func suite_name() -> String:
	return "koperasi_chat_bubble"


# ----- DialogueCatalog -----

func test_every_pool_is_non_empty() -> void:
	for key in DialogueCatalog.LINES.keys():
		var pool: Array = DialogueCatalog.LINES[key]
		assert_true(pool.size() > 0, "Pool %s is empty" % key)


func test_every_line_fits_the_bubble() -> void:
	for key in DialogueCatalog.LINES.keys():
		for line in DialogueCatalog.LINES[key]:
			assert_true(line.length() <= 60, "Line too long (%d): %s" % [line.length(), line])
	for item_name in DialogueCatalog.ITEM_LINES.keys():
		for line in DialogueCatalog.ITEM_LINES[item_name]:
			assert_true(line.length() <= 60, "Item line too long (%d): %s" % [line.length(), line])


func test_item_lines_reference_real_items() -> void:
	var known := {}
	for item in ItemDatabase.get_all_items():
		known[item.item_name] = true
	for item_name in DialogueCatalog.ITEM_LINES.keys():
		assert_true(known.has(item_name), "ITEM_LINES key %s not in ItemDatabase" % item_name)


func test_anti_repetition_holds_over_ten_picks() -> void:
	var last := ""
	for i in range(10):
		var line := DialogueCatalog.pick(&"IDLE")
		assert_true(line != last, "IDLE returned the same line twice in a row")
		last = line


func test_pick_for_item_anti_repetition_holds_over_ten_picks() -> void:
	# "Bank Soal" has 4 ITEM_LINES entries -- enough room to check the same
	# cheap anti-repetition pick_for_item() applies per item.
	var last := ""
	for i in range(10):
		var line := DialogueCatalog.pick_for_item(&"ADD", "Bank Soal")
		assert_true(line != last, "pick_for_item returned the same line twice in a row")
		last = line


# ----- ChatBubble -----

## A ChatBubble with the same Body/Text/Tail shape as koprasi.tscn's
## authored node, so say() has a real RichTextLabel to write into and
## _ready() can compute a pivot from the Tail's rect.
func _make_bubble() -> ChatBubble:
	var bubble := ChatBubble.new()

	var body := PanelContainer.new()
	body.name = "Body"
	var text := RichTextLabel.new()
	text.name = "Text"
	body.add_child(text)
	bubble.add_child(body)

	var tail := TextureRect.new()
	tail.name = "Tail"
	tail.position = Vector2(751.0, 230.0)
	tail.size = Vector2(65.0, 115.0)
	bubble.add_child(tail)

	return bubble


func _live_bubble() -> ChatBubble:
	var bubble := _make_bubble()
	Engine.get_main_loop().root.add_child(bubble)
	track(bubble)
	return bubble


func test_bubble_starts_idle() -> void:
	var bubble := _live_bubble()
	assert_eq(bubble.get_state(), ChatBubble.State.IDLE)


func test_say_transitions_to_showing_with_a_welcome_line() -> void:
	var bubble := _live_bubble()
	bubble.say(&"WELCOME")
	assert_eq(bubble.get_state(), ChatBubble.State.SHOWING)
	assert_true(DialogueCatalog.LINES[&"WELCOME"].has(bubble._label.text),
		"bubble text should be one of the WELCOME lines, got: %s" % bubble._label.text)


func test_say_for_item_uses_item_lines_when_present() -> void:
	var bubble := _live_bubble()
	bubble.say_for_item(&"ADD", "Komik")
	assert_eq(bubble.get_state(), ChatBubble.State.SHOWING)
	assert_true(DialogueCatalog.ITEM_LINES["Komik"].has(bubble._label.text),
		"bubble text should be one of Komik's ITEM_LINES, got: %s" % bubble._label.text)


func test_sticky_ignores_queued_events() -> void:
	var bubble := _live_bubble()
	bubble.say_sticky("stuck")
	bubble.say(&"WELCOME")
	assert_eq(bubble._label.text, "stuck")
	assert_eq(bubble.get_state(), ChatBubble.State.SHOWING)


func test_clear_sticky_transitions_to_hiding() -> void:
	var bubble := _live_bubble()
	bubble.say_sticky("stuck")
	bubble.clear_sticky()
	assert_eq(bubble.get_state(), ChatBubble.State.HIDING)


func test_bare_instance_without_children_does_not_crash() -> void:
	# No Body/Text/Tail at all -- get_node_or_null() must degrade quietly.
	var bubble := ChatBubble.new()
	Engine.get_main_loop().root.add_child(bubble)
	track(bubble)
	bubble.say(&"WELCOME")
	assert_eq(bubble.get_state(), ChatBubble.State.SHOWING)
