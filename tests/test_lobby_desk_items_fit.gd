@tool
extends McpTestSuite

## The Lobby's seating follows the owner's reference picture
## (docs/superpowers/mockups/lobby-seating-reference-2026-09-30.jpg): where
## each seat's Portrait sits, and how every Hand_<Name> node -- a student's
## arms and desk items, one texture -- is sized and placed.
##
## Until 2026-09-30 this suite kept every desk item inside its desk's width,
## with three owner-sized exceptions. The picture replaced that rule: it
## draws both pictured students of a row at ONE scale (0.80 of the native
## art in the back row, 1.00 in the front), so every student in a row now
## wears that scale, and every student's arms and items sit at one place on
## its own body in every seat (since 2026-10-01); the front row's wider items
## still run past their desks and off the screen's edge exactly as the
## picture's do.
##
## The picture's numbers are mapped through K = 448 / 429 (game desk width
## over the picture's), anchored on each desk's back edge: spec and plan
## 2026-09-30-lobby-seating-and-planks. That pass anchored on the top of the
## chair back drawn into every desk plate, which is the same wood as the desk,
## so every seat sat one chair-height too high; since 2026-10-01 the edge is
## read from the plate's own pixels (spec 2026-10-01-lobby-seat-on-desk-edge).
##
## Measured from the packed scene's SceneState, so the Lobby is never
## instanced. A Hand_* node draws its texture at native size (stretch_mode 3)
## centred in its box, then scales about pivot_offset; a negative x scale
## mirrors it.
##
## Must be @tool, and no test here may be a coroutine.

## The scene under test.
const SCENE := "res://Scenes/Lobby/Lobby.tscn"
## The 1080x1920 plate every desk and hand slot is laid out in.
const CLASSROOM := "World/Classroom"
## The classroom's size; a hand must draw at least partly inside it.
const CLASSROOM_SIZE := Vector2(1080, 1920)
## Four slots, each carrying one Hand_* node per character.
const EXPECTED_HANDS := 24
## Picture pixels to game pixels: game desk width over the picture's.
const K := 448.0 / 429.0
## Slack for the scene's three-decimal offsets, in pixels.
const TOLERANCE := 0.5
## Slack on a scale.
const SCALE_TOLERANCE := 0.002
## The portraits' native side, px.
const PORTRAIT_SIDE := 1280.0
## Reads a texture's pixels whatever its import compression.
const TexturePixels := preload("res://tests/texture_pixels.gd")
## A desk plate row with an opaque run wider than this is desk, not chair:
## the chair backs drawn into the plates run at most 223 px, and each desk's
## first row at least 303.
const DESK_MIN_RUN := 260
## Slack between a seat's Portrait bottom and its desk's back edge, px; the
## picture's own gap is 1.25 (Thea's square ends at 811.8, her desk at 813).
const EDGE_TOLERANCE := 1.5

## What the picture shows in each seat. anchor_picture / anchor_game are one
## point in each: vertically the desk's back edge; horizontally, in the front
## row, the desk's inner edge, and in the back row the student's own centre
## line -- the portrait's centre in the picture, the desk top's centre in the
## game (test_lobby_layout keeps the back seats centred on their desks, an
## owner rule the picture's looser desk art does not overrule). hand_origin
## and portrait_origin are where the native texture's pixel (0, 0) lands in
## the picture. "desk" is the seat's desk plate node.
const SEATS := {
	"Slot1": {
		"portraits": "StudentPortraitsContainer_Back/Slot1", "hands": "StudentHandsContainer_Back/Slot1", "desk": "Meja_KiriAtas",
		"anchor_picture": Vector2(253.8, 523.0), "anchor_game": Vector2(271.26, 400.045),
		"student": "Andi", "hand_scale": 0.80, "hand_origin": Vector2(48.2, 499.0), "mirrored": false,
		"portrait_scale": 0.20, "portrait_origin": Vector2(125.8, 267.4),
	},
	"Slot2": {
		"portraits": "StudentPortraitsContainer_Back/Slot2", "hands": "StudentHandsContainer_Back/Slot2", "desk": "Meja_KananAtas",
		"anchor_picture": Vector2(826.2, 523.5), "anchor_game": Vector2(803.74, 400.0),
		"student": "Citra", "hand_scale": 0.80, "hand_origin": Vector2(630.0, 462.0), "mirrored": false,
		"portrait_scale": 0.20, "portrait_origin": Vector2(698.2, 267.4),
	},
	"Slot3": {
		"portraits": "StudentPortraitsContainer_Front/Slot3", "hands": "StudentHandsContainer_Front/Slot3", "desk": "Meja_KiriBawah",
		"anchor_picture": Vector2(481.0, 813.0), "anchor_game": Vector2(462, 766),
		"student": "Marcel", "hand_scale": 1.00, "hand_origin": Vector2(-41.0, 717.0), "mirrored": true,
		"portrait_scale": 0.25, "portrait_origin": Vector2(67.8, 491.8),
	},
	"Slot4": {
		"portraits": "StudentPortraitsContainer_Front/Slot4", "hands": "StudentHandsContainer_Front/Slot4", "desk": "Meja_KananBawah",
		"anchor_picture": Vector2(599.0, 813.0), "anchor_game": Vector2(622, 766),
		"student": "Thea", "hand_scale": 1.00, "hand_origin": Vector2(598.0, 727.0), "mirrored": false,
		"portrait_scale": 0.25, "portrait_origin": Vector2(692.2, 491.8),
	},
}
## The front desks' inner edges, classroom px: a front-row item stays on its
## desk's side of this line, so the aisle stays clear.
const FRONT_INNER_EDGE := {"Slot3": 462.0, "Slot4": 622.0}

