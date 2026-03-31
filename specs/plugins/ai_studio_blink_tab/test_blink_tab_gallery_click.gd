extends GutTest

## Test e2e : ouvre le Studio IA avec une vraie story, navigue vers Blink, clique Galerie.
## Reproduit le crash signalé par l'utilisateur.

var _dialog: Window = null
var _story_base_path: String = ""


func before_each() -> void:
	# Utiliser la vraie story du projet
	_story_base_path = ProjectSettings.globalize_path("res://stories/epreuve-du-heros")
	if not DirAccess.dir_exists_absolute(_story_base_path):
		# Fallback : créer un dossier temporaire avec quelques images
		_story_base_path = ProjectSettings.globalize_path("user://test_blink_e2e")
		DirAccess.make_dir_recursive_absolute(_story_base_path + "/assets/foregrounds")
		# Créer une image test
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color.RED)
		img.save_png(_story_base_path + "/assets/foregrounds/test_image.png")

	# Charger la story si possible
	var StorySaver = load("res://src/persistence/story_saver.gd")
	var story = StorySaver.load_story("res://stories/epreuve-du-heros")

	var AIStudioDialog = load("res://plugins/ai_studio/ai_studio_dialog.gd")
	_dialog = Window.new()
	_dialog.set_script(AIStudioDialog)
	add_child(_dialog)
	_dialog.setup(story, _story_base_path)


func after_each() -> void:
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	await get_tree().process_frame


func test_click_gallery_button_in_blink_tab() -> void:
	# Trouver le TabContainer
	var tab_container: TabContainer = _find_child_of_type(_dialog, "TabContainer")
	assert_not_null(tab_container, "TabContainer doit exister")
	if tab_container == null:
		return

	# Trouver l'index de l'onglet Blink
	var blink_idx = -1
	for i in range(tab_container.get_tab_count()):
		if tab_container.get_tab_title(i) == "Blink":
			blink_idx = i
			break
	assert_ne(blink_idx, -1, "Onglet Blink doit exister")
	if blink_idx == -1:
		return

	# Basculer sur l'onglet Blink
	tab_container.current_tab = blink_idx
	await get_tree().process_frame

	# Trouver le bouton Galerie dans l'onglet Blink
	var blink_scroll = tab_container.get_child(blink_idx)
	var gallery_btn: Button = _find_button_by_text(blink_scroll, "Galerie...")
	assert_not_null(gallery_btn, "Bouton 'Galerie...' doit exister")
	if gallery_btn == null:
		return

	assert_false(gallery_btn.disabled, "Galerie ne doit pas être désactivé (story chargée)")

	# Cliquer sur Galerie — c'est ici que le crash se produit
	gallery_btn.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Si on arrive ici sans crash, vérifier qu'une fenêtre gallery s'est ouverte
	var gallery_window: Window = null
	for child in _dialog.get_children():
		if child is Window and child.title == "Choisir les images sources":
			gallery_window = child
			break

	assert_not_null(gallery_window, "La fenêtre galerie multi-sélection doit s'être ouverte")

	# Nettoyer
	if gallery_window and is_instance_valid(gallery_window):
		gallery_window.queue_free()

	pass_test("Clic sur Galerie dans l'onglet Blink fonctionne sans crash")


func _find_child_of_type(root: Node, type_name: String) -> Node:
	for child in root.get_children():
		if child.get_class() == type_name:
			return child
		var found = _find_child_of_type(child, type_name)
		if found:
			return found
	return null


func _find_button_by_text(root: Node, text: String) -> Button:
	if root is Button and root.text == text:
		return root
	for child in root.get_children():
		var found = _find_button_by_text(child, text)
		if found:
			return found
	return null
