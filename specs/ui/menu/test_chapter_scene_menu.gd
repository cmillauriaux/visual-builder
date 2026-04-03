extends GutTest

## Tests pour ChapterSceneMenu — menu de sélection chapitres/scènes.

var ChapterSceneMenuScript = load("res://src/ui/menu/chapter_scene_menu.gd")
var ChapterScript = load("res://src/models/chapter.gd")
var SceneScript = load("res://src/models/scene_data.gd")
var StoryScript = load("res://src/models/story.gd")

var _menu: Control


func before_each() -> void:
	_menu = Control.new()
	_menu.set_script(ChapterSceneMenuScript)
	_menu.build_ui()
	add_child_autofree(_menu)


# --- État initial ---

func test_starts_hidden() -> void:
	assert_false(_menu.visible, "Le menu doit démarrer caché")


func test_process_mode_always() -> void:
	assert_eq(_menu.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_has_title_label() -> void:
	assert_not_null(_menu._title_label)
	assert_eq(_menu._title_label.text, "Chapitres / Scènes")


func test_has_chapters_container() -> void:
	assert_not_null(_menu._chapters_container)
	assert_eq(_menu._chapters_container.name, "ChaptersContainer")


# --- show_menu / hide_menu ---

func test_show_menu_makes_visible() -> void:
	var story = _make_simple_story()
	_menu.show_menu(story, 0, 0)
	assert_true(_menu.visible)


func test_hide_menu_hides() -> void:
	var story = _make_simple_story()
	_menu.show_menu(story, 0, 0)
	_menu.hide_menu()
	assert_false(_menu.visible)


# --- Rendu des chapitres ---

func test_one_chapter_header_per_chapter() -> void:
	var story = _make_story_with(2, 1)
	_menu.show_menu(story, 1, 0)
	await get_tree().process_frame
	var chapter_sections = _menu._chapters_container.get_children()
	assert_eq(chapter_sections.size(), 2, "Doit y avoir 2 sections de chapitre")


func test_chapter_header_contains_name() -> void:
	var story = _make_simple_story()
	story.chapters[0].chapter_name = "Mon Chapitre"
	_menu.show_menu(story, 0, 0)
	await get_tree().process_frame
	var section = _menu._chapters_container.get_child(0)
	var header = section.get_node_or_null("ChapterHeader")
	assert_not_null(header, "Doit avoir un en-tête de chapitre")
	assert_true(header.text.contains("Mon Chapitre"))


func test_chapter_header_contains_number() -> void:
	var story = _make_story_with(2, 1)
	story.chapters[1].chapter_name = "Deuxième Chapitre"
	_menu.show_menu(story, 1, 0)
	await get_tree().process_frame
	var section = _menu._chapters_container.get_child(1)
	var header = section.get_node_or_null("ChapterHeader")
	assert_not_null(header)
	assert_true(header.text.contains("2"), "L'en-tête doit contenir le numéro 2")


# --- Scènes débloquées ---

func test_unlocked_scene_is_button() -> void:
	var story = _make_story_with(1, 2)
	story.chapters[0].scenes[0].scene_name = "Scène Débloquée"
	_menu.show_menu(story, 0, 0)
	await get_tree().process_frame
	var btn = _find_scene_button(0, 0)
	assert_not_null(btn, "La scène débloquée doit être un bouton")
	assert_true(btn is Button)
	assert_eq(btn.text, "Scène Débloquée")


func test_unlocked_scene_button_name() -> void:
	var story = _make_story_with(1, 1)
	_menu.show_menu(story, 0, 0)
	await get_tree().process_frame
	var btn = _find_scene_button(0, 0)
	assert_not_null(btn)
	assert_eq(btn.name, "SceneButton_0")


func test_all_scenes_before_max_chapter_unlocked() -> void:
	var story = _make_story_with(2, 2)
	# max = chapitre 1, scène 0 : toutes les scènes du chapitre 0 sont débloquées
	_menu.show_menu(story, 1, 0)
	await get_tree().process_frame
	var btn0 = _find_scene_button(0, 0)
	var btn1 = _find_scene_button(0, 1)
	assert_not_null(btn0, "Scène 0 du chapitre 0 doit être débloquée")
	assert_not_null(btn1, "Scène 1 du chapitre 0 doit être débloquée")
	assert_true(btn0 is Button)
	assert_true(btn1 is Button)


func test_scenes_up_to_max_scene_in_max_chapter_unlocked() -> void:
	var story = _make_story_with(1, 3)
	# max = chapitre 0, scène 1 : scènes 0 et 1 débloquées, scène 2 verrouillée
	_menu.show_menu(story, 0, 1)
	await get_tree().process_frame
	assert_not_null(_find_scene_button(0, 0), "Scène 0 doit être débloquée")
	assert_not_null(_find_scene_button(0, 1), "Scène 1 doit être débloquée")
	var locked = _find_locked_scene(0, 2)
	assert_not_null(locked, "Scène 2 doit être verrouillée")


# --- Scènes verrouillées ---

func test_locked_scene_is_panel_not_button() -> void:
	var story = _make_story_with(1, 2)
	_menu.show_menu(story, 0, 0)
	await get_tree().process_frame
	var locked = _find_locked_scene(0, 1)
	assert_not_null(locked, "La scène verrouillée doit exister")
	assert_true(locked is PanelContainer, "La scène verrouillée doit être un PanelContainer")


func test_locked_scene_shows_chapter_number() -> void:
	var story = _make_story_with(1, 2)
	_menu.show_menu(story, 0, 0)
	await get_tree().process_frame
	var locked = _find_locked_scene(0, 1)
	assert_not_null(locked)
	var chap_lbl = locked.find_child("LockedChapterLabel", true, false)
	assert_not_null(chap_lbl, "Doit avoir un label 'Chapitre N'")
	assert_eq(chap_lbl.text, "Chapitre 1")


func test_locked_scene_shows_question_marks() -> void:
	var story = _make_story_with(1, 2)
	_menu.show_menu(story, 0, 0)
	await get_tree().process_frame
	var locked = _find_locked_scene(0, 1)
	assert_not_null(locked)
	var scene_lbl = locked.find_child("LockedSceneLabel", true, false)
	assert_not_null(scene_lbl, "Doit avoir un label '??????'")
	assert_eq(scene_lbl.text, "??????")


func test_locked_scene_chapter_two() -> void:
	var story = _make_story_with(2, 1)
	_menu.show_menu(story, 0, 0)
	await get_tree().process_frame
	var locked = _find_locked_scene(1, 0)
	assert_not_null(locked)
	var chap_lbl = locked.find_child("LockedChapterLabel", true, false)
	assert_not_null(chap_lbl)
	assert_eq(chap_lbl.text, "Chapitre 2")


func test_locked_scene_is_semi_transparent() -> void:
	var story = _make_story_with(1, 2)
	_menu.show_menu(story, 0, 0)
	await get_tree().process_frame
	var locked = _find_locked_scene(0, 1)
	assert_not_null(locked)
	assert_lt(locked.self_modulate.a, 1.0, "La scène verrouillée doit être semi-transparente")


# --- Signal scene_selected ---

func test_clicking_unlocked_scene_emits_signal() -> void:
	var story = _make_story_with(1, 1)
	var chapter_uuid = story.chapters[0].uuid
	var scene_uuid = story.chapters[0].scenes[0].uuid
	_menu.show_menu(story, 0, 0)
	await get_tree().process_frame
	watch_signals(_menu)
	var btn = _find_scene_button(0, 0)
	assert_not_null(btn)
	btn.pressed.emit()
	assert_signal_emitted(_menu, "scene_selected")
	var args = get_signal_parameters(_menu, "scene_selected")
	assert_eq(args[0], chapter_uuid, "chapter_uuid doit correspondre")
	assert_eq(args[1], scene_uuid, "scene_uuid doit correspondre")


func test_scene_selected_signal_has_correct_uuids() -> void:
	var story = _make_story_with(2, 2)
	story.chapters[0].scenes[1].scene_name = "Scène Cible"
	var chapter_uuid = story.chapters[0].uuid
	var scene_uuid = story.chapters[0].scenes[1].uuid
	_menu.show_menu(story, 1, 0)
	await get_tree().process_frame
	watch_signals(_menu)
	var btn = _find_scene_button(0, 1)
	assert_not_null(btn)
	btn.pressed.emit()
	var args = get_signal_parameters(_menu, "scene_selected")
	assert_eq(args[0], chapter_uuid)
	assert_eq(args[1], scene_uuid)


# --- Signal close_pressed ---

func test_close_button_emits_signal() -> void:
	watch_signals(_menu)
	# Le bouton fermer est dans l'en-tête
	var header = _find_header()
	assert_not_null(header)
	var close_btn: Button = null
	for child in header.get_children():
		if child is Button and child.text == "✕":
			close_btn = child
			break
	assert_not_null(close_btn, "Doit trouver le bouton fermer")
	close_btn.pressed.emit()
	assert_signal_emitted(_menu, "close_pressed")


# --- Cas sans sauvegardes (max=0,0) ---

func test_only_first_scene_unlocked_when_no_saves() -> void:
	var story = _make_story_with(2, 2)
	_menu.show_menu(story, 0, 0)
	await get_tree().process_frame
	# Chapitre 0, scène 0 : débloquée
	assert_not_null(_find_scene_button(0, 0), "Première scène doit être débloquée")
	# Chapitre 0, scène 1 : verrouillée
	assert_not_null(_find_locked_scene(0, 1), "Deuxième scène du chapitre 0 doit être verrouillée")
	# Chapitre 1 : toutes verrouillées
	assert_not_null(_find_locked_scene(1, 0), "Première scène du chapitre 1 doit être verrouillée")
	assert_not_null(_find_locked_scene(1, 1), "Deuxième scène du chapitre 1 doit être verrouillée")


# --- Nettoyage entre show_menu ---

func test_repopulate_clears_previous_content() -> void:
	var story1 = _make_story_with(1, 1)
	var story2 = _make_story_with(2, 1)
	_menu.show_menu(story1, 0, 0)
	await get_tree().process_frame
	_menu.show_menu(story2, 1, 0)
	await get_tree().process_frame
	var sections = _menu._chapters_container.get_children()
	assert_eq(sections.size(), 2, "Doit y avoir exactement 2 chapitres après rechargement")


# --- Helpers ---

func _make_simple_story():
	return _make_story_with(1, 1)


func _make_story_with(num_chapters: int, scenes_per_chapter: int):
	var story = StoryScript.new()
	for ci in range(num_chapters):
		var ch = ChapterScript.new()
		ch.chapter_name = "Chapitre %d" % (ci + 1)
		for si in range(scenes_per_chapter):
			var sc = SceneScript.new()
			sc.scene_name = "Scène %d-%d" % [ci, si]
			ch.scenes.append(sc)
		story.chapters.append(ch)
	return story


func _find_header() -> HBoxContainer:
	for child in _menu.get_children():
		if child is CenterContainer:
			for panel_child in child.get_children():
				if panel_child is PanelContainer:
					for vbox_child in panel_child.get_children():
						if vbox_child is VBoxContainer:
							for item in vbox_child.get_children():
								if item is HBoxContainer:
									return item
	return null


func _get_scenes_row(chapter_idx: int) -> FlowContainer:
	if _menu._chapters_container == null:
		return null
	var sections = _menu._chapters_container.get_children()
	if chapter_idx >= sections.size():
		return null
	var section = sections[chapter_idx]
	return section.get_node_or_null("ScenesRow")


func _find_scene_button(chapter_idx: int, scene_idx: int) -> Button:
	var row := _get_scenes_row(chapter_idx)
	if row == null:
		return null
	var btn_name := "SceneButton_%d" % scene_idx
	return row.get_node_or_null(btn_name)


func _find_locked_scene(chapter_idx: int, scene_idx: int) -> PanelContainer:
	var row := _get_scenes_row(chapter_idx)
	if row == null:
		return null
	var node_name := "LockedScene_%d" % scene_idx
	return row.get_node_or_null(node_name)


func test_apply_custom_theme_method_exists() -> void:
	assert_true(_menu.has_method("apply_custom_theme"), "chapter_scene_menu should have apply_custom_theme")

func test_apply_custom_theme_does_not_crash() -> void:
	_menu.apply_custom_theme("")
	pass_test("apply_custom_theme did not crash")
