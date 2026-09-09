@tool
extends McpTestSuite

## 2026-09-08 fix: the stat/trait detail popups (StatDetailPopup,
## TraitDetailPopup) closed on the same tap that opened them, because the
## full-screen Scrim started at MOUSE_FILTER_STOP and its gui_input handler
## caught the very press that had just fired the icon cluster / trait
## badge. Both scripts now start the scrim at MOUSE_FILTER_IGNORE and flip
## to MOUSE_FILTER_STOP only after the open() reveal's scrim-fade tween
## finishes, so the opening tap can never also be the closing tap.
##
## Also pins the companion typography fix: DescriptionLabel moved off the
## bold display-font TitleLabel variation onto the body-weight
## EventBodyLabel, so the gameplay explanation reads as body text instead
## of a second heading.

func suite_name() -> String:
	return "popup_dismiss"

func _read(p: String) -> String:
	return FileAccess.get_file_as_string(p)


func test_stat_popup_scrim_starts_ignoring_input() -> void:
	var src := _read("res://Scripts/UI/StatDetailPopup.gd")
	assert_true(src.contains("scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE"),
		"Scrim must start ignoring input to prevent the opening tap from closing the popup")


func test_stat_popup_scrim_enables_after_open() -> void:
	var src := _read("res://Scripts/UI/StatDetailPopup.gd")
	assert_true(src.contains("scrim.mouse_filter = Control.MOUSE_FILTER_STOP"),
		"Scrim must re-enable input after the open animation so tap-to-dismiss works")


func test_trait_popup_scrim_starts_ignoring_input() -> void:
	var src := _read("res://Scripts/UI/TraitDetailPopup.gd")
	assert_true(src.contains("scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE"),
		"Scrim must start ignoring input")


func test_trait_popup_scrim_enables_after_open() -> void:
	var src := _read("res://Scripts/UI/TraitDetailPopup.gd")
	assert_true(src.contains("scrim.mouse_filter = Control.MOUSE_FILTER_STOP"),
		"Scrim must re-enable input after open")


func test_stat_popup_description_uses_body_font() -> void:
	var src := _read("res://Scenes/UI/StatDetailPopup.tscn")
	assert_false(src.contains('theme_type_variation = &"TitleLabel"'),
		"DescriptionLabel should no longer use the bold TitleLabel variation")
	assert_true(src.contains('theme_type_variation = &"EventBodyLabel"'),
		"DescriptionLabel should use the body-weight EventBodyLabel variation")


## Scoped to the DescriptionLabel NODE rather than scanning the whole
## .tscn for the string "TitleLabel", which is what this did until
## 2026-09-09. That scan passed only for as long as no other node in the
## file wanted a heading; when "EFEK GAMEPLAY:" was split out of the
## description into its own display-font label, the file-wide scan failed
## on a heading it was never meant to police. The invariant was always
## about the description alone.
func test_trait_popup_description_uses_body_font() -> void:
	var popup: Node = load("res://Scenes/UI/TraitDetailPopup.tscn").instantiate()
	track(popup)
	var description: Label = popup.get_node(
		"Scrim/Card/Layout/Body/BodyLayout/DescriptionLabel")
	assert_eq(description.theme_type_variation, &"EventBodyLabel",
		"the description must be body weight, not a heading variation")
