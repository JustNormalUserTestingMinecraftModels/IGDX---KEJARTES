@tool
class_name SpecialtyMatchBurst
extends CPUParticles2D

## A one-shot gold star burst fired on the AturJadwal sticky note when the
## player schedules a student onto their specialty subject. Authored scene
## (Scenes/AturJadwal/SpecialtyMatchBurst.tscn), driven entirely by the
## @export knobs below -- no runtime visual construction. play() is a no-op
## in the editor; it never awaits, it schedules its own free with a timer.

## Jumlah partikel bintang saat murid dijadwalkan ke mapel favoritnya.
@export var burst_amount: int = 14
## Radius sebaran partikel dari titik tengah note, dalam piksel.
@export var spread_px: float = 46.0
## Umur tiap partikel, dalam detik.
@export var life_seconds: float = 0.7
## Warna partikel. Kosong (default) = emas dari DesignTokens.currency_gold.
@export var burst_color: Color = Color(0, 0, 0, 0)


func _ready() -> void:
	emitting = false
	one_shot = true
	if burst_color.a == 0.0:
		burst_color = DesignTokens.load_default().currency_gold


## Fire the burst once, then free self after the particles finish.
func play() -> void:
	if Engine.is_editor_hint():
		return
	amount = maxi(1, burst_amount)
	lifetime = life_seconds
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = spread_px
	color = burst_color
	restart()
	emitting = true
	get_tree().create_timer(life_seconds + 0.3).timeout.connect(queue_free)
