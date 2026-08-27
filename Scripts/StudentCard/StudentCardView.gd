class_name StudentCardView
extends RefCounted

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
static func populate(card: Control, student: Dictionary, icon_magnify: Texture2D,
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

	# Update Profil
	var profil_label = card.get_node_or_null("Profil")
	if profil_label and profil_label is Label:
		var p_text = "Nama: " + student.get("name", "") + "\n\n"
		p_text += student.get("profil", "")
		profil_label.text = p_text

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
	build_stat_bars(card, student, icon_magnify, on_bar_input)
	StudentCardView._style_trait_badge(card, "KutuBuku", "quirk",
		"QUIRK: " + student.get("quirk", "-"), student,
		on_badge_hover_enter, on_badge_hover_exit, on_badge_pressed)
	StudentCardView._style_trait_badge(card, "KutuBuku2", "persona",
		"PERSONA: " + student.get("persona", "-").replace("Persona ", ""), student,
		on_badge_hover_enter, on_badge_hover_exit, on_badge_pressed)


# ================= BAR RESIZE & BADGE CREATION =================

static func build_stat_bars(kertas: Control, s_data: Dictionary, icon_magnify: Texture2D,
		on_bar_input: Callable) -> void:
	const BAR_HEIGHT := 68.0

	var bar_names = ["Kepribadian1", "Kepribadian2", "Akademis1", "Akademis2", "Akademis3"]
	var bar_index := {
		"Kepribadian1": 0,
		"Kepribadian2": 1,
		"Akademis1": 2,
		"Akademis2": 3,
		"Akademis3": 4
	}

	for bname in bar_names:
		var bar = kertas.get_node_or_null(bname)
		if not bar or not bar is ProgressBar:
			continue

		var idx: int = bar_index[bname]

		var current_val = 0.0
		var max_val = 100.0
		if bname == "Kepribadian1":
			current_val = s_data.get("kepribadian1", 0)
			max_val = 100.0
		elif bname == "Kepribadian2":
			current_val = s_data.get("kepribadian2", 0)
			max_val = 100.0
		elif bname == "Akademis1":
			current_val = s_data.get("akademis1", 0)
		elif bname == "Akademis2":
			current_val = s_data.get("akademis2", 0)
		elif bname == "Akademis3":
			current_val = s_data.get("akademis3", 0)

		# Style stat name label (MOOD, ENERGY, AKADEMIS, SENI BUDAYA, OLAHRAGA).
		# The old code picked between a dark and a light text color based on
		# how full the bar was, so a label could flip color mid-run. The
		# BarLabel theme variation replaces that with one legible treatment
		# (white glyph, dark rim) that reads over both the track and every
		# category fill, so no per-node override is needed at all.
		var stat_lbl = bar.get_node_or_null("Label")
		if stat_lbl and stat_lbl is Label:
			stat_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
			stat_lbl.offset_left = 24
			stat_lbl.offset_top = 0
			stat_lbl.offset_right = 300
			stat_lbl.offset_bottom = BAR_HEIGHT
			stat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			stat_lbl.theme_type_variation = &"BarLabel"

		# The bars are StatBar nodes now: the pill track and the white
		# fill come from the StatBar theme variation, and the per-category
		# tint from StatBar.category (set in the scene) via self_modulate.
		# Nothing here needs to build a stylebox any more. Animating the
		# value through set_stat() also gives each bar a fill sweep on
		# entry instead of snapping to its final width.
		if bar is StatBar:
			bar.set_stat(current_val)
		else:
			bar.value = current_val
		bar.show_percentage = false

		# Make it obviously clickable
		bar.mouse_filter = Control.MOUSE_FILTER_STOP
		bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		# Ensure clean event binding for bar
		var callable = on_bar_input.bind(kertas, bname, s_data)
		if bar.has_meta("bar_gui_callable"):
			bar.gui_input.disconnect(bar.get_meta("bar_gui_callable"))
		bar.gui_input.connect(callable)
		bar.set_meta("bar_gui_callable", callable)

		# Add a magnifying glass icon (Lup)
		var info_icon = bar.get_node_or_null("InfoIcon")
		if not info_icon:
			if icon_magnify:
				var tex = TextureRect.new()
				tex.texture = icon_magnify
				tex.name = "InfoIcon"
				tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				info_icon = tex
			else:
				var lbl = Label.new()
				lbl.name = "InfoIcon"
				lbl.text = "??"
				lbl.theme_type_variation = &"TitleLabel"
				info_icon = lbl

			info_icon.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			info_icon.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			info_icon.custom_minimum_size = Vector2(56, 56)
			info_icon.offset_left = 16
			info_icon.offset_right = 72
			info_icon.offset_top = -28
			info_icon.offset_bottom = 28

			info_icon.mouse_filter = Control.MOUSE_FILTER_STOP
			info_icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

			bar.add_child(info_icon)
			StudentCardView._start_button_wiggle(info_icon, idx * 0.2, "big")

		if info_icon.has_meta("icon_gui_callable"):
			info_icon.gui_input.disconnect(info_icon.get_meta("icon_gui_callable"))
		info_icon.gui_input.connect(callable)
		info_icon.set_meta("icon_gui_callable", callable)

		# Add or update numerical value label
		var val_lbl = bar.get_node_or_null("ValueLabel")
		if not val_lbl:
			val_lbl = Label.new()
			val_lbl.name = "ValueLabel"
			bar.add_child(val_lbl)

		val_lbl.text = "%d / %d" % [int(current_val), int(max_val)]
		val_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		val_lbl.offset_left = 10
		val_lbl.offset_top = 0
		val_lbl.offset_right = bar.size.x - 24
		val_lbl.offset_bottom = BAR_HEIGHT
		val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.theme_type_variation = &"BarLabel"


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
	pass
