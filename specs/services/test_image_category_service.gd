extends GutTest

## Tests pour ImageCategoryService — gestion des catégories d'images

const ImageCategoryService = preload("res://src/services/image_category_service.gd")

var _service: RefCounted
var _test_dir: String = ""


func before_each():
	_service = ImageCategoryService.new()
	_test_dir = "user://test_img_cat_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets")


func after_each():
	_remove_dir_recursive(_test_dir)


# --- Catégories par défaut ---

func test_default_categories():
	var cats = _service.get_categories()
	assert_eq(cats.size(), 3)
	assert_has(cats, "Base")
	assert_has(cats, "NPC")
	assert_has(cats, "Character")


func test_get_categories_returns_copy():
	var cats = _service.get_categories()
	cats.append("Extra")
	assert_eq(_service.get_categories().size(), 3)


# --- Ajout de catégorie ---

func test_add_category():
	_service.add_category("Monster")
	var cats = _service.get_categories()
	assert_has(cats, "Monster")
	assert_eq(cats.size(), 4)


func test_add_category_ignores_duplicate():
	_service.add_category("Base")
	assert_eq(_service.get_categories().size(), 3)


func test_add_category_emits_signal():
	watch_signals(_service)
	_service.add_category("Monster")
	assert_signal_emitted(_service, "categories_changed")


func test_add_duplicate_does_not_emit_signal():
	watch_signals(_service)
	_service.add_category("Base")
	assert_signal_not_emitted(_service, "categories_changed")


# --- Renommage de catégorie ---

func test_rename_category():
	_service.rename_category("Base", "Décor")
	var cats = _service.get_categories()
	assert_has(cats, "Décor")
	assert_does_not_have(cats, "Base")


func test_rename_category_updates_assignments():
	_service.assign_image_to_category("backgrounds/forest.png", "Base")
	_service.rename_category("Base", "Décor")
	assert_true(_service.is_image_in_category("backgrounds/forest.png", "Décor"))
	assert_false(_service.is_image_in_category("backgrounds/forest.png", "Base"))


func test_rename_category_emits_signal():
	watch_signals(_service)
	_service.rename_category("Base", "Décor")
	assert_signal_emitted(_service, "categories_changed")


func test_rename_nonexistent_category_does_nothing():
	watch_signals(_service)
	_service.rename_category("Inexistant", "Nouveau")
	assert_signal_not_emitted(_service, "categories_changed")
	assert_eq(_service.get_categories().size(), 3)


func test_rename_to_existing_name_does_nothing():
	watch_signals(_service)
	_service.rename_category("Base", "NPC")
	assert_signal_not_emitted(_service, "categories_changed")
	assert_has(_service.get_categories(), "Base")
	assert_has(_service.get_categories(), "NPC")


# --- Suppression de catégorie ---

func test_remove_category():
	_service.remove_category("NPC")
	var cats = _service.get_categories()
	assert_does_not_have(cats, "NPC")
	assert_eq(cats.size(), 2)


func test_remove_category_clears_assignments():
	_service.assign_image_to_category("foregrounds/hero.png", "NPC")
	_service.remove_category("NPC")
	assert_false(_service.is_image_in_category("foregrounds/hero.png", "NPC"))


func test_remove_category_emits_signal():
	watch_signals(_service)
	_service.remove_category("NPC")
	assert_signal_emitted(_service, "categories_changed")


func test_remove_nonexistent_category_does_nothing():
	watch_signals(_service)
	_service.remove_category("Inexistant")
	assert_signal_not_emitted(_service, "categories_changed")


# --- Assignation ---

func test_assign_image_to_category():
	_service.assign_image_to_category("backgrounds/forest.png", "Base")
	assert_true(_service.is_image_in_category("backgrounds/forest.png", "Base"))


func test_assign_image_to_multiple_categories():
	_service.assign_image_to_category("foregrounds/hero.png", "Character")
	_service.assign_image_to_category("foregrounds/hero.png", "NPC")
	var cats = _service.get_image_categories("foregrounds/hero.png")
	assert_eq(cats.size(), 2)
	assert_has(cats, "Character")
	assert_has(cats, "NPC")


func test_assign_same_category_twice_no_duplicate():
	_service.assign_image_to_category("backgrounds/forest.png", "Base")
	_service.assign_image_to_category("backgrounds/forest.png", "Base")
	var cats = _service.get_image_categories("backgrounds/forest.png")
	assert_eq(cats.size(), 1)


func test_assign_to_nonexistent_category_does_nothing():
	_service.assign_image_to_category("backgrounds/forest.png", "Inexistant")
	assert_false(_service.is_image_in_category("backgrounds/forest.png", "Inexistant"))


# --- Désassignation ---

