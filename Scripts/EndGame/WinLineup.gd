class_name WinLineup
extends RefCounted

## The win screen's roster arrangement (2026-09-09). EndCutscene shows the
## run's own approved students posed on win_background; this file decides
## who stands where, and where each one's ground shadow goes.
##
## Plain static functions over Dictionaries, no nodes, which is why
## tests/test_win_lineup.gd can test it behaviourally rather than by source
## scan the way a scene script has to be tested. Same shape as
## Scripts/Debug/EndGameRehearsal.gd.
##
## Coordinates are in the backdrop's own 1536x2048 art space, except
## FOOT_ANCHORS, which is in each splash's own 1080x1080 canvas space.
## EndCutscene.gd converts. Full derivation:
## docs/superpowers/specs/2026-09-09-win-screen-lineup-design.md

## The one fixed rule: Doni is always the front figure.
const PINNED_FRONT := "Doni"

## Slot ids, front to back. Draw order follows this array reversed, so
## FRONT_LOW ends up on top.
const SLOT_FRONT_LOW := "front_low"
const SLOT_FRONT_MID := "front_mid"
const SLOT_SIDE_LEFT := "side_left"
const SLOT_SIDE_RIGHT := "side_right"

## Where each figure's feet meet the floor, measured from its splash's
## alpha at threshold 128 -- the low threshold used for a bounding box
## reports a shared baseline whether or not one exists, because every PNG
## carries stray near-transparent pixels to the canvas edge.
##
## `centre_x` and `span` are the midpoint and width of the contact band
## (the 40 rows above the baseline). `widen` multiplies the shadow for
## poses whose contact band is far narrower than the body: Marcel leans on
## one foot, Thea is mid-stride, and an unwidened shadow under either
## reads as a smudge rather than as contact.
const FOOT_ANCHORS := {
	"Doni": {"centre_x": 587.0, "span": 597.0},
	"Andi": {"centre_x": 488.0, "span": 390.0},
	"Citra": {"centre_x": 530.0, "span": 352.0},
	"Shinta": {"centre_x": 526.0, "span": 186.0},
	"Marcel": {"centre_x": 480.0, "span": 116.0, "widen": 2.0},
	"Thea": {"centre_x": 546.0, "span": 100.0, "widen": 2.0},
}
