@tool
class_name PressFeel
extends RefCounted

## Which press a button gets (2026-09-28 UI depth pass). A button resting on a
## lipped face (LippedBox) sinks through its own pressed stylebox on the touch frame,
## so it must not also shrink -- it gets Juice.pop_release on letting go.
## Every other button keeps Juice.press/release. The main-action roles also
## tick the phone's motor (Haptics.buzz, which honours the Getar setting).
## Pure and static, so UIPolish and the tests share one answer.

## Length of the press tick, ms: Haptics' existing "Tick" tier.
const PRESS_TICK_MS := 8
## The only roles whose press vibrates -- the main action and affirm roles,
## the danger roles, and the notebook's close.
const MAIN_ACTION_ROLES: Array[StringName] = [
	&"BookHeroButton", &"LobbyCtaButton",
	&"PrimaryButton", &"PrimaryButtonM", &"PrimaryButtonL",
	&"SuccessButton", &"SuccessButtonL",
	&"DangerButton", &"DangerButtonM", &"DangerButtonL",
	&"NotebookClose",
]


## True when `normal` -- a button's resting stylebox -- has a lip to sink onto.
static func sinks(normal: StyleBox) -> bool:
	return LippedBox.is_lipped(normal)


## True when a button of theme variation `variation` ticks on press.
static func ticks(variation: StringName) -> bool:
	return MAIN_ACTION_ROLES.has(variation)