## Where Doni's and Shinta's arms and items sit on their own body, in body
## sides: x from the body's centre in the art's own frame (a mirrored hand
## flips it), y from the body's top. Neither is in the owner's picture; this
## is each one's mean placement in the scene before the picture pass
## (4ec87bc0^), where each already sat the same in every seat.
const OWN_PLACE := {"Doni": Vector2(0.010120, 1.166307), "Shinta": Vector2(0.041973, 1.071228)}
## The Hand_* nodes drawn mirrored, by hands slot: the picture mirrors
## Marcel in Slot3; the rest keep the mirroring they always had.
const MIRRORED := {
	"StudentHandsContainer_Back/Slot2": ["Andi"],
	"StudentHandsContainer_Front/Slot3": ["Marcel"],
	"StudentHandsContainer_Front/Slot4": ["Andi", "Doni", "Marcel"],
}


## Written properties per node, keyed by path under the scene root.
var _props: Dictionary
## Each seat's desk back edge in classroom px, read once from the plates.
var _edges: Dictionary


## The runner's name for this suite.
func suite_name() -> String:
	return "lobby_desk_items_fit"


## Reads the scene's node properties and the desks' back edges once for
## every test.
func suite_setup(_ctx: Dictionary) -> void:
	_props = read_scene_props(load(SCENE) as PackedScene)
	_edges = {}
	for name: String in SEATS:
		_edges[name] = _desk_back_edge(SEATS[name]["desk"])


## Every node's written properties, keyed by its path under the root.
static func read_scene_props(scene: PackedScene) -> Dictionary:
	var state := scene.get_state()
	var out := {}
	for i in state.get_node_count():
		var props := {}
		for j in state.get_node_property_count(i):
			props[state.get_node_property_name(i, j)] = state.get_node_property_value(i, j)
		out[String(state.get_node_path(i)).trim_prefix("./")] = props
	return out


## One node's properties, by its path under the classroom.
func _node(path: String) -> Dictionary:
	return _props["%s/%s" % [CLASSROOM, path]]


## A picture point, in game pixels, for `seat`.
static func to_game(seat: Dictionary, picture: Vector2) -> Vector2:
	return (seat["anchor_game"] as Vector2) + (picture - (seat["anchor_picture"] as Vector2)) * K


## A slot's rect in classroom pixels: its own offsets inside its container's.
func _slot_rect(slot_path: String) -> Rect2:
	var container: Dictionary = _node(slot_path.get_base_dir())
	var slot: Dictionary = _node(slot_path)
	var origin := Vector2(float(container.get("offset_left", 0.0)) + float(slot.get("offset_left", 0.0)),
		float(container.get("offset_top", 0.0)) + float(slot.get("offset_top", 0.0)))
	var size := Vector2(float(slot.get("offset_right", 0.0)) - float(slot.get("offset_left", 0.0)),
		float(slot.get("offset_bottom", 0.0)) - float(slot.get("offset_top", 0.0)))
	return Rect2(origin, size)


## The first row of `plate`'s texture whose longest opaque run is wider than
## DESK_MIN_RUN, in classroom px (the plate's offset_top added; the plates
## are never stretched vertically). A colour or alpha bounding box would start
## at the chair back's top instead.
func _desk_back_edge(plate: String) -> float:
	var props := _node(plate)
	var img := TexturePixels.of(props["texture"] as Texture2D)
	if img.is_compressed():
		img.decompress()
	for y in img.get_height():
		var run := 0
		for x in img.get_width():
			run = run + 1 if img.get_pixel(x, y).a > 0.5 else 0
			if run > DESK_MIN_RUN:
				return y + float(props.get("offset_top", 0.0))
	return INF


