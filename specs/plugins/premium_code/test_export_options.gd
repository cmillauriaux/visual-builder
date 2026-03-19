extends GutTest

const ExportDialogScript = preload("res://src/ui/dialogs/export_dialog.gd")
const GameContributions = preload("res://src/plugins/game_contributions.gd")
const VBGamePluginScript = preload("res://src/plugins/game_plugin.gd")


# --- ExportOptionDef ---

func test_export_option_def_defaults():
	var def = GameContributions.ExportOptionDef.new()
	assert_eq(def.label, "")
	assert_eq(def.key, "")
	assert_true(def.default_value)


func test_export_option_def_custom_values():
	var def = GameContributions.ExportOptionDef.new()
	def.label = "Version limitée"
	def.key = "premium_code_enabled"
	def.default_value = false
	assert_eq(def.label, "Version limitée")
	assert_eq(def.key, "premium_code_enabled")
	assert_false(def.default_value)


# --- VBGamePlugin base class ---

func test_base_get_export_options_returns_empty():
	var plugin = VBGamePluginScript.new()
	assert_eq(plugin.get_export_options(), [])


func test_base_get_plugin_folder_returns_empty():
	var plugin = VBGamePluginScript.new()
	assert_eq(plugin.get_plugin_folder(), "")
