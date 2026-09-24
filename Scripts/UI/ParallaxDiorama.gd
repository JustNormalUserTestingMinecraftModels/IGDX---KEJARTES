@tool
extends Control

## Gives an already-layered screen depth by sliding its bands against each
## other as the device tilts.
##
## Two screens in this game are dioramas that were authored as separate depth
## bands and then drawn perfectly flat: the Lobby's Classroom (wall, back row,
## front row) and Koperasi's Stage (backdrop and goods, shopkeeper, counter).
## The art already has the layers; nothing here adds a visual, it only moves
## what is there.
##
## A DRIVER, NOT A BAND. This node hangs off the diorama as an extra child and
## drives its SIBLINGS, named relative to `bands_root`. It works that way
## because the obvious host is often taken -- Koperasi's Stage already runs
## rakbarang_1.gd, and a node has only one script -- and because a driver that
## owns no pixels cannot be mistaken for part of the picture.
##
## WHAT DRIVES IT. On a phone, the accelerometer: tilt the handset and the
## near bands swing further than the far ones, which is what parallax does
## under a translating viewpoint. On desktop, where Input.get_accelerometer()
## returns zero, the pointer stands in for tilt, measured from the middle of
## the screen. force_deflection() drives either without a device, an input
## event or a frame of smoothing, which is how the suite checks it.
##
## WHICH BANDS NEED OVERSCAN, AND WHY IT GROWS THE RECT. Most bands are
## cutouts on transparency -- desks, students, hands, the shopkeeper -- and
## moving those reveals nothing. Two are opaque to their own edges, measured:
## loby_no_tables.png on all four sides and shop_foreground.png on three. Move
## one of those and its edge drags into view, which on the Lobby's BGLayer
## means the black Backdrop behind it. `overscan_children` names just those,
## and they are grown by pushing their OFFSETS outward.
##
## Growing the rect rather than setting `scale` is not a style choice. Scale
## and pivot_offset are already spoken for: Koperasi's Herman is authored with
## pivot (540, 1920) so HermanAP can scale him up from the floor, and that
## animation writes `scale` every frame it plays. A parallax that also wrote
## them would fight the animation and silently lose its overscan. Offsets are
## nobody else's.
##
## WHY THE ROWS SHARE A DEPTH. A student's hands are a separate band from the
## desk they rest on. Give those two different depths and the hands slide off
## the desk, so `depth_by_child` puts each row -- desk, portraits and hands --
## on one plane. The parallax is between rows, not within one.
##
## NOTHING IS WRITTEN OUTSIDE PLAY. Every mutation this script makes -- the
## bands' offsets, grown and then shifted -- happens in _process,
## and _process is off under Engine.is_editor_hint(). An editor that moved or
## grew these nodes would bake the result into the .tscn on the next save,
## which is how StickyNote's pins once shifted 20px. The editor always shows
## the authored diorama; the parallax exists only in a running game.

## Absolute slack added to the overscan, in pixels, on top of the fractional
## margin. Guards against a hairline seam from rounding on the deepest band,
## where the fraction alone buys a fraction of a pixel.
const SEAM_PAD := Vector2(3.0, 3.0)

## The node whose children are the bands. Defaults to this driver's parent.
@export var bands_root: NodePath = ^".."

## Child name -> depth multiplier, resolved against `bands_root`. Higher moves
## further, because a nearer thing sweeps further across the view when the
## viewpoint shifts. A child missing from this map never moves, which is the
## right default for UI sitting on top of the diorama.
@export var depth_by_child: Dictionary = {}

## How far a band at depth 1.0 travels from rest at full deflection, in
## pixels. Small on purpose: this is a depth cue, not a camera move. The
## overscan needed to hide the band edges is derived from it.
@export var travel: Vector2 = Vector2(14.0, 8.0)

## Children that are opaque to their own edges and must be grown before they
## move, as measured on the source art. A cutout on transparency does not
## belong here: growing it would only stretch empty pixels.
@export var overscan_children: Array[StringName] = []

## Extra margin beyond what `travel` strictly needs, as a fraction. Covers
## smoothing overshoot and rounding so an edge never shows for a frame.
@export_range(0.0, 0.25, 0.005) var overscan_margin: float = 0.01

## How fast the bands chase the tilt, in units per second. Low feels weighty;
## high feels twitchy and shows up hand tremor.
@export_range(0.5, 20.0, 0.1) var smoothing: float = 5.0

## Multiplies the accelerometer vector before it is clamped to [-1, 1]. Only
## the phone path uses it; the pointer path is already normalised.
@export_range(0.05, 2.0, 0.01) var tilt_gain: float = 0.35

## Set false to pin every band at rest.
@export var enabled: bool = true

## How fast the phone path's neutral pose follows the way the player holds the
## handset, per second. Tilt is read against this, not against gravity, so any
## comfortable holding angle rests at zero deflection and only a change of
## angle moves the bands. Low keeps a deliberate tilt from being absorbed.
@export_range(0.05, 5.0, 0.05) var tilt_recenter: float = 0.6

## Rest offsets of each band (left, top, right, bottom), captured on the first
## frame that has real layout, so motion is always written as rest + offset
## and can never accumulate. Offsets rather than positions so the anchors keep
## doing their job: a band moved this way still follows its parent through a
## resize or a rotation, where a captured absolute position would go stale.
var _rest: Dictionary = {}

