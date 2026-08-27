@tool
extends Node

# item_name -> ItemData
var items: Dictionary = {}

const DEFAULT_ITEMS: Array[Dictionary] = [
	{
		"name": "Bank Soal",
		"price": 500,
		"category": "Buku",
		"desc": "Kumpulan soal latihan untuk persiapan ujian sekolah.",
		"icon_path": "res://Assets/Images/Shop/ItemRak/bank soal.png",
		"display_size": Vector2(220, 280),
		"mood": 10,
		"energy": 5
	},
	{
		"name": "Komik",
		"price": 800,
		"category": "Buku",
		"desc": "Buku komik seru untuk hiburan di waktu luang.",
		"icon_path": "res://Assets/Images/Shop/ItemRak/komik.png",
		"display_size": Vector2(200, 260),
		"mood": 25,
		"energy": 5
	},
	{
		"name": "LKS",
		"price": 400,
		"category": "Buku",
		"desc": "Lembar Kerja Siswa untuk latihan di rumah.",
		"icon_path": "res://Assets/Images/Shop/ItemRak/LKS.png",
		"display_size": Vector2(220, 270),
		"mood": 5,
		"energy": 5
	},
	{
		"name": "Lompat Tali",
		"price": 1200,
		"category": "Olahraga",
		"desc": "Alat lompat tali untuk olahraga dan bermain.",
		"icon_path": "res://Assets/Images/Shop/ItemRak/lompat tali.png",
		"display_size": Vector2(240, 220),
		"mood": 20,
		"energy": 15
	},
	{
		"name": "Raket",
		"price": 1500,
		"category": "Olahraga",
		"desc": "Raket badminton untuk bermain bersama teman.",
		"icon_path": "res://Assets/Images/Shop/ItemRak/raket.png",
		"display_size": Vector2(180, 280),
		"mood": 30,
		"energy": 20
	},
	{
		"name": "Cilok",
		"price": 500,
		"category": "Makanan",
		"desc": "Jajanan cilok kenyal dan lezat dengan bumbu gurih.",
		"icon_path": "res://Assets/Images/Shop/ItemRak/cilok.png",
		"display_size": Vector2(180, 220),
		"mood": 15,
		"energy": 20
	},
	{
		"name": "Mie Instan",
		"price": 1000,
		"category": "Makanan",
		"desc": "Mie instan hangat dan lezat favorit anak sekolah.",
		"icon_path": "res://Assets/Images/Shop/ItemRak/mie.png",
		"display_size": Vector2(200, 200),
		"mood": 20,
		"energy": 35
	},
	{
		"name": "Pop Ice",
		"price": 800,
		"category": "Makanan",
		"desc": "Minuman es blender manis dan menyegarkan.",
		"icon_path": "res://Assets/Images/Shop/ItemRak/pop es.png",
		"display_size": Vector2(160, 240),
		"mood": 25,
		"energy": 15
	},
	{
		"name": "Susu Kotak",
		"price": 1200,
		"category": "Makanan",
		"desc": "Susu kotak bernutrisi untuk menambah energi belajar.",
		"icon_path": "res://Assets/Images/Shop/ItemRak/susus.png",
		"display_size": Vector2(160, 250),
		"mood": 10,
		"energy": 30
	},
]

func _ready():
	_init_database()

func _init_database():
	for info in DEFAULT_ITEMS:
		var tex = load(info["icon_path"])
		var size = info.get("display_size", Vector2.ZERO)
		var mood = info.get("mood", 0)
		var energy = info.get("energy", 0)
		register(info["name"], info["price"], tex, info["desc"], info["category"], size, mood, energy)

func register(
	item_name: String,
	price: int,
	icon: Texture2D,
	description: String = "",
	category: String = "",
	display_size: Vector2 = Vector2.ZERO,
	mood_boost: int = 0,
	energy_boost: int = 0
) -> ItemData:
	if items.has(item_name):
		var existing = items[item_name]
		if icon != null and existing.icon == null:
			existing.icon = icon
		if description != "" and existing.description == "":
			existing.description = description
		if category != "" and existing.category == "":
			existing.category = category
		if display_size != Vector2.ZERO and existing.display_size == Vector2.ZERO:
			existing.display_size = display_size
		if mood_boost != 0:
			existing.mood_boost = mood_boost
		if energy_boost != 0:
			existing.energy_boost = energy_boost
		return existing

	var data = ItemData.new()
	data.item_name = item_name
	data.price = price
	data.icon = icon
	data.description = description
	data.category = category
	data.display_size = display_size
	data.mood_boost = mood_boost
	data.energy_boost = energy_boost
	items[item_name] = data
	return data

func get_item(item_name: String) -> ItemData:
	return items.get(item_name, null)

func has_item(item_name: String) -> bool:
	return items.has(item_name)

func get_all_items() -> Array[ItemData]:
	var list: Array[ItemData] = []
	for key in items:
		list.append(items[key])
	return list

func get_random_items(count: int) -> Array[ItemData]:
	var all = get_all_items()
	all.shuffle()
	return all.slice(0, min(count, all.size()))
