extends RefCounted

## Fits question text to the SoalCard (QuestionCard.tscn) on the Akademis
## quizzes: Variabel, Password, PilihanGanda and Menjodohkan's tiles.
##
## Returns the largest font size at which the text fits the card's label once
## wrapped, measured with the label's own font rather than guessed from a line
## count: Variabel's item names wrap unpredictably ("PENGGARIS + PENGGARIS =
## 16" breaks, "BUKU + BUKU = 8" does not), and a fixed size ladder clipped the
## question on the first playtest (2026-09-16). The fit keeps a badge-height
## strip clear at the top and bottom, so vertically centred text never runs
## under the card's "Soal N/M" badge.
##
## Static functions only; preload it, it is not an autoload.

## Each step down shrinks the text by this many px.
const STEP := 2
## Horizontal room kept off the card's rounded edges.
const SIDE_PADDING := 24.0
## Clear space between the badge and the text's first line.
const BADGE_GAP := 12.0
## The card's TextLabel row at its design size -- used only when the label
## has not been laid out yet, which is every Menjodohkan tile, since they are
## instantiated and fitted in the same frame. 850 wide less the card's 24px
## content margins is 802; 200 is the row's own custom_minimum_size.
##
## Deliberately the row's MINIMUM rather than a typical height: the fitter
## must under-estimate here, never over-estimate. TextLabel sets
## clip_text, so a size chosen against too generous a box is silently
## clipped, while too small a box only costs a rung.
## (Was 699x333, describing a 715x345 card that had already grown to
## 850x480 before 2026-09-21.)
const FALLBACK_BOX := Vector2(802, 200)


## Largest size from `max_size` down to `min_size` at which `text` fits
## `label`, keeping clear of `badge` (which may be null).
static func font_size(label: Label, badge: Control, text: String,
		max_size: int, min_size: int) -> int:
	if label == null:
		return max_size
	var font_res := label.get_theme_font("font")
	var box := label.size
	if box.x <= 0.0 or box.y <= 0.0:
		box = FALLBACK_BOX
	var reserved := 0.0
	if badge:
		reserved = (badge.size.y + BADGE_GAP) * 2.0
	var room := Vector2(box.x - SIDE_PADDING, box.y - reserved)
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var spacing := label.get_theme_constant("line_spacing")
	var size := max_size
	while size > min_size:
		var measured := font_res.get_multiline_string_size(
			text, HORIZONTAL_ALIGNMENT_CENTER, room.x, size, -1, flags)
		# The font measure omits the Label's own line_spacing; add it per line.
		var lines := roundi(measured.y / font_res.get_height(size))
		var height := measured.y + spacing * maxi(lines - 1, 0)
		if measured.x <= room.x and height <= room.y:
			return size
		size -= STEP
	return min_size
