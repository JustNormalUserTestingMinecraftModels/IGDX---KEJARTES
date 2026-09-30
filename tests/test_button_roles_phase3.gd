@tool
extends McpTestSuite

## UI depth pass Phase 3's role fixes (plan decisions P2, P3). Back is
## brown, like Inventory's, ShopHub's and Settings'; mint is the one
## thing to press. Hapus only clears the unsent answer -- routine and
## reversible, beside Kirim -- so it is brown too: tomato would say
## "destructive", and DangerButton ticks the motor on every clear. Hapus
## takes the M step: the base step's 36 px label looked lost beside
## Kirim's 64 px one, and the L step (166 px) overflows AksiRow's 156 px.
## Since 2026-09-30 (minigame hierarchy) both take the minigame pair,
## MinigameSecondaryButton and MinigameCtaButton, at one T2 (45) size: same
## roles, brown and mint, on the minigame ladder.
##
## Must be @tool; no test here may be a coroutine.

## scene -> {node path: the variation it must wear}.
const ROLES := {
	"res://Scenes/ReportCard/ReportCard.tscn": {"Safe/UI/BackButton": &"SecondaryButton"},
	"res://Scenes/Minigames/Akademis/Password.tscn": {
		"Safe/Column/MinigameTray/AksiRow/BtnHapus": &"MinigameSecondaryButton", "Safe/Column/MinigameTray/AksiRow/BtnKirim": &"MinigameCtaButton"},
	"res://Scenes/Minigames/Akademis/Variabel.tscn": {
		"Safe/Column/MinigameTray/AksiRow/BtnHapus": &"MinigameSecondaryButton", "Safe/Column/MinigameTray/AksiRow/BtnKirim": &"MinigameCtaButton"},
}


func suite_name() -> String:
	return "button_roles_phase3"


## Every listed button wears the variation its role calls for.
func test_each_button_wears_its_role() -> void:
	for scene_path in ROLES:
		var scene := (load(scene_path) as PackedScene).instantiate()
		track(scene)
		for node_path in ROLES[scene_path]:
			var b := scene.get_node_or_null(node_path) as Control
			assert_true(b != null, "%s: missing %s" % [scene_path, node_path])
			if b != null:
				assert_eq(b.theme_type_variation, ROLES[scene_path][node_path],
					"%s: %s" % [scene_path, node_path])
