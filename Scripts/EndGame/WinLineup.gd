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

## Art-space geometry per slot: where the splash's bottom-centre lands in
## the backdrop's 1536x2048 space, and what the 1080x1080 canvas scales by.
##
## Seeded from mockup_winscreen.png -- the four figures there occupy
## x 244-1386, y 818-1797 -- and tuned by eye in the editor. These are the
## only estimated numbers in this file; everything else is measured.
const SLOT_GEOMETRY := {
	SLOT_FRONT_LOW: {"anchor": Vector2(700.0, 1810.0), "scale": 0.95},
	SLOT_FRONT_MID: {"anchor": Vector2(940.0, 1770.0), "scale": 0.90},
	SLOT_SIDE_LEFT: {"anchor": Vector2(470.0, 1660.0), "scale": 0.86},
	SLOT_SIDE_RIGHT: {"anchor": Vector2(1210.0, 1680.0), "scale": 0.86},
}

## Which slots a roster of `count` uses, ordered BACK TO FRONT so a caller
## can add nodes in array order and get the right z-order for free.
##
## Each size is arranged rather than derived: a 2-student shot that simply
## left the side slots empty would read as a gappy 4-figure composition
## instead of a deliberate 2-figure one.
const ARRANGEMENTS := {
	2: [SLOT_SIDE_LEFT, SLOT_FRONT_LOW],
	3: [SLOT_SIDE_LEFT, SLOT_FRONT_MID, SLOT_FRONT_LOW],
	4: [SLOT_SIDE_LEFT, SLOT_SIDE_RIGHT, SLOT_FRONT_MID, SLOT_FRONT_LOW],
}

## How many figures the composition holds.
const MAX_FIGURES := 4

## Half of a splash canvas, in its own space. A figure's horizontal offset
## from its anchor is measured from here.
const CANVAS_HALF := 540.0

## Foot span assumed for a name with no measured anchor. Roughly a
## two-footed stance, so an unmeasured student gets a plausible shadow
## instead of none.
const FALLBACK_SPAN := 300.0


## The slots a roster of `count` uses, back to front. Counts outside 2-4
## clamp into range: 0 and 1 borrow the 2-figure arrangement's tail, and
## anything above MAX_FIGURES is truncated by assign().
static func slots_for(count: int) -> Array[String]:
	var n := clampi(count, 1, MAX_FIGURES)
	if ARRANGEMENTS.has(n):
		var out: Array[String] = []
		out.assign(ARRANGEMENTS[n])
		return out
	# n == 1: the front figure alone.
	return [SLOT_FRONT_LOW]


## Place `names` into slots. Doni takes the front whenever he is approved;
## everyone else fills the remaining slots in roster order. Deterministic,
## so the arrangement can be asserted in tests and screenshotted without
## surprise.
##
## Returns one Dictionary per placed student:
##   {"name": String, "slot": String, "anchor": Vector2, "scale": float}
## `anchor` is the splash's bottom-centre in art space; `scale` multiplies
## its 1080x1080 canvas. Extra students beyond MAX_FIGURES are dropped.
static func assign(names: Array) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	if names.is_empty():
		return placed

	var roster: Array = names.slice(0, MAX_FIGURES)
	var slots := slots_for(roster.size())

	# Front first, so the pinned student is resolved before anyone else
	# can take the slot. The rest keep roster order.
	var front_name: String = PINNED_FRONT if roster.has(PINNED_FRONT) else roster[0]
	var rest: Array = []
	for n in roster:
		if n != front_name:
			rest.append(n)

	var free_slots: Array = slots.duplicate()
	free_slots.erase(SLOT_FRONT_LOW)

	placed.append(_place(front_name, SLOT_FRONT_LOW))
	for i in range(rest.size()):
		if i >= free_slots.size():
			break
		placed.append(_place(rest[i], free_slots[i]))
	return placed


static func _place(name: String, slot: String) -> Dictionary:
	var g: Dictionary = SLOT_GEOMETRY[slot]
	return {
		"name": name,
		"slot": slot,
		"anchor": g["anchor"],
		"scale": g["scale"],
	}


## Where a placed student's ground shadow goes, in art space.
##
## `spread` multiplies the measured foot span and `flatness` sets the
## ellipse's height as a fraction of its width -- both are EndCutscene
## exports, so the shadows can be art-directed without touching the
## measured numbers in FOOT_ANCHORS.
##
## Returns {"centre": Vector2, "size": Vector2}.
static func shadow_for(placed: Dictionary, spread: float,
		flatness: float) -> Dictionary:
	var scale: float = placed["scale"]
	var anchor: Vector2 = placed["anchor"]
	var a: Dictionary = FOOT_ANCHORS.get(placed["name"], {})

	var centre_x: float = a.get("centre_x", CANVAS_HALF)
	var span: float = a.get("span", FALLBACK_SPAN)
	var widen: float = a.get("widen", 1.0)

	var width: float = span * widen * spread * scale
	return {
		# The splash is anchored bottom-CENTRE, so the foot centre's offset
		# from the canvas midline is what displaces the shadow.
		"centre": Vector2(anchor.x + (centre_x - CANVAS_HALF) * scale, anchor.y),
		"size": Vector2(width, width * flatness),
	}
