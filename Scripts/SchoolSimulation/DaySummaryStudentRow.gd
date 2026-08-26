extends PanelContainer
class_name DaySummaryStudentRow

@onready var avatar_rect: TextureRect = %AvatarTexture
@onready var name_label: Label = %NameLabel
@onready var badge_container: HBoxContainer = %BadgeContainer
@onready var pills_container: HFlowContainer = %PillsContainer

@export_group("Card Styling")
@export var card_bg_color: Color = Color(0.1, 0.12, 0.24, 0.95)
@export var card_border_color: Color = Color(0.18, 0.22, 0.38)
@export var card_border_width: int = 2
@export var card_corner_radius: int = 20

@export_group("Avatar Styling")
@export var avatar_bg_color: Color = Color(0.15, 0.18, 0.3)
@export var avatar_corner_radius: int = 56

@export_group("Pill Colors")
@export var pill_akademis_color: Color = Color(0.16, 0.27, 1.0)
@export var pill_senibudaya_color: Color = Color(0.0, 0.6, 0.25)
@export var pill_olahraga_color: Color = Color(0.75, 0.1, 0.1)
@export var pill_energy_loss_color: Color = Color(0.85, 0.2, 0.2)
@export var pill_mood_loss_color: Color = Color(0.88, 0.42, 0.08)
@export var pill_recovery_color: Color = Color(0.1, 0.65, 0.3)
@export var pill_bonus_color: Color = Color(0.82, 0.68, 0.08)
@export var pill_warning_color: Color = Color(0.78, 0.08, 0.08)

@export_group("Typography")
@export var font: Font = null

func _ready() -> void:
	_apply_visual_styles()

func _apply_visual_styles() -> void:
	var sp_sb = StyleBoxFlat.new()
	sp_sb.bg_color = card_bg_color
	sp_sb.border_color = card_border_color
	sp_sb.border_width_left = card_border_width
	sp_sb.border_width_top = card_border_width
	sp_sb.border_width_right = card_border_width
	sp_sb.border_width_bottom = card_border_width
	sp_sb.corner_radius_top_left = card_corner_radius
	sp_sb.corner_radius_top_right = card_corner_radius
	sp_sb.corner_radius_bottom_left = card_corner_radius
	sp_sb.corner_radius_bottom_right = card_corner_radius
	add_theme_stylebox_override("panel", sp_sb)

	var av_sb = StyleBoxFlat.new()
	av_sb.bg_color = avatar_bg_color
	av_sb.corner_radius_top_left = avatar_corner_radius
	av_sb.corner_radius_top_right = avatar_corner_radius
	av_sb.corner_radius_bottom_left = avatar_corner_radius
	av_sb.corner_radius_bottom_right = avatar_corner_radius
	var avatar_container = get_node("%AvatarContainer")
	if avatar_container:
		avatar_container.add_theme_stylebox_override("panel", av_sb)

func setup_row(student_name: String, changes: Array, student: StudentData) -> void:
	name_label.text = student_name
	if font:
		name_label.add_theme_font_override("font", font)
	if student and student.avatar_texture:
		avatar_rect.texture = student.avatar_texture
		
	# Setup badges
	for child in badge_container.get_children():
		child.queue_free()
		
	var event_delta_sum = 0
	for ch in changes:
		if ch.get("source") == "event":
			event_delta_sum += int(ch.get("delta"))
			
	if student and student.energy <= 20.0:
		_add_name_row_badge("⚠️ KELELAHAN", Color(0.95, 0.35, 0.35), Color(0.78, 0.08, 0.08))
	elif event_delta_sum > 0:
		_add_name_row_badge("✨ BONUS EVENT +%d" % event_delta_sum, Color(0.95, 0.82, 0.28), Color(0.85, 0.7, 0.1))
		
	# Setup pills
	for child in pills_container.get_children():
		child.queue_free()
		
	for ch in changes:
		var sk = ch.get("stat_key", "")
		var delta = ch.get("delta", 0.0)
		var source = ch.get("source", "")
		if delta == 0.0:
			continue
			
		var sign_str = "+" if delta > 0 else ""
		var suffix = ""
		if delta < 0:
			suffix = " ↓"
		elif delta > 0 and (sk == "energy" or sk == "mood"):
			suffix = " ↑"
			
		var stat_names = {
			"akademis": "Akademis",
			"seni_budaya": "Seni",
			"olahraga": "Olahraga",
			"energy": "Energy",
			"mood": "Mood"
		}
		var name_str = stat_names.get(sk, sk)
		var pill_text = "%s%d %s%s" % [sign_str, int(delta), name_str, suffix]
		var pill_color = _get_summary_pill_color(sk, delta, source)
		_add_pill(pill_text, pill_color)

func _add_name_row_badge(text: String, color: Color, outline_color: Color) -> void:
	var badge_scene = load("res://Scenes/SchoolSimulation/DaySummaryBadge.tscn")
	var lbl = badge_scene.instantiate() as Label
	lbl.text = " %s " % text
	lbl.add_theme_color_override("font_color", color)
	if font: lbl.add_theme_font_override("font", font)
	
	var base_style = lbl.get_theme_stylebox("normal")
	if base_style is StyleBoxFlat:
		var style = base_style.duplicate() as StyleBoxFlat
		style.bg_color = Color(outline_color.r, outline_color.g, outline_color.b, 0.18)
		style.border_color = outline_color
		lbl.add_theme_stylebox_override("normal", style)
	badge_container.add_child(lbl)

func _add_pill(text: String, bg_color: Color) -> void:
	var pill_scene = load("res://Scenes/SchoolSimulation/DaySummaryPill.tscn")
	var lbl = pill_scene.instantiate() as Label
	lbl.text = " %s " % text
	if font: lbl.add_theme_font_override("font", font)
	
	var base_style = lbl.get_theme_stylebox("normal")
	if base_style is StyleBoxFlat:
		var style = base_style.duplicate() as StyleBoxFlat
		style.bg_color = bg_color
		lbl.add_theme_stylebox_override("normal", style)
	pills_container.add_child(lbl)

func _get_summary_pill_color(stat_key: String, delta: float, source: String) -> Color:
	if source == "minigame_win": return pill_bonus_color
	if source == "event": return Color(0.45, 0.18, 0.72)
	if delta > 0:
		match stat_key:
			"akademis": return pill_akademis_color
			"seni_budaya": return pill_senibudaya_color
			"olahraga": return pill_olahraga_color
			"energy": return pill_recovery_color
			"mood": return pill_recovery_color
	else:
		match stat_key:
			"energy": return pill_energy_loss_color
			"mood": return pill_mood_loss_color
	return Color(0.35, 0.35, 0.4)