## A slot's Portrait rect in classroom pixels.
func _portrait_rect(slot_path: String) -> Rect2:
	var slot := _slot_rect(slot_path)
	var p := _node("%s/Portrait" % slot_path)
	return Rect2(slot.position + Vector2(p.get("offset_left", 0.0), p.get("offset_top", 0.0)),
		slot.size + Vector2(float(p.get("offset_right", 0.0)) - float(p.get("offset_left", 0.0)),
			float(p.get("offset_bottom", 0.0)) - float(p.get("offset_top", 0.0))))


## Where a Hand_* node draws its texture's centre, in classroom pixels.
func _hand_centre(slot_path: String, hand: Dictionary) -> Vector2:
	var slot := _slot_rect(slot_path)
	var a0 := Vector2(hand.get("anchor_left", 0.0), hand.get("anchor_top", 0.0))
	var a1 := Vector2(hand.get("anchor_right", 0.0), hand.get("anchor_bottom", 0.0))
	var o0 := Vector2(hand.get("offset_left", 0.0), hand.get("offset_top", 0.0))
	var o1 := Vector2(hand.get("offset_right", 0.0), hand.get("offset_bottom", 0.0))
	var box := Rect2(slot.position + a0 * slot.size + o0, (a1 - a0) * slot.size + o1 - o0)
	var scale: Vector2 = hand.get("scale", Vector2.ONE)
	var pivot: Vector2 = hand.get("pivot_offset", Vector2.ZERO)
	return box.position + pivot + (box.size / 2.0 - pivot) * scale


## The pictured student's target in `seat`: [scale, drawn centre].
static func pictured_target(seat: Dictionary) -> Array:
	var tex := load("res://Assets/Images/MuridPortrait/TanganItems/%s_Table.png" % seat["student"]) as Texture2D
	var scale: float = float(seat["hand_scale"]) * K
	return [scale, to_game(seat, seat["hand_origin"]) + tex.get_size() * scale / 2.0]


## The widest desk art `student` can wear: the Lobby swaps each skin's table
## image onto the same node, at the same transform, so a placement made for
## the scene's texture only holds while every skin's art is that width.
static func widest_hand_art(student: String) -> float:
	var widest := 0.0
	for id: String in StudentSkins.SKINS[student]:
		var tex := load(StudentSkins.layer_path(student, id, "hand")) as Texture2D
		widest = maxf(widest, tex.get_width())
	return widest


## Where `student`'s arms and items sit on its own body, in OWN_PLACE's
## frame: read from the picture for the four it shows, else OWN_PLACE.
func _place_on_body(student: String) -> Vector2:
	for name: String in SEATS:
		var seat: Dictionary = SEATS[name]
		if seat["student"] != student:
			continue
		var side: float = PORTRAIT_SIDE * float(seat["portrait_scale"]) * K
		var top_left := to_game(seat, seat["portrait_origin"])
		var centre: Vector2 = pictured_target(seat)[1]
		var mirror := -1.0 if bool(seat["mirrored"]) else 1.0
		return Vector2((centre.x - top_left.x - side / 2.0) / side * mirror, (centre.y - top_left.y) / side)
	return OWN_PLACE[student]


func test_each_seats_portrait_sits_where_the_picture_puts_it() -> void:
	for name: String in SEATS:
		var seat: Dictionary = SEATS[name]
		var got := _portrait_rect(seat["portraits"])
		var side: float = PORTRAIT_SIDE * float(seat["portrait_scale"]) * K
		var want := Rect2(to_game(seat, seat["portrait_origin"]), Vector2(side, side))
		assert_true(got.position.distance_to(want.position) < TOLERANCE and got.end.distance_to(want.end) < TOLERANCE,
			"%s Portrait is %s, the picture puts it at %s" % [name, str(got), str(want)])


func test_the_pictured_students_match_the_picture() -> void:
	for name: String in SEATS:
		var seat: Dictionary = SEATS[name]
		var hand: Dictionary = _node("%s/Hand_%s" % [seat["hands"], seat["student"]])
		var target := pictured_target(seat)
		var scale: Vector2 = hand.get("scale", Vector2.ONE)
		assert_true(absf(absf(scale.x) - float(target[0])) < SCALE_TOLERANCE and absf(scale.y - float(target[0])) < SCALE_TOLERANCE,
			"%s in %s is scaled %s, the picture says %.4f" % [seat["student"], name, str(scale), target[0]])
		assert_eq(scale.x < 0.0, bool(seat["mirrored"]), "%s in %s is mirrored only where the picture mirrors" % [seat["student"], name])
		var centre := _hand_centre(seat["hands"], hand)
		assert_true(centre.distance_to(target[1]) < TOLERANCE,
			"%s in %s draws at %s, the picture puts it at %s" % [seat["student"], name, str(centre), str(target[1])])


