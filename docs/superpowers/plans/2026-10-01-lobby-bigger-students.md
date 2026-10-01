# Lobby students at their old size, desk items unchanged — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Students and their arms return to their pre-2026-09-30 size while desk items keep today's size and place.

**Architecture:** Each student's combined desk art is split into arms and items layers on the same canvas. The scene gets an `Items_<Name>` node beside every `Hand_<Name>` (arms), and each seat grows about the point where the body meets the desk. Code shows the items with the arms; tests pin seats, arms, items and art registration.

**Tech Stack:** Godot 4.6, GDScript, McpTestSuite via godot-ai `test_run`.

Spec: `docs/superpowers/specs/2026-10-01-lobby-bigger-students-design.md`.

## Global Constraints

- Work only in `C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project/.claude/worktrees/lobby-bigger-students/` (branch `feat/lobby-bigger-students`). Never edit the main checkout.
- Tests: `@tool`, no coroutines, a `##` doc line on every new const/func/var. TAB indentation.
- Seat sides: back 365, front 400 px. Items keep the exact 2026-10-01 hand transforms. Arms follow the body with no aisle clamp. Items keep the aisle clamp, except the pictured student in its own seat.
- Commits: Conventional Commits with a scope, written to a file and passed to `git commit -F`, ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

### Task 1 (controller, done): art and scene

The art files, `.import` settings and `Lobby.tscn` rewrite are produced by the controller with the editor closed (scratchpad scripts; numbers in the spec).

### Task 2: code and tests

**Files:** `Scripts/Skins/StudentSkins.gd`, `Scripts/Lobby/Lobby.gd`, `tests/test_student_skins.gd`, `tests/test_lobby_skins.gd`, `tests/test_lobby_desk_items_fit.gd`.

- [ ] **StudentSkins.gd** `layer_path`, `hand` layer:
  - default: `"res://Assets/Images/MuridPortrait/TanganItems/%s_Arms.png" % student_name`
  - skin: `folder + "%s_arms_%s.png" % [lower, id]`

  Update any doc comment that says the hand layer is the desk art/table: it is the student's arms. Desk items are one `TanganItems/<Name>_Items.png` per student, shared by every skin, set in the Lobby scene.
- [ ] **Lobby.gd**:
  - Add, under `HAND_FALLBACK_NAME`:

```gdscript
## Name prefix of a student's desk items node, the sibling drawn under its
## Hand_* (arms) node. Items are shared by every skin and keep their own
## authored transform, so a seat can grow the student without growing the desk.
const ITEMS_NODE_PREFIX := "Items_"
```

  - Make `_show_hand_for` `static`. In its loop, also hide every child whose name begins with `ITEMS_NODE_PREFIX`. After `chosen.show()`, show the chosen node's `Items_<who>` sibling when it exists:

```gdscript
	if chosen != null:
		chosen.show()
		var items := h_slot.get_node_or_null(NodePath(ITEMS_NODE_PREFIX + String(chosen.name).substr(HAND_NODE_PREFIX.length())))
		if items != null:
			(items as CanvasItem).show()
```

  - Rewrite `_show_hand_for`'s doc comment: each slot has, per student, an arms node (`Hand_<Name>`) and an items node (`Items_<Name>`), both authored in the scene. The function only picks which pair is visible and never writes position, size or scale. Keep the fallback paragraph. Also fix `HAND_FALLBACK_NAME`'s doc: Doni's arms are just two hands at the desk edge, so a wrong match still reads as a plain desk.
  - `_apply_hand_skins` stays as is (it only touches `Hand_*`). Append to its doc: `Items_* nodes are never touched: skins change arms, not desk items.`
- [ ] **test_student_skins.gd**: change the expected `hand` paths to `.../TanganItems/Thea_Arms.png` and `.../Skins/Andi/andi_arms_skin1.png` (three asserts: lines that end in `Thea_Table.png` / `andi_table_skin1.png`).
- [ ] **test_lobby_skins.gd** `test_hand_skins_swap_and_restore`: `Andi_Table.png` → `Andi_Arms.png`; `andi_table_skin1.png` → `andi_arms_skin1.png`. Add a test:

```gdscript
## Showing a student shows its arms and its desk items together, and only
## those; a name with no node of its own shows the fallback student's pair.
func test_show_hand_for_shows_the_arms_and_items_pair() -> void:
	var lobby_script: GDScript = load("res://Scripts/Lobby/Lobby.gd")
	var slot := Control.new()
	track(slot)
	for n: String in ["Hand_Andi", "Items_Andi", "Hand_Doni", "Items_Doni"]:
		var c := TextureRect.new()
		c.name = n
		slot.add_child(c)
	lobby_script._show_hand_for(slot, "Andi")
	var shown: Array[String] = []
	for c in slot.get_children():
		if (c as CanvasItem).visible:
			shown.append(String(c.name))
	assert_eq(shown, ["Hand_Andi", "Items_Andi"] as Array[String])
	lobby_script._show_hand_for(slot, "Murid1")
	shown.clear()
	for c in slot.get_children():
		if (c as CanvasItem).visible:
			shown.append(String(c.name))
	assert_eq(shown, ["Hand_Doni", "Items_Doni"] as Array[String])
```

