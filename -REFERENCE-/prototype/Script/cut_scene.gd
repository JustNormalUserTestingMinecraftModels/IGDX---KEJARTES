extends Control

@onready var dialogue_label: RichTextLabel = $DialogueBox/DialogueLabel
@onready var bg_cutscene: TextureRect = $BgCutScene
@onready var fade_overlay: ColorRect = $FadeOverlay

var cg_data = [
	{
		"image": preload("res://Asset/BG.jpg"),
		"text": "Fiuh, setelah sekian lama aku mendaftar di sekolah ini. Akhirnya saya resmi diakui untuk mengajar disini!"
	},
	{
		"image": preload("res://Asset/cg1.jpg"),
		"text": "Formulir pengajuan yang diterima dan ditandatangani resmi dari guru yang akan menjadi karakter kita ini"
	},
	{
		"image": preload("res://Asset/cg2.jpg"),
		"text": "Karakter kita ini senang atau bangga besar."
	},
	{
		"image": preload("res://Asset/cg3.jpg"),
		"text": "Lokasi halaman depan Akademi, yang akan menjadi latar kita nanti untuk mengajar."
	},
	{
		"image": preload("res://Asset/cg4.jpg"),
		"text": "Pemandangan kelas dari pojok kanan atas, memperlihatkan seluruh isi kelas yang kosong dan yang akan diajar oleh sang guru."
	}
]

var cg_index := 0
var is_typing := false
var char_index := 0
var is_transitioning := false

func _ready():
	fade_overlay.color.a = 0.0
	show_current()

func show_current():
	bg_cutscene.texture = cg_data[cg_index]["image"]
	type_text(cg_data[cg_index]["text"])

func type_text(full_text: String):
	is_typing = true
	char_index = 0
	dialogue_label.text = ""
	while is_typing and char_index < full_text.length():
		dialogue_label.text += full_text[char_index]
		char_index += 1
		await get_tree().create_timer(0.03).timeout
	is_typing = false

func _input(event):
	if is_transitioning:
		return

	var tapped = false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true

	if not tapped:
		return

	if is_typing:
		dialogue_label.text = cg_data[cg_index]["text"]
		is_typing = false
		return

	advance()

func advance():
	cg_index += 1
	if cg_index >= cg_data.size():
		go_to_gameplay()
	else:
		transition_to_next()

func transition_to_next():
	is_transitioning = true
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.4)
	await tween.finished

	show_current()

	var tween_in = create_tween()
	tween_in.tween_property(fade_overlay, "color:a", 0.0, 0.4)
	await tween_in.finished

	is_transitioning = false

func go_to_gameplay():
	is_transitioning = true
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.8)
	await tween.finished
	GameState.next_scene = "res://Scene/loby.tscn"
	get_tree().change_scene_to_file("res://Scene/loading.tscn")
