@tool
class_name MinigameScoreHUD
extends Control

## The shared in-run score readout, mounted by every minigame that keeps score.
##
## Before this template, MainBola, Badminton, LombaMenari and Menjodohkan each
## styled a bare ScoreLabel at runtime with five theme_override_* calls apiece,
## all slightly different and none carrying an icon. Chrome now comes from the
## ScoreHudPanel / ScoreHudValueLabel theme variations; the only thing this
## script sets is content.
##
## Affects: nothing outside itself. Every method is synchronous so a minigame
## can call it from _process or a signal handler.
##
## @tool so the scene previews in the editor.

## Combo length at or above which the combo chip appears. Two-in-a-row is
## noise; three is a streak worth telling the player about.
const COMBO_DISPLAY_MIN: int = 3
## Peak scale of the value label's pop on a score increase.
const POP_SCALE: float = 1.28
## Seconds the pop takes to swell, and again to settle.
const POP_TIME: float = 0.12
## Burst fired at the readout when the score goes up.
const BURST_SCENE := "res://Scenes/Minigames/UI/ScorePopBurst.tscn"

@onready var panel: PanelContainer = $Panel
@onready var icon: TextureRect = $Panel/Row/Icon
@onready var value_label: Label = $Panel/Row/ValueLabel
@onready var target_label: Label = $Panel/Row/TargetLabel
@onready var combo_chip: PanelContainer = $Panel/Row/ComboChip
@onready var combo_chip_label: Label = $Panel/Row/ComboChip/ComboRow/ComboLabel
@onready var burst_slot: Control = $BurstSlot

## Last value set_score() saw, so a re-set of the same score does not re-pop.
var _last_score: int = 0


## The root Control does not auto-propagate Panel's minimum size the way a
## Container parent would, so a parent VBoxContainer (Menjodohkan,
## PilihanGanda, Password, Variabel all mount the HUD as a VBox child) was
## allocating this node zero height, and an absolute-positioned mount
## (MainBola's HUDLayer -- itself a Container -- worked once this reported a
## real minimum, but Badminton/LombaMenari mount it directly under the root
## scene with no Container parent at all, which never auto-clamps a
## Control's authored size up to its minimum) was left at literal zero size.
## Panel fills this Control's full rect (see the .tscn), so reporting
## Panel's own combined minimum size here is this node's real minimum size.
func _get_minimum_size() -> Vector2:
	if not is_instance_valid(panel):
		return Vector2.ZERO
	return panel.get_combined_minimum_size()


## A Control outside any Container is never auto-resized to its minimum, so
## Badminton.tscn/LombaMenari.tscn's HUD instances -- authored with
## offset_left == offset_right (and top == bottom) as a "centered on this
## point" anchor, the standard technique for a Container-managed sibling,
## but mounted with no Container in between -- were staying at their
## authored zero size. Grow explicitly around that authored anchor point.
## Called from setup() (not _ready()) because every minigame already calls
## setup() once at mount time, giving this a single, predictable moment to
## run at rather than depending on node-ready ordering across scene trees.
## Ungated by Engine.is_editor_hint() -- unlike set_score()'s audio/particle
## side effects, this is pure layout math with no external effect, and
## running it in the editor too is what makes the scene preview correctly.
func _grow_to_minimum_if_unmanaged() -> void:
	if get_parent() is Container:
		return
	var min_size := get_combined_minimum_size()
	if min_size == Vector2.ZERO:
		return
	if size != Vector2.ZERO:
		return
	position -= min_size / 2.0
	size = min_size


## Install the readout's icon and its target. A `target` of 0 or less hides the
## target half, for a game that scores without a ceiling.
##
## Affects: this HUD's own icon, value and target labels.
func setup(hud_icon: Texture2D, target: int) -> void:
	icon.texture = hud_icon
	target_label.visible = target > 0
	if target > 0:
		target_label.text = "/ %d" % target
	value_label.text = "0"
	_last_score = 0
	_grow_to_minimum_if_unmanaged()


## Set the score. A genuine increase pops the label, fires a burst and ticks; a
## re-set of the same number does none of those, so a minigame is free to call
## this every frame.
##
## Affects: this HUD's value label, and adds a self-freeing burst under
## BurstSlot on an increase.
func set_score(value: int) -> void:
	value_label.text = str(value)
	if value <= _last_score:
		_last_score = value
		return
	_last_score = value
	if Engine.is_editor_hint():
		return
	AudioDirector.play_sfx(&"score_tick")
	var burst: Node = load(BURST_SCENE).instantiate()
	burst_slot.add_child(burst)
	burst.fire()
	Juice.set_pivot_center(value_label)
	var tw := create_tween()
	tw.tween_property(value_label, "scale", Vector2(POP_SCALE, POP_SCALE), POP_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(value_label, "scale", Vector2.ONE, POP_TIME)\
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


## Show or hide the combo chip. Below COMBO_DISPLAY_MIN it stays hidden, and
## the cue fires only on the transition into visibility, never every hit.
##
## Affects: this HUD's combo chip.
func set_combo(value: int) -> void:
	var show_chip: bool = value >= COMBO_DISPLAY_MIN
	if show_chip and not combo_chip.visible and not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"combo_up")
	combo_chip.visible = show_chip
	combo_chip_label.text = "x%d" % value


## Write the value half verbatim, for a game whose score is not a single number
## -- Badminton's "7 - 6", say. Leaves the target half untouched.
##
## Affects: this HUD's value label.
func set_label_text(text: String) -> void:
	value_label.text = text
