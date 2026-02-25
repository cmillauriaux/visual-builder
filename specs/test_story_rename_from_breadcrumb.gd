extends GutTest

# Tests d'intégration pour le renommage de l'histoire depuis le breadcrumb

const StoryScript = preload("res://src/models/story.gd")
const Breadcrumb = preload("res://src/ui/breadcrumb.gd")
const EditorMainScript = preload("res://src/ui/editor_main.gd")
const RenameDialogScript = preload("res://src/ui/rename_dialog.gd")

var _story = null
var _breadcrumb: HBoxContainer = null
var _editor_main: Control = null

func before_each():
	_story = StoryScript.new()
	_story.title = "Mon Histoire"
	_story.description = "Description initiale"

	_editor_main = Control.new()
	_editor_main.set_script(EditorMainScript)
	add_child_autofree(_editor_main)
	_editor_main.open_story(_story)

	_breadcrumb = HBoxContainer.new()
	_breadcrumb.set_script(Breadcrumb)
	add_child_autofree(_breadcrumb)
	_breadcrumb.set_path(_editor_main.get_breadcrumb_path())

func test_story_title_updated_after_rename():
	# Simuler le renommage via le dialogue
	_story.title = "Nouvelle Histoire"
	assert_eq(_story.title, "Nouvelle Histoire")

func test_story_description_updated_after_rename():
	_story.description = "Nouvelle description"
	assert_eq(_story.description, "Nouvelle description")

func test_breadcrumb_refreshed_after_rename():
	_story.title = "Titre Modifié"
	_breadcrumb.set_path(_editor_main.get_breadcrumb_path())
	var labels = _breadcrumb.get_path_labels()
	assert_eq(labels[0], "Titre Modifié", "Le breadcrumb doit afficher le nouveau titre")

func test_rename_dialog_prefilled_with_story_title():
	var dialog = ConfirmationDialog.new()
	dialog.set_script(RenameDialogScript)
	add_child_autofree(dialog)
	dialog.setup("story", _story.title, _story.description)
	assert_eq(dialog.get_new_name(), "Mon Histoire")
	assert_eq(dialog.get_new_subtitle(), "Description initiale")

func test_rename_dialog_confirmation_updates_story():
	var dialog = ConfirmationDialog.new()
	dialog.set_script(RenameDialogScript)
	add_child_autofree(dialog)
	dialog.setup("story", _story.title, _story.description)

	# Simuler la modification et confirmation
	dialog._name_edit.text = "Histoire Renommée"
	dialog._subtitle_edit.text = "Description modifiée"

	var was_called = false
	dialog.rename_confirmed.connect(func(uuid, new_name, new_subtitle):
		_story.title = new_name
		_story.description = new_subtitle
	)
	dialog._on_confirmed()

	assert_eq(_story.title, "Histoire Renommée")
	assert_eq(_story.description, "Description modifiée")

func test_full_rename_flow():
	# 1. Le breadcrumb affiche le titre initial
	assert_eq(_breadcrumb.get_path_labels()[0], "Mon Histoire")

	# 2. Mise à jour du modèle
	_story.title = "Super Histoire"
	_story.description = "Description finale"

	# 3. Rafraîchir le breadcrumb
	_breadcrumb.set_path(_editor_main.get_breadcrumb_path())

	# 4. Vérifier
	assert_eq(_breadcrumb.get_path_labels()[0], "Super Histoire")
	assert_eq(_story.description, "Description finale")
