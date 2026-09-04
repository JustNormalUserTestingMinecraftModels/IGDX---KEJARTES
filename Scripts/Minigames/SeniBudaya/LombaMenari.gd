extends BaseMinigame

## SeniBudaya minigame: a 4-direction rhythm game. Notes spawn per
## rhythm_patterns and travel toward the hit zone; the player swipes the
## matching direction (LEFT/RIGHT/TOP_LEFT/TOP_RIGHT) as each one arrives.
## The dancer character's pose reflects the most recent swipe result.
##
## Winning (reaching target_score) feeds the SeniBudaya stat -- see
## StudentData.apply_minigame_result.

enum NoteType {
	LEFT,       # Red
	RIGHT,      # Blue
	TOP_LEFT,   # Yellow
	TOP_RIGHT   # Green
}

## Backdrop behind the dance stage.
@export var background_texture: Texture2D

@export_group("Note Textures (Incoming PNGs)")
## Sprite for an unswiped LEFT note approaching the hit zone.
@export var left_note_texture: Texture2D
## Same as left_note_texture, for RIGHT.
@export var right_note_texture: Texture2D
## Same as left_note_texture, for TOP_LEFT.
@export var top_left_note_texture: Texture2D
## Same as left_note_texture, for TOP_RIGHT.
@export var top_right_note_texture: Texture2D

@export_group("Swiped Textures (Feedback PNGs)")
## Sprite briefly shown on a LEFT note after a successful swipe.
@export var left_swiped_texture: Texture2D
## Same as left_swiped_texture, for RIGHT.
@export var right_swiped_texture: Texture2D
## Same as left_swiped_texture, for TOP_LEFT.
@export var top_left_swiped_texture: Texture2D
## Same as left_swiped_texture, for TOP_RIGHT.
@export var top_right_swiped_texture: Texture2D

# ─── Visual - Hit Zone ──────────────────────────────────────────────────────
@export_group("Visual - Hit Zone")
## Sprite marking where notes must be swiped. Null draws hit_zone_color instead.
@export var hit_zone_texture: Texture2D = null
## Procedural-mode fill for the hit zone.
@export var hit_zone_color: Color = Color(0.0, 1.0, 0.0, 0.3)

# ─── Visual - Note Colors ────────────────────────────────────────────────────
@export_group("Visual - Note Colors")
## Procedural-mode tint for LEFT notes, used when left_note_texture is null.
@export var left_note_color: Color     = Color(1.0, 0.2, 0.2)
## Same as left_note_color, for RIGHT.
@export var right_note_color: Color    = Color(0.2, 0.5, 1.0)
## Same as left_note_color, for TOP_LEFT.
@export var top_left_note_color: Color = Color(1.0, 0.8, 0.1)
## Same as left_note_color, for TOP_RIGHT.
@export var top_right_note_color: Color = Color(0.2, 0.8, 0.3)

# ─── Visual - Typography ─────────────────────────────────────────────────────
@export_group("Visual - Typography")
## Optional font override for the score/feedback labels. Null keeps the
## theme default.
@export var font: Font = null
## Font size for the per-note hit/miss feedback text.
@export var feedback_font_size: int = 40

@export_group("Dancer Character Assets")
## Dancer pose while waiting for the next note.
@export var dancer_idle_texture: Texture2D
## Dancer pose immediately after a successful LEFT swipe.
@export var dancer_left_texture: Texture2D
## Same as dancer_left_texture, for RIGHT.
@export var dancer_right_texture: Texture2D
## Same as dancer_left_texture, for TOP_LEFT.
@export var dancer_top_left_texture: Texture2D
## Same as dancer_left_texture, for TOP_RIGHT.
@export var dancer_top_right_texture: Texture2D
## Dancer pose after a missed note.
@export var dancer_fail_texture: Texture2D

## Points a PERFECT hit is worth. The star rubric divides by this, so it is a
## const rather than an inline literal at the two award sites.
const POINTS_PERFECT: int = 100
## Points a merely-good (matched but outside the tight window) hit is worth.
const POINTS_GOOD: int = 50

