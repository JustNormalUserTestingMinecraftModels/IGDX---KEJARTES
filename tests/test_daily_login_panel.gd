@tool
extends McpTestSuite

## DailyLoginPanel (2026-09-28 daily-login polish): the Lobby's
## daily-login popup as its own component. Pins the streak rules (the day
## after 7 is 1; a missed day breaks the streak), the escalating reward
## curve and the claim's GameState writes (money, date, advanced day; a
## second claim the same day is a no-op), plus a source scan that the
## Lobby no longer owns any of it.
##
## Suite is @tool and no test is a coroutine, per the runner constraints.
## Most tests use a bare DailyLoginPanel.new() that never enters the tree,
## so its @onready % lookups never run: claim() and the static rules touch
## no node. The tests that draw (refresh, the reveal's payout) use a Lobby
## and a reveal the suite instances into the editor root once; only their
## gated _readys run there, and nothing touches the edited scene.

const _LOBBY_SCENE := "res://Scenes/Lobby/Lobby.tscn"
const _LOBBY_SCRIPT := "res://Scripts/Lobby/Lobby.gd"
const _PANEL_SCRIPT := "res://Scripts/Lobby/DailyLoginPanel.gd"
const _REVEAL_SCENE := "res://Scenes/Lobby/DailyRewardReveal.tscn"
const _REVEAL_SCRIPT := "res://Scripts/Lobby/DailyRewardReveal.gd"
const _TODAY := "2026-09-28"
const _YESTERDAY := "2026-09-27"
const _TWO_DAYS_AGO := "2026-09-26"
## What a full seven-day streak pays: the priciest Koperasi item.
const WEEKLY_TOTAL := 1500


func suite_name() -> String:
	return "daily_login_panel"


var _panel: DailyLoginPanel
var _reveal: DailyRewardReveal
## The real Lobby, whose DailyReward panel resolves its % nodes; the tests
## that draw use its panel.
var _lobby: Control
var _saved_money: int
var _saved_day: int
var _saved_date: String
var _saved_reduce_motion: bool


## One bare panel, one reveal and one Lobby for the whole suite (instancing
## per test floods the deferred-call queue). The reveal and the Lobby enter
## the editor root so their @onready lookups resolve; their _readys are
## gated, so nothing plays. Not tracked; suite_teardown frees all three.
func suite_setup(_ctx: Dictionary) -> void:
	_panel = DailyLoginPanel.new()
	var root: Node = Engine.get_main_loop().root
	if ResourceLoader.exists(_REVEAL_SCENE):
		var reveal_scene: PackedScene = load(_REVEAL_SCENE) as PackedScene
		_reveal = reveal_scene.instantiate() as DailyRewardReveal
		root.add_child(_reveal)
	var lobby_scene: PackedScene = load(_LOBBY_SCENE) as PackedScene
	_lobby = lobby_scene.instantiate() as Control
	root.add_child(_lobby)


func suite_teardown() -> void:
	for fixture: Node in [_panel, _reveal, _lobby]:
		if is_instance_valid(fixture):
			fixture.free()
	_panel = null
	_reveal = null
	_lobby = null


func setup() -> void:
	_saved_money = GameState.player_money
	_saved_day = GameState.daily_login_day
	_saved_date = GameState.last_claim_date
	_saved_reduce_motion = GameSettings.reduce_motion


func teardown() -> void:
	GameState.player_money = _saved_money
	GameState.daily_login_day = _saved_day
	GameState.last_claim_date = _saved_date
	GameSettings.reduce_motion = _saved_reduce_motion


## The Lobby fixture's panel, or null (with a failed assertion) if the
## Lobby lost it.
func _lobby_panel() -> DailyLoginPanel:
	var panel: DailyLoginPanel = null
	if is_instance_valid(_lobby):
		panel = _lobby.get_node_or_null("DailyReward") as DailyLoginPanel
	assert_true(panel != null, "the Lobby fixture must carry its DailyReward panel")
	return panel


