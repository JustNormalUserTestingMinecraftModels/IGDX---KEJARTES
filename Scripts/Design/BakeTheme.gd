@tool
extends EditorScript

## Regenerates Assets/Theme/kejartes_theme.tres from design_tokens.tres.
##
## Run it from the Godot editor: open this file, then File > Run
## (Ctrl+Shift+X). Run it after ANY change to design_tokens.tres —
## the baked theme is what the game actually loads.

const OUTPUT_PATH := "res://Assets/Theme/kejartes_theme.tres"


func _run() -> void:
	var tokens := DesignTokens.load_default()
	if tokens == null:
		push_error("BakeTheme: could not load " + DesignTokens.DEFAULT_PATH)
		return

	var theme := ThemeFactory.build(tokens)
	var err := ResourceSaver.save(theme, OUTPUT_PATH)
	if err != OK:
		push_error("BakeTheme: save failed with error %d" % err)
		return

	print("BakeTheme: wrote ", OUTPUT_PATH, " (",
		theme.get_type_list().size(), " types)")
	EditorInterface.get_resource_filesystem().scan()