var score: int = 0
var target_score: int = 1500

## Notes swiped inside the PERFECT window this run. Read by get_star_ratio().
var perfect_hits: int = 0
## Notes swiped correctly but outside the PERFECT window this run.
var good_hits: int = 0
## Notes that reached the hit zone unanswered this run.
var missed_notes: int = 0
## Consecutive hits without a miss, for the HUD's combo chip. Reset by a miss.
var current_combo: int = 0
## Longest combo this run. Not yet read by the star rubric -- reserved for a
## balance pass once real playtest numbers exist.
var best_combo: int = 0

var next_spawn_time: float = 1.0
var time_elapsed: float = 0.0

var active_notes: Array = []
var note_speed: float = 220.0 # Lower speed for balanced reaction time

# Rhythm pattern sequence configuration (no simultaneous opposite notes)
var rhythm_patterns: Array = [
	# Pattern 1: Basic Groove (Single beat sequence)
	[
		{"types": [NoteType.LEFT], "interval": 1.2},
		{"types": [NoteType.RIGHT], "interval": 1.2},
		{"types": [NoteType.TOP_LEFT], "interval": 1.2},
		{"types": [NoteType.TOP_RIGHT], "interval": 1.6}
	],
	# Pattern 2: Rapid Staggered Steps (Left -> Top-Left -> Top-Right -> Right)
	[
		{"types": [NoteType.LEFT], "interval": 0.8},
		{"types": [NoteType.TOP_LEFT], "interval": 0.8},
		{"types": [NoteType.TOP_RIGHT], "interval": 0.8},
		{"types": [NoteType.RIGHT], "interval": 1.6}
	],
	# Pattern 3: Corner Pair Steps (Compatible adjacent pairs)
	[
		{"types": [NoteType.LEFT, NoteType.TOP_LEFT], "interval": 1.5},
		{"types": [NoteType.RIGHT, NoteType.TOP_RIGHT], "interval": 1.8}
	],
	# Pattern 4: Syncopated Single Beats
	[
		{"types": [NoteType.TOP_LEFT], "interval": 0.7},
		{"types": [NoteType.RIGHT], "interval": 1.1},
		{"types": [NoteType.TOP_RIGHT], "interval": 0.7},
		{"types": [NoteType.LEFT], "interval": 1.6}
	],
	# Pattern 5: Dance Wave (Flowing across the stage)
	[
		{"types": [NoteType.LEFT], "interval": 0.7},
		{"types": [NoteType.RIGHT], "interval": 0.7},
		{"types": [NoteType.LEFT], "interval": 1.2},
		{"types": [NoteType.TOP_RIGHT], "interval": 1.6}
	]
]

var active_pattern_index: int = 0
var pattern_step_index: int = 0

@onready var background_rect: TextureRect = $Background
@onready var score_hud: MinigameScoreHUD = $ScoreHUD
@onready var hit_zone: Control = $HitZone
@onready var notes_parent: Control = $NotesParent
@onready var character_display: TextureRect = $CharacterDisplay

var dancer_label: Label
var dancer_tween: Tween
var is_dancer_failed: bool = false
var dancer_base_scale: Vector2 = Vector2.ONE
var dancer_base_rotation: float = 0.0

var hit_zone_base_scale: Vector2 = Vector2.ONE
var hit_zone_base_rotation: float = 0.0
var hit_zone_tween: Tween = null

# Swipe gesture variables
var swipe_start_pos: Vector2
var is_swiping: bool = false
var min_swipe_length: float = 40.0 # Threshold for swipe detection

