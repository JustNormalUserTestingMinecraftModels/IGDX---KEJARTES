class_name StudentCardView
extends RefCounted

const _CARD_ART := "res://Assets/Images/StudentCard/"

## Shared, stateless rendering for one `KertasMurid` card. Extracted from
## `student_card.gd`, which still owns everything interactive (approval,
## stamping, the tutorial, popups) -- this class only fills a card's nodes
## from a student data Dictionary and builds/styles its stat bars and
## trait badges.
##
## `student` dictionaries use the exact schema `student_card.gd` builds
## (see its `student_data_list`): "name", "kepribadian1", "kepribadian2",
## "akademis1", "akademis2", "akademis3", "quirk", "persona", "portrait",
## "profil", etc. `GameState.approved_students` entries are literal
## duplicates of that same schema, so this view works unchanged on either.

# ================= TRAIT DESCRIPTIONS =================

const QUIRK_DESCRIPTIONS: Dictionary = {
	"Kutu Buku":     "Nilai Akademis naik 15% lebih cepat saat dijadwalkan kegiatan Akademis.",
	"Semangat Juang":"Tidak mudah lelah -- biaya Energi berkurang 10% per sesi Olahraga.",
	"Penasaran":     "Seni Budaya & Akademis sama-sama meningkat lebih merata per minggu.",
	"Penyendiri":    "Lebih efektif sendiri -- sesi Akademis solo memberi +5% bonus nilai.",
	"Biang Onar":    "Ada peluang kecil mengganggu murid lain saat dijadwalkan bersama.",
	"Pekerja Keras": "Skill growth +10% tapi Energy berkurang lebih cepat setiap minggu."
}

const PERSONA_DESCRIPTIONS: Dictionary = {
	"Persona Tekun":   "Konsisten belajar -- tidak kehilangan progress meski Mood sedang rendah.",
	"Persona Aktif":   "Butuh minimal 1 sesi Olahraga per minggu atau Mood turun otomatis.",
	"Persona Kreatif": "Seni Budaya memberi bonus ganda jika dijadwalkan 2x atau lebih seminggu.",
	"Persona Pendiam": "Mood naik lebih lambat dalam kegiatan kelompok, tapi Akademis lebih stabil.",
	"Persona Santai":  "Perlu 1 sesi Istirahat per minggu atau Energi drop drastis akhir minggu."
}


static func quirk_description(quirk: String) -> String:
	return QUIRK_DESCRIPTIONS.get(quirk, "")


static func persona_description(persona: String) -> String:
	return PERSONA_DESCRIPTIONS.get(persona, "")


# ================= PER-CARD POPULATE =================

## Fills one `KertasMurid` card from one student Dictionary: name, quirk,
## persona, profil, portrait, and progress bar values, then builds/styles
## the stat bars and the two trait badges. Reaches for nothing on the
## calling scene -- everything it needs to wire interactivity back to the
## caller (bar taps, badge hover/press) comes in as unbound Callables that
## it binds itself, exactly as `student_card.gd` used to bind them inline.
static func populate(card: Control, student: Dictionary,
		on_bar_input: Callable, on_badge_hover_enter: Callable,
		on_badge_hover_exit: Callable, on_badge_pressed: Callable) -> void:
	if not card:
		return

	# Update Name
	var name_label = card.get_node_or_null("Nama")
	if name_label and name_label is Label:
		name_label.text = student.get("name", "Unknown")

	# Update Quirk (KutuBuku)
	var quirk_label = card.get_node_or_null("KutuBuku")
	if quirk_label and quirk_label is Label:
		var quirk_text = student.get("quirk", "")
		quirk_label.text = ("Quirk " + quirk_text) if quirk_text != "" else ""

	# Update Persona (KutuBuku2)
	var persona_label = card.get_node_or_null("KutuBuku2")
	if persona_label and persona_label is Label:
		persona_label.text = student.get("persona", "")

	# Update Portrait Texture
	var portrait_node = card.get_node_or_null("TextureRect")
	if portrait_node and portrait_node is TextureRect:
		var p_path = student.get("portrait", "")
		if p_path != "" and ResourceLoader.exists(p_path):
			portrait_node.texture = load(p_path)

	# Update ProgressBars
	var kp1 = card.get_node_or_null("Kepribadian1")
	if kp1 and kp1 is ProgressBar:
		kp1.value = student.get("kepribadian2", 0)
	var kp2 = card.get_node_or_null("Kepribadian2")
	if kp2 and kp2 is ProgressBar:
		kp2.value = student.get("kepribadian1", 0)
	var ak1 = card.get_node_or_null("Akademis1")
	if ak1 and ak1 is ProgressBar:
		ak1.value = student.get("akademis1", 0)
	var ak2 = card.get_node_or_null("Akademis2")
	if ak2 and ak2 is ProgressBar:
		ak2.value = student.get("akademis2", 0)
	var ak3 = card.get_node_or_null("Akademis3")
	if ak3 and ak3 is ProgressBar:
		ak3.value = student.get("akademis3", 0)

	# -- Upgrade bar visuals & replace trait labels with animated badges --
	build_stat_bars(card, student, on_bar_input)
	build_icon_clusters(card, student, on_bar_input)
	build_bio_panel(card, student)
	StudentCardView._style_trait_badge(card, "KutuBuku", "quirk",
		"QUIRK: " + student.get("quirk", "-"), student,
		on_badge_hover_enter, on_badge_hover_exit, on_badge_pressed)
	StudentCardView._style_trait_badge(card, "KutuBuku2", "persona",
		"PERSONA: " + student.get("persona", "-").replace("Persona ", ""), student,
		on_badge_hover_enter, on_badge_hover_exit, on_badge_pressed)


