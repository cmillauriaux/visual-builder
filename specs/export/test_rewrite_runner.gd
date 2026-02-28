extends GutTest

## Tests pour RewriteRunner — vérification du script et du StoryPathRewriter.

const StoryPathRewriter = preload("res://src/export/story_path_rewriter.gd")


func test_story_path_rewriter_exists() -> void:
	assert_not_null(StoryPathRewriter, "StoryPathRewriter should be loadable")


func test_rewrite_runner_script_loads() -> void:
	var script = load("res://src/export/rewrite_runner.gd")
	assert_not_null(script, "rewrite_runner.gd should be loadable")


func test_rewriter_has_rewrite_method() -> void:
	var instance = StoryPathRewriter.new()
	assert_true(instance.has_method("rewrite_story_paths"), "should have rewrite_story_paths method")


func test_rewriter_on_nonexistent_folder_returns_false() -> void:
	var result = StoryPathRewriter.rewrite_story_paths("res://nonexistent_folder_12345", "res://story")
	assert_false(result, "should return false for nonexistent folder")
