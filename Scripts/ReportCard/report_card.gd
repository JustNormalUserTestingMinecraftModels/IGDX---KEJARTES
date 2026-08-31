extends Control

## Report card: a read-only viewer over GameState.approved_students.
## Derived from Scripts/StudentCard/student_card.gd by deleting the
## approve/batal/belajar workflow and the onboarding tutorial -- this
## screen only pages through and displays the roster the player already
## assembled, re-rendering live as stats change.

@export_group("UI Textures (Optional Replace)")
@export var icon_magnify: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_magnify.svg")
@export var icon_mood: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_mood.svg")
@export var icon_energy: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_energy.svg")
@export var icon_akademis: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_akademis.svg")
@export var icon_seni: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_seni.svg")
@export var icon_olahraga: Texture2D = preload("res://Assets/Images/UI/Placeholders/icon_olahraga.svg")

# ================= TRAIT DESCRIPTIONS =================
# QUIRK_DESCRIPTIONS / PERSONA_DESCRIPTIONS live on StudentCardView;
# use StudentCardView.quirk_description()/persona_description().

# ================= TOKENS =================

## The project's modal scrim. `alpha_scale` of 0 gives the same hue at
## zero opacity, which is what both popup fades tween from and back to --
## tweening between two different hues would flash mid-fade.
func _scrim_color(alpha_scale: float = 1.0) -> Color:
	var c := DesignTokens.load_default().scrim_color()
	c.a *= alpha_scale
	return c


# ================= ACTIVE POPUP =================
var _active_popup: Node = null

# --- Paginasi Kertas Murid ---
@onready var kertas_murid: Array = [$KertasMurid1, $KertasMurid2, $KertasMurid3, $KertasMurid4, $KertasMurid5, $KertasMurid6]
@onready var next_kanan: BaseButton = $NextButtonKanan
@onready var next_kiri: BaseButton = $NextButtonKiri
@onready var back_button: Button = $BackButton
@onready var page_label: Label = $PageLabel

var current_page := 0
var is_animating := false

## The viewer shows the students actually under the player's care, with
## whatever stats the most recent school day left them at -- not the
## six-entry candidate list student_card pages through.
var student_data_list: Array = []


func _load_roster() -> void:
	student_data_list = GameState.approved_students
	for i in kertas_murid.size():
		var has_student: bool = i < student_data_list.size()
		kertas_murid[i].visible = has_student and i == current_page
		if has_student:
			StudentCardView.populate(kertas_murid[i], student_data_list[i],
				_on_bar_gui_input, _on_btn_mouse_entered, _on_btn_mouse_exited,
				_on_trait_btn_pressed)


