class_name DebugLookPanel
extends RefCounted

## The debug overlay's Look tab, built by DebugManager (moved out of it, which
## sits at its clean-code size ceiling). Like the rest of the overlay it is a
## programmatic developer tool, out of scope for the design system.
##
## Two halves. "Efek layar ini" reaches whatever screen is up when a control
## moves: the Efek Suasana and Efek Visual switches, and every AmbientGlow (the
## Lobby's bloom), ScreenGlow, ScreenSaturation, LightPool and SunShafts in the tree, so the bloom on the shops, the end game
## and the minigames can be seen and tuned live. The rest tunes SHARED
## materials (AO, rim, the Lobby's shafts and its WorldEnvironment glow), so one
## drag moves every plate at once. Nothing here persists except the two
## switches, which are the player's own settings; copy a value into the .tres
## or .tscn once it looks right.

## Font sizes of the panel's headings, captions and notes.
const TITLE_FONT := 26
const CAPTION_FONT := 22
const NOTE_FONT := 20
## Height of each slider and button row, so a thumb can grab it on a phone.
const ROW_HEIGHT := 60
## Gap between the panel's rows, and inside one slider row.
const ROW_GAP := 24
const SLIDER_GAP := 6
## Inset of the whole panel from the tab's edges.
const MARGIN := 30
## The per-screen sliders: [kit class, property, caption, min, max, step,
## the piece's own default]. Each ends at the piece's own clamp.
const NODE_SLIDERS := [
	[&"AmbientGlow", "glow_threshold", "Bloom Lobby: Ambang Terang", 0.0, 1.0, 0.01, 0.7],
	[&"AmbientGlow", "glow_intensity", "Bloom Lobby: Intensitas", 0.0, 4.0, 0.05, 1.5],
	[&"AmbientGlow", "glow_strength", "Bloom Lobby: Kekuatan", 0.0, 2.0, 0.05, 1.2],
	[&"ScreenGlow", "threshold", "Bloom Layar: Ambang Terang", 0.0, 1.0, 0.01, 0.7],
	[&"ScreenGlow", "intensity", "Bloom Layar: Intensitas", 0.0, 2.0, 0.01, 0.8],
	[&"ScreenGlow", "spread", "Bloom Layar: Sebaran", 0.0, 5.0, 0.1, 2.0],
	[&"LightPool", "intensity", "Cahaya (LightPool): Kekuatan", 0.0, 0.12, 0.005, 0.08],
	[&"SunShafts", "intensity", "Berkas (SunShafts): Kekuatan", 0.0, 0.2, 0.005, 0.2],
	[&"ScreenSaturation", "saturation", "Saturasi Layar", 0.0, 2.0, 0.01, 0.7],
]


## Builds the tab under `parent` and returns its root, for DebugManager's
## `panels` table.
static func build(parent: Control) -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	var margin_container := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin_container.add_theme_constant_override(side, MARGIN)
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin_container)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", ROW_GAP)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.add_child(vbox)

	_build_screen_section(vbox)
	_build_shared_section(vbox)
	_add_note(vbox, "Catatan: slider di sini hilang saat keluar. Salin nilainya ke .tres / .tscn kalau sudah pas.")
	return scroll


# ── This screen ──────────────────────────────────────────────────────────────

static func _build_screen_section(vbox: VBoxContainer) -> void:
	_add_heading(vbox, "Efek layar ini (semua layar, live):")
	_add_setting_switch(vbox, " Efek Suasana (cahaya, berkas, bloom layar) ",
		"ambient_effects_enabled")
	_add_setting_switch(vbox, " Efek Visual (vignette, grain) ",
		"look_layer_enabled")
	# Efek Visual's own full-screen bloom, off by default; it shows only while
	# Efek Visual and Grafis HD are both on.
	var look: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("LookLayer")
	if look != null:
		_add_setting_switch(vbox, " Bloom global Efek Visual (bawaan mati) ", "bloom_enabled", look)
	_add_setting_switch(vbox, " Grafis HD (MSAA, semua bloom) ",
		"hd_graphics_enabled")

	var count := Label.new()
	count.add_theme_font_size_override("font_size", CAPTION_FONT)
	vbox.add_child(count)
	var refresh := Button.new()
	refresh.text = " Hitung efek di layar ini "
	refresh.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	refresh.add_theme_font_size_override("font_size", CAPTION_FONT)
	refresh.pressed.connect(func(): count.text = _census_text())
	vbox.add_child(refresh)
	count.text = "Tekan tombol di bawah untuk menghitung bloom dan cahaya layar ini."

	for spec in NODE_SLIDERS:
		_add_node_slider(vbox, spec[0], spec[1], spec[2], spec[3], spec[4], spec[5], spec[6])


## A switch bound to a boolean on `target`: one of the player's GameSettings
## by default, whose setter emits that setting's signal so every kit piece
## follows at once.
static func _add_setting_switch(vbox: VBoxContainer, caption: String, property: String,
		target: Object = GameSettings) -> void:
	var toggle := CheckButton.new()
	toggle.text = caption
	toggle.button_pressed = bool(target.get(property))
	toggle.add_theme_font_size_override("font_size", CAPTION_FONT)
	toggle.toggled.connect(func(on: bool): target.set(property, on))
	vbox.add_child(toggle)


## Every node in the running tree whose script is the global class `kind`.
static func _nodes_of(kind: StringName) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return []
	var found: Array = []
	for node in tree.root.find_children("*", "", true, false):
		var script := node.get_script() as Script
		if script != null and script.get_global_name() == kind:
			found.append(node)
	return found


