@tool
class_name MinigameWinScreen
extends CanvasLayer

## The won-minigame screen (2026-09-25 minigame-win-screen spec; mockup
## minigamewinscreen_mockup.jpeg). BaseMinigame shows it over the minigame,
## which keeps running, blurred, behind it. A loss keeps MinigameResultPopup.
##
## Everything is authored in MinigameWinScreen.tscn: configure() only sets
## textures, text, visibility and the stars, and play() runs the reveal in
## REVEAL_ORDER, waits for LOBBY or LANJUT and returns which.

## Emitted once, with &"lobby" or &"lanjut", when an armed button is pressed.
signal exited(choice: StringName)

## The reveal, in order: the big box, the speaker, the line, the stats, the
## stars, the buttons. play() walks it; the suite pins it.
const REVEAL_ORDER: Array[StringName] = [&"card", &"splash", &"bubble", &"stats", &"stars", &"buttons"]
## Which Daily Results icon (DaySummaryStatRow.ICON_FOR) each category's skill chip wears.
const SKILL_KEY := {"Akademis": "akademis", "SeniBudaya": "seni_budaya", "Olahraga": "olahraga"}
## The energy chip's icon: the mockup's lightning.
const ENERGY_ICON: Texture2D = preload("res://Assets/Images/StudentCard/stat_energy.png")
## Tint that turns star.png into an unearned silhouette; BaseMinigame's
## popup_star_empty_color default, so both result cards dim alike.
const EMPTY_STAR_COLOR := Color(0.28, 0.28, 0.32)
## Seconds the card takes to rise into place while the blur fades in.
const CARD_RISE_TIME := 0.35
## Pause after the card lands before the speaker starts.
const SPLASH_GAP := 0.12
## Seconds the speaker takes to fade in while rising SPLASH_RISE_PX.
const SPLASH_RISE_TIME := 0.30
## How far the speaker rises as it fades in, px.
const SPLASH_RISE_PX := 60.0
## Pause after the speaker before the bubble pops.
const BUBBLE_GAP := 0.12
## Gap between the two stat chips starting their reveal.
const STAT_STAGGER := 0.15
## Seconds each chip's number counts from 0 to its delta.
const STAT_COUNT_TIME := 0.5
## Seconds the screen takes to fade away after a choice.
const FADE_OUT_TIME := 0.25

@onready var root: Control = $Root
@onready var blur: ColorRect = $Root/Blur
@onready var splash: TextureRect = $Root/Splash
@onready var bubble: Control = $Root/Bubble
@onready var line_label: Label = $Root/Bubble/Panel/Line
@onready var card: PanelContainer = $Root/Card
@onready var star_row: HBoxContainer = $Root/Card/Layout/StarRow
@onready var stat_row: HBoxContainer = $Root/Card/Layout/StatRow
@onready var skill_chip: MinigameWinStat = $Root/Card/Layout/StatRow/SkillChip
@onready var energy_chip: MinigameWinStat = $Root/Card/Layout/StatRow/EnergyChip
@onready var button_row: HBoxContainer = $Root/Card/Layout/ButtonRow
@onready var lobby_button: Button = $Root/Card/Layout/ButtonRow/LobbyButton
@onready var lanjut_button: Button = $Root/Card/Layout/ButtonRow/LanjutButton
@onready var fireworks: ConfettiFireworks = $Root/ConfettiFireworks
@onready var confetti: RewardParticles = $Root/ResultConfetti

## Stars earned, 0-3, from configure().
var _star_count: int = 0
## True once the buttons have been revealed; presses before that are ignored.
var _armed: bool = false


func _ready() -> void:
	lobby_button.pressed.connect(_choose.bind(&"lobby"))
	lanjut_button.pressed.connect(_choose.bind(&"lanjut"))


## Dress the screen. `speaker_path` "" shows no splash. `shown` is what the
## host reported: {"stat_delta", "energy_delta"}, either may be absent; a zero
## or absent stat hides its chip, and two hidden chips hide the row.
func configure(stars: int, speaker_path: String, line: String, category: String, shown: Dictionary) -> void:
	_star_count = clampi(stars, 0, 3)
	_armed = false
	splash.texture = load(speaker_path) if speaker_path != "" and ResourceLoader.exists(speaker_path) else null
	splash.visible = splash.texture != null
	line_label.text = line
	var i := 0
	for star in star_row.get_children():
		(star as ResultStar).set_filled(i < _star_count, null, null, Color.WHITE, EMPTY_STAR_COLOR)
		i += 1
	var skill_icon: Texture2D = DaySummaryStatRow.ICON_FOR.get(SKILL_KEY.get(category, ""), null)
	var stat_delta := float(shown.get("stat_delta", 0.0))
	var energy_delta := float(shown.get("energy_delta", 0.0))
	skill_chip.set_stat(skill_icon, stat_delta)
	skill_chip.visible = skill_icon != null and not is_zero_approx(stat_delta)
	energy_chip.set_stat(ENERGY_ICON, energy_delta)
	energy_chip.visible = not is_zero_approx(energy_delta)
	stat_row.visible = skill_chip.visible or energy_chip.visible