- [ ] **test_lobby_desk_items_fit.gd** (read it whole first):
  1. Header: add a paragraph saying that since 2026-10-01 (owner's pick) each seat grows the picture's student to the size before the picture pass (back 365, front 400 px) about the bottom centre of its Portrait square, where the body meets the desk. `Hand_<Name>` is now the arms layer and grows with the body. `Items_<Name>` holds the desk items at exactly the earlier placement.
  2. Add consts and helpers after `EDGE_TOLERANCE`:

```gdscript
## Each row's Portrait square side since 2026-10-01, px: the sizes before the
## picture pass. The picture's square grows to it about its bottom centre.
const SEAT_SIDE := {"Back": 365.0, "Front": 400.0}
```

  and, after `to_game`:

```gdscript
## The picture's Portrait square for `seat`, before the seat grows.
static func picture_square(seat: Dictionary) -> Rect2:
	var side: float = PORTRAIT_SIDE * float(seat["portrait_scale"]) * K
	return Rect2(to_game(seat, seat["portrait_origin"]), Vector2(side, side))


## How much `seat` grows the picture's student: its row's SEAT_SIDE over the
## picture's square.
static func seat_factor(seat: Dictionary) -> float:
	var row := "Back" if String(seat["portraits"]).contains("_Back") else "Front"
	return float(SEAT_SIDE[row]) / picture_square(seat).size.x


## `r` grown by `f` about its bottom centre, where a body meets its desk.
static func grow_about_bottom(r: Rect2, f: float) -> Rect2:
	var s := r.size * f
	return Rect2(Vector2(r.get_center().x - s.x / 2.0, r.end.y - s.y), s)
```

  3. `pictured_target`: load `%s_Arms.png` instead of `%s_Table.png` (same canvas). Its result stays the picture's (ungrown) target.
  4. `test_each_seats_portrait_sits_where_the_picture_puts_it`: `want := grow_about_bottom(picture_square(seat), seat_factor(seat))` (delete the old side/want lines).
  5. `test_the_pictured_students_match_the_picture`: the expected scale is `float(target[0]) * seat_factor(seat)`, and the expected centre is `pivot + (target[1] - pivot) * seat_factor(seat)` with `pivot := Vector2(picture_square(seat).get_center().x, picture_square(seat).end.y)`. Keep the mirroring assert.
  6. Split `test_every_student_wears_its_rows_scale_and_sits_the_same_on_its_body` into two tests sharing one helper:

```gdscript
## Where `student`'s art centre belongs on `body` (a Portrait rect), mirrored
## with the art: the body-relative place of _place_on_body.
func _on_body(student: String, body: Rect2, mirrored: bool) -> Vector2:
	var place := _place_on_body(student)
	return Vector2(body.get_center().x + place.x * body.size.x * (-1.0 if mirrored else 1.0),
		body.position.y + place.y * body.size.y)
```

   - `test_every_arms_layer_grows_with_its_body`: for every `Hand_*` in every seat (24), check:
     - scale is `hand_scale * K * seat_factor(seat)` (abs on x);
     - mirroring is per `MIRRORED`;
     - the `widest_hand_art` guard holds;
     - the centre is `_on_body(student, _portrait_rect(seat["portraits"]), mirrored)` within TOLERANCE, with no aisle clamp.

     Doc comment: the arms are the student's own and sit at one place on the grown body; the aisle rule is for desk items, so the arms are never pushed off the body.
   - `test_every_items_layer_keeps_its_desk_place`: for every `Hand_*` in every seat (24 found):
     - an `Items_<student>` exists in the same slot, and its `_props` key comes before the `Hand_` key in `_props.keys()` (drawn under);
     - its scale is `hand_scale * K` with the same sign as the arms' x scale;
     - its centre is `_on_body(student, grow_about_bottom(body, 1.0 / seat_factor(seat)), mirrored)`, then the old aisle clamp (`FRONT_INNER_EDGE`, half width from the items texture width × `hand_scale * K`), except for the pictured student in its own seat, within TOLERANCE;
     - its texture's size equals every skin's arms texture size for that student (`StudentSkins.layer_path(student, id, "hand")`), with the message `"%s's items and %s arms are on different canvases"`.

     Doc comment: the desk items keep the size and place they had before the seat grew; they share the arms' canvas, so every skin's arms land on them.
  7. `test_no_desk_item_leaves_the_classroom`: check both `Hand_` and `Items_` nodes (prefix loop over both).
  8. Delete anything left unused. Keep `test_each_seat_is_anchored_on_its_desks_back_edge` and `test_each_seats_portrait_ends_on_its_desks_back_edge` unchanged.

- [ ] Do not run tests (the controller does). Commit with `feat(lobby): split desk art into arms and items; grow the class to its old size` only after the controller confirms; for now leave the changes uncommitted and report.