static func _census_text() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: String = tree.current_scene.scene_file_path.get_file() if tree and tree.current_scene else "?"
	return "%s: %d bloom Lobby, %d bloom layar, %d cahaya, %d berkas" % [scene,
		_nodes_of(&"AmbientGlow").size(), _nodes_of(&"ScreenGlow").size(),
		_nodes_of(&"LightPool").size(), _nodes_of(&"SunShafts").size()]


## One slider writing `property` on every `kind` node on screen at drag time,
## so it follows the player from screen to screen. It starts at `start`, the
## piece's own default, because the screen it will act on is not up yet.
static func _add_node_slider(vbox: VBoxContainer, kind: StringName, property: String,
		caption: String, min_value: float, max_value: float, step: float, start: float) -> void:
	var lbl := _add_slider_row(vbox, caption, min_value, max_value, step, start,
		func(v: float) -> int:
			var nodes := _nodes_of(kind)
			for node in nodes:
				node.set(property, v)
			return nodes.size())
	lbl.text = "%s: %.3f (geser untuk menerapkan)" % [caption, start]


# ── Shared materials ─────────────────────────────────────────────────────────

static func _build_shared_section(vbox: VBoxContainer) -> void:
	_add_heading(vbox, "Tampilan Ilustrasi (material bersama):")
	# The cutout, the Lobby's desks and the Lobby's faces share their AO and rim
	# values (test_illustration_ao pins it), so one slider drives all three.
	var cutouts: Array = [
		load("res://Scripts/Shaders/illustration_grade_cutout.tres"),
		load("res://Scripts/Shaders/illustration_grade_cutout_lobby.tres"),
		load("res://Scripts/Shaders/illustration_grade_face.tres"),
	]
	_add_material_slider(vbox, cutouts, "ao_strength", "Kekuatan AO", 0.0, 1.0, 0.01)
	_add_material_slider(vbox, cutouts, "ao_radius_px", "Lebar AO (piksel layar)", 0.0, 16.0, 0.5)
	_add_material_slider(vbox, cutouts, "rim_strength", "Kekuatan Rim", 0.0, 0.8, 0.01)
	_add_material_slider(vbox, cutouts, "rim_radius_px", "Lebar Rim (piksel layar)", 0.0, 16.0, 0.5)

	_add_heading(vbox, "Cahaya Jendela (khusus Lobby):")
	var shafts: ShaderMaterial = load("res://Scripts/Shaders/window_shafts_material.tres")
	_add_material_slider(vbox, [shafts], "intensity", "Kekuatan Cahaya", 0.0, 0.4, 0.005)
	_add_material_slider(vbox, [shafts], "shaft_count", "Jumlah Berkas", 3.0, 16.0, 1.0)

	# The Lobby's WorldEnvironment glow. The resource is the cached instance the
	# Lobby's WorldEnvironment wears, so a change shows on the next frame.
	_add_heading(vbox, "Bloom WorldEnvironment (khusus Lobby):")
	var env: Environment = load("res://Scenes/Lobby/lobby_environment.tres")
	if env == null:
		return
	var glow_on := CheckButton.new()
	glow_on.text = " Bloom Aktif "
	glow_on.button_pressed = env.glow_enabled
	glow_on.add_theme_font_size_override("font_size", CAPTION_FONT)
	glow_on.toggled.connect(func(on: bool): env.glow_enabled = on)
	vbox.add_child(glow_on)

	var blend := OptionButton.new()
	for mode_name in ["Additive", "Screen", "Softlight", "Replace", "Mix"]:
		blend.add_item(mode_name)
	blend.selected = env.glow_blend_mode
	blend.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	blend.add_theme_font_size_override("font_size", CAPTION_FONT)
	blend.item_selected.connect(func(i: int): env.glow_blend_mode = i)
	vbox.add_child(blend)

	for row in [["glow_intensity", "Intensitas", 4.0, 0.05], ["glow_strength", "Kekuatan", 2.0, 0.05],
			["glow_bloom", "Bloom Menyeluruh", 1.0, 0.01], ["glow_hdr_threshold", "Ambang Terang", 1.0, 0.01]]:
		var property: String = row[0]
		_add_slider_row(vbox, row[1], 0.0, row[2], row[3], float(env.get(property)),
			func(v: float) -> int:
				env.set(property, v)
				return 1)


## One slider bound to one shader uniform, written to every material in `mats`
## at once. It starts at the first material's value.
static func _add_material_slider(vbox: VBoxContainer, mats: Array, uniform: String,
		caption: String, min_value: float, max_value: float, step: float) -> void:
	var live: Array = mats.filter(func(m): return m is ShaderMaterial)
	if live.is_empty():
		return
	_add_slider_row(vbox, caption, min_value, max_value, step,
		float(live[0].get_shader_parameter(uniform)),
		func(v: float) -> int:
			for mat in live:
				mat.set_shader_parameter(uniform, v)
			return live.size())


# ── Rows ─────────────────────────────────────────────────────────────────────

static func _add_heading(vbox: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", TITLE_FONT)
	vbox.add_child(lbl)


static func _add_note(vbox: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", NOTE_FONT)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)


## A caption over a slider. `apply` takes the new value and returns how many
## things it reached; the caption shows both, so a slider that reaches nothing
## on this screen says so instead of silently doing nothing.
static func _add_slider_row(vbox: VBoxContainer, caption: String, min_value: float,
		max_value: float, step: float, start: float, apply: Callable) -> Label:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", SLIDER_GAP)
	vbox.add_child(row)

	var lbl := Label.new()
	lbl.text = "%s: %.3f" % [caption, start]
	lbl.add_theme_font_size_override("font_size", CAPTION_FONT)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = start
	slider.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float):
		var reached: int = apply.call(v)
		lbl.text = "%s: %.3f (%d)" % [caption, v, reached])
	row.add_child(slider)
	return lbl
