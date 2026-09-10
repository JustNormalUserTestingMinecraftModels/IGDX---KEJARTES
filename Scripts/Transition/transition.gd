@tool
extends CanvasLayer

## Scene transitions. Autoloaded as `Transition`.
##
## change_scene(path) keeps its original one-argument form because 21
## call sites across the project use it. The style parameter is optional.

enum Style { WIPE, FADE, IRIS }

## Emitted after the new scene is loaded and the cover has retracted.
## Screens connect to this to start their entry animations.
signal scene_changed(path: String)

@export_group("Appearance")
## Color of the cover. Defaults to brand_primary from the design tokens.
@export var cover_color: Color = Color("2e5bff")
## Unused by change_scene() itself (every call site passes its own style
## explicitly) -- kept as the Inspector-visible default for future call
## sites that omit the argument.
@export var default_style: Style = Style.WIPE
## How much to enlarge the motif tile before it repeats across the cover.
## The fill tiles carry a 20x19 motif period, sized for a 148px-wide
## progress bar; repeated untouched across a 1080px screen that is ~54
## motifs across and reads as flat grain rather than as a pattern. 3.0
## puts it around 18 across. Raise for a bolder motif, lower for finer;
## 1.0 is the tile's own scale.
@export_range(1.0, 8.0, 0.5) var pattern_tile_scale: float = 3.0
## Opacity of the motif layer over the cover colour. Low by design -- the
## motif is a texture under the brand fill, not a foreground element.
@export_range(0.0, 1.0, 0.01) var pattern_opacity: float = 0.18
## How far the cover hangs past each screen edge, as a fraction of screen
## width.
##
## The gradient's alpha dips to 0.65 at both ends. On a cover sized
## exactly to the viewport those soft ends sit *on screen* at the moment
## the scene swaps, so the outgoing scene shows through two vertical
## bands -- reads as a glitch, not as a soft edge. Overhanging pushes the
## ramp off both sides, leaving only the fully-opaque middle over the
## screen while the ends still feather as they enter and leave.
##
## The floor is set by the ramp's own stops: the opaque run is 0.18..0.82
## of the cover, so it spans 0.64 of the total width and must still cover
## the screen. That needs an overhang of at least 0.28 per side; 0.35
## keeps a margin.
@export_range(0.0, 1.0, 0.01) var cover_overhang_ratio: float = 0.35

@onready var _cover: ColorRect = $ColorRect
@onready var _gradient: TextureRect = $ColorRect/Gradient
@onready var _pattern: TextureRect = $ColorRect/Pattern

## The progress bars' motif tiles, reused here so the cover carries the
## same visual language as the rest of the game rather than a flat field.
## One is picked at random per transition -- see _pick_pattern().
const PATTERN_TILES: Array[String] = [
	"res://Assets/Images/UI/BarFill/fill_akademis.png",
	"res://Assets/Images/UI/BarFill/fill_senibudaya.png",
	"res://Assets/Images/UI/BarFill/fill_olahraga.png",
	"res://Assets/Images/UI/BarFill/fill_wirausaha.png",
	"res://Assets/Images/UI/BarFill/fill_istirahat.png",
	"res://Assets/Images/UI/BarFill/fill_libur.png",
	"res://Assets/Images/UI/BarFill/fill_mood.png",
	"res://Assets/Images/UI/BarFill/fill_energi.png",
]

## The tiling middle of a fill tile, in that tile's own pixels.
##
## A fill tile is a 256x256 capsule with transparent surround, cropped for
## the bars from region (60, 66) 148x124 and nine-sliced with a 24px
## margin. Using the whole file here would sweep a pill shape across the
## screen; only the nine-slice middle repeats cleanly. That middle is
## (60+24, 66+24) at 100x76, which the tiles' 20x19 motif period divides
## exactly -- 5 across, 4 down -- so TILE shows no seam.
## See Assets/Images/UI/BarFill/README.md.
const PATTERN_REGION := Rect2(84, 90, 100, 76)

var _busy: bool = false

## Cropped motif textures, keyed by source tile path. Populated lazily by
## _pick_pattern(); a cache, not a knob, so it is not an @export.
var _pattern_cache: Dictionary = {}


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tokens := DesignTokens.load_default()
	if tokens != null:
		cover_color = tokens.brand_primary
	# The colour now rides on the gradient layer rather than on the
	# ColorRect itself: the ramp texture is white with an alpha that dips
	# at both edges, so modulating it by cover_color gives the brand fill
	# in the middle and a softer leading/trailing edge. The ColorRect
	# stays fully transparent and serves only as the animated parent --
	# its position, scale and modulate still drive the whole cover.
	_cover.color = Color(cover_color, 0.0)
	_gradient.modulate = cover_color
	_pattern.modulate.a = pattern_opacity
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_cover()


