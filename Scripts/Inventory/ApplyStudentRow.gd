@tool
class_name ApplyStudentRow
extends StudentCardButton

## One selectable student on ApplyItemScreen, wearing the real DaySummary
## card (2026-09-12 event-cards spec, section 1.5). The content is unchanged
## from the old checkbox row: only the stats the item boosts are shown,
## picking the card previews the gain, a stat already at 100 reads MAKS, and
## a student too tired to benefit shows LELAH and cannot be picked.

## Fired whenever the player picks or un-picks this student.
signal selection_changed

## Logical boost name -> the roster Dictionary key it writes. Fixed mapping:
## akademis1=akademis, akademis2=seni_budaya, akademis3=olahraga,
## kepribadian1=mood, kepribadian2=energy (the project's canonical keys).
const KEY := {
	"akademis": "akademis1", "seni_budaya": "akademis2", "olahraga": "akademis3",
	"mood": "kepribadian1", "energy": "kepribadian2",
}

## kepribadian2 (energy) at or below this forces "Izin" -- such a student
## cannot take the item, so the card cannot be picked.
@export var tired_energy_threshold: float = 5.0

## Boost key -> a schedule category that carries a DesignTokens accent, used to
## tint the picked card. First boosted stat wins.
const _STAT_TO_CATEGORY := {
	"akademis": "Akademis", "seni_budaya": "SeniBudaya", "olahraga": "Olahraga",
	"mood": "Istirahat", "energy": "Libur",
}

## Faint diagonal stripe decoration behind the card content, built once.
static var _stripe_tex: ImageTexture = null

## The LELAH chip, authored under Card. Tinted state_danger at setup.
@onready var lelah_chip: Control = get_node_or_null("Card/LelahChip") as Control
## The coloured, patterned header band and its parts.
@onready var _header: Control = get_node_or_null("Header") as Control
@onready var _header_panel: PanelContainer = get_node_or_null("Header/HeaderPanel") as PanelContainer
@onready var _header_stripes: TextureRect = get_node_or_null("Header/HeaderStripes") as TextureRect
@onready var _header_name: Label = get_node_or_null("Header/HeaderName") as Label

## Header band height in the card's own design space (scaled to fit like the
## rest of the card art).
const HEADER_DESIGN_H := 104.0

## Where the avatar sits in this row's 410-tall design box. The hosted
## DaySummaryStudentRow moved its avatar 76 px down for its own name band
## (2026-09-19, PR #53's ID card); this row hides that band and draws its
## own header, so it puts the avatar back beside the restacked bars.
const AVATAR_TOP := 52.0
## The avatar's bottom edge in the same box.
const AVATAR_BOTTOM := 338.0
## The hosted card's own chrome, hidden because this row's stylebox and
## Header replace it.
const HOSTED_CHROME := ["CardBg", "HeaderBand"]

## The roster entry this row stands for.
var student: Dictionary = {}
var _boosts: Dictionary = {}
## True when this student is too tired to take the item (kept so the stock cap
## never re-enables a card that LELAH already disabled).
var _tired := false
## Each visible bar -> its pre-boost value, captured before any preview so the
## apply-time rise can start from the real current fill.
var _bar_current: Dictionary = {}
## While a student is picked, one solid "current" overlay bar per visible bar,
## drawn over the translucent ghost. Entries: {bar, overlay}.
var _overlays: Array = []


## Fill the card from a roster entry and the item's non-zero boosts. Call
## after the row is in the tree: the card's parts are only ready then.
func setup(p_student: Dictionary, boosts: Dictionary) -> void:
	student = p_student
	_boosts = {}
	for k in boosts:
		if int(boosts[k]) != 0:
			_boosts[k] = int(boosts[k])
	var sd: StudentData = GameState.student_data_from_dict(student)
	card.setup_current_row(sd)
	card.show_only(_boosts.keys())
	_relayout_bars()
	_capture_bar_current()
	_tired = float(student.get("kepribadian2", 100.0)) <= tired_energy_threshold
	lelah_chip.visible = _tired
	if _tired:
		lelah_chip.self_modulate = DesignTokens.load_default().state_danger
	set_selectable(not _tired)
	_decorate_card()


