@tool
extends McpTestSuite

## Reads pixels from textures the import may have compressed.
const TexturePixels := preload("res://tests/texture_pixels.gd")

## The UI icon set (2026-09-28 UI depth pass): one file per job at a fixed
## path, so the owner's chunky set drops in with no code change. A
## replacement must read on BOTH the cream panels and the brown boards, which
## this checks the way the placeholders achieve it: a light fill AND a dark
## outline, on a transparent ground, at least 256 px.
## Rules for replacements: Assets/Images/UI/Icons/README.md.
##
## Must be @tool; no test here may be a coroutine.

const DIR := "res://Assets/Images/UI/Icons/"
const NAMES := [
	"nav_jadwal", "nav_students", "nav_koperasi", "nav_inventory", "nav_rapor",
	"chevron_left", "chevron_right", "exit", "close", "home",
	"info", "music", "sound", "vibrate", "cat_istirahat", "cat_wirausaha",
]
## Minimum side, px.
const MIN_SIDE := 256
## Luminance an opaque pixel must exceed to count as the light fill.
const LIGHT := 0.85
## Luminance an opaque pixel must stay under to count as the dark outline.
const DARK := 0.25
## The owner's finished art (PNG): painted in its own palette, so it is held
## to size and transparency only, not the placeholders' outline rule.
const FINISHED := ["nav_jadwal", "nav_koperasi", "nav_inventory", "nav_rapor", "exit"]


func suite_name() -> String:
	return "ui_icons"


func _image(name: String) -> Image:
	var ext := ".png" if name in FINISHED else ".svg"
	var tex := load(DIR + name + ext) as Texture2D
	if tex == null:
		return null
	var img := TexturePixels.of(tex)
	if img.is_compressed():
		img.decompress()
	return img


func test_every_icon_exists_and_is_big_enough() -> void:
	for name in NAMES:
		var img := _image(name)
		assert_true(img != null, name + " exists and imports")
		if img == null:
			continue
		assert_true(img.get_width() >= MIN_SIDE and img.get_height() >= MIN_SIDE,
			"%s is at least %d px" % [name, MIN_SIDE])


func test_every_icon_has_a_transparent_ground() -> void:
	for name in NAMES:
		var img := _image(name)
		if img == null:
			continue
		assert_true(img.get_pixel(0, 0).a < 0.1, name + " has a transparent corner")


func test_every_icon_reads_on_cream_and_on_brown() -> void:
	for name in NAMES:
		if name in FINISHED:
			continue
		var img := _image(name)
		if img == null:
			continue
		var has_light := false
		var has_dark := false
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				var p := img.get_pixel(x, y)
				if p.a < 0.9:
					continue
				has_light = has_light or p.get_luminance() > LIGHT
				has_dark = has_dark or p.get_luminance() < DARK
		assert_true(has_light, name + " has a light fill (reads on brown)")
		assert_true(has_dark, name + " has a dark outline (reads on cream)")