func _ready() -> void:
	super._ready()
	if background_rect:
		if background_texture:
			background_rect.texture = background_texture
		else:
			background_rect.texture = _create_flat_texture(Color(0.08, 0.08, 0.12))
			
	if hit_zone:
		hit_zone.pivot_offset = hit_zone.size / 2.0
		hit_zone.resized.connect(func(): hit_zone.pivot_offset = hit_zone.size / 2.0)
		if hit_zone_texture:
			hit_zone.texture = hit_zone_texture
		else:
			hit_zone.texture = _create_rounded_box_texture(
				Color(0.1, 0.9, 0.3, 0.22), # Translucent emerald green fill
				Color(0.2, 1.0, 0.4, 0.85), # Neon green glowing border
			)
			
func start_minigame(game_difficulty: int, _time_limit: float = 30.0) -> void:
	super.start_minigame(game_difficulty, 0.0)
	score = 0
	perfect_hits = 0
	good_hits = 0
	missed_notes = 0
	if difficulty == 2:
		target_score = 2000
		note_speed = 270.0
	elif difficulty >= 3:
		target_score = 2500
		note_speed = 320.0
	else:
		target_score = 1500
		note_speed = 220.0
	
	current_combo = 0
	best_combo = 0
	if score_hud:
		score_hud.setup(load("res://Assets/Images/UI/Placeholders/icon_seni.svg"), target_score)

	# Setup Dancer Character Display
	if character_display:
		character_display.pivot_offset = character_display.size / 2.0
		
		# Create overlay label for placeholder visual indication
		dancer_label = Label.new()
		dancer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dancer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dancer_label.add_theme_font_size_override("font_size", 32)
		dancer_label.add_theme_color_override("font_color", Color.WHITE)
		dancer_label.add_theme_constant_override("outline_size", 12)
		dancer_label.add_theme_color_override("font_outline_color", Color.BLACK)
		dancer_label.anchor_left = 0.0
		dancer_label.anchor_top = 0.0
		dancer_label.anchor_right = 1.0
		dancer_label.anchor_bottom = 1.0
		dancer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		dancer_label.grow_vertical = Control.GROW_DIRECTION_BOTH
		character_display.add_child(dancer_label)
		
		_set_dancer_idle()
	
	# Start spawning beats
	next_spawn_time = 1.0

func _process(delta: float) -> void:
	super._process(delta)
	
	if not is_game_active:
		return
		
	time_elapsed += delta
	
	# Spawn notes procedurally based on rhythm pattern
	if time_elapsed >= next_spawn_time:
		_spawn_rhythm_beat()
		
	# Rhythmic breathing & bounce animation for all non-failed dancer poses (Idle, Left, Right, Top-Left, Top-Right)
	if character_display and not is_dancer_failed:
		var breath_phase: float = time_elapsed * 5.0
		var breath_y: float = sin(breath_phase) * 0.05
		var breath_x: float = -sin(breath_phase) * 0.03
		character_display.scale = dancer_base_scale * Vector2(1.0 + breath_x, 1.0 + breath_y)
		character_display.rotation = dancer_base_rotation + sin(breath_phase * 0.5) * 0.03
		
	# Rhythmic continuous wiggle & pulse animation for the green hit zone
	if hit_zone:
		var hz_phase: float = time_elapsed * 8.0
		var hz_bounce_y: float = sin(hz_phase) * 0.04
		var hz_bounce_x: float = -sin(hz_phase) * 0.02
		var hz_wobble: float = sin(hz_phase * 0.5) * 0.03
		hit_zone.scale = hit_zone_base_scale * Vector2(1.0 + hz_bounce_x, 1.0 + hz_bounce_y)
		hit_zone.rotation = hit_zone_base_rotation + hz_wobble
		
	# Move notes and apply jumpy impatient idle dance animation
	var hz_center = hit_zone.get_global_rect().get_center()
	var notes_to_remove = []
	for note in active_notes:
		var move_dir: Vector2 = note.get_meta("move_dir", Vector2.DOWN)
		note.global_position += move_dir * note_speed * delta
		
		# Jumpy impatient pulse and wobble animation
		var phase: float = note.get_meta("anim_phase", 0.0) + time_elapsed * 14.0
		var bounce_scale: float = 1.0 + sin(phase) * 0.12 # Energetic scale pulse
		var wobble_rot: float = sin(phase * 0.8) * 0.15 # Impatient wobble
		note.scale = Vector2(bounce_scale, bounce_scale)
		note.rotation = wobble_rot
		
		# Miss if note moves past the hit zone center
		var note_center = note.global_position + note.size / 2.0
		var vec_from_target = note_center - hz_center
		if vec_from_target.dot(move_dir) > 80.0:
			missed_notes += 1
			current_combo = 0
			if score_hud:
				score_hud.set_combo(current_combo)
			notes_to_remove.append(note)
			
	for note in notes_to_remove:
		active_notes.erase(note)
		note.queue_free()
		_show_hit_feedback("MISS!", Color.RED)
		_play_dancer_fail_motion()