## The picture draws both students of a row at one scale, so the whole row
## wears it. Every student's arms and items sit at one place on its own body
## in every seat, mirrored with the art. Until 2026-10-01 an unpictured
## student kept its old x and only rose with its row, so its hands drifted
## off the smaller bodies. In the front row an item wider than its desk is
## still pushed off the screen's edge, never over the aisle. The pictured
## student in its own seat sits exactly where the picture puts it.
func test_every_student_wears_its_rows_scale_and_sits_the_same_on_its_body() -> void:
	var checked := 0
	for name: String in SEATS:
		var seat: Dictionary = SEATS[name]
		var row_scale: float = float(seat["hand_scale"]) * K
		var body := _portrait_rect(seat["portraits"])
		var prefix := "%s/%s/Hand_" % [CLASSROOM, seat["hands"]]
		for path: String in _props:
			if not path.begins_with(prefix):
				continue
			checked += 1
			var student := path.trim_prefix(prefix)
			var hand: Dictionary = _props[path]
			var scale: Vector2 = hand.get("scale", Vector2.ONE)
			assert_true(absf(absf(scale.x) - row_scale) < SCALE_TOLERANCE and absf(scale.y - row_scale) < SCALE_TOLERANCE,
				"%s in %s is scaled %s, its row wears %.4f" % [student, name, str(scale), row_scale])
			var mirrored: bool = (MIRRORED.get(seat["hands"], []) as Array).has(student)
			assert_eq(scale.x < 0.0, mirrored, "%s in %s is mirrored only where it always was" % [student, name])
			var place := _place_on_body(student)
			var want := Vector2(body.get_center().x + place.x * body.size.x * (-1.0 if mirrored else 1.0),
				body.position.y + place.y * body.size.y)
			var half: float = (hand["texture"] as Texture2D).get_width() * row_scale / 2.0
			assert_eq(widest_hand_art(student), float((hand["texture"] as Texture2D).get_width()),
				"%s has a skin whose table art is another width: place it for the widest" % student)
			# The picture governs its own student's seat, aisle included.
			if FRONT_INNER_EDGE.has(name) and student != seat["student"]:
				var edge: float = FRONT_INNER_EDGE[name]
				want.x = minf(want.x, edge - half) if edge < CLASSROOM_SIZE.x / 2.0 else maxf(want.x, edge + half)
			var centre := _hand_centre(seat["hands"], hand)
			assert_true(centre.distance_to(want) < TOLERANCE,
				"%s in %s draws at %s, expected %s (its place on its body, kept off the aisle)" % [student, name, str(centre), str(want)])
	assert_eq(checked, EXPECTED_HANDS, "every slot's Hand_* nodes were found")


## Front-row items may run past their desk and off the screen, as the
## picture's do, but no item may leave the classroom altogether.
func test_no_desk_item_leaves_the_classroom() -> void:
	for name: String in SEATS:
		var seat: Dictionary = SEATS[name]
		var prefix := "%s/%s/Hand_" % [CLASSROOM, seat["hands"]]
		for path: String in _props:
			if not path.begins_with(prefix):
				continue
			var hand: Dictionary = _props[path]
			var size: Vector2 = (hand["texture"] as Texture2D).get_size() * (hand.get("scale", Vector2.ONE) as Vector2).abs()
			var drawn := Rect2(_hand_centre(seat["hands"], hand) - size / 2.0, size)
			var inside := drawn.intersection(Rect2(Vector2.ZERO, CLASSROOM_SIZE))
			assert_true(inside.get_area() >= drawn.get_area() * 0.75,
				"%s in %s draws %s, more than a quarter outside the classroom" % [path.get_file(), name, str(drawn)])


## The picture is anchored on each desk's real back edge, read from the
## plate's pixels, so a moved plate or new desk art cannot leave the seats
## on a stale number.
func test_each_seat_is_anchored_on_its_desks_back_edge() -> void:
	for name: String in SEATS:
		var seat: Dictionary = SEATS[name]
		var plate := _node(seat["desk"])
		assert_eq((plate.get("scale", Vector2.ONE) as Vector2).y, 1.0,
			"%s is not stretched vertically" % seat["desk"])
		assert_true(absf((seat["anchor_game"] as Vector2).y - float(_edges[name])) < 0.01,
			"%s is anchored at y=%.3f, its desk's back edge is at %.3f"
				% [name, (seat["anchor_game"] as Vector2).y, _edges[name]])


## As in the picture, each seat's body ends on its desk's back edge, so the
## arms rest on the desk top and the body hides the chair behind it.
func test_each_seats_portrait_ends_on_its_desks_back_edge() -> void:
	for name: String in SEATS:
		var bottom := _portrait_rect(SEATS[name]["portraits"]).end.y
		assert_true(absf(bottom - float(_edges[name])) <= EDGE_TOLERANCE,
			"%s's Portrait ends at y=%.2f, its desk's back edge is at %.2f"
				% [name, bottom, _edges[name]])