func test_unassign_image_from_category():
	_service.assign_image_to_category("backgrounds/forest.png", "Base")
	_service.unassign_image_from_category("backgrounds/forest.png", "Base")
	assert_false(_service.is_image_in_category("backgrounds/forest.png", "Base"))


func test_unassign_cleans_empty_assignments():
	_service.assign_image_to_category("backgrounds/forest.png", "Base")
	_service.unassign_image_from_category("backgrounds/forest.png", "Base")
	assert_eq(_service.get_image_categories("backgrounds/forest.png").size(), 0)


func test_unassign_nonexistent_image_does_nothing():
	_service.unassign_image_from_category("nonexistent.png", "Base")
	assert_eq(_service.get_image_categories("nonexistent.png").size(), 0)


# --- Requêtes ---

func test_is_image_in_category_false_for_unassigned():
	assert_false(_service.is_image_in_category("backgrounds/forest.png", "Base"))


func test_get_image_categories_empty_for_unassigned():
	assert_eq(_service.get_image_categories("backgrounds/forest.png").size(), 0)


func test_get_assigned_image_count():
	_service.assign_image_to_category("backgrounds/forest.png", "Base")
	_service.assign_image_to_category("backgrounds/city.png", "Base")
	_service.assign_image_to_category("foregrounds/hero.png", "Character")
	assert_eq(_service.get_assigned_image_count("Base"), 2)
	assert_eq(_service.get_assigned_image_count("Character"), 1)
	assert_eq(_service.get_assigned_image_count("NPC"), 0)


# --- Filtrage ---

func test_filter_paths_by_category():
	_service.assign_image_to_category("backgrounds/forest.png", "Base")
	_service.assign_image_to_category("backgrounds/city.png", "NPC")
	var paths = [
		"/home/test/story/assets/backgrounds/forest.png",
		"/home/test/story/assets/backgrounds/city.png",
		"/home/test/story/assets/backgrounds/sky.png"
	]
	var filtered = _service.filter_paths_by_category(paths, "Base")
	assert_eq(filtered.size(), 1)
	assert_string_contains(filtered[0], "forest.png")


func test_filter_paths_empty_when_no_match():
	var paths = ["/home/test/story/assets/backgrounds/forest.png"]
	var filtered = _service.filter_paths_by_category(paths, "Base")
	assert_eq(filtered.size(), 0)


# --- path_to_key ---

func test_path_to_key_backgrounds():
	var key = ImageCategoryService.path_to_key("/some/path/assets/backgrounds/forest.png")
	assert_eq(key, "backgrounds/forest.png")


func test_path_to_key_foregrounds():
	var key = ImageCategoryService.path_to_key("/some/path/assets/foregrounds/hero.png")
	assert_eq(key, "foregrounds/hero.png")


func test_path_to_key_unknown_path():
	var key = ImageCategoryService.path_to_key("/some/random/path/image.png")
	assert_eq(key, "image.png")


# --- Persistance ---

func test_save_and_load_roundtrip():
	_service.add_category("Monster")
	_service.assign_image_to_category("backgrounds/forest.png", "Base")
	_service.assign_image_to_category("foregrounds/hero.png", "Character")
	_service.assign_image_to_category("foregrounds/hero.png", "NPC")
	_service.save_to(_test_dir)

	var loaded = ImageCategoryService.new()
	loaded.load_from(_test_dir)

	assert_has(loaded.get_categories(), "Monster")
	assert_eq(loaded.get_categories().size(), 4)
	assert_true(loaded.is_image_in_category("backgrounds/forest.png", "Base"))
	assert_true(loaded.is_image_in_category("foregrounds/hero.png", "Character"))
	assert_true(loaded.is_image_in_category("foregrounds/hero.png", "NPC"))


func test_load_missing_file_uses_defaults():
	_service.load_from(_test_dir + "/nonexistent")
	var cats = _service.get_categories()
	assert_eq(cats.size(), 3)
	assert_has(cats, "Base")


func test_save_creates_file():
	_service.save_to(_test_dir)
	assert_true(FileAccess.file_exists(_test_dir + "/assets/categories.yaml"))


func test_load_clears_previous_data():
	_service.assign_image_to_category("backgrounds/old.png", "Base")
	_service.save_to(_test_dir)

	var service2 = ImageCategoryService.new()
	service2.assign_image_to_category("foregrounds/other.png", "NPC")
	service2.load_from(_test_dir)

	assert_true(service2.is_image_in_category("backgrounds/old.png", "Base"))
	assert_false(service2.is_image_in_category("foregrounds/other.png", "NPC"))


# --- Helpers ---

func _remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname == "." or fname == "..":
			fname = dir.get_next()
			continue
		var full = path + "/" + fname
		if dir.current_is_dir():
			_remove_dir_recursive(full)
		else:
			DirAccess.remove_absolute(full)
		fname = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