func _spawn_rhythm_beat() -> void:
	if rhythm_patterns.is_empty():
		return
		
	var pattern = rhythm_patterns[active_pattern_index]
	var beat_info = pattern[pattern_step_index]
	
	# Spawn notes for this beat
	for type in beat_info["types"]:
		_spawn_single_note(type)
		
	# Schedule next beat time based on the rhythm pattern's interval
	var next_interval: float = beat_info.get("interval", 1.2)
	next_spawn_time = time_elapsed + next_interval
	
	# Advance pattern step
	pattern_step_index += 1
	if pattern_step_index >= pattern.size():
		pattern_step_index = 0
		# Pick next pattern
		active_pattern_index = (active_pattern_index + randi_range(1, rhythm_patterns.size() - 1)) % rhythm_patterns.size()

func _spawn_single_note(type: int) -> void:
	var note = TextureRect.new()
	note.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	var hz_rect = hit_zone.get_global_rect()
	var hz_center = hz_rect.get_center()
	var note_size_val = max(hz_rect.size.x * 0.4, 60.0)
	var note_size = Vector2(note_size_val, note_size_val)
	note.custom_minimum_size = note_size
	note.size = note_size
	note.set_meta("note_type", type)
	
	# Determine movement vector and origin position based on NoteType
	# LEFT: comes from Left off-screen, moves RIGHT
	# RIGHT: comes from Right off-screen, moves LEFT
	# TOP_LEFT: comes from Top-Left off-screen, moves DOWN-RIGHT
	# TOP_RIGHT: comes from Top-Right off-screen, moves DOWN-LEFT
	var move_dir = Vector2.ZERO
	var fallback_color = Color.WHITE
	var arrow = ""
	var tex = null
	
	match type:
		NoteType.LEFT:
			tex = left_note_texture
			fallback_color = left_note_color
			arrow = "←"
			move_dir = Vector2(1, 0)
		NoteType.RIGHT:
			tex = right_note_texture
			fallback_color = right_note_color
			arrow = "→"
			move_dir = Vector2(-1, 0)
		NoteType.TOP_LEFT:
			tex = top_left_note_texture
			fallback_color = top_left_note_color
			arrow = "↖"
			move_dir = Vector2(0.7071, 0.7071)
		NoteType.TOP_RIGHT:
			tex = top_right_note_texture
			fallback_color = top_right_note_color
			arrow = "↗"
			move_dir = Vector2(-0.7071, 0.7071)
			
	note.set_meta("move_dir", move_dir)
	
	if tex:
		note.texture = tex
		note.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		note.texture = _create_rounded_box_texture(fallback_color, Color.WHITE, 4)
	
	# Visual text indicator inside note
	var label = Label.new()
	label.name = "ArrowLabel"
	label.text = arrow
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.visible = (tex == null)
	
	note.add_child(label)
	
	# Compute spawn position far enough away along the reverse movement direction
	var spawn_distance = max(get_viewport_rect().size.x, get_viewport_rect().size.y) * 0.55
	var spawn_center = hz_center - move_dir * spawn_distance
	note.global_position = spawn_center - note_size / 2.0
	
	note.pivot_offset = note_size / 2.0
	note.set_meta("anim_phase", randf_range(0.0, 6.28))
	
	notes_parent.add_child(note)
	active_notes.append(note)