## Let LOBBY and LANJUT answer. The reveal's last step calls it.
func arm_buttons() -> void:
	_armed = true


## Every piece the reveal brings in, hidden and waiting. play() calls it
## first; a test calls it to check nothing shows before its turn.
func hide_for_reveal() -> void:
	for n in [blur, card, splash, bubble, lobby_button, lanjut_button,
			skill_chip.icon_box, energy_chip.icon_box, skill_chip.value, energy_chip.value]:
		n.modulate.a = 0.0
	for star in star_row.get_children():
		star.modulate.a = 0.0
		star.scale = Vector2(0.3, 0.3)
		star.pivot_offset = star.custom_minimum_size / 2.0


## Run the reveal in REVEAL_ORDER, wait for LOBBY or LANJUT, fade out, free
## this screen, and return the choice. Callers must await it.
func play() -> StringName:
	hide_for_reveal()
	for step in REVEAL_ORDER:
		await _reveal(step)
	var choice: StringName = await exited
	var out := create_tween()
	out.tween_property(root, "modulate:a", 0.0, FADE_OUT_TIME)
	await out.finished
	queue_free()
	return choice


func _reveal(step: StringName) -> void:
	match step:
		&"card":
			var rest_y := card.position.y
			card.position.y = rest_y + card.size.y
			card.modulate.a = 1.0
			var rise := create_tween().set_parallel(true)
			rise.tween_property(blur, "modulate:a", 1.0, CARD_RISE_TIME)
			rise.tween_property(card, "position:y", rest_y, CARD_RISE_TIME) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			await rise.finished
			if not Engine.is_editor_hint():
				RewardFeedback.play(&"minigame_win", self)
		&"splash":
			await get_tree().create_timer(SPLASH_GAP).timeout
			if splash.visible:
				var rest_y := splash.position.y
				splash.position.y = rest_y + SPLASH_RISE_PX
				var rise := create_tween().set_parallel(true)
				rise.tween_property(splash, "modulate:a", 1.0, SPLASH_RISE_TIME)
				rise.tween_property(splash, "position:y", rest_y, SPLASH_RISE_TIME) \
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
				await rise.finished
		&"bubble":
			await get_tree().create_timer(BUBBLE_GAP).timeout
			var pop := Juice.pop_in(bubble)
			if pop != null:
				await pop.finished
		&"stats":
			var chips: Array = [skill_chip, energy_chip].filter(func(c): return c.visible)
			for i in chips.size():
				if i < chips.size() - 1:
					chips[i].reveal(STAT_COUNT_TIME)
					await get_tree().create_timer(STAT_STAGGER).timeout
				else:
					await chips[i].reveal(STAT_COUNT_TIME)
		&"stars":
			await _land_stars()
		&"buttons":
			Juice.stagger_in([lobby_button, lanjut_button])
			arm_buttons()


## MinigameResultPopup's escalating ladder: each star pops a little harder
## than the last, an earned one blooms and fires its firework, and a full
## house rains confetti.
func _land_stars() -> void:
	var index := 0
	for star in star_row.get_children():
		var pop_scale: float = MinigameResultPopup.STAR_POP_SCALES[
			mini(index, MinigameResultPopup.STAR_POP_SCALES.size() - 1)]
		var tw := create_tween().set_parallel(true)
		tw.tween_property(star, "modulate:a", 1.0, 0.15)
		tw.tween_property(star, "scale", Vector2(pop_scale, pop_scale), 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished
		star.celebrate(index)
		if index < _star_count and not Engine.is_editor_hint():
			fireworks.fire_burst(index)
		await get_tree().create_timer(MinigameResultPopup.STAR_HOLD_TIMES[
			mini(index, MinigameResultPopup.STAR_HOLD_TIMES.size() - 1)]).timeout
		var settle := create_tween()
		settle.tween_property(star, "scale", Vector2.ONE, 0.1) \
			.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		await settle.finished
		index += 1
	if _star_count >= MinigameResultPopup.CONFETTI_STAR_THRESHOLD and not Engine.is_editor_hint():
		confetti.fire()


func _choose(choice: StringName) -> void:
	if not _armed:
		return
	_armed = false
	exited.emit(choice)