func test_day_after_wraps() -> void:
	for day in range(1, DailyLoginPanel.STREAK_DAYS):
		assert_eq(DailyLoginPanel.day_after(day), day + 1,
			"the day after %d is %d" % [day, day + 1])
	assert_eq(DailyLoginPanel.day_after(DailyLoginPanel.STREAK_DAYS), 1,
		"the day after the last streak day wraps to day 1")


func test_streak_breaks_only_after_a_missed_day() -> void:
	assert_true(DailyLoginPanel.is_streak_broken(_TWO_DAYS_AGO, _TODAY),
		"a whole missed day breaks the streak")
	assert_false(DailyLoginPanel.is_streak_broken(_YESTERDAY, _TODAY),
		"claiming yesterday keeps the streak")
	assert_false(DailyLoginPanel.is_streak_broken("", _TODAY),
		"no claim yet is not a broken streak")
	assert_false(DailyLoginPanel.is_streak_broken(_TODAY, _TODAY),
		"a claim today is not a broken streak")


## Task 2: the reward escalates day by day to a day-7 peak, and a full
## week pays WEEKLY_TOTAL.
func test_reward_curve_shape() -> void:
	var curve: Array[int] = DailyLoginPanel.REWARD_CURVE
	assert_eq(curve.size(), DailyLoginPanel.STREAK_DAYS, "one reward per streak day")
	var total: int = 0
	for index: int in curve.size():
		total += curve[index]
		if index > 0:
			assert_true(curve[index] > curve[index - 1],
				"day %d pays more than day %d" % [index + 1, index])
	assert_eq(curve.max(), curve[DailyLoginPanel.STREAK_DAYS - 1],
		"the last streak day pays the most")
	assert_eq(total, WEEKLY_TOTAL, "a full week pays %dG" % WEEKLY_TOTAL)


func test_claim_pays_the_days_reward() -> void:
	for day: int in range(1, DailyLoginPanel.STREAK_DAYS + 1):
		GameState.daily_login_day = day
		GameState.last_claim_date = _YESTERDAY
		var before: int = GameState.player_money
		var paid: int = _panel.claim(_TODAY)
		assert_eq(paid, DailyLoginPanel.REWARD_CURVE[day - 1],
			"day %d pays its curve entry" % day)
		assert_eq(GameState.player_money, before + paid,
			"day %d's reward lands in the wallet" % day)
		assert_eq(GameState.daily_login_day, DailyLoginPanel.day_after(day),
			"day %d advances the streak" % day)
		assert_eq(GameState.last_claim_date, _TODAY, "the claim date is today")
	assert_eq(GameState.daily_login_day, 1, "claiming day 7 wraps the streak to day 1")


func test_reward_for_day_clamps() -> void:
	assert_eq(DailyLoginPanel.reward_for_day(0), DailyLoginPanel.REWARD_CURVE[0],
		"a day below 1 pays day 1's reward")
	assert_eq(DailyLoginPanel.reward_for_day(DailyLoginPanel.STREAK_DAYS + 1),
		DailyLoginPanel.REWARD_CURVE[DailyLoginPanel.STREAK_DAYS - 1],
		"a day past the last pays the last day's reward")


func test_second_claim_same_day_is_a_no_op() -> void:
	GameState.daily_login_day = 3
	GameState.last_claim_date = _YESTERDAY
	_panel.claim(_TODAY)
	var money: int = GameState.player_money
	var day: int = GameState.daily_login_day
	assert_eq(_panel.claim(_TODAY), 0, "a second claim today pays nothing")
	assert_eq(GameState.player_money, money, "the wallet is untouched")
	assert_eq(GameState.daily_login_day, day, "the streak does not advance twice")
	assert_eq(GameState.last_claim_date, _TODAY, "the claim date stays today")


func test_day_panels_cover_the_streak() -> void:
	assert_eq(DailyLoginPanel.DAY_PANELS.size(), DailyLoginPanel.STREAK_DAYS,
		"one panel frame per streak day")