# ================= BAR RESIZE & BADGE CREATION =================

## Where each pill's fill sits, in card-local pixels. These are the exact
## positions of the tracks painted into card_bg.png, measured from the art;
## the card is sized to the texture's own 1080x1920 so they map 1:1.
const PILL_RECTS := {
	"Akademis1": Rect2(284, 763, 211, 67),
	"Akademis2": Rect2(284, 888, 211, 67),
	"Akademis3": Rect2(284, 1014, 211, 67),
	"Kepribadian1": Rect2(716, 762, 211, 67),
	"Kepribadian2": Rect2(717, 888, 211, 67),
}


## Lays each bar's fill onto its painted track. The redesign moves all
## labelling out of the bar: no stat name, no value readout, and no
## magnifying glass -- the icon cluster beside the pill (see
## build_icon_clusters) both names the stat and carries the tap.
static func build_stat_bars(kertas: Control, s_data: Dictionary,
		_on_bar_input: Callable) -> void:
	var values := {
		"Kepribadian1": s_data.get("kepribadian1", 0),
		"Kepribadian2": s_data.get("kepribadian2", 0),
		"Akademis1": s_data.get("akademis1", 0),
		"Akademis2": s_data.get("akademis2", 0),
		"Akademis3": s_data.get("akademis3", 0),
	}

	for bar_name in PILL_RECTS.keys():
		var bar = kertas.get_node_or_null(bar_name)
		if bar == null or not bar is ProgressBar:
			continue

		var rect: Rect2 = PILL_RECTS[bar_name]
		bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
		bar.offset_left = rect.position.x
		bar.offset_top = rect.position.y
		bar.offset_right = rect.position.x + rect.size.x
		bar.offset_bottom = rect.position.y + rect.size.y
		bar.show_percentage = false

		# The pill is decoration now; the icon cluster takes the input.
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Drop the children the old bar carried: the stat-name label, the
		# value readout, and the magnifier. Leaving any of them would draw
		# text on a pill the design wants blank.
		for child_name in ["Label", "ValueLabel", "InfoIcon"]:
			var stale = bar.get_node_or_null(child_name)
			if stale != null:
				bar.remove_child(stale)
				stale.queue_free()

		if bar is StatBar:
			bar.variation = &"StatPill"
			bar.set_stat(values[bar_name])
		else:
			bar.value = values[bar_name]


const _ICON_SIZE := 128.0
## Gap between the icon's right edge and the pill's left edge.
const _ICON_GAP := 24.0
## The (i) badge, overlapping the icon's bottom-right corner.
const _BADGE_SIZE := 56.0

const _STAT_ICONS: Dictionary = {
	"Akademis1": "stat_akademis.png",
	"Akademis2": "stat_senibudaya.png",
	"Akademis3": "stat_olahraga.png",
	"Kepribadian1": "stat_mood.png",
	"Kepribadian2": "stat_energy.png",
}


## One tappable icon per stat, sitting left of its pill and vertically
## centred on it. Each carries a small (i) badge so the icon reads as
## something you can press.
##
## These are siblings of the bars rather than children on purpose: the
## tutorial addresses bars by string path (`KertasMurid1/Kepribadian1`),
## so nothing may be re-parented under them.
static func build_icon_clusters(kertas: Control, s_data: Dictionary,
		on_bar_input: Callable) -> void:
	for bar_name in _STAT_ICONS.keys():
		var rect: Rect2 = PILL_RECTS[bar_name]
		var node_name: String = "Icon" + bar_name

		var cluster := kertas.get_node_or_null(node_name) as TextureRect
		if cluster == null:
			cluster = TextureRect.new()
			cluster.name = node_name
			kertas.add_child(cluster)

			var badge := TextureRect.new()
			badge.name = "InfoBadge"
			badge.texture = load(_CARD_ART + "icon_info.png")
			badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			badge.offset_left = -_BADGE_SIZE
			badge.offset_top = -_BADGE_SIZE
			badge.offset_right = 0.0
			badge.offset_bottom = 0.0
			cluster.add_child(badge)

		cluster.texture = load(_CARD_ART + _STAT_ICONS[bar_name])
		cluster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cluster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cluster.set_anchors_preset(Control.PRESET_TOP_LEFT)
		cluster.offset_left = rect.position.x - _ICON_GAP - _ICON_SIZE
		cluster.offset_top = rect.position.y + rect.size.y * 0.5 - _ICON_SIZE * 0.5
		cluster.offset_right = cluster.offset_left + _ICON_SIZE
		cluster.offset_bottom = cluster.offset_top + _ICON_SIZE

		cluster.mouse_filter = Control.MOUSE_FILTER_STOP
		cluster.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var callable := on_bar_input.bind(kertas, bar_name, s_data)
		if cluster.has_meta("cluster_gui_callable"):
			cluster.gui_input.disconnect(cluster.get_meta("cluster_gui_callable"))
		cluster.gui_input.connect(callable)
		cluster.set_meta("cluster_gui_callable", callable)


