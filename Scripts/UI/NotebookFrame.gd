@tool
class_name NotebookFrame
extends Container

## The notebook popup frame (2026-09-28 UI depth pass;
## docs/superpowers/specs/2026-09-28-ui-depth-pass-design.md). A brown
## hardcover on a lip, a ruled cream page with spiral rings, up to three
## tabs, a stitched sticker title, washi tape and a round close.
##
## Host content: drop your nodes in as children of the frame. Every child
## except the Chrome node is laid into content_rect(); Chrome -- the
## decoration, authored in NotebookFrame.tscn -- stays full-size and, being
## the first child, behind. A dialog is the same frame with no tabs, four
## rings and no well. Nothing here is built at runtime: the three tabs and
## eight rings exist in the scene and are only shown or hidden.

## Emitted when tab `index` is pressed; it has already become active.
signal tab_selected(index: int)
## Emitted when the round close button is pressed.
signal close_pressed

## Most tabs the frame carries: Tab0..Tab2 in the scene.
const MAX_TABS := 3
## Most rings the frame carries: Ring0..Ring7 in the scene.
const MAX_RINGS := 8
## Rings shown by default.
const DEFAULT_RINGS := 7
## Space around the host content by default: left, top, right, bottom, px.
## The left clears the rings and margin line, the top the sticker.
const DEFAULT_PADDING := Vector4i(72, 120, 40, 48)
## How far the sunken well reaches past the content on each side, px.
const WELL_BLEED := 16
## Meta key on the decoration node, which sort_now() keeps full-size.
const CHROME_META := &"notebook_chrome"
## The washi tape's default tint: sunflower, a little see-through.
const DEFAULT_TAPE := Color("FFC93CCC")

## The title on the stitched sticker.
@export var title_text: String = "":
	set(value):
		title_text = value
		_refresh()
## Tab names, left to right; up to MAX_TABS are shown. Empty hides the strip.
@export var tabs: PackedStringArray = PackedStringArray():
	set(value):
		tabs = value
		_refresh()
## Index of the active, gold tab.
@export var active_tab: int = 0:
	set(value):
		active_tab = value
		_refresh()
## How many spiral rings show down the page's left edge.
@export_range(0, MAX_RINGS) var ring_count: int = DEFAULT_RINGS:
	set(value):
		ring_count = value
		_refresh()
## Whether the host content sits in a sunken well.
@export var show_well: bool = true:
	set(value):
		show_well = value
		_refresh()
## Whether a strip of washi tape pins the bottom-left corner.
@export var show_tape: bool = true:
	set(value):
		show_tape = value
		_refresh()
## The washi tape's tint.
@export var tape_color: Color = DEFAULT_TAPE:
	set(value):
		tape_color = value
		_refresh()
## Whether the round close button shows on the top-right corner.
@export var show_close: bool = true:
	set(value):
		show_close = value
		_refresh()
## Space between the frame's edges and the host content: x left, y top,
## z right, w bottom, px.
@export var content_padding: Vector4i = DEFAULT_PADDING:
	set(value):
		content_padding = value
		queue_sort()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_wire()
		_refresh()
	elif what == NOTIFICATION_SORT_CHILDREN:
		sort_now()


## Where host content goes, in the frame's own coordinates.
func content_rect() -> Rect2:
	var pad := content_padding
	return Rect2(Vector2(pad.x, pad.y), size - Vector2(pad.x + pad.z, pad.y + pad.w))


## Lay out every child now: Chrome over the whole frame, host content into
## content_rect(), and the well around it.
func sort_now() -> void:
	for child in get_children():
		var control := child as Control
		if control == null:
			continue
		if control.has_meta(CHROME_META):
			fit_child_in_rect(control, Rect2(Vector2.ZERO, size))
		else:
			fit_child_in_rect(control, content_rect())
	var well := get_node_or_null("Chrome/Well") as Control
	if well != null:
		var r := content_rect().grow(WELL_BLEED)
		well.position = r.position
		well.size = r.size
	_spread_rings()


## Re-gap the shown rings so they always span the Rings box top to bottom,
## instead of sitting bunched at the authored separation and alignment --
## which only look right at the full MAX_RINGS count. A layout-only constant
## override, allowed alongside the ThemeFactory-variation rule.
func _spread_rings() -> void:
	var rings := get_node_or_null("Chrome/Rings") as BoxContainer
	if rings == null:
		return
	var shown := mini(ring_count, MAX_RINGS)
	if shown < 2:
		return
	var ring_h := (rings.get_child(0) as Control).get_combined_minimum_size().y
	var gap := (rings.size.y - shown * ring_h) / (shown - 1)
	rings.add_theme_constant_override(&"separation", maxi(floori(gap), 0))


func _wire() -> void:
	for i in MAX_TABS:
		_tab(i).pressed.connect(_on_tab_pressed.bind(i))
	(get_node("Chrome/Close") as Button).pressed.connect(_on_close_pressed)


func _refresh() -> void:
	if get_node_or_null("Chrome") == null:
		return
	(get_node("Chrome/Sticker/Title") as Label).text = title_text
	(get_node("Chrome/Tabs") as Control).visible = not tabs.is_empty()
	for i in MAX_TABS:
		var tab := _tab(i)
		tab.visible = i < tabs.size()
		if tab.visible:
			tab.text = tabs[i]
			tab.theme_type_variation = &"NotebookTabActive" if i == active_tab else &"NotebookTab"
	for i in MAX_RINGS:
		(get_node("Chrome/Rings/Ring%d" % i) as CanvasItem).visible = i < ring_count
	(get_node("Chrome/Well") as CanvasItem).visible = show_well
	var tape := get_node("Chrome/Tape") as CanvasItem
	tape.visible = show_tape
	tape.self_modulate = tape_color
	(get_node("Chrome/Close") as CanvasItem).visible = show_close
	queue_sort()


func _tab(index: int) -> Button:
	return get_node("Chrome/Tabs/Tab%d" % index) as Button


func _on_tab_pressed(index: int) -> void:
	active_tab = index
	tab_selected.emit(index)


func _on_close_pressed() -> void:
	close_pressed.emit()