## approved_students is mutated in place by item use and by the school-day
## simulation, so an open card re-renders rather than showing a snapshot.
func _refresh_current_page() -> void:
	if current_page < student_data_list.size():
		StudentCardView.populate(kertas_murid[current_page], student_data_list[current_page],
			_on_bar_gui_input, _on_btn_mouse_entered, _on_btn_mouse_exited,
			_on_trait_btn_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_refresh_current_page()


func _ready():
	_load_roster()

	if not GameState.inventory_changed.is_connected(_refresh_current_page):
		GameState.inventory_changed.connect(_refresh_current_page)

	next_kanan.pressed.connect(_on_next_kanan_pressed)
	next_kiri.pressed.connect(_on_next_kiri_pressed)
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	for k in kertas_murid:
		k.set_meta("original_position", k.position)

	_show_page(current_page)
	AudioDirector.play_bgm_playlist(&"lobby")

func _on_back_pressed() -> void:
	Transition.change_scene("res://Scenes/Lobby/loby.tscn", Transition.Style.WIPE)

# ================= TOUCH SWIPE NAVIGATION =================

var swipe_start_pos: Vector2 = Vector2.ZERO
var is_swiping: bool = false
const SWIPE_THRESHOLD: float = 60.0

func _input(event: InputEvent):
	if is_animating or (_active_popup != null and is_instance_valid(_active_popup)):
		is_swiping = false
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				swipe_start_pos = event.position
				is_swiping = true
			else:
				if is_swiping:
					is_swiping = false
					_evaluate_swipe(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			swipe_start_pos = event.position
			is_swiping = true
		else:
			if is_swiping:
				is_swiping = false
				_evaluate_swipe(event.position)

func _evaluate_swipe(end_pos: Vector2):
	if _active_popup != null and is_instance_valid(_active_popup):
		return
	var delta_x = end_pos.x - swipe_start_pos.x
	var delta_y = end_pos.y - swipe_start_pos.y
	if abs(delta_x) > 40.0 and abs(delta_x) > abs(delta_y):
		if delta_x < 0:
			_on_next_kanan_pressed()
		else:
			_on_next_kiri_pressed()

# ================= PAGINASI =================

func _on_next_kanan_pressed():
	if is_animating:
		return
	if current_page < student_data_list.size() - 1:
		AudioDirector.play_sfx(&"swipe")
		var old_page = current_page
		current_page += 1
		_transition_page(old_page, current_page, -1)

func _on_next_kiri_pressed():
	if is_animating:
		return
	if current_page > 0:
		AudioDirector.play_sfx(&"swipe")
		var old_page = current_page
		current_page -= 1
		_transition_page(old_page, current_page, 1)

func _transition_page(old_index: int, new_index: int, direction: int):
	if _active_popup and is_instance_valid(_active_popup):
		_active_popup.queue_free()
		_active_popup = null
	is_animating = true
	next_kanan.disabled = true
	next_kiri.disabled = true

	var old_kertas = kertas_murid[old_index]
	var new_kertas = kertas_murid[new_index]

	var screen_width = get_viewport_rect().size.x
	var throw_distance = screen_width * direction

	# --- TWEEN OUT (Throw old card off-screen) ---
	var tween_out = create_tween().set_parallel(true)
	tween_out.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_out.tween_property(old_kertas, "position:x", old_kertas.position.x + throw_distance, 0.35)
	tween_out.tween_property(old_kertas, "rotation_degrees", 15 * direction, 0.35)
	tween_out.tween_property(old_kertas, "modulate:a", 0.0, 0.35)

	await tween_out.finished

	# Reset old card
	old_kertas.hide()
	old_kertas.position = old_kertas.get_meta("original_position")
	old_kertas.rotation_degrees = 0
	old_kertas.modulate.a = 1.0

	# Prepare new card and nav state
	new_kertas.show()
	var original_pos = new_kertas.get_meta("original_position")
	new_kertas.position = original_pos - Vector2(throw_distance, 0)
	new_kertas.rotation_degrees = -15 * direction
	new_kertas.modulate.a = 0.0

	_update_nav_buttons(new_index)

	# --- TWEEN IN (Slide new card in from off-screen) ---
	var tween_in = create_tween().set_parallel(true)
	tween_in.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(new_kertas, "position", original_pos, 0.35)
	tween_in.tween_property(new_kertas, "rotation_degrees", 0, 0.35)
	tween_in.tween_property(new_kertas, "modulate:a", 1.0, 0.35)

	await tween_in.finished

	_stagger_in_card(new_index)
	_update_page_label(new_index)

	is_animating = false
	next_kanan.disabled = false
	next_kiri.disabled = false

	# Returning to a page should never show a stale snapshot of the roster.
	_refresh_current_page()

func _update_nav_buttons(index: int):
	next_kiri.visible = index > 0
	next_kanan.visible = index < student_data_list.size() - 1

func _update_page_label(index: int):
	page_label.text = str(index + 1) + "/" + str(student_data_list.size())

## The rows of one student page, top to bottom, for staggered entry.
## Order matters: Juice.stagger_in delays each node by one stagger_step,
## so this list is what the player's eye follows down the card.
const CARD_ROW_ORDER := ["Nama", "Profil", "Kepribadian", "Kepribadian1",
	"Kepribadian2", "Akademis", "Akademis1", "Akademis2", "Akademis3",
	"KutuBuku", "KutuBuku2"]


## Reveal the newly-shown page's contents row by row instead of having
## the whole card appear at once. Only ever called for a page that is
## already visible and settled, never mid page-transition.
func _stagger_in_card(index: int) -> void:
	if index < 0 or index >= kertas_murid.size():
		return
	var kertas: Node = kertas_murid[index]
	var rows: Array = []
	for row_name in CARD_ROW_ORDER:
		var node = kertas.get_node_or_null(row_name)
		if node != null:
			rows.append(node)
	Juice.stagger_in(rows)


func _show_page(index: int):
	for i in kertas_murid.size():
		kertas_murid[i].visible = (i == index)

	_stagger_in_card(index)
	_update_nav_buttons(index)
	_update_page_label(index)

# ================= BAR RESIZE & BADGE CREATION =================

func _get_stat_icon(bname: String) -> Texture2D:
	match bname:
		"Kepribadian1": return icon_mood
		"Kepribadian2": return icon_energy
		"Akademis1": return icon_akademis
		"Akademis2": return icon_seni
		"Akademis3": return icon_olahraga
	return null

## The accent colour a given bar wears, from DesignTokens via StatInfo.
## Affects: the tint of the bars drawn on the card itself.
func _get_bar_color(bname: String) -> Color:
	return DesignTokens.load_default().category_color(StatInfo.token_category(bname))

func _on_bar_gui_input(ev: InputEvent, kertas: Control, bname: String, s_data: Dictionary) -> void:
	if is_animating or _active_popup != null:
		return
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or \
	   (ev is InputEventScreenTouch and ev.pressed):
		_show_bar_popup(kertas, bname, s_data)

## The scene the stat-detail modal is authored in. Exported so the popup can
## be restyled or swapped without touching this screen.
@export var stat_popup_scene: PackedScene = preload("res://Scenes/UI/StatDetailPopup.tscn")

## Open the stat-detail modal for one bar.
##
## Affects: adds a CanvasLayer child to `kertas`, hides the page-turn arrows
## while it is open, and sets `_active_popup` so a second tap is ignored.
## No longer a coroutine -- StatDetailPopup.open() owns the reveal.
func _show_bar_popup(kertas: Control, bname: String, s_data: Dictionary) -> void:
	if _active_popup != null and is_instance_valid(_active_popup):
		return
	if next_kanan: next_kanan.hide()
	if next_kiri: next_kiri.hide()

	var popup: StatDetailPopup = stat_popup_scene.instantiate()
	_active_popup = popup
	kertas.add_child(popup)
	popup.configure(bname, s_data, _get_stat_icon(bname))
	popup.closed.connect(_on_detail_popup_closed)
	popup.open()

## Clear the guard and restore the page-turn arrows once a modal finishes
## its exit animation. Shared by the stat and trait popups.
func _on_detail_popup_closed() -> void:
	_active_popup = null
	_update_nav_buttons(current_page)
# ================= TRAIT POPUP =================

func _show_trait_popup(kertas: Control, type: String, name: String, desc: String, on_close: Callable = Callable()) -> void:
	if _active_popup and is_instance_valid(_active_popup):
		return  # already open
	AudioDirector.play_sfx(&"popup_open")

	var vp: Vector2 = get_viewport_rect().size
	var is_quirk := (type == "quirk")
	# Matches the QuirkBadge / PersonaBadge button variations, so tapping a
	# badge opens a popup headed in that badge's own color.
	var accent_tokens := DesignTokens.load_default()
	var accent := accent_tokens.brand_primary if is_quirk \
		else accent_tokens.cat_istirahat

	var canvas := CanvasLayer.new()
	canvas.name = "PopupCanvas"
	canvas.layer = 100
	kertas.add_child(canvas)

	# Full-screen dim overlay
	var overlay := ColorRect.new()
	overlay.name = "TraitOverlay"
	overlay.color = _scrim_color(0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(overlay)
	_active_popup = canvas

	# ── Popup panel ──
	var popup := PanelContainer.new()
	popup.name = "TraitPopupPanel"
	var panel_w := vp.x * 0.94
	popup.custom_minimum_size = Vector2(panel_w, 0)

	popup.theme_type_variation = &"Card"
	overlay.add_child(popup)

	# Hide navigation arrows to prevent accidental sliding
	if next_kanan: next_kanan.hide()
	if next_kiri: next_kiri.hide()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	popup.add_child(vbox)

	# ── Colored header ──
	# The one surface in this screen that genuinely varies per instance:
	# its whole job is to carry the quirk-vs-persona accent, so no fixed
	# variation can express it. Every value below still comes from a
	# token; only the accent is chosen at runtime.
	var header := PanelContainer.new()
	var tok := DesignTokens.load_default()
	var hdr_bg := StyleBoxFlat.new()
	hdr_bg.bg_color = accent
	hdr_bg.corner_radius_top_left = tok.radius_lg
	hdr_bg.corner_radius_top_right = tok.radius_lg
	hdr_bg.content_margin_left = tok.space_md
	hdr_bg.content_margin_top = tok.space_sm
	hdr_bg.content_margin_right = tok.space_md
	hdr_bg.content_margin_bottom = tok.space_sm
	header.add_theme_stylebox_override("panel", hdr_bg)
	vbox.add_child(header)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	header.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = "⚡" if is_quirk else "🌟"
	icon_lbl.theme_type_variation = &"H1Label"
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title_vbox)

	# Both sit on the saturated accent header, which is exactly the
	# backdrop BarLabel exists for: white glyph, dark rim.
	var type_lbl := Label.new()
	type_lbl.text = "QUIRK" if is_quirk else "PERSONA"
	type_lbl.theme_type_variation = &"BarLabel"
	title_vbox.add_child(type_lbl)

	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.theme_type_variation = &"BarLabel"
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_vbox.add_child(name_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.theme_type_variation = &"SecondaryButton"
	close_btn.custom_minimum_size = Vector2.ONE * float(DesignTokens.load_default().touch_target_min)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(close_btn)

	# ── Body ──
	var body := PanelContainer.new()
	body.theme_type_variation = &"SunkenPanel"
	vbox.add_child(body)

	var desc_lbl := Label.new()
	desc_lbl.text = "💡  EFEK GAMEPLAY:\n" + desc
	desc_lbl.theme_type_variation = &"TitleLabel"
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_constant_override("line_spacing", 12)
	body.add_child(desc_lbl)

	# ── Slide-up animation ──
	await get_tree().process_frame
	if not is_instance_valid(popup):
		return
	# Same reveal as the stat popup: place, then Juice.pop_in.
	var pw := popup.size.x
	var ph := popup.size.y
	popup.position = Vector2((vp.x - pw) * 0.5,
		vp.y - ph - float(DesignTokens.load_default().space_md))
	Juice.pop_in(popup)

	var tw2 := create_tween()
	tw2.set_trans(Tween.TRANS_LINEAR)
	tw2.tween_property(overlay, "color", _scrim_color(), 0.22)

	var close_fn = func(): _close_trait_popup(canvas, overlay, popup, on_close)
	close_btn.pressed.connect(close_fn)
	overlay.gui_input.connect(func(ev):
		if (ev is InputEventMouseButton and ev.pressed) or \
		   (ev is InputEventScreenTouch and ev.pressed):
			_close_trait_popup(canvas, overlay, popup, on_close)
	)

func _close_trait_popup(canvas: CanvasLayer, overlay: Control, popup: Control, on_close: Callable = Callable()) -> void:
	if not is_instance_valid(canvas) or _active_popup != canvas:
		return
	AudioDirector.play_sfx(&"popup_close")

	# Mark as closing immediately to prevent double-calls
	_active_popup = null

	var vp := get_viewport_rect().size
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if is_instance_valid(popup):
		tw.tween_property(popup, "position:y", vp.y, 0.26)
	if is_instance_valid(overlay):
		tw.tween_property(overlay, "color", _scrim_color(0.0), 0.22)
	tw.chain().tween_callback(func():
		if is_instance_valid(canvas):
			canvas.queue_free()
		if _active_popup == canvas:
			_active_popup = null
		if on_close.is_valid():
			on_close.call()

		# Restore navigation arrows
		_update_nav_buttons(current_page)
	)

# ──────────────────────────────────────────────────────────────────────────────

func _setup_button_juice(btn: Control):
	if not btn:
		return
	btn.pivot_offset = btn.size / 2.0
	if not btn.mouse_entered.is_connected(_on_btn_mouse_entered.bind(btn)):
		btn.mouse_entered.connect(_on_btn_mouse_entered.bind(btn))
	if not btn.mouse_exited.is_connected(_on_btn_mouse_exited.bind(btn)):
		btn.mouse_exited.connect(_on_btn_mouse_exited.bind(btn))

func _on_btn_mouse_entered(btn: Control):
	if not is_instance_valid(btn) or (btn is BaseButton and btn.disabled):
		return
	btn.pivot_offset = btn.size / 2.0

	# Pause wiggle tween if running
	if btn.has_meta("wiggle_tween"):
		var tw = btn.get_meta("wiggle_tween")
		if is_instance_valid(tw):
			tw.pause()

	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(btn, "scale", Vector2(1.12, 1.12), 0.15)
	tw.parallel().tween_property(btn, "rotation_degrees", 0.0, 0.15)

func _on_btn_mouse_exited(btn: Control):
	if not is_instance_valid(btn):
		return
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)

	# Resume wiggle tween if paused
	tw.chain().tween_callback(func():
		if is_instance_valid(btn) and btn.has_meta("wiggle_tween"):
			var wiggle = btn.get_meta("wiggle_tween")
			if is_instance_valid(wiggle):
				wiggle.play()
	)

func _animate_button_click_bounce(btn: Control, flash_color: Color = Color.TRANSPARENT) -> Tween:
	if not is_instance_valid(btn):
		return null
	btn.pivot_offset = btn.size / 2.0

	# Scale animation
	var scale_tw = create_tween()
	scale_tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tw.tween_property(btn, "scale", Vector2(0.8, 1.25), 0.08)
	scale_tw.tween_property(btn, "scale", Vector2(1.18, 0.85), 0.1)
	scale_tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)

	# Color flash animation
	if flash_color != Color.TRANSPARENT:
		var orig = btn.modulate
		btn.modulate = flash_color
		var color_tw = create_tween()
		color_tw.tween_property(btn, "modulate", orig, 0.3).set_delay(0.05)

	return scale_tw

func _on_trait_btn_pressed(kertas: Control, type: String, trait_name: String):
	if type == "quirk":
		var desc = StudentCardView.quirk_description(trait_name)
		_show_trait_popup(kertas, "quirk", trait_name, desc if desc != "" else "Tidak ada info.")
	else:
		var desc = StudentCardView.persona_description(trait_name)
		_show_trait_popup(kertas, "persona", trait_name, desc if desc != "" else "Tidak ada info.")
