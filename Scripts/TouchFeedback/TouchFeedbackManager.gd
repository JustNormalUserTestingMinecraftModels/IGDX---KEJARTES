extends CanvasLayer

## Global tap/click ripple. An autoload -- watches every mouse/touch press
## via `_input()` and spawns a `TouchFeedbackEffect` at the press position,
## reaching every screen automatically with no per-node opt-in (unlike
## `UIPolish`/`Juice`, there is no per-node opt-out meta flag either; the
## only way to suppress it on a screen is adding that scene's filename to
## `BLOCKED_SCENES` below, which the minigames use to avoid obscuring
## gameplay). Runs even while the game is paused
## (`process_mode = PROCESS_MODE_ALWAYS`) so pause-menu taps still ripple.

const TOUCH_EFFECT_SCRIPT = preload("res://Scripts/TouchFeedback/TouchFeedbackEffect.gd")

# Scenes where touch feedback should be disabled to prevent obstruction
const BLOCKED_SCENES = [
	"mainbola.tscn",
	"lombamenari.tscn",
	"badminton.tscn"
]

# Anti-spam cooldown in milliseconds (80ms)
const SPAWN_COOLDOWN_MS: int = 80

# Prevent duplicate triggers from mouse emulation in the same frame
var last_press_position: Vector2 = Vector2.ZERO
var last_press_frame: int = -1
var last_spawn_time_ms: int = 0

func _ready() -> void:
	# Layer 125 is on top of normal UI and transitions
	layer = 125
	# Always process, even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	var is_press = false
	var pos = Vector2.ZERO
	
	# Only detect the initial press (pressed == true)
	# Drag/motion events do not satisfy this condition, preventing spam when holding/moving
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			is_press = true
			pos = event.position
	elif event is InputEventScreenTouch:
		if event.pressed:
			is_press = true
			pos = event.position
			
	if is_press:
		var current_frame = Engine.get_frames_drawn()
		# 1. Prevent double triggering due to touch-from-mouse emulation in the same frame
		if current_frame == last_press_frame and pos.distance_to(last_press_position) < 5.0:
			return
			
		last_press_frame = current_frame
		last_press_position = pos
		
		# 2. Check if enough time has passed since last spawn (anti-spam)
		var now = Time.get_ticks_msec()
		if now - last_spawn_time_ms < SPAWN_COOLDOWN_MS:
			return
			
		# 3. Check if the current scene is blacklisted
		var current_scene = get_tree().current_scene
		if current_scene and not current_scene.scene_file_path.is_empty():
			var path_lower = current_scene.scene_file_path.to_lower()
			for blocked in BLOCKED_SCENES:
				if blocked in path_lower:
					return # Disabled for this scene
					
		# Trigger the effect!
		last_spawn_time_ms = now
		_spawn_effect(pos)

func _spawn_effect(pos: Vector2) -> void:
	var effect = Node2D.new()
	effect.set_script(TOUCH_EFFECT_SCRIPT)
	effect.position = pos
	add_child(effect)