## Grey this card out when the item has run out (as many students picked as
## copies owned). A tired card stays disabled regardless; a picked card is
## never capped.
func apply_cap(capped: bool) -> void:
	if _tired or is_selected():
		return
	set_selectable(not capped)


## Dim the header band along with the hosted card so a disabled/capped row
## reads as unavailable across the whole card, not just its body.
func set_selectable(on: bool) -> void:
	super.set_selectable(on)
	if _header != null:
		_header.modulate.a = 1.0 if on else 0.45


## Swap the shared card frame for a bright paper card the mentor is happy
## with: hide the hosted card's HOSTED_CHROME and give this wrapper button its own
## cream stylebox, with a bold accent border when picked. The accent is the
## first boosted stat's colour, so the pick reads in the item's own hue.
func _decorate_card() -> void:
	var tokens := DesignTokens.load_default()
	var accent: Color = tokens.text_secondary
	for k in _boosts:
		var cat: String = _STAT_TO_CATEGORY.get(k, "")
		if cat != "":
			accent = tokens.category_color(cat)
			break
	if card != null:
		for chrome_name in HOSTED_CHROME:
			var chrome := card.get_node_or_null(chrome_name)
			if chrome is CanvasItem:
				(chrome as CanvasItem).visible = false
		# The header band shows the name now, so hide the card's own label.
		var name_label := card.get_node_or_null("NameLabel") as Label
		if name_label != null:
			name_label.visible = false
	_style_header(accent)
	var normal := StyleBoxFlat.new()
	normal.bg_color = tokens.surface_sunken
	normal.set_corner_radius_all(20)
	normal.set_border_width_all(2)
	normal.border_color = tokens.surface_sunken.darkened(0.12)
	var sh := tokens.text_primary
	sh.a = 0.2
	normal.shadow_color = sh
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(0, 4)
	var selected := normal.duplicate()
	selected.bg_color = tokens.surface_sunken.lerp(accent, 0.18)
	selected.set_border_width_all(6)
	selected.border_color = accent
	for box in ["normal", "hover", "focus", "disabled"]:
		add_theme_stylebox_override(box, normal)
	for box in ["pressed", "hover_pressed"]:
		add_theme_stylebox_override(box, selected)


## The day-summary card lays its bars in two narrow columns (needs left,
## skills right), so a card that shows only one or two bars leaves the far
## side blank. On the apply screen we restack the *visible* bars into one
## full-width column so each progress bar uses the whole card. Offsets are in
## the card's own 992-wide design space, so they scale with the card art.
func _relayout_bars() -> void:
	if card == null:
		return
	var avatar := card.get_node_or_null("Avatar") as Control
	if avatar != null:
		avatar.offset_top = AVATAR_TOP
		avatar.offset_bottom = AVATAR_BOTTOM
	var left := 336.0
	var right := 952.0
	var h := 92.0
	var gap := 14.0
	var y := 48.0
	# Highlighted skill stats sit full-width on top.
	for sr in card.stat_rows:
		if sr != null and sr.visible:
			sr.offset_left = left
			sr.offset_right = right
			sr.offset_top = y
			sr.offset_bottom = y + h
			y += h + gap
	# Mood and energy share the row below, left and right.
	var needs: Array[Control] = []
	if card.mood_bar != null and card.mood_bar.visible:
		needs.append(card.mood_bar)
	if card.energy_bar != null and card.energy_bar.visible:
		needs.append(card.energy_bar)
	if needs.size() == 1:
		needs[0].offset_left = left
		needs[0].offset_right = right
		needs[0].offset_top = y
		needs[0].offset_bottom = y + h
	elif needs.size() == 2:
		var mid := (left + right) * 0.5
		needs[0].offset_left = left
		needs[0].offset_right = mid - gap * 0.5
		needs[0].offset_top = y
		needs[0].offset_bottom = y + h
		needs[1].offset_left = mid + gap * 0.5
		needs[1].offset_right = right
		needs[1].offset_top = y
		needs[1].offset_bottom = y + h
	call_deferred("_enlarge_stat_icons")