## Returns one randomly chosen fill tile's tiling middle as a standalone
## texture, so each transition carries a different motif. Returns null if
## the chosen file is missing or cannot be read back, which leaves the
## cover a plain gradient rather than failing the scene change.
##
## The region is copied into its own ImageTexture rather than wrapped in
## an AtlasTexture: a TextureRect in TILE mode repeats the whole atlas,
## not the atlas's region, so an AtlasTexture here tiles the 256x256
## capsule -- rounded corners, transparent surround and all -- instead of
## the dense motif inside it. Copying the pixels out is what makes the
## 100x76 repeat actually be the repeat.
##
## Results are cached in _pattern_cache: there are only eight, they never
## change at runtime, and re-cropping on every scene change would decode
## a PNG during the frame the wipe starts.
func _pick_pattern() -> Texture2D:
	var path: String = PATTERN_TILES[randi() % PATTERN_TILES.size()]
	if _pattern_cache.has(path):
		return _pattern_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tile := load(path)
	if not (tile is Texture2D):
		return null
	var img: Image = tile.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	var cropped := img.get_region(Rect2i(PATTERN_REGION))
	# Resizing the image rather than scaling the node: TILE repeats at the
	# texture's own size, so growing the motif means growing the texture.
	# Scaling the TextureRect instead would shrink the area it covers by
	# the same factor and leave the cover's edges bare.
	if pattern_tile_scale != 1.0:
		cropped.resize(
			int(round(PATTERN_REGION.size.x * pattern_tile_scale)),
			int(round(PATTERN_REGION.size.y * pattern_tile_scale)),
			Image.INTERPOLATE_BILINEAR)
	var tex := ImageTexture.create_from_image(cropped)
	_pattern_cache[path] = tex
	return tex


## Widens the cover so it hangs cover_overhang_ratio past each screen
## edge, keeping the gradient's soft ends off-screen. Anchors stay at the
## full-rect preset; only the offsets move, so the cover still tracks the
## viewport if it resizes. Returns the per-side overhang in pixels, which
## _cover_in/_cover_out add to their travel so the cover still starts and
## ends completely off-screen.
func _size_cover() -> float:
	var overhang: float = get_viewport().get_visible_rect().size.x * cover_overhang_ratio
	_cover.offset_left = -overhang
	_cover.offset_right = overhang
	return overhang


func _reset_cover() -> void:
	_cover.modulate.a = 0.0
	_cover.scale = Vector2.ONE
	_cover.position = Vector2.ZERO


## duration_override lets one call site request a slower (or faster) wipe
## than the shared default, without changing behavior for the ~20 other
## call sites that don't pass it. -1.0 (the default) means "use the
## normal token-based duration."
func change_scene(path: String, style: Style = Style.WIPE, duration_override: float = -1.0) -> void:
	# Guard against double-taps firing two transitions at once, which
	# would change scene twice and strand the cover on screen.
	if _busy:
		return
	_busy = true

	if not Engine.is_editor_hint():
		GameState.save_inventory()

	# Re-rolled per transition, before the cover is visible, so two
	# consecutive scene changes rarely show the same motif.
	_pattern.texture = _pick_pattern()

	AudioDirector.play_sfx(&"whoosh")
	await _cover_in(style, duration_override)

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Transition: failed to load %s (error %d)" % [path, err])

	# One frame so the incoming scene's _ready has run and it can paint
	# before the cover retracts, otherwise the first frame flashes.
	await get_tree().process_frame

	await _cover_out(style, duration_override)
	_busy = false
	scene_changed.emit(path)


func _durations(duration_override: float = -1.0) -> Array:
	if duration_override > 0.0:
		return [duration_override, duration_override]
	var tokens := DesignTokens.load_default()
	if tokens == null:
		return [0.32, 0.32]
	return [tokens.dur_normal, tokens.dur_normal]


func _cover_in(style: Style, duration_override: float = -1.0) -> void:
	var d: float = _durations(duration_override)[0]
	var viewport := get_viewport().get_visible_rect().size
	var overhang := _size_cover()
	# The covered position is -overhang, not zero: setting `position` on
	# an anchored Control overrides the offsets _size_cover() just wrote,
	# so parking at zero would put the cover's left edge at the screen's
	# left edge and drag the soft end back on screen -- the see-through
	# band this overhang exists to remove.
	var rest := Vector2(-overhang, 0)
	var tw := create_tween()
	match style:
		Style.FADE:
			_cover.position = rest
			tw.tween_property(_cover, "modulate:a", 1.0, d) \
				.set_ease(Tween.EASE_IN_OUT)
		Style.IRIS:
			_cover.modulate.a = 1.0
			# In the cover's own coordinates local x=0 is its left edge,
			# which now sits `overhang` px left of the screen -- so the
			# screen's centre is that much further in. Using viewport*0.5
			# here would iris around a point off to the left.
			_cover.position = rest
			_cover.pivot_offset = Vector2(overhang + viewport.x * 0.5, viewport.y * 0.5)
			_cover.scale = Vector2(1.6, 1.6)
			tw.tween_property(_cover, "scale", Vector2.ONE, d) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		_:
			# WIPE: the cover sweeps in from the right edge. `position` is
			# the cover's left edge, so starting at viewport.x already
			# puts the whole cover off-screen.
			_cover.modulate.a = 1.0
			_cover.position = Vector2(viewport.x, 0)
			tw.tween_property(_cover, "position", rest, d) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tw.finished


func _cover_out(style: Style, duration_override: float = -1.0) -> void:
	var d: float = _durations(duration_override)[1]
	var viewport := get_viewport().get_visible_rect().size
	var overhang: float = viewport.x * cover_overhang_ratio
	var tw := create_tween()
	match style:
		Style.FADE:
			tw.tween_property(_cover, "modulate:a", 0.0, d) \
				.set_ease(Tween.EASE_IN_OUT)
		Style.IRIS:
			tw.tween_property(_cover, "scale", Vector2(1.6, 1.6), d) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.parallel().tween_property(_cover, "modulate:a", 0.0, d)
		_:
			# WIPE: continues sweeping off the left edge. The cover is
			# viewport + 2*overhang wide, so its right edge only clears
			# the screen once its left edge passes that full width.
			tw.tween_property(_cover, "position",
				Vector2(-(viewport.x + 2.0 * overhang), 0), d) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
	_reset_cover()