## The painted purple panel's interior, in card-local pixels, measured from
## card_bg.png.
const BIO_PANEL_RECT := Rect2(120, 300, 489, 367)
## Inset so the text does not crowd the painted panel's rounded border.
const _BIO_PADDING := 32.0


## Lays the three bio rows over the painted panel: a heading and a value
## per row. The panel art itself comes from the card background, so this
## only positions text.
##
## Also hides the three labels the redesign supersedes -- `Profil` (whose
## content these rows replace) and the `Kepribadian` / `Akademis` section
## headings, which the icon-led layout has no room for.
static func build_bio_panel(kertas: Control, s_data: Dictionary) -> void:
	for stale_name in ["Profil", "Kepribadian", "Akademis"]:
		var stale := kertas.get_node_or_null(stale_name) as CanvasItem
		if stale != null:
			stale.visible = false

	var panel := kertas.get_node_or_null("BioPanel") as VBoxContainer
	if panel == null:
		panel = VBoxContainer.new()
		panel.name = "BioPanel"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kertas.add_child(panel)

	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = BIO_PANEL_RECT.position.x + _BIO_PADDING
	panel.offset_top = BIO_PANEL_RECT.position.y + _BIO_PADDING
	panel.offset_right = BIO_PANEL_RECT.end.x - _BIO_PADDING
	panel.offset_bottom = BIO_PANEL_RECT.end.y - _BIO_PADDING

	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()

	var rows := [
		["Nama:", str(s_data.get("name", ""))],
		["Jenis Kelamin:", str(s_data.get("jenis_kelamin", ""))],
		["Tanggal Lahir:", str(s_data.get("tanggal_lahir", ""))],
	]
	for row in rows:
		var heading := Label.new()
		heading.text = row[0]
		heading.theme_type_variation = &"BioLabel"
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(heading)

		var value := Label.new()
		value.text = row[1]
		value.theme_type_variation = &"BioValue"
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(value)


static func _style_trait_badge(kertas: Control, node_name: String, trait_type: String, badge_text: String,
		s_data: Dictionary, on_hover_enter: Callable, on_hover_exit: Callable,
		on_pressed: Callable) -> void:
	var btn = kertas.get_node_or_null(node_name)
	if not btn or not btn is Button:
		return

	btn.text = badge_text
	btn.theme_type_variation = &"QuirkBadge" if trait_type == "quirk" else &"PersonaBadge"
	btn.pivot_offset = btn.size / 2.0

	if not btn.mouse_entered.is_connected(on_hover_enter.bind(btn)):
		btn.mouse_entered.connect(on_hover_enter.bind(btn))
	if not btn.mouse_exited.is_connected(on_hover_exit.bind(btn)):
		btn.mouse_exited.connect(on_hover_exit.bind(btn))
	var trait_name: String = s_data.get(trait_type, "")
	if not btn.pressed.is_connected(on_pressed):
		btn.pressed.connect(on_pressed.bind(kertas, trait_type, trait_name))

	var anim_delay = randf_range(0.4, 0.8) if trait_type == "quirk" else randf_range(1.2, 1.6)
	StudentCardView._start_button_wiggle(btn, anim_delay, "medium")


static func _start_button_wiggle(btn: Control, delay: float = 0.0, wiggle_type: String = "small") -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0

	# Kill existing wiggle tween if it exists on this button to prevent duplicates
	if btn.has_meta("wiggle_tween"):
		var old_tw = btn.get_meta("wiggle_tween")
		if is_instance_valid(old_tw):
			old_tw.kill()

	var tw := btn.create_tween().set_loops()
	btn.set_meta("wiggle_tween", tw)

	if delay > 0:
		tw.tween_interval(delay)

	if wiggle_type == "big":
		tw.tween_property(btn, "scale", Vector2(1.3, 1.3), 0.2)
		tw.tween_property(btn, "rotation_degrees", 15.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", -15.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", 10.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", -10.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", 0.0, 0.1)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
		tw.tween_interval(2.0)
	elif wiggle_type == "medium":
		tw.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.2)
		tw.tween_property(btn, "rotation_degrees", 8.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", -8.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", 5.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", -5.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", 0.0, 0.1)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
		tw.tween_interval(3.5)
	else:
		tw.tween_property(btn, "rotation_degrees", 5.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", -5.0, 0.1)
		tw.tween_property(btn, "rotation_degrees", 0.0, 0.1)
		tw.tween_interval(2.0)
