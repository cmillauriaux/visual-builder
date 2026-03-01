extends GutTest

## Tests pour CategoryManagerDialog — dialog de gestion des catégories

const CategoryManagerDialogScript = preload("res://src/ui/dialogs/category_manager_dialog.gd")
const ImageCategoryService = preload("res://src/services/image_category_service.gd")

var _dialog: Window
var _service: RefCounted


func before_each():
	_service = ImageCategoryService.new()
	_dialog = Window.new()
	_dialog.set_script(CategoryManagerDialogScript)
	add_child_autofree(_dialog)
	_dialog.setup(_service)


# --- Structure UI ---

func test_is_window():
	assert_is(_dialog, Window)


func test_has_title():
	assert_eq(_dialog.title, "Gérer les catégories")


func test_is_exclusive():
	assert_true(_dialog.exclusive)


func test_has_item_list():
	assert_not_null(_dialog._item_list)
	assert_is(_dialog._item_list, ItemList)


func test_has_add_input():
	assert_not_null(_dialog._add_input)
	assert_is(_dialog._add_input, LineEdit)


func test_has_add_button():
	assert_not_null(_dialog._add_button)
	assert_eq(_dialog._add_button.text, "Ajouter")


func test_has_rename_button():
	assert_not_null(_dialog._rename_button)
	assert_eq(_dialog._rename_button.text, "Renommer")


func test_has_remove_button():
	assert_not_null(_dialog._remove_button)
	assert_eq(_dialog._remove_button.text, "Supprimer")


func test_has_close_button():
	assert_not_null(_dialog._close_button)
	assert_eq(_dialog._close_button.text, "Fermer")


# --- État initial ---

func test_item_list_shows_default_categories():
	assert_eq(_dialog._item_list.item_count, 3)


func test_item_list_contains_base():
	var found = false
	for i in range(_dialog._item_list.item_count):
		if _dialog._item_list.get_item_text(i) == "Base":
			found = true
	assert_true(found)


func test_rename_button_initially_disabled():
	assert_true(_dialog._rename_button.disabled)


func test_remove_button_initially_disabled():
	assert_true(_dialog._remove_button.disabled)


# --- Sélection ---

func test_selecting_item_enables_rename():
	_dialog._item_list.select(0)
	_dialog._on_item_selected(0)
	assert_false(_dialog._rename_button.disabled)


func test_selecting_item_enables_remove():
	_dialog._item_list.select(0)
	_dialog._on_item_selected(0)
	assert_false(_dialog._remove_button.disabled)


# --- Ajout ---

func test_add_category_via_button():
	_dialog._add_input.text = "Monster"
	_dialog._on_add_pressed()
	assert_eq(_dialog._item_list.item_count, 4)
	assert_has(_service.get_categories(), "Monster")


func test_add_empty_name_does_nothing():
	_dialog._add_input.text = "  "
	_dialog._on_add_pressed()
	assert_eq(_dialog._item_list.item_count, 3)


func test_add_clears_input():
	_dialog._add_input.text = "Monster"
	_dialog._on_add_pressed()
	assert_eq(_dialog._add_input.text, "")


func test_add_emits_categories_changed():
	watch_signals(_dialog)
	_dialog._add_input.text = "Monster"
	_dialog._on_add_pressed()
	assert_signal_emitted(_dialog, "categories_changed")


# --- Suppression ---

func test_remove_category():
	_dialog._item_list.select(0)
	_dialog._on_item_selected(0)
	var cat_name = _dialog._item_list.get_item_text(0)
	_dialog._on_remove_pressed()
	assert_does_not_have(_service.get_categories(), cat_name)


func test_remove_emits_categories_changed():
	watch_signals(_dialog)
	_dialog._item_list.select(0)
	_dialog._on_item_selected(0)
	_dialog._on_remove_pressed()
	assert_signal_emitted(_dialog, "categories_changed")


func test_remove_with_assigned_images_shows_confirmation():
	_service.assign_image_to_category("backgrounds/test.png", "Base")
	_dialog._item_list.select(0)
	_dialog._on_item_selected(0)
	# Find "Base" index
	var base_idx = -1
	for i in range(_dialog._item_list.item_count):
		if _dialog._item_list.get_item_text(i) == "Base":
			base_idx = i
	if base_idx >= 0:
		_dialog._item_list.select(base_idx)
		_dialog._on_item_selected(base_idx)
	var child_count_before = _dialog.get_child_count()
	_dialog._on_remove_pressed()
	# A confirmation dialog should have been added
	assert_gt(_dialog.get_child_count(), child_count_before)


# --- Signal ---

func test_has_categories_changed_signal():
	assert_true(_dialog.has_signal("categories_changed"))


# --- Refresh ---

func test_refresh_after_external_add():
	_service.add_category("Extra")
	_dialog._refresh_list()
	assert_eq(_dialog._item_list.item_count, 4)
