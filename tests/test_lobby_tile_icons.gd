@tool
extends McpTestSuite

## UI depth pass Phase 3 (docs/superpowers/plans/2026-09-29-ui-depth-pass-phase3.md):
## the Lobby's five nav tiles wear the Icons/ set, so the owner's chunky
## icons drop in at those paths with no scene change. The four rail icons
## (settings, achievements, daily login, skins) are finished art and stay.
##
## Must be @tool; no test here may be a coroutine.

const LOBBY := "res://Scenes/Lobby/Lobby.tscn"
## Tile node path -> the icon it must wear.
const TILES := {
	"Safe/UI/Hud/BookHud/RaisedBlock/RaisedPage/Student": "res://Assets/Images/UI/Icons/nav_students.svg",
	"Safe/UI/Hud/BookHud/RaisedBlock/RaisedPage/Jadwal": "res://Assets/Images/UI/Icons/nav_jadwal.png",
	"Safe/UI/Hud/BookHud/Shelf/ShelfPage/Koperasi": "res://Assets/Images/UI/Icons/nav_koperasi.png",
	"Safe/UI/Hud/BookHud/Shelf/ShelfPage/Inventory": "res://Assets/Images/UI/Icons/nav_inventory.png",
	"Safe/UI/Hud/BookHud/Shelf/ShelfPage/ReportStudent": "res://Assets/Images/UI/Icons/nav_rapor.png",
}
## The retired Nav art no scene may point at any more.
const RETIRED := ["icon_cta_student.png", "icon_cta_jadwal.png", "icon_nav_koperasi.png",
	"icon_nav_inventory.png", "icon_nav_rapor.png"]


func suite_name() -> String:
	return "lobby_tile_icons"


func test_each_tile_wears_its_icons_set_picture() -> void:
	var lobby := (load(LOBBY) as PackedScene).instantiate()
	track(lobby)
	for path in TILES:
		var tile := lobby.get_node_or_null(path) as Button
		assert_true(tile != null, "missing tile " + path)
		if tile != null:
			assert_true(tile.icon != null, path + " has no icon")
			if tile.icon != null:
				assert_eq(tile.icon.resource_path, TILES[path], path)


func test_the_retired_nav_art_is_unreferenced() -> void:
	var src := FileAccess.get_file_as_string(LOBBY)
	for name in RETIRED:
		assert_false(src.contains(name), "Lobby.tscn still references " + name)
