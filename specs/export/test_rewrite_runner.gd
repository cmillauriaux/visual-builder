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


# --- Tests unitaires de _rewrite_path ---

func test_rewrite_path_empty_returns_empty() -> void:
	var result = StoryPathRewriter._rewrite_path("", "res://story", "backgrounds")
	assert_eq(result, "")


func test_rewrite_path_res_prefix_unchanged() -> void:
	var result = StoryPathRewriter._rewrite_path("res://story/assets/music/theme.ogg", "res://story", "music")
	assert_eq(result, "res://story/assets/music/theme.ogg")


func test_rewrite_path_user_prefix_rewritten() -> void:
	var result = StoryPathRewriter._rewrite_path("user://stories/test/assets/music/theme.ogg", "res://story", "music")
	assert_eq(result, "res://story/assets/music/theme.ogg")


func test_rewrite_path_absolute_windows_rewritten() -> void:
	var result = StoryPathRewriter._rewrite_path("C:/Projets/Game/assets/music/Inn_theme.mp3", "res://story", "music")
	assert_eq(result, "res://story/assets/music/Inn_theme.mp3")


func test_rewrite_path_absolute_unix_rewritten() -> void:
	var result = StoryPathRewriter._rewrite_path("/home/user/projects/game/assets/fx/click.ogg", "res://story", "fx")
	assert_eq(result, "res://story/assets/fx/click.ogg")


func test_rewrite_path_relative_unchanged() -> void:
	var result = StoryPathRewriter._rewrite_path("backgrounds/menu.png", "res://story", "backgrounds")
	assert_eq(result, "backgrounds/menu.png")


func test_rewrite_path_icons_subfolder() -> void:
	var result = StoryPathRewriter._rewrite_path("C:/Projets/Game/icon.png", "res://story", "icons")
	assert_eq(result, "res://story/assets/icons/icon.png")


# --- Tests de _rewrite_sequence_paths ---

func test_rewrite_sequence_paths_rewrites_music() -> void:
	var seq = _make_sequence()
	seq.music = "user://stories/test/assets/music/battle.ogg"
	StoryPathRewriter._rewrite_sequence_paths(seq, "res://story")
	assert_eq(seq.music, "res://story/assets/music/battle.ogg")


func test_rewrite_sequence_paths_rewrites_audio_fx() -> void:
	var seq = _make_sequence()
	seq.audio_fx = "C:/Game/assets/fx/explosion.mp3"
	StoryPathRewriter._rewrite_sequence_paths(seq, "res://story")
	assert_eq(seq.audio_fx, "res://story/assets/fx/explosion.mp3")


func test_rewrite_sequence_paths_rewrites_background() -> void:
	var seq = _make_sequence()
	seq.background = "user://stories/test/assets/backgrounds/forest.png"
	StoryPathRewriter._rewrite_sequence_paths(seq, "res://story")
	assert_eq(seq.background, "res://story/assets/backgrounds/forest.png")


func test_rewrite_sequence_paths_empty_audio_stays_empty() -> void:
	var seq = _make_sequence()
	StoryPathRewriter._rewrite_sequence_paths(seq, "res://story")
	assert_eq(seq.music, "")
	assert_eq(seq.audio_fx, "")


# --- Helpers ---

func _make_sequence():
	var seq = SequenceModel.new()
	return seq
