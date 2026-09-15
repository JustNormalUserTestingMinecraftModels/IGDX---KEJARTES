@tool
extends McpTestSuite

## LombaMenari's timing (2026-09-15): a wider hit window, three grades --
## UPS!, BAGUS!, SEMPURNA! -- and the dancer drawn behind the hit zone, so
## the target is never hidden under her. grade_for_distance() is pure and
## tested directly; the rest is source and scene shape, since the minigame
## cannot be played inside the editor.
##
## Must be @tool; no test here may be a coroutine.

const SCRIPT_PATH := "res://Scripts/Minigames/SeniBudaya/LombaMenari.gd"
const SCENE_PATH := "res://Scenes/Minigames/SeniBudaya/LombaMenari.tscn"


func suite_name() -> String:
	return "lomba_menari_timing"


## Siblings draw in tree order: an earlier sibling is behind a later one.
func test_the_dancer_draws_behind_the_hit_zone() -> void:
	var scene := load(SCENE_PATH).instantiate() as Node
	track(scene)
	var backdrop: int = scene.get_node("Background").get_index()
	var dancer: int = scene.get_node("CharacterDisplay").get_index()
	var zone: int = scene.get_node("HitZone").get_index()
	var notes: int = scene.get_node("NotesParent").get_index()
	assert_true(dancer < zone, "CharacterDisplay is before HitZone, so the zone draws over her")
	assert_true(backdrop < dancer, "she still stands in front of the backdrop")
	assert_true(zone < notes, "and the notes still fly over the zone")