func _input(event: InputEvent) -> void:
	if not is_game_active:
		return
		
	if event is InputEventScreenTouch:
		if event.is_pressed():
			swipe_start_pos = event.position
			is_swiping = true
		else:
			if is_swiping:
				_handle_swipe(event.position)
				is_swiping = false
				
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			swipe_start_pos = event.position
			is_swiping = true
		else:
			if is_swiping:
				_handle_swipe(event.position)
				is_swiping = false

func _handle_swipe(end_pos: Vector2) -> void:
	var swipe_vec = end_pos - swipe_start_pos
	if swipe_vec.length() < min_swipe_length:
		return
		
	var swipe_dir = swipe_vec.normalized()
	
	# Direction vectors corresponding to LEFT, RIGHT, TOP_LEFT, TOP_RIGHT
	var dirs = {
		NoteType.LEFT: Vector2(-1, 0),
		NoteType.RIGHT: Vector2(1, 0),
		NoteType.TOP_LEFT: Vector2(-0.7071, -0.7071),
		NoteType.TOP_RIGHT: Vector2(0.7071, -0.7071)
	}
	
	var best_type = NoteType.LEFT
	var max_dot = -2.0
	
	for type in dirs:
		var dot = swipe_dir.dot(dirs[type])
		if dot > max_dot:
			max_dot = dot
			best_type = type
			
	# If the swipe aligns nicely (dot > 0.707, i.e. < 45 degrees deviation)
	if max_dot > 0.707:
		_evaluate_swipe(best_type)

func _evaluate_swipe(swipe_type: int) -> void:
	_show_swipe_effect(swipe_type)
	
	if active_notes.is_empty():
		_play_dancer_fail_motion()
		return
		
	var hz_center = hit_zone.get_global_rect().get_center()
	
	# Find matching note closest to hit zone center within threshold
	var best_note: Control = null
	var min_dist: float = 999999.0
	
	for note in active_notes:
		if note.get_meta("note_type") == swipe_type:
			var note_center = note.global_position + note.size / 2.0
			var dist = note_center.distance_to(hz_center)
			if dist < min_dist:
				min_dist = dist
				best_note = note
				
	if best_note != null and min_dist < 120.0:
		var required_type = best_note.get_meta("note_type")
		if swipe_type == required_type:
			if min_dist < 45.0:
				score += POINTS_PERFECT
				perfect_hits += 1
				current_combo += 1
				best_combo = maxi(best_combo, current_combo)
				_show_hit_feedback("PERFECT!", Color(1.0, 0.84, 0.0))
				_pulse_hit_zone(Color(1.0, 0.9, 0.2)) # Glowing gold/yellow pulse
			else:
				score += POINTS_GOOD
				good_hits += 1
				current_combo += 1
				best_combo = maxi(best_combo, current_combo)
				_show_hit_feedback("GOOD!", Color(0.2, 0.9, 0.4))
				_pulse_hit_zone(Color(0.3, 1.0, 0.5)) # Glowing green pulse
			_play_dancer_motion(swipe_type)
			active_notes.erase(best_note)
			_animate_swiped_note(best_note, swipe_type)
		else:
			_show_hit_feedback("WRONG SWIPE!", Color(0.9, 0.3, 0.3))
			_pulse_hit_zone(Color(0.9, 0.2, 0.2)) # Failed red pulse
			_play_dancer_fail_motion()
	else:
		_show_hit_feedback("TOO EARLY!", Color(1.0, 0.6, 0.2))
		_pulse_hit_zone(Color(1.0, 0.55, 0.15)) # Orange alert pulse
		_play_dancer_fail_motion()
			
	if score_hud:
		score_hud.set_score(score)
		score_hud.set_combo(current_combo)

	if score >= target_score:
		win_game()

