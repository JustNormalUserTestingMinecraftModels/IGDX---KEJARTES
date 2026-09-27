@tool
class_name StatGainPop
extends HBoxContainer

## One skill's gain floating up from a SchoolDay avatar chip (2026-09-25),
## while the BookClockWidget's day runs behind it. It is dressed like one row
## of the daily result card, DaySummaryStatRow, so the in-day pop and the
## evening's result read as the same thing: the stat's own icon, the gold up
## arrow and the number in the DaySummaryStat face. It replaced a bare "+N"
## drawn by AnimUtils.create_floating_text, which named no stat at all.
##
## Only the number differs from the card: the pop reads "+3", not "+3/65".
## It floats over a 200 px chip in a clipping strip, and the target already
## rides the card's track that evening.
##
## Instanced from StatGainPop.tscn, never built. AvatarChip places it over
## its rings and calls play(), which frees the node once it has faded.

## How far the pop rises while it fades, px. The chip's Headroom node gives
## it that much room above its start inside the clipping strip.
@export_range(0.0, 200.0, 1.0) var rise_px: float = 36.0
## Seconds from appearing to fully faded.
@export_range(0.1, 4.0, 0.05) var rise_seconds: float = 1.2
## Share of rise_seconds the pop holds fully opaque before it fades out.
@export_range(0.0, 1.0, 0.05) var hold_fraction: float = 0.55
## Seconds the pop takes to spring from pop_in_scale up to full size.
@export_range(0.0, 1.0, 0.01) var pop_in_seconds: float = 0.22
## The scale the pop springs up from.
@export_range(0.1, 1.0, 0.05) var pop_in_scale: float = 0.6


## "+3": the sign rides with the number, as it does on the card.
static func format_gain(amount: int) -> String:
	return "+%d" % amount


## Dresses the pop for `stat_key` (akademis / seni_budaya / olahraga) and a
## gain of `amount` whole points. Reads its children by path, so it works on
## an instance that has not entered the tree yet.
func set_gain(stat_key: String, amount: int) -> void:
	var icon := get_node_or_null("Icon") as TextureRect
	if icon != null and DaySummaryStatRow.ICON_FOR.has(stat_key):
		icon.texture = DaySummaryStatRow.ICON_FOR[stat_key]
	var value := get_node_or_null("Value") as Label
	if value != null:
		value.text = format_gain(amount)


## Springs in, rises rise_px and fades, then frees itself. Under
## reduce_motion it neither springs nor rises; it only fades, so the number
## still shows. Game only: the suite instances pops to inspect them.
func play() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	pivot_offset = size * 0.5
	var tween := create_tween().set_parallel(true)
	if not GameSettings.reduce_motion:
		scale = Vector2.ONE * pop_in_scale
		tween.tween_property(self, "scale", Vector2.ONE, pop_in_seconds) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position:y", position.y - rise_px, rise_seconds) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, rise_seconds * (1.0 - hold_fraction)) \
		.set_delay(rise_seconds * hold_fraction)
	tween.chain().tween_callback(queue_free)
