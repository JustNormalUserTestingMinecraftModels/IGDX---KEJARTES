@tool
extends GPUParticles2D
class_name AnnouncementBurst

## One-shot celebratory burst spawned by EventAnnouncement when the
## popup fades in. Fires particle_burst.png outward in a ring, tinted
## gold, then frees itself once the emission window closes.

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	emitting = true
	var t := lifetime + 0.2
	await get_tree().create_timer(t).timeout
	queue_free()