## Task 5: the streak flame grows from day 1 to the last streak day and
## never shrinks on the way. Export initialisers run at construction, so
## the bare panel carries the real defaults.
func test_flame_scale_grows_with_the_streak() -> void:
	assert_eq(_panel.flame_scale_for(1), _panel.flame_scale_min,
		"day 1 shows the smallest flame")
	assert_eq(_panel.flame_scale_for(DailyLoginPanel.STREAK_DAYS), _panel.flame_scale_max,
		"the last streak day shows the biggest flame")
	for day: int in range(2, DailyLoginPanel.STREAK_DAYS + 1):
		assert_true(_panel.flame_scale_for(day) >= _panel.flame_scale_for(day - 1),
			"the flame on day %d is no smaller than on day %d" % [day, day - 1])


## Task 3 regression guard: the daily_claim cue was registered but never
## played by anything.
func test_claim_plays_the_daily_claim_cue() -> void:
	var panel_src := FileAccess.get_file_as_string(_PANEL_SCRIPT)
	assert_true(panel_src.contains('AudioDirector.play_sfx(&"daily_claim")'),
		"a claim must play the daily_claim cue")


func test_claim_counts_the_amount_up() -> void:
	var panel_src := FileAccess.get_file_as_string(_PANEL_SCRIPT)
	assert_true(panel_src.contains("Juice.count_up(reward_amount"),
		"the reward amount must count up on a claim, not snap")


## Task 6: the claim moment is its own component scene, with the firework
## volley instanced from the shared ConfettiFireworks scene.
func test_reveal_scene_holds_its_parts() -> void:
	var src := FileAccess.get_file_as_string(_REVEAL_SCENE)
	assert_true(src.contains("ConfettiFireworks.tscn"),
		"the reveal instances the shared ConfettiFireworks volley")
	for part: String in ["Box", "Lid", "Shine", "WalletCoin"]:
		assert_true(src.contains('[node name="%s"' % part),
			"DailyRewardReveal.tscn is missing its %s node" % part)


func test_reveal_defaults() -> void:
	assert_true(_reveal != null, "DailyRewardReveal.tscn must instance as a DailyRewardReveal")
	if _reveal == null:
		return
	assert_false(_reveal.use_chest_sprite, "the reveal ships on the gift fallback")
	assert_eq(_reveal.coin_count, 14, "an ordinary day fans 14 coins")
	assert_eq(_reveal.star_count, 6, "an ordinary day fans 6 stars")


## The reveal sits over the claim button; any Control in it that stops
## the mouse would eat the claim tap.
func test_reveal_never_eats_a_tap() -> void:
	assert_true(_reveal != null, "DailyRewardReveal.tscn must instance")
	if _reveal == null:
		return
	var offenders: Array[String] = []
	_collect_mouse_catchers(_reveal, offenders)
	assert_eq(offenders.size(), 0,
		"these reveal Controls do not ignore the mouse: " + ", ".join(offenders))


func _collect_mouse_catchers(node: Node, out: Array[String]) -> void:
	var control := node as Control
	if control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		out.append(String(node.name))
	for child: Node in node.get_children():
		_collect_mouse_catchers(child, out)


func test_reveal_builds_no_visual_at_runtime() -> void:
	var src := FileAccess.get_file_as_string(_REVEAL_SCRIPT)
	assert_false(src.contains(".new("),
		"the reveal instances its templates; it never constructs a node")


## Task 7: once today is claimed, the teaser names tomorrow's reward,
## wrapping from the last streak day back to day 1's.
func test_teaser_names_tomorrows_reward() -> void:
	assert_eq(DailyLoginPanel.teaser_text(2), "Besok: +120G",
		"tomorrow being day 2 teases day 2's reward")
	assert_eq(DailyLoginPanel.teaser_text(DailyLoginPanel.day_after(DailyLoginPanel.STREAK_DAYS)),
		"Besok: +80G", "after the last streak day the teaser wraps to day 1's reward")


## The invite's own tween must loop and bounce the reward row; a bare
## "set_loops()" scan would pass on the flame's flicker alone.
func test_idle_invite_is_a_looped_squash_bounce() -> void:
	var panel_src := FileAccess.get_file_as_string(_PANEL_SCRIPT)
	assert_true(panel_src.contains("_invite = create_tween().set_loops()"),
		"the idle invite repeats on its own looped tween")
	assert_true(panel_src.contains("_invite.tween_callback(AnimUtils.squash_bounce.bind(reward_row))"),
		"each loop of the idle invite squash-bounces the reward row")