## Note accuracy: points earned as a fraction of the points that were actually
## on the table. An all-PERFECT routine rates 1.0; a routine that only ever
## grazes the window tops out at 0.5 even if it clears the score target.
##
## Affects: nothing. Pure. Static so a test can call it with no instance.
static func _note_accuracy_ratio(perfect_hits: int, good_hits: int, missed_notes: int) -> float:
	var notes_presented: int = perfect_hits + good_hits + missed_notes
	if notes_presented <= 0:
		return STAR_RATIO_UNKNOWN
	var earned: int = perfect_hits * POINTS_PERFECT + good_hits * POINTS_GOOD
	var possible: int = notes_presented * POINTS_PERFECT
	return clampf(float(earned) / float(possible), 0.0, 1.0)


## How well the player did this run, delegated to the static helper above.
##
## Affects: nothing. Pure. Read by BaseMinigame._show_result_overlay().
func get_star_ratio() -> float:
	return _note_accuracy_ratio(perfect_hits, good_hits, missed_notes)

func _remove_note(note: Control) -> void:
	active_notes.erase(note)
	note.queue_free()

func _animate_swiped_note(note: Control, swipe_type: int) -> void:
	if not note:
		return
		
	# Bring hit note to front
	if notes_parent and note.get_parent() == notes_parent:
		notes_parent.move_child(note, notes_parent.get_child_count() - 1)
		
	var arrow_char = ""
	var target_color = Color.WHITE
	var slide_dir = Vector2.ZERO
	var rot_target = 0.0
	var swiped_tex: Texture2D = null
	
	match swipe_type:
		NoteType.LEFT:
			arrow_char = "←"
			target_color = left_note_color
			slide_dir = Vector2(-160, 0)
			rot_target = -0.3
			swiped_tex = left_swiped_texture
		NoteType.RIGHT:
			arrow_char = "→"
			target_color = right_note_color
			slide_dir = Vector2(160, 0)
			rot_target = 0.3
			swiped_tex = right_swiped_texture
		NoteType.TOP_LEFT:
			arrow_char = "↖"
			target_color = top_left_note_color
			slide_dir = Vector2(-120, -120)
			rot_target = -0.4
			swiped_tex = top_left_swiped_texture
		NoteType.TOP_RIGHT:
			arrow_char = "↗"
			target_color = top_right_note_color
			slide_dir = Vector2(120, -120)
			rot_target = 0.4
			swiped_tex = top_right_swiped_texture
			
	if swiped_tex:
		note.texture = swiped_tex
		note.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var label = note.get_node_or_null("ArrowLabel")
		if label:
			label.visible = false
	else:
		# Glow color calculation (slightly brighter note color)
		var glow_color = Color(target_color.r * 1.25, target_color.g * 1.25, target_color.b * 1.25, 0.9)
		note.texture = _create_rounded_box_texture(glow_color, Color.WHITE, 5)
		var label = note.get_node_or_null("ArrowLabel")
		if label:
			label.text = arrow_char
			label.visible = true
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			
	var tween = create_tween()
	tween.set_parallel(true)
	# Slide in the direction of swipe
	tween.tween_property(note, "global_position", note.global_position + slide_dir, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Expand scale
	tween.tween_property(note, "scale", Vector2(1.5, 1.5), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Decelerating rotation
	tween.tween_property(note, "rotation", rot_target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Gradual smooth alpha fade out
	tween.tween_property(note, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.set_parallel(false)
	tween.tween_callback(note.queue_free)

func _show_hit_feedback(feedback_text: String, color: Color) -> void:
	var feedback = Label.new()
	feedback.text = feedback_text
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback.add_theme_font_size_override("font_size", 48)
	feedback.add_theme_color_override("font_color", color)
	feedback.add_theme_constant_override("outline_size", 12)
	feedback.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Spawn slightly above hit zone
	feedback.global_position = hit_zone.global_position + Vector2((hit_zone.size.x - 200)/2, -60)
	add_child(feedback)
	
	# Fade and slide up
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(feedback, "global_position:y", feedback.global_position.y - 50, 0.4)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.4)
	tween.set_parallel(false)
	tween.tween_callback(feedback.queue_free)

func _show_swipe_effect(swipe_type: int) -> void:
	var effect = Label.new()
	var arrow_char = ""
	var color = Color.WHITE
	
	match swipe_type:
		NoteType.LEFT:
			arrow_char = "←"
			color = Color(1.0, 0.2, 0.2)
		NoteType.RIGHT:
			arrow_char = "→"
			color = Color(0.2, 0.5, 1.0)
		NoteType.TOP_LEFT:
			arrow_char = "↖"
			color = Color(1.0, 0.8, 0.1)
		NoteType.TOP_RIGHT:
			arrow_char = "↗"
			color = Color(0.2, 0.8, 0.3)
			
	effect.text = arrow_char
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effect.add_theme_font_size_override("font_size", 96)
	effect.add_theme_color_override("font_color", color)
	effect.add_theme_constant_override("outline_size", 16)
	effect.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Position at center of hit zone
	effect.global_position = hit_zone.global_position + hit_zone.size / 2 - Vector2(50, 50)
	add_child(effect)
	
	# Visual offset vectors for drift drift
	var dir = Vector2.ZERO
	match swipe_type:
		NoteType.LEFT: dir = Vector2(-80, 0)
		NoteType.RIGHT: dir = Vector2(80, 0)
		NoteType.TOP_LEFT: dir = Vector2(-60, -60)
		NoteType.TOP_RIGHT: dir = Vector2(60, -60)
		
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "global_position", effect.global_position + dir, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(effect, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(effect.queue_free)

# Utility helper to generate a solid color texture dynamically if no texture is assigned in inspector
func _create_flat_texture(color: Color) -> ImageTexture:
	var img = Image.create(80, 80, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _set_dancer_idle() -> void:
	is_dancer_failed = false
	dancer_base_rotation = 0.0
	dancer_base_scale = Vector2.ONE
	
	if not character_display:
		return
		
	if dancer_idle_texture:
		character_display.texture = dancer_idle_texture
		if dancer_label:
			dancer_label.text = ""
	else:
		character_display.texture = _create_flat_texture(Color(0.2, 0.25, 0.35, 0.6))
		if dancer_label:
			dancer_label.text = "🕺 IDLE"
			
	character_display.modulate = Color.WHITE

func _play_dancer_motion(swipe_type: int) -> void:
	is_dancer_failed = false
	
	if not character_display:
		return
		
	if dancer_tween and dancer_tween.is_running():
		dancer_tween.kill()
		
	var target_tex: Texture2D = null
	var label_str: String = ""
	var rot_target: float = 0.0
	var scale_target: Vector2 = Vector2(1.15, 1.15)
	
	match swipe_type:
		NoteType.LEFT:
			target_tex = dancer_left_texture
			label_str = "◄ DANCE LEFT 🕺"
			rot_target = deg_to_rad(-15.0)
			scale_target = Vector2(1.2, 0.85)
		NoteType.RIGHT:
			target_tex = dancer_right_texture
			label_str = "🕺 DANCE RIGHT ►"
			rot_target = deg_to_rad(15.0)
			scale_target = Vector2(1.2, 0.85)
		NoteType.TOP_LEFT:
			target_tex = dancer_top_left_texture
			label_str = "↖ DIAGONAL LEFT 💃"
			rot_target = deg_to_rad(-22.0)
			scale_target = Vector2(1.15, 1.25)
		NoteType.TOP_RIGHT:
			target_tex = dancer_top_right_texture
			label_str = "💃 DIAGONAL RIGHT ↗"
			rot_target = deg_to_rad(22.0)
			scale_target = Vector2(1.15, 1.25)

	# Direct texture swap without alpha flickering
	if target_tex:
		character_display.texture = target_tex
		if dancer_label:
			dancer_label.text = ""
	else:
		var colors = {
			NoteType.LEFT: Color(0.9, 0.2, 0.2, 0.8),
			NoteType.RIGHT: Color(0.2, 0.5, 0.9, 0.8),
			NoteType.TOP_LEFT: Color(0.9, 0.7, 0.1, 0.8),
			NoteType.TOP_RIGHT: Color(0.2, 0.8, 0.4, 0.8)
		}
		character_display.texture = _create_flat_texture(colors.get(swipe_type, Color.WHITE))
		if dancer_label:
			dancer_label.text = label_str

	character_display.modulate = Color.WHITE

	# Spring dance motion tween updating base pose scale and rotation
	dancer_tween = create_tween()
	dancer_tween.set_parallel(true)
	dancer_tween.tween_property(self, "dancer_base_rotation", rot_target, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dancer_tween.tween_property(self, "dancer_base_scale", scale_target, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Hold pose for 0.9s delay before smoothly returning base scale/rotation to Idle
	dancer_tween.chain().tween_interval(0.9)
	dancer_tween.chain().set_parallel(true)
	dancer_tween.tween_property(self, "dancer_base_rotation", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	dancer_tween.tween_property(self, "dancer_base_scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	dancer_tween.chain().tween_callback(_set_dancer_idle)

func _play_dancer_fail_motion() -> void:
	is_dancer_failed = true
	
	if not character_display:
		return
		
	if dancer_tween and dancer_tween.is_running():
		dancer_tween.kill()
		
	if dancer_fail_texture:
		character_display.texture = dancer_fail_texture
		if dancer_label:
			dancer_label.text = ""
	else:
		character_display.texture = _create_flat_texture(Color(0.85, 0.15, 0.2, 0.85))
		if dancer_label:
			dancer_label.text = "💔 MISSED!"
			
	character_display.modulate = Color.WHITE

	# Shake & droop motion tween directly animating character_display
	dancer_tween = create_tween()
	dancer_tween.set_parallel(true)
	dancer_tween.tween_property(character_display, "scale", Vector2(0.85, 0.85), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dancer_tween.tween_property(character_display, "rotation", deg_to_rad(-8.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Hold fail pose for 0.9s delay before returning to Idle
	dancer_tween.chain().tween_interval(0.9)
	dancer_tween.chain().set_parallel(true)
	dancer_tween.tween_property(character_display, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	dancer_tween.tween_property(character_display, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	dancer_tween.chain().tween_callback(_set_dancer_idle)

func _pulse_hit_zone(flash_color: Color) -> void:
	if not hit_zone:
		return
	if hit_zone_tween and hit_zone_tween.is_running():
		hit_zone_tween.kill()
		
	hit_zone.modulate = flash_color
	hit_zone_tween = create_tween()
	hit_zone_tween.set_parallel(true)
	# Elastic quick bounce scaling and flash fadeout
	hit_zone_tween.tween_property(self, "hit_zone_base_scale", Vector2(1.15, 1.15), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hit_zone_tween.tween_property(hit_zone, "modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Smoothly return base scale back to original
	hit_zone_tween.set_parallel(false)
	hit_zone_tween.tween_property(self, "hit_zone_base_scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Utility helper to generate a rounded box texture with optional border dynamically
func _create_rounded_box_texture(fill_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> ImageTexture:
	var width = 96
	var height = 96
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var radius = 16.0
	for y in range(height):
		for x in range(width):
			var dx = max(0.0, max(radius - x, x - (width - 1 - radius)))
			var dy = max(0.0, max(radius - y, y - (height - 1 - radius)))
			var dist = sqrt(dx * dx + dy * dy)
			if dist <= radius:
				var is_border = false
				if border_width > 0:
					# Check if within border distance
					if x < border_width or x >= width - border_width or y < border_width or y >= height - border_width or dist > radius - border_width:
						is_border = true
				if is_border:
					img.set_pixel(x, y, border_color)
				else:
					img.set_pixel(x, y, fill_color)
	return ImageTexture.create_from_image(img)
