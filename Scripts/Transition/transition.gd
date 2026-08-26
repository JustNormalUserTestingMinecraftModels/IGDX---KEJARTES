extends CanvasLayer

@onready var color_rect = $ColorRect
@onready var anim_player = $AnimationPlayer

func _ready():
	layer = 100  # pastikan selalu di atas semua node lain
	color_rect.color = Color.BLACK
	color_rect.modulate.a = 0  # transparan di awal

func change_scene(path: String):
	anim_player.play("fade_out")
	await anim_player.animation_finished
	get_tree().change_scene_to_file(path)
	anim_player.play("fade_in")
