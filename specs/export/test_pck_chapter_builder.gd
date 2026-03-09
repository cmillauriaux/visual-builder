extends GutTest

var PckChapterBuilderScript

func before_each():
	PckChapterBuilderScript = load("res://src/export/pck_chapter_builder.gd")

func test_script_loads():
	assert_not_null(PckChapterBuilderScript)

func test_normalize_path():
	var builder = PckChapterBuilderScript.new()
	assert_eq(builder._normalize_path("res://story/assets/img.png"), "assets/img.png")
	assert_eq(builder._normalize_path("assets/img.png"), "assets/img.png")
	assert_eq(builder._normalize_path(""), "")
	builder.free()

func test_split_groups_into_chunks_single_small():
	var builder = PckChapterBuilderScript.new()
	var groups = [{"total_size": 1000}]
	var chunks = builder._split_groups_into_chunks(groups)
	assert_eq(chunks.size(), 1)
	assert_eq(chunks[0].size(), 1)
	builder.free()

func test_split_groups_into_chunks_multiple_small():
	var builder = PckChapterBuilderScript.new()
	var groups = [
		{"total_size": 10 * 1024 * 1024},
		{"total_size": 10 * 1024 * 1024}
	]
	# MAX_PCK_SIZE is 19MB, so two 10MB groups should be in two chunks
	var chunks = builder._split_groups_into_chunks(groups)
	assert_eq(chunks.size(), 2)
	builder.free()

func test_collect_menu_assets():
	var builder = PckChapterBuilderScript.new()
	var story = {
		"menu_background": "res://story/bg.png",
		"menu_music": "music.mp3",
		"app_icon": ""
	}
	var assets = builder._collect_menu_assets(story)
	assert_true(assets.has("bg.png"))
	assert_true(assets.has("music.mp3"))
	assert_eq(assets.size(), 2)
	builder.free()


func test_remove_orphan_assets_returns_zero_for_missing_dir():
	var builder = PckChapterBuilderScript.new()
	var removed = builder._remove_orphan_assets("/nonexistent/path/xyz", "/nonexistent", {})
	assert_eq(removed, 0)
	builder.free()


func test_remove_orphan_assets_deletes_orphan_files():
	var builder = PckChapterBuilderScript.new()

	# Créer une structure de dossier temporaire simulant story/assets/foregrounds/
	var abs_story = ProjectSettings.globalize_path("user://test_orphan_story")
	var abs_fg_dir = abs_story + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(abs_fg_dir)

	# Créer un faux fichier source (.png orphelin)
	var abs_source = abs_fg_dir + "/unused_char.png"
	var f = FileAccess.open(abs_source, FileAccess.WRITE)
	f.store_string("fake png")
	f.close()

	# Créer un faux .import sans path= vers un fichier importé (cas simplifié)
	var abs_import = abs_fg_dir + "/unused_char.png.import"
	f = FileAccess.open(abs_import, FileAccess.WRITE)
	f.store_string("[params]\n# no path= here\n")
	f.close()

	var removed = builder._remove_orphan_assets(abs_fg_dir, abs_story, {})

	assert_true(removed >= 2, "Doit supprimer au moins le .import et la source")
	assert_false(FileAccess.file_exists(abs_import), ".import doit être supprimé")
	assert_false(FileAccess.file_exists(abs_source), "Source PNG doit être supprimée")

	# Nettoyage
	DirAccess.remove_absolute(abs_fg_dir)
	DirAccess.remove_absolute(abs_story + "/assets")
	DirAccess.remove_absolute(abs_story)
	builder.free()


func test_remove_orphan_assets_skips_menu_assets():
	var builder = PckChapterBuilderScript.new()

	var abs_story = ProjectSettings.globalize_path("user://test_orphan_menu_story")
	var abs_bg_dir = abs_story + "/assets/backgrounds"
	DirAccess.make_dir_recursive_absolute(abs_bg_dir)

	# Créer un background qui EST un menu asset
	var abs_source = abs_bg_dir + "/menu_bg.png"
	var f = FileAccess.open(abs_source, FileAccess.WRITE)
	f.store_string("fake bg")
	f.close()

	var abs_import = abs_bg_dir + "/menu_bg.png.import"
	f = FileAccess.open(abs_import, FileAccess.WRITE)
	f.store_string("[params]\n")
	f.close()

	# menu_assets contient ce fichier
	var menu_assets = {"assets/backgrounds/menu_bg.png": true}
	var removed = builder._remove_orphan_assets(abs_bg_dir, abs_story, menu_assets)

	assert_eq(removed, 0, "Aucun fichier menu asset ne doit être supprimé")
	assert_true(FileAccess.file_exists(abs_import), ".import menu doit rester")
	assert_true(FileAccess.file_exists(abs_source), "Source menu doit rester")

	# Nettoyage
	DirAccess.remove_absolute(abs_import)
	DirAccess.remove_absolute(abs_source)
	DirAccess.remove_absolute(abs_bg_dir)
	DirAccess.remove_absolute(abs_story + "/assets")
	DirAccess.remove_absolute(abs_story)
	builder.free()