## The streak day claimed today is the day before the advanced
## daily_login_day, day 1 wrapping back to the last streak day.
func test_claimed_day_for_is_the_day_before() -> void:
	assert_eq(DailyLoginPanel.claimed_day_for(1), DailyLoginPanel.STREAK_DAYS,
		"after claiming the last streak day, daily_login_day 1 means day 7 was claimed")
	assert_eq(DailyLoginPanel.claimed_day_for(4), 3,
		"daily_login_day 4 means day 3 was claimed")
	for day: int in range(1, DailyLoginPanel.STREAK_DAYS + 1):
		assert_eq(DailyLoginPanel.claimed_day_for(DailyLoginPanel.day_after(day)), day,
			"claimed_day_for undoes day_after for day %d" % day)


## Review Important 1: the Lobby re-runs refresh() on every visit the same
## day. After a claim it must still draw the CLAIMED day (strip slot,
## streak line, amount), dimmed, while the teaser names tomorrow's reward.
## Day 7 is the case that used to read "Streak 1 hari".
func test_refresh_after_a_claim_draws_the_claimed_day() -> void:
	var panel: DailyLoginPanel = _lobby_panel()
	if panel == null:
		return
	var cases: Array[Dictionary] = [
		{"day": 3, "streak": "Streak 3 hari", "amount": "160G", "teaser": "Besok: +200G"},
		{"day": DailyLoginPanel.STREAK_DAYS, "streak": "Streak 7 hari", "amount": "400G",
			"teaser": "Besok: +80G"},
	]
	for expected: Dictionary in cases:
		var day: int = expected["day"]
		GameState.daily_login_day = day
		GameState.last_claim_date = _YESTERDAY
		panel.claim(_TODAY)
		panel.refresh(_TODAY)
		assert_eq(panel.streak_label.text, expected["streak"], "day %d's streak line survives a reload" % day)
		assert_eq(panel.reward_amount.text, expected["amount"], "day %d's amount survives a reload" % day)
		assert_eq(panel.texture, DailyLoginPanel.DAY_PANELS[day - 1],
			"the strip keeps day %d's slot lit after a reload" % day)
		assert_true(panel.claim_button.disabled, "day %d stays claimed after a reload" % day)
		assert_true(panel.besok_teaser.visible, "the teaser shows once day %d is claimed" % day)
		assert_eq(panel.besok_teaser.text, expected["teaser"], "the teaser names tomorrow's reward after day %d" % day)


## Review Minor 1: the reveal's payout contract. Under reduce_motion
## play() is synchronous: burst_started, then coin_landed, once each; a
## later skip() owes nothing and emits nothing.
func test_reveal_under_reduce_motion_emits_each_signal_once() -> void:
	assert_true(_reveal != null and _reveal.is_inside_tree(),
		"the suite's reveal fixture must be in the tree")
	if _reveal == null or not _reveal.is_inside_tree():
		return
	GameSettings.reduce_motion = true
	var emitted: Array[String] = []
	var on_burst: Callable = func() -> void: emitted.append("burst_started")
	var on_land: Callable = func() -> void: emitted.append("coin_landed")
	_reveal.burst_started.connect(on_burst)
	_reveal.coin_landed.connect(on_land)
	_reveal.play(false, Vector2.ZERO)
	var after_play: String = ",".join(emitted)
	_reveal.skip()
	_reveal.skip()
	_reveal.burst_started.disconnect(on_burst)
	_reveal.coin_landed.disconnect(on_land)
	assert_eq(after_play, "burst_started,coin_landed",
		"play() under reduce_motion emits burst_started then coin_landed at once")
	assert_eq(",".join(emitted), after_play, "skip() after the payout emits nothing more")


