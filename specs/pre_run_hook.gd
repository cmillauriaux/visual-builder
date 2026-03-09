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
	
	# Instrumenter explicitement les scripts critiques en premier
	var critical_dirs = [
		"res://src/commands/",
		"res://src/services/",
		"res://src/models/",
		"res://src/persistence/",
		"res://src/controllers/",
		"res://src/views/",
		"res://src/ui/"
	]
	
	for dir in critical_dirs:
		coverage.instrument_scripts(dir)
	
	# Forcer l'instrumentation des autoloads
	coverage.instrument_autoloads()