## Scale up each visible bar's stat icon so it reads clearly on a phone.
## Deferred so the bars have a real size to pivot around first.
func _enlarge_stat_icons() -> void:
	if card == null:
		return
	var icons: Array[Control] = []
	for sr in card.stat_rows:
		if sr != null and sr.visible:
			var i := sr.get_node_or_null("Icon") as Control
			if i != null:
				icons.append(i)
	for b in [card.mood_bar, card.energy_bar]:
		if b != null and b.visible:
			var i2 := b.get_node_or_null("Icon") as Control
			if i2 != null:
				icons.append(i2)
	for ic in icons:
		ic.pivot_offset = ic.size * 0.5
		ic.scale = Vector2(1.45, 1.45)


## Remember each visible bar's current fill so the apply-time rise can start
## from the real value rather than from empty.
func _capture_bar_current() -> void:
	_bar_current.clear()
	for b in _visible_bars():
		_bar_current[b] = b.value


## Every visible progress bar on this card (skill tracks + needs bars).
func _visible_bars() -> Array:
	var out: Array = []
	for sr in card.stat_rows:
		if sr != null and sr.visible:
			var t := sr.get_node_or_null("Track")
			if t != null:
				out.append(t)
	for b in [card.mood_bar, card.energy_bar]:
		if b != null and b.visible:
			out.append(b)
	return out


## On apply, rise each solid overlay from the current fill up into the ghost
## target -- the item "filling in" for real over the translucent projection.
func play_apply_rise() -> void:
	for entry in _overlays:
		var b = entry["bar"]
		var ov = entry["overlay"]
		if is_instance_valid(ov) and is_instance_valid(b):
			Juice.fill_bar(ov, b.value)


## Show (or clear) what the item would do to each boosted stat. While picked,
## the underlying bar goes to the target but translucent (a ghost of the
## result), and a solid overlay bar sits on top at the current value -- so the
## gap between the two reads as the pending gain. The apply-time rise then
## fills the solid overlay up into the ghost.
func set_preview(active: bool) -> void:
	_clear_overlays()
	for key in _boosts:
		var cur := float(student.get(KEY[key], 0.0))
		var after := clampf(cur + float(_boosts[key]), 0.0, 100.0)
		var delta := (after - cur) if active else 0.0
		if key == "mood" or key == "energy":
			card.preview_need(key, delta)
		else:
			card.preview_stat(key, delta, active and cur >= 100.0)
	var ghost_a := 0.4 if active else 1.0
	for b in _visible_bars():
		b.self_modulate.a = ghost_a
	if active:
		_build_overlays()


## Spawn a solid "current" bar over each ghost. A duplicate of the bar with its
## track cleared and its children stripped, so only the solid fill up to the
## current value shows on top of the translucent ghost behind it.
func _build_overlays() -> void:
	for b in _visible_bars():
		var src := b as Range
		if src == null:
			continue
		var ov: Range = src.duplicate()
		ov.set_script(null)
		for c in ov.get_children():
			ov.remove_child(c)
			c.queue_free()
		ov.name = "SolidOverlay"
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# A see-through copy of the real track (not an empty box) so the
		# overlay keeps the bar's fill margins and lines up exactly with the
		# ghost behind it -- the stat tracks inset their fill, the needs bars
		# do not.
		ov.add_theme_stylebox_override("background", _transparent_bg(src))
		ov.self_modulate.a = 1.0
		ov.value = float(_bar_current.get(b, src.value))
		# Child of the bar, first in draw order: it covers the bar's own fill
		# but sits UNDER the bar's icon/word/chevron children, which come after.
		src.add_child(ov)
		src.move_child(ov, 0)
		ov.anchor_right = 1.0
		ov.anchor_bottom = 1.0
		ov.offset_left = 0.0
		ov.offset_top = 0.0
		ov.offset_right = 0.0
		ov.offset_bottom = 0.0
		_overlays.append({"bar": src, "overlay": ov})


