@tool
extends McpTestSuite

## The 2026-09-25 icon refresh (spec:
## docs/superpowers/specs/2026-09-25-minigame-win-screen-design.md, sections 1
## and 5): the four Lobby icons and the canonical back arrow were replaced in
## place with the owner's delivered art. Each file is pinned by the MD5 of the
## delivered original, so a lost copy or a stale file fails here rather than
## on a phone. A future art swap updates the hash on purpose.
##
## Must be @tool, and no test here may be a coroutine.

## res:// path -> MD5 of the file delivered in Downloads on 2026-09-25.
const DELIVERED := {
	"res://Assets/Images/Achievements/achievement_button.png": "8bdcd0b22d81846bb2544a136ca1fac9",
	"res://Assets/Images/UI/setting.png": "06020ee18ea4d3bb00ea5fa4ce61504d",
	"res://Assets/Images/UI/skin_switch.png": "0f777eb6e443a0e5bdee3bdfca9434ac",
	"res://Assets/Images/UI/icon_daily_login.png": "6a5ab7bf6da4257bbd5986ff43c03320",
	"res://Assets/Images/UI/Nav/return_button.png": "7891144f317b79d2d93bf52343e4bd5a",
}
## The Lobby, whose bottom bar wears four of the five.
const _LOBBY := "res://Scenes/Lobby/Lobby.tscn"


func suite_name() -> String:
	return "ui_icon_refresh"


func test_every_delivered_icon_is_in_place() -> void:
	for path in DELIVERED:
		assert_eq(FileAccess.get_md5(path), DELIVERED[path],
			"%s must be the art delivered on 2026-09-25" % path)


## The new calendar is 322x359; drawn with stretch_mode 0 it squashed into the
## button. All four rail buttons keep aspect with STRETCH_KEEP_ASPECT (not
## centred): each is 142 tall, so the square icon sits at the top 96x96 and the
## lower part is the word's tap area.
func test_the_daily_login_button_keeps_its_aspect() -> void:
	var lobby := (load(_LOBBY) as PackedScene).instantiate()
	track(lobby)
	for path in ["Safe/UI/Hud/IconRail/DailyLogin", "Safe/UI/Hud/IconRail/SettingsButton",
			"Safe/UI/Hud/IconRail/AchievementButton", "Safe/UI/Hud/IconRail/SkinSwitchButton"]:
		var btn := lobby.get_node_or_null(path) as TextureButton
		assert_true(btn != null, path + " must exist")
		if btn != null:
			assert_eq(btn.stretch_mode, TextureButton.STRETCH_KEEP_ASPECT,
				path + " must keep its icon's aspect at the top of its 142-tall button")
