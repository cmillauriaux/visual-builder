extends "res://addons/gut/hook_script.gd"

func run():
	var Coverage = load("res://addons/coverage/coverage.gd")
	if not Coverage:
		return
	var exclude_paths = [
		"res://addons/*", 
		"res://specs/*",
		"res://src/export/test_*.gd",
		"res://src/export/rewrite_runner.gd"
	]
	var coverage = Coverage.new(gut.get_tree(), exclude_paths)
	coverage.instrument_scripts("res://src/")
