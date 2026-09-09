@tool
extends McpTestSuite

## Regenerates Assets/Theme/kejartes_theme.tres, headlessly.
##
## Scripts/Design/BakeTheme.gd is an EditorScript, and there is no MCP
## entry point for one -- it needs File > Run by hand. This suite does the
## same build-and-save through test_run instead, which is the only way an
## agent-driven session can rebake at all.
##
## It is a build utility wearing a test's clothes. It asserts only that
## the save succeeded, because that is the only thing about it that can
## fail. Run it after ANY change to DesignTokens.gd or ThemeFactory.gd.

const OUTPUT_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "theme_rebake"


func test_rebake_writes_the_theme() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")

	var theme := ThemeFactory.build(tokens)
	assert_not_null(theme, "ThemeFactory.build returned null")

	var err := ResourceSaver.save(theme, OUTPUT_PATH)
	assert_eq(err, OK, "ResourceSaver.save failed with error %d" % err)

	print("theme_rebake: wrote ", OUTPUT_PATH, " (",
		theme.get_type_list().size(), " types)")