## Current smoothed deflection, each component in [-1, 1].
var _deflection: Vector2 = Vector2.ZERO

## The accelerometer reading the phone path treats as zero tilt, tracked
## toward the current reading at `tilt_recenter`.
var _neutral: Vector3 = Vector3.ZERO

## Whether `_neutral` has been seeded from a real reading yet.
var _has_neutral: bool = false


func _ready() -> void:
	# The motion is this script's only side effect; see the file header.
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	if not enabled:
		return
	if _rest.is_empty() and not _capture_rest():
		return
	_deflection = _deflection.lerp(_read_tilt(delta), clampf(smoothing * delta, 0.0, 1.0))
	_apply()


## The node holding the bands, or null when `bands_root` points nowhere.
func bands_parent() -> Control:
	return get_node_or_null(bands_root) as Control


## Grows the bands that need it, then records where every band rests, so
## motion is always written as rest + offset and can never accumulate.
## Returns false while layout has not produced real sizes yet -- capturing a
## rest position of zero would slam the whole diorama into the corner on the
## first frame that did have layout.
func _capture_rest() -> bool:
	var root := bands_parent()
	if root == null or root.size.x <= 0.0 or root.size.y <= 0.0:
		return false
	# Every band is checked before any is grown. Growing as it went, a band
	# still unsized further down the map would fail the capture after an
	# earlier one had grown, and the next frame would grow that one again.
	var bands := {}
	for name_key in depth_by_child:
		var band := root.get_node_or_null(NodePath(String(name_key))) as Control
		if band == null or band.size.x <= 0.0 or band.size.y <= 0.0:
			return false
		bands[name_key] = band
	var reach := required_reach()
	var captured := {}
	for name_key in bands:
		var band: Control = bands[name_key]
		if overscan_children.has(StringName(String(name_key))):
			_grow(band, reach)
		captured[name_key] = Vector4(band.offset_left, band.offset_top,
				band.offset_right, band.offset_bottom)
	_rest = captured
	return not _rest.is_empty()


## Pushes `band`'s offsets out by `reach` on every side, so it still covers
## its parent once it has travelled. Only ever called on a band named in
## `overscan_children`, and only in a running game.
func _grow(band: Control, reach: Vector2) -> void:
	band.offset_left -= reach.x
	band.offset_right += reach.x
	band.offset_top -= reach.y
	band.offset_bottom += reach.y


## How far the furthest-travelling band moves from rest. An overscanned band
## needs at least this much margin on each side.
##
## The fractional margin alone is not enough for the deepest band, which is
## the one most likely to be overscanned: at depth 1.0 a 1% margin buys a
## seventh of a pixel, and rounding can still show a hairline. SEAM_PAD adds
## an absolute floor on top, so the slack never depends on how deep the
## deepest band happens to be.
func required_reach() -> Vector2:
	var deepest := 0.0
	for name_key in depth_by_child:
		deepest = maxf(deepest, absf(float(depth_by_child[name_key])))
	return travel * deepest * (1.0 + overscan_margin) + SEAM_PAD


## Tilt as a vector in [-1, 1]: the accelerometer where there is one, the
## pointer otherwise.
func _read_tilt(delta: float) -> Vector2:
	var accel := Input.get_accelerometer()
	if not accel.is_zero_approx():
		# Read against the pose the player is holding, not against gravity.
		# Against gravity, pitch sat at a constant 5-10 m/s^2 at every normal
		# holding angle, so the clamp pinned it at full deflection and the
		# bands never answered a tilt. x is roll, z is pitch.
		if not _has_neutral:
			_neutral = accel
			_has_neutral = true
		else:
			_neutral = _neutral.lerp(accel, clampf(tilt_recenter * delta, 0.0, 1.0))
		var tilt := accel - _neutral
		return Vector2(
			clampf(tilt.x * tilt_gain, -1.0, 1.0),
			clampf(tilt.z * tilt_gain, -1.0, 1.0))
	var view := get_viewport()
	if view == null:
		return Vector2.ZERO
	var half: Vector2 = view.get_visible_rect().size * 0.5
	if half.x <= 0.0 or half.y <= 0.0:
		return Vector2.ZERO
	var centred := (view.get_mouse_position() - half) / half
	return Vector2(clampf(centred.x, -1.0, 1.0), clampf(centred.y, -1.0, 1.0))


## Writes this frame's position for every band.
func _apply() -> void:
	var root := bands_parent()
	if root == null:
		return
	for name_key in _rest:
		var band := root.get_node_or_null(NodePath(String(name_key))) as Control
		if band == null:
			continue
		var depth := float(depth_by_child.get(name_key, 0.0))
		var shift := -_deflection * travel * depth
		var rest: Vector4 = _rest[name_key]
		band.offset_left = rest.x + shift.x
		band.offset_top = rest.y + shift.y
		band.offset_right = rest.z + shift.x
		band.offset_bottom = rest.w + shift.y


## Test seam: drive the bands to a known deflection with no device, no input
## event and no smoothing. Returns false when layout is not ready yet.
func force_deflection(value: Vector2) -> bool:
	if _rest.is_empty() and not _capture_rest():
		return false
	_deflection = Vector2(clampf(value.x, -1.0, 1.0), clampf(value.y, -1.0, 1.0))
	_apply()
	return true