## A see-through copy of a bar's "background" stylebox: same content margins
## (so the overlay's fill lines up with the ghost's) but nothing drawn.
func _transparent_bg(bar: Range) -> StyleBox:
	var bg := bar.get_theme_stylebox("background")
	if bg is StyleBoxFlat:
		var f: StyleBoxFlat = (bg as StyleBoxFlat).duplicate()
		f.draw_center = false
		f.border_width_left = 0
		f.border_width_top = 0
		f.border_width_right = 0
		f.border_width_bottom = 0
		return f
	if bg is StyleBoxTexture:
		var t: StyleBoxTexture = (bg as StyleBoxTexture).duplicate()
		var m := t.modulate_color
		m.a = 0.0
		t.modulate_color = m
		return t
	return StyleBoxEmpty.new()


## Remove the solid overlays (on deselect or re-preview).
func _clear_overlays() -> void:
	for entry in _overlays:
		var ov = entry.get("overlay")
		if is_instance_valid(ov):
			ov.queue_free()
	_overlays.clear()


## False for a student too tired to take the item.
func can_select() -> bool:
	return not disabled


## Pick or un-pick this student, unless they cannot be picked.
func set_selected(on: bool) -> void:
	if not disabled:
		button_pressed = on


## The roster id of the student this row stands for.
func selected_student_id() -> int:
	return int(student.get("id", -1))


func _selection_toggled(toggled_on: bool) -> void:
	if not Engine.is_editor_hint():
		AudioDirector.play_sfx(&"select")
		if toggled_on and select_badge != null:
			select_badge.pivot_offset = select_badge.size * 0.5
			select_badge.scale = Vector2.ZERO
			select_badge.create_tween().tween_property(select_badge, "scale",
				Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			AnimUtils.squash_bounce(self)
	set_preview(toggled_on)
	selection_changed.emit()


## Paint the header band: the first boosted stat's colour, faint white stripes
## over it, and the student's name in light ink. Per-instance styleboxes, the
## accepted per-call-dynamic exception.
func _style_header(accent: Color) -> void:
	var tokens := DesignTokens.load_default()
	if _header_panel != null:
		var box := StyleBoxFlat.new()
		box.bg_color = accent
		box.corner_radius_top_left = 20
		box.corner_radius_top_right = 20
		_header_panel.add_theme_stylebox_override("panel", box)
	if _header_stripes != null:
		_header_stripes.texture = _build_stripes()
		var wash := tokens.surface_card
		wash.a = 0.14
		_header_stripes.self_modulate = wash
	if _header_name != null:
		_header_name.text = String(student.get("name", ""))
		_header_name.add_theme_color_override("font_color", tokens.surface_card)
	_fit_card()


## Like the base fit, but leaves a scaled header band above the card art and
## grows the wrapper to hold both.
func _fit_card() -> void:
	if not is_inside_tree() or size.x <= 0.0 or card == null:
		return
	var s := StudentCardButton.fit_scale(size.x, card_design_size.x, max_card_scale)
	var hh := HEADER_DESIGN_H * s
	card.position = Vector2(0.0, hh)
	card.size = card_design_size
	card.scale = Vector2(s, s)
	custom_minimum_size = Vector2(0.0, card_design_size.y * s + hh)
	if _header != null:
		_header.position = Vector2.ZERO
		_header.size = Vector2(size.x, hh)


## A 28px diagonal-stripe tile, white so the caller can wash it in any accent.
## Built once and shared across every row.
static func _build_stripes() -> ImageTexture:
	if _stripe_tex != null:
		return _stripe_tex
	var s := 28
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for y in s:
		for x in s:
			if (x + y) % 16 < 5:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	_stripe_tex = ImageTexture.create_from_image(img)
	return _stripe_tex
