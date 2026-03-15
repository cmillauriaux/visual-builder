extends "res://addons/gut/hook_script.gd"

func run():
	var Coverage = load("res://addons/coverage/coverage.gd")
	const COVERAGE_TARGET = 65.0
	const FILE_TARGET = 0.0
	
	var coverage = Coverage.instance
	if coverage:
		coverage.set_coverage_targets(COVERAGE_TARGET, FILE_TARGET)
		# Verbosity: NONE=0, FILENAMES=1, FAILING_FILES=3, PARTIAL_FILES=4, ALL_FILES=5
		Coverage.finalize(3) 
		if !coverage.coverage_passing():
			gut.get_logger().failed("Couverture insuffisante (cible: " + str(COVERAGE_TARGET) + "%)")
