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


func _choose(choice: StringName) -> void:
	if not _armed:
		return
	_armed = false
	exited.emit(choice)
