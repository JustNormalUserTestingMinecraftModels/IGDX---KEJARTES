@tool
extends McpTestSuite

## Red and green mean something specific, or they mean nothing.
##
## Before 2026-09-10 every confirm was a green/red pair regardless of what
## was being confirmed, which spent the palette's loudest colours on
## ordinary "carry on?" prompts and left nothing louder for the genuinely
## destructive ones. The split is by meaning:
##
##   destructive (discards something)  -> DangerButton
##   ordinary confirm                  -> PrimaryButton + SecondaryButton
##   something earned, not confirmed   -> SuccessButton
##
## Two categories deliberately keep their colours, and the 2026-09-10
## audit found both by reading the button text rather than trusting the
## plan: status badges that encode state rather than action, and rewards.
##
## Source-text scans, following the established pattern: most of this UI
## cannot be instantiated headlessly.

## Ordinary confirms. None of these should carry DangerButton.
const NON_DESTRUCTIVE_SCENES := [
	"res://Scenes/AturJadwal/atur_jadwal.tscn",
	"res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn",
	"res://Scenes/Inventory/ApplyItemScreen.tscn",
	"res://Scenes/StudentCard/student_card.tscn",
]

## Quitting a minigame discards the run in progress.
const DESTRUCTIVE_SCENE := "res://Scenes/Minigames/UI/QuitConfirmDialog.tscn"


func suite_name() -> String:
	return "confirm_pair_semantics"


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var src := f.get_as_text()
	f.close()
	return src


func test_ordinary_confirms_do_not_use_danger() -> void:
	for path in NON_DESTRUCTIVE_SCENES:
		var src := _read(path)
		assert_ne(src, "", "could not open " + path)
		assert_false(src.contains("DangerButton"),
			"%s is an ordinary confirm and should not use DangerButton" % path)


func test_the_peringatan_dialog_pairs_primary_with_secondary() -> void:
	var src := _read("res://Scenes/AturJadwal/atur_jadwal.tscn")
	assert_ne(src, "", "could not open atur_jadwal.tscn")
	assert_contains(src, "PrimaryButton",
		"the PERINGATAN confirm needs one filled affirmative")
	assert_contains(src, "SecondaryButton",
		"the PERINGATAN confirm needs one quiet negative")


## The point of the split: red still exists where it is earned.
func test_the_destructive_confirm_keeps_danger() -> void:
	var src := _read(DESTRUCTIVE_SCENE)
	assert_ne(src, "", "could not open " + DESTRUCTIVE_SCENE)
	assert_contains(src, "DangerButton",
		"quitting a minigame discards the run; it should stay red")


func test_the_cutscene_skip_and_grade_choice_are_not_destructive() -> void:
	var src := _read("res://Scripts/CutScene/cut_scene.gd")
	assert_ne(src, "", "could not open cut_scene.gd")
	assert_false(src.contains("&\"DangerButton\""),
		"skipping a cutscene and picking a grade discard nothing")


## StudentList's green/red are not buttons the player presses to act --
## they are status badges reading BELUM/SUDAH TERJADWALKAN. The colour IS
## the information, so the confirm-pair rule must not touch them.
func test_the_schedule_status_badges_keep_their_colours() -> void:
	var src := _read("res://Scenes/StudentList/student_list.tscn")
	assert_ne(src, "", "could not open student_list.tscn")
	assert_contains(src, "DangerButton",
		"BELUM TERJADWALKAN encodes state, not a destructive action")
	assert_contains(src, "SuccessButton",
		"SUDAH TERJADWALKAN encodes state, not a reward")


## Claiming a reward is the one case where something is genuinely earned
## rather than confirmed. It used to say so with SuccessButton. Since the
## 2026-09-10 daily-login rebuild the panel art bakes the bright gold
## "claim me" pill itself, so the button is GhostButton and draws no chrome
## of its own -- a SuccessButton here would paint a green pill on top of the
## gold one. The rule the colour split protects is unchanged: the claim is
## never restyled as an ordinary confirm or as a destructive action.
func test_the_lobby_claim_is_never_a_confirm_or_a_danger() -> void:
	var src := _read("res://Scenes/Lobby/loby.tscn")
	assert_ne(src, "", "could not open loby.tscn")
	assert_contains(src, "GhostButton",
		"CLAIM sits on the panel art's own pill and must draw no chrome")
	assert_false(src.contains("DangerButton"),
		"CLAIM is a reward, not a destructive action")
	assert_false(src.contains("SecondaryButton"),
		"CLAIM is a reward, not an ordinary confirm")