## Review Minor 1: `claimed` goes out once per claim, however many paths
## try to pay it.
func test_pay_out_announces_a_claim_once() -> void:
	var paid: Array[int] = []
	var on_claimed: Callable = func(amount: int, _previous: int) -> void: paid.append(amount)
	_panel.claimed.connect(on_claimed)
	_panel._pending_amount = DailyLoginPanel.REWARD_CURVE[0]
	_panel._pending_previous_money = 0
	_panel._is_payout_pending = true
	_panel._pay_out()
	_panel._pay_out()
	_panel.claimed.disconnect(on_claimed)
	assert_eq(paid.size(), 1, "a held claim is announced exactly once")


## Review Minor 4: a new claim moment pays a still-pending payout first
## instead of overwriting it.
func test_a_new_claim_moment_pays_the_pending_payout_first() -> void:
	var panel: DailyLoginPanel = _lobby_panel()
	if panel == null:
		return
	GameSettings.reduce_motion = true
	var earlier: int = DailyLoginPanel.REWARD_CURVE[0]
	var paid: Array[int] = []
	var on_claimed: Callable = func(amount: int, _previous: int) -> void: paid.append(amount)
	panel.claimed.connect(on_claimed)
	panel._pending_amount = earlier
	panel._pending_previous_money = 0
	panel._is_payout_pending = true
	panel._play_claim_moment(DailyLoginPanel.REWARD_CURVE[1], 2, 0)
	panel.claimed.disconnect(on_claimed)
	panel._is_payout_pending = false
	assert_true(paid.size() >= 1 and paid[0] == earlier,
		"the earlier claim is paid before the new one is held, got %s" % str(paid))
	assert_eq(paid.count(earlier), 1, "the earlier claim is paid exactly once")


## Review Minor 6: a zero loop duration typed in the Inspector must not
## start an infinite zero-length loop; the loop is simply skipped.
func test_a_zero_loop_duration_starts_no_loop() -> void:
	var panel: DailyLoginPanel = _lobby_panel()
	if panel == null:
		return
	GameSettings.reduce_motion = false
	GameState.last_claim_date = _YESTERDAY
	panel.refresh(_TODAY)
	var saved_flicker: float = panel.flame_flicker_seconds
	var saved_invite: float = panel.idle_invite_seconds
	panel.flame_flicker_seconds = 0.0
	panel.idle_invite_seconds = 0.0
	panel._start_flicker()
	panel._start_idle_invite()
	var flicker: Tween = panel._flicker
	var invite: Tween = panel._invite
	panel._stop_flicker()
	panel._stop_idle_invite()
	panel.flame_flicker_seconds = saved_flicker
	panel.idle_invite_seconds = saved_invite
	assert_true(flicker == null, "a zero flame_flicker_seconds starts no flicker loop")
	assert_true(invite == null, "a zero idle_invite_seconds starts no invite loop")


## Task 6: the Lobby's daily-gift badge asks is_claimable() rather than
## reading GameState itself, so it must track the day the last refresh()
## drew, not the live claim state alone.
func test_is_claimable_reflects_the_drawn_days_claim() -> void:
	var panel: DailyLoginPanel = _lobby_panel()
	if panel == null:
		return
	GameState.last_claim_date = _YESTERDAY
	panel.refresh(_TODAY)
	assert_true(panel.is_claimable(), "yesterday's claim date leaves today claimable")
	GameState.last_claim_date = _TODAY
	panel.refresh(_TODAY)
	assert_false(panel.is_claimable(), "today's claim date is no longer claimable")


func test_lobby_no_longer_owns_the_claim() -> void:
	var lobby_src := FileAccess.get_file_as_string(_LOBBY_SCRIPT)
	for moved: String in ["_on_claim_pressed", "DAILY_REWARD", "DAY_PANELS",
			"CLAIMED_CUE_DIM_ALPHA", "_check_daily_login_reset",
			"_update_daily_login_visual", "GameState.player_money +="]:
		assert_false(lobby_src.contains(moved),
			"Lobby.gd still holds %s; the claim is the panel's" % moved)
	var panel_src := FileAccess.get_file_as_string(_PANEL_SCRIPT)
	assert_true(panel_src.contains("claimed.emit("),
		"the panel announces a payout rather than reaching into the Lobby")
	assert_false(panel_src.contains("money_label"),
		"the panel never touches the Lobby's wallet label")
