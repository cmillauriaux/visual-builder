# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Control

## Scène principale du jeu standalone — lecture d'une story sans éditeur.
##
## Mode de fonctionnement :
## - Si `story_path` est défini (via l'inspecteur ou par code), charge directement cette story.
## - Sinon, affiche un sélecteur parmi les stories de `user://stories/`.
##
## Pour l'export : définir `story_path` vers le dossier de la story embarquée
## (ex: "res://story" ou "user://stories/mon_histoire").

const GameUIBuilder = preload("res://src/controllers/game_ui_builder.gd")
const GamePlayControllerScript = preload("res://src/controllers/game_play_controller.gd")
const StorySaver = preload("res://src/persistence/story_saver.gd")
const GameSettings = preload("res://src/ui/menu/game_settings.gd")
const StoryI18nService = preload("res://src/services/story_i18n_service.gd")
const GameSaveManager = preload("res://src/persistence/game_save_manager.gd")
const OptionsMenuScript = preload("res://src/ui/menu/options_menu.gd")
const PckChapterLoaderScript = preload("res://src/services/pck_chapter_loader.gd")
const UIScale = preload("res://src/ui/themes/ui_scale.gd")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")
const PwaInstallPromptScript = preload("res://src/ui/menu/pwa_install_prompt.gd")
const GamePluginManagerScript = preload("res://src/plugins/game_plugin_manager.gd")
const GamePluginContextScript = preload("res://src/plugins/game_plugin_context.gd")
const LocaleDetector = preload("res://src/services/locale_detector.gd")
const ScreenshotServiceScript = preload("res://src/services/screenshot_service.gd")
const SequenceVisualEditorScript = preload("res://src/ui/sequence/sequence_visual_editor.gd")

## Chemin vers la story à charger automatiquement.
## Si vide, affiche le sélecteur. Peut pointer vers res:// ou user://.
@export var story_path: String = ""

# Contrôleurs
var _play_ctrl: Node
var _sequence_editor_ctrl: Control
var _story_play_ctrl: Node
var _foreground_transition: Node
var _sequence_fx_player: Node
var _music_player: Node

# UI — Visual
var _visual_editor: Control

# UI — Play overlay
var _play_overlay: Control
var _play_dialogue_panel: PanelContainer
var _play_character_box: PanelContainer
var _play_character_label: Label
var _play_text_label: RichTextLabel
var _typewriter_timer: Timer
var _choice_overlay: CenterContainer
var _choice_panel: PanelContainer
var _play_title_overlay: CenterContainer
var _play_title_label: Label
var _play_subtitle_label: Label

# UI — Menu button, Play buttons bar & Pause menu
var _menu_button: Button
var _auto_play_button: Button
var _skip_button: Button
var _history_button: Button
var _quicksave_button: Button
var _quickload_button: Button
var _play_buttons_bar: HBoxContainer
var _toolbar_toggle_button: Button
var _pause_menu: Control

# UI — Save/Load menu
var _save_load_menu: Control
var _pending_screenshot: Image = null
# Contexte d'ouverture de la grille : "pause" ou "main"
var _save_load_context: String = "pause"

# UI — Chapter/Scene menu
var _chapter_scene_menu: Control
# Contexte d'ouverture : "pause" ou "main"
var _chapter_scene_context: String = "pause"

# UI — Story selector
var _story_selector: PanelContainer
var _story_selector_title: Label
var _story_list: VBoxContainer

# UI — Variables display
var _variable_sidebar: VBoxContainer
var _variable_sidebar_scroll: ScrollContainer
var _variable_details_overlay: CenterContainer

# UI — Menu principal
var _main_menu: Control

# UI — Écrans de fin
var _game_over_screen: Control
var _to_be_continued_screen: Control

# UI — Options menu (pause context)
var _pause_options_center: MarginContainer
var _pause_options_menu: PanelContainer

# UI — Toast
var _toast_overlay: PanelContainer
var _toast_label: Label
var _toast_generation: int = 0

# UI — PWA install prompt
var _pwa_install_prompt: Control

# UI — Loading overlay (chargement PCK entre chapitres)
var _loading_overlay: Control
var _loading_overlay_label: Label
var _loading_overlay_bg: TextureRect

# UI — Quickload confirmation
var _quickload_confirm_overlay: Control
var _quickload_confirm_label: Label
var _quickload_yes_btn: Button
var _quickload_no_btn: Button

# Game plugin system
var _game_plugin_manager: Node
var _plugin_toolbar: HBoxContainer
var _plugin_overlay_left: VBoxContainer
var _plugin_overlay_right: VBoxContainer
var _plugin_overlay_top: HBoxContainer

# PCK chapter loader
var _pck_loader: RefCounted

# Screenshot service (miniatures basse résolution pour les sauvegardes)
var _screenshot_service: Node

# State
var _current_story = null
var _current_story_path: String = ""
var _settings: RefCounted
var _i18n_dict: Dictionary = {}
var _cached_max_progression: Dictionary = {"chapter": -1, "scene": -1}
var _play_ui_state_before_menu: Dictionary = {}

const _PENDING_RESTORE_PATH := "user://_pending_options_restore.json"


func _ready() -> void:
	# Forcer le ratio 16:9 avec bandes noires sur les écrans non-conformes (iPhone, etc.)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	# Charger les réglages
	_settings = GameSettings.new()
	_settings.load_settings()
	_settings.apply_settings()

	# Appliquer le multiplicateur d'échelle UI avant de construire l'interface
	UIScale.set_user_multiplier(_settings.get_ui_scale_factor())

	GameUIBuilder.build(self)

	# Initialiser le système de plugins in-game
	_game_plugin_manager = Node.new()
	_game_plugin_manager.set_script(GamePluginManagerScript)
	add_child(_game_plugin_manager)
	_game_plugin_manager.load_enabled_states(_settings)
	_game_plugin_manager.scan_and_load_plugins()

	# Initialiser le service de screenshot basse résolution
	_screenshot_service = Node.new()
	_screenshot_service.set_script(ScreenshotServiceScript)
	add_child(_screenshot_service)
	_screenshot_service.setup(get_viewport())

	# Configurer le contrôleur de jeu avec les réglages
	_story_play_ctrl.setup(null, _settings.autosave_enabled)

	# Vérifier si un chemin de story est défini dans les paramètres du projet (via override.cfg)
	var overridden_path = ProjectSettings.get_setting("application/config/story_path", "")
	if overridden_path != "":
		story_path = overridden_path

	_play_ctrl = Node.new()
	_play_ctrl.set_script(GamePlayControllerScript)
	_play_ctrl.setup(self)
	_play_ctrl._game_plugin_manager = _game_plugin_manager
	add_child(_play_ctrl)

	# Connecter les signaux du play
	_menu_button.pressed.connect(_on_menu_button_pressed)
	_auto_play_button.pressed.connect(_play_ctrl.toggle_auto_play)
	_skip_button.pressed.connect(_play_ctrl.execute_skip)
	_history_button.pressed.connect(_play_ctrl.open_history)
	_play_ctrl.set_auto_play_delay(_settings.auto_play_delay)
	_play_ctrl.set_auto_play_enabled(_settings.auto_play_enabled)
	_play_ctrl.set_typewriter_speed(_settings.typewriter_speed)
	_play_ctrl.set_dialogue_opacity(_settings.dialogue_opacity / 100.0)
	_play_ctrl.set_toolbar_visible(_settings.toolbar_visible)
	_play_ctrl.set_voice_language(_settings.voice_language)
	_typewriter_timer.timeout.connect(_play_ctrl.on_typewriter_tick)
	_story_play_ctrl.sequence_play_requested.connect(_play_ctrl.on_sequence_play_requested)
	_story_play_ctrl.choice_display_requested.connect(_play_ctrl.on_choice_display_requested)
	_story_play_ctrl.play_finished.connect(_play_ctrl.on_play_finished)
	_sequence_editor_ctrl.play_dialogue_changed.connect(_play_ctrl.on_play_dialogue_changed)
	_sequence_editor_ctrl.play_stopped.connect(_play_ctrl.on_play_stopped)
	_play_ctrl.play_finished_show_menu.connect(_on_play_finished_return)
	_play_ctrl.toolbar_toggled.connect(_on_toolbar_toggled)

	# Connecter le signal scene_entered pour mettre à jour la disponibilité du Skip
	_story_play_ctrl.scene_entered.connect(_on_scene_entered_update_skip)

	# Connecter les signaux d'affichage des variables
	_story_play_ctrl.variables_display_changed.connect(_on_variables_display_changed)
	_variable_sidebar.details_requested.connect(_on_variable_details_requested)
	_variable_details_overlay.close_requested.connect(_on_variable_details_close)

	# Connecter le signal autosave
	_story_play_ctrl.autosave_triggered.connect(_on_autosave_triggered)

	# Connecter le signal story_finished pour les analytics (via plugin)
	_story_play_ctrl.story_finished_with_reason.connect(_on_analytics_story_finished)

	# Connecter les signaux pour le système de plugins in-game
	_story_play_ctrl.chapter_entered.connect(_on_plugin_chapter_entered)
	_story_play_ctrl.scene_entered.connect(_on_plugin_scene_entered)
	_story_play_ctrl.sequence_entered.connect(_on_plugin_sequence_entered)
	_story_play_ctrl.choice_made.connect(_on_plugin_choice_made)

	# Connecter les signaux de chargement PCK entre chapitres
	_story_play_ctrl.chapter_loading_started.connect(_on_chapter_loading_started)
	_story_play_ctrl.chapter_loading_finished.connect(_on_chapter_loading_finished)

	# Connecter les signaux du menu principal
	_main_menu.new_game_pressed.connect(_on_new_game)
	_main_menu.load_game_pressed.connect(_on_load_game)
	_main_menu.chapters_scenes_pressed.connect(_on_main_menu_chapters_scenes_pressed)
	_main_menu.quit_pressed.connect(_on_quit)
	_main_menu.options_applied.connect(_on_options_applied)
	_main_menu.set_settings(_settings)
	_main_menu.set_game_plugin_manager(_game_plugin_manager)

	# Connecter les signaux des écrans de fin
	_game_over_screen.back_to_menu_pressed.connect(_on_play_finished_return)
	_to_be_continued_screen.back_to_menu_pressed.connect(_on_play_finished_return)
	_game_over_screen.load_last_autosave_pressed.connect(_on_game_over_load_autosave)

	# Connecter les signaux du menu pause
	_pause_menu.resume_pressed.connect(_on_pause_resume)
	_pause_menu.save_pressed.connect(_on_pause_save)
	_pause_menu.load_pressed.connect(_on_pause_load)
	_pause_menu.chapters_scenes_pressed.connect(_on_chapters_scenes_pressed)
	_pause_menu.new_game_pressed.connect(_on_pause_new_game)
	_pause_menu.quit_pressed.connect(_on_pause_quit)
	_pause_menu.options_pressed.connect(_on_pause_options)

	# Connecter les signaux du menu chapitres/scènes
	_chapter_scene_menu.scene_selected.connect(_on_chapter_scene_selected)
	_chapter_scene_menu.close_pressed.connect(_on_chapter_scene_close)

	# Options menu (pause context, plein écran avec marge)
	_pause_options_center = MarginContainer.new()
	_pause_options_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pause_margin = UIScale.scale(40)
	_pause_options_center.add_theme_constant_override("margin_top", pause_margin)
	_pause_options_center.add_theme_constant_override("margin_bottom", pause_margin)
	_pause_options_center.add_theme_constant_override("margin_left", pause_margin)
	_pause_options_center.add_theme_constant_override("margin_right", pause_margin)
	_pause_options_center.visible = false
	_pause_options_center.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_options_center.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
	add_child(_pause_options_center)

	_pause_options_menu = PanelContainer.new()
	_pause_options_menu.set_script(OptionsMenuScript)
	_pause_options_menu.build_ui()
	_pause_options_menu.applied.connect(_on_pause_options_applied)
	_pause_options_menu.closed.connect(_on_pause_options_closed)
	_pause_options_menu.set_game_plugin_manager(_game_plugin_manager)
	_pause_options_center.add_child(_pause_options_menu)

	# Connecter les signaux du menu save/load
	_save_load_menu.save_slot_pressed.connect(_on_save_slot)
	_save_load_menu.load_slot_pressed.connect(_on_load_slot)
	_save_load_menu.delete_slot_pressed.connect(_on_delete_slot)
	_save_load_menu.close_pressed.connect(_on_save_load_close)

	# Connecter les signaux quicksave/quickload
	_quicksave_button.pressed.connect(_on_quicksave)
	_quickload_button.pressed.connect(_on_quickload)
	_quickload_yes_btn.pressed.connect(_do_quickload)
	_quickload_no_btn.pressed.connect(_cancel_quickload)

	# PWA install prompt — build_ui et add_child différés dans show_if_needed
	_pwa_install_prompt = Control.new()
	_pwa_install_prompt.set_script(PwaInstallPromptScript)
	_pwa_install_prompt.closed.connect(_on_pwa_prompt_closed)

	# Chercher si un chemin est forcé via override.cfg/settings
	var override_path = ProjectSettings.get_setting("application/config/story_path", "")
	if override_path != "":
		story_path = override_path

	if story_path != "":
		_load_story_and_show_menu(story_path)
	else:
		_show_story_selector()

	# Restaurer l'état du jeu après un rechargement de scène (changement d'échelle UI)
	if FileAccess.file_exists(_PENDING_RESTORE_PATH):
		_handle_pending_restore()


func _load_story_and_show_menu(path: String) -> void:
	print("Game: Tentative de chargement de la story : ", path)
	TextureLoader.base_dir = path
	var story = StorySaver.load_story(path)
	
	if story == null and path != "res://story":
		# Tentative désespérée si on ne trouve pas à l'endroit prévu (ex: export PCK interne)
		print("Game: Échec chargement ", path, ". Essai fallback res://story")
		path = "res://story"
		TextureLoader.base_dir = path
		story = StorySaver.load_story(path)
		
	if story == null:
		printerr("Game: Erreur critique - Impossible de charger story.yaml à ", path)
		_show_error("Erreur de chargement de l'histoire.\nChemin : " + path + "\n\nAssurez-vous que le dossier story contient un fichier story.yaml valide.")
		_show_story_selector()
		return
		
	_current_story = story
	_current_story_path = path
	_setup_loading_overlay_image(_current_story)

	# Initialiser le chargeur de PCK chapitres (pour les exports avec split PCK)
	_pck_loader = PckChapterLoaderScript.new()
	_pck_loader.setup(path, get_tree())
	_story_play_ctrl.set_pck_loader(_pck_loader)

	# Auto-détecter la langue si aucune préférence n'a été sauvegardée,
	# OU si la langue sauvegardée n'est pas disponible dans cet export
	# (ex: export langue unique "en" alors que settings.cfg contient "fr").
	if _settings.is_language_auto():
		_auto_detect_language()
	else:
		var _lang_config = StoryI18nService.load_languages_config(_current_story_path)
		var _available: Array = _lang_config.get("languages", ["fr"])
		if not _available.has(_settings.language):
			_auto_detect_language()

	_reload_i18n()
	_load_max_progression()
	_apply_game_ui_theme(story)
	await _setup_game_plugins()
	_show_main_menu(_current_story)
	_pwa_install_prompt.show_if_needed(self, _settings.pwa_prompt_dismissed)


func _reload_i18n() -> void:
	if _current_story_path != "":
		# Recharger la story depuis le YAML pour avoir les textes originaux (clés i18n)
		# et éviter l'écrasement destructif lors des changements de langue successifs.
		_current_story = StorySaver.load_story(_current_story_path)
		_i18n_dict = StoryI18nService.load_i18n(_current_story_path, _settings.language)

		# Appliquer les traductions si ce n'est pas la langue source de la story
		var lang_config = StoryI18nService.load_languages_config(_current_story_path)
		var source_lang: String = lang_config.get("default", "fr")
		if _settings.language != source_lang and not _i18n_dict.is_empty():
			StoryI18nService.apply_to_story(_current_story, _i18n_dict)
	else:
		_i18n_dict = {}
	_apply_ui_lang()
	_update_play_story_references()


func _update_play_story_references() -> void:
	if _current_story == null or not _story_play_ctrl.is_playing():
		return
	_story_play_ctrl.update_story(_current_story)
	var new_seq = _story_play_ctrl.get_current_sequence()
	if new_seq == null:
		return
	_play_ctrl._current_playing_sequence = new_seq
	_sequence_editor_ctrl._sequence = new_seq
	# Rafraîchir le texte du dialogue courant
	var play_idx: int = _sequence_editor_ctrl.get_play_dialogue_index()
	if play_idx >= 0 and play_idx < new_seq.dialogues.size():
		var dlg = new_seq.dialogues[play_idx]
		_play_character_label.text = dlg.character
		_play_character_box.visible = dlg.character != ""
		_play_text_label.text = dlg.text
		_play_text_label.visible_characters = -1


func _auto_detect_language() -> void:
	var config = StoryI18nService.load_languages_config(_current_story_path)
	var available: Array = config.get("languages", ["fr"])
	var default_lang: String = config.get("default", "fr")
	var detected = LocaleDetector.detect_locale()
	_settings.language = LocaleDetector.resolve_language(detected, available, default_lang)


## Scanne la story pour trouver les langues de voix disponibles.
## Retourne un Array de codes langues (ex: ["en", "fr"]) triés.
func _get_story_voice_languages(story) -> Array:
	var langs: Dictionary = {}
	if story == null:
		return []
	var chapters: Array = story.chapters if story.get("chapters") != null else []
	for chapter in chapters:
		var scenes: Array = chapter.scenes if chapter.get("scenes") != null else []
		for scene in scenes:
			var sequences: Array = scene.sequences if scene.get("sequences") != null else []
			for seq in sequences:
				var dialogues: Array = seq.dialogues if seq.get("dialogues") != null else []
				for dlg in dialogues:
					var vf = dlg.get("voice_files")
					if vf != null and vf is Dictionary:
						for key in vf:
							langs[key] = true
	var result: Array = langs.keys()
	result.sort()
	return result


func _apply_ui_lang() -> void:
	_menu_button.text = StoryI18nService.get_ui_string("Menu", _i18n_dict)
	if _story_selector_title:
		_story_selector_title.text = StoryI18nService.get_ui_string("Sélectionnez une histoire", _i18n_dict)
	_main_menu.apply_ui_translations(_i18n_dict)
	_pause_menu.apply_ui_translations(_i18n_dict)
	_pause_options_menu.apply_ui_translations(_i18n_dict)
	_save_load_menu.apply_ui_translations(_i18n_dict)
	_chapter_scene_menu.apply_ui_translations(_i18n_dict)
	_game_over_screen.apply_ui_translations(_i18n_dict)
	_to_be_continued_screen.apply_ui_translations(_i18n_dict)
	_play_ctrl.set_i18n(_i18n_dict)
	# Play buttons bar
	_quicksave_button.text = StoryI18nService.get_ui_string("Save (F5)", _i18n_dict)
	_quickload_button.text = StoryI18nService.get_ui_string("Load (F9)", _i18n_dict)
	_auto_play_button.text = StoryI18nService.get_ui_string("Auto", _i18n_dict)
	_skip_button.text = StoryI18nService.get_ui_string("Skip (S)", _i18n_dict)
	_history_button.text = StoryI18nService.get_ui_string("Histo (H)", _i18n_dict)
	# Quickload confirm
	_quickload_confirm_label.text = StoryI18nService.get_ui_string("Charger la sauvegarde rapide ?", _i18n_dict)
	_quickload_yes_btn.text = StoryI18nService.get_ui_string("Oui", _i18n_dict)
	_quickload_no_btn.text = StoryI18nService.get_ui_string("Non", _i18n_dict)
	# Loading overlay
	_loading_overlay_label.text = StoryI18nService.get_ui_string("Chargement...", _i18n_dict)
	# PWA install prompt
	if _pwa_install_prompt and _pwa_install_prompt.has_method("apply_ui_translations"):
		_pwa_install_prompt.apply_ui_translations(_i18n_dict)


func _on_options_applied() -> void:
	# Vérifier si l'échelle UI a changé — nécessite un rechargement de la scène
	var new_multiplier: float = _settings.get_ui_scale_factor()
	if not is_equal_approx(new_multiplier, UIScale.get_user_multiplier()):
		UIScale.set_user_multiplier(new_multiplier)
		get_tree().reload_current_scene()
		return

	_reload_i18n()
	_play_ctrl.set_auto_play_delay(_settings.auto_play_delay)
	_play_ctrl.set_auto_play_enabled(_settings.auto_play_enabled)
	_play_ctrl.set_typewriter_speed(_settings.typewriter_speed)
	_play_ctrl.set_dialogue_opacity(_settings.dialogue_opacity / 100.0)
	_story_play_ctrl._autosave_enabled = _settings.autosave_enabled
	_play_ctrl.set_toolbar_visible(_settings.toolbar_visible)
	_play_ctrl.set_voice_language(_settings.voice_language)


func _on_toolbar_toggled(p_visible: bool) -> void:
	_settings.toolbar_visible = p_visible
	_settings.save_settings()


func _show_main_menu(story) -> void:
	_story_selector.visible = false
	_menu_button.visible = false
	_game_over_screen.hide_screen()
	_to_be_continued_screen.hide_screen()
	_main_menu.setup(story, _current_story_path)
	_main_menu.set_voice_languages(_get_story_voice_languages(story))
	_main_menu.show_menu()
	var patreon_url = story.patreon_url if story.get("patreon_url") != null else ""
	var itchio_url = story.itchio_url if story.get("itchio_url") != null else ""
	_pause_menu.set_external_links(patreon_url, itchio_url)
	_game_over_screen.setup(
		story.game_over_title if story.get("game_over_title") != null else "",
		story.game_over_subtitle if story.get("game_over_subtitle") != null else "",
		story.game_over_background if story.get("game_over_background") != null else "",
		_current_story_path,
		patreon_url,
		itchio_url
	)
	_game_over_screen.set_load_autosave_visible(not GameSaveManager.list_autosaves().is_empty())
	_to_be_continued_screen.setup(
		story.to_be_continued_title if story.get("to_be_continued_title") != null else "",
		story.to_be_continued_subtitle if story.get("to_be_continued_subtitle") != null else "",
		story.to_be_continued_background if story.get("to_be_continued_background") != null else "",
		_current_story_path,
		patreon_url,
		itchio_url
	)
	if _music_player and story.get("menu_music") != null and story.menu_music != "":
		var music_path = MusicPlayer._resolve_path(story.menu_music, _current_story_path)
		_music_player.play_menu_music(music_path)


## Précharge un PCK chapitre sur le web en affichant la progression dans le menu.
func _preload_chapter_with_ui(chapter_uuid: String) -> void:
	if not _pck_loader or not _pck_loader.has_manifest() or OS.get_name() != "Web":
		return
	if _pck_loader.is_chapter_loaded(chapter_uuid):
		return
	_main_menu.set_loading_visible(true)
	var download_cb = func(_name: String, progress: float):
		_main_menu.update_loading_text(StoryI18nService.get_ui_string("Téléchargement...", _i18n_dict) + " %d%%" % int(progress * 100))
	var mounting_cb = func(_name: String):
		_main_menu.update_loading_text(StoryI18nService.get_ui_string("Chargement...", _i18n_dict))
	_pck_loader.chapter_download_progress.connect(download_cb)
	_pck_loader.chapter_mounting_started.connect(mounting_cb)
	var ok = await _pck_loader.ensure_chapter_loaded(chapter_uuid)
	_pck_loader.chapter_download_progress.disconnect(download_cb)
	_pck_loader.chapter_mounting_started.disconnect(mounting_cb)
	_main_menu.set_loading_visible(false)
	if not ok:
		push_warning("PckChapterLoader: failed to preload chapter %s" % chapter_uuid)


func _on_new_game() -> void:
	# Sur le web, charger le PCK du 1er chapitre AVANT de cacher le menu
	if _pck_loader and _pck_loader.has_manifest() and OS.get_name() == "Web":
		var chapter = _story_play_ctrl._find_entry(_current_story.chapters, _current_story.entry_point_uuid)
		if chapter:
			await _preload_chapter_with_ui(chapter.uuid)
	_main_menu.hide_menu()
	if _game_plugin_manager:
		var ctx = _build_game_plugin_context()
		_game_plugin_manager.dispatch_on_story_started(ctx, _current_story.title, _current_story.version)
	_play_ctrl.start_story(_current_story, _current_story_path)


func _on_load_game() -> void:
	_main_menu.hide_menu()
	_save_load_context = "main"
	_save_load_menu.show_as_load_mode()


func _on_quit() -> void:
	if _game_plugin_manager:
		var ctx = _build_game_plugin_context()
		_game_plugin_manager.dispatch_on_game_quit(ctx, "", "", "")
	get_tree().quit()


func _on_play_finished_return() -> void:
	_game_over_screen.hide_screen()
	_to_be_continued_screen.hide_screen()
	if _current_story:
		_show_main_menu(_current_story)
	else:
		_show_story_selector()


func _on_game_over_load_autosave() -> void:
	_game_over_screen.hide_screen()
	var autosaves := GameSaveManager.list_autosaves()
	if autosaves.is_empty():
		return
	var latest_slot: int = autosaves[0]["slot_index"]
	_on_load_slot(-(latest_slot + 2))


# --- Menu pause ---

func _on_menu_button_pressed() -> void:
	# Capturer le screenshot avant d'afficher le menu (sans overlay)
	_pending_screenshot = _screenshot_service.capture()
	_hide_play_ui_for_menu()
	get_tree().paused = true
	_pause_menu.show_menu()


func _on_pause_options() -> void:
	_pause_menu.hide_menu()
	if _pause_options_menu.has_method("setup_languages") and _current_story_path != "":
		_pause_options_menu.setup_languages(_current_story_path)
	if _pause_options_menu.has_method("setup_voice_languages") and _current_story != null:
		_pause_options_menu.setup_voice_languages(_get_story_voice_languages(_current_story))
	if _settings:
		_pause_options_menu.load_from_settings(_settings)
	_pause_options_menu.visible = true
	_pause_options_center.visible = true


func _on_pause_options_applied() -> void:
	_pause_options_center.visible = false

	# Si l'échelle UI a changé, sauvegarder l'état du jeu avant le rechargement
	var new_multiplier: float = _settings.get_ui_scale_factor()
	if not is_equal_approx(new_multiplier, UIScale.get_user_multiplier()):
		var state := _collect_game_state()
		var f := FileAccess.open(_PENDING_RESTORE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(state))
			f.close()
		UIScale.set_user_multiplier(new_multiplier)
		get_tree().paused = false
		get_tree().reload_current_scene()
		return

	_on_options_applied()
	_pause_menu.show_menu()


func _on_pause_options_closed() -> void:
	_pause_options_center.visible = false
	_pause_menu.show_menu()


func _handle_pending_restore() -> void:
	var f := FileAccess.open(_PENDING_RESTORE_PATH, FileAccess.READ)
	if f == null:
		return
	var json_str := f.get_as_text()
	f.close()
	DirAccess.remove_absolute(_PENDING_RESTORE_PATH)
	var save_data = JSON.parse_string(json_str)
	if not save_data is Dictionary or save_data.is_empty():
		return
	# Charger la story si pas encore chargée
	var target_path: String = save_data.get("story_path", "")
	if _current_story == null and target_path != "":
		_load_story_and_show_menu(target_path)
	if _current_story == null:
		return
	_main_menu.hide_menu()
	_story_selector.visible = false
	_play_ctrl.start_from_save(_current_story, save_data, _current_story_path)


func _on_pause_resume() -> void:
	_pause_menu.hide_menu()
	_restore_play_ui_after_menu()
	get_tree().paused = false


func _on_pause_save() -> void:
	_pause_menu.hide_menu()
	_save_load_context = "pause"
	_save_load_menu.show_as_save_mode()


func _on_pause_load() -> void:
	_pause_menu.hide_menu()
	_save_load_context = "pause"
	_save_load_menu.show_as_load_mode()


func _on_main_menu_chapters_scenes_pressed() -> void:
	if _current_story == null:
		return
	_main_menu.hide_menu()
	_chapter_scene_context = "main"
	_open_chapter_scene_menu()


func _on_chapters_scenes_pressed() -> void:
	if _current_story == null:
		return
	_pause_menu.hide_menu()
	_chapter_scene_context = "pause"
	_open_chapter_scene_menu()


func _open_chapter_scene_menu() -> void:
	var max_chapter_idx: int = maxi(_cached_max_progression["chapter"], 0)
	var max_scene_idx: int = maxi(_cached_max_progression["scene"], 0)
	_chapter_scene_menu.show_menu(_current_story, max_chapter_idx, max_scene_idx)


func _on_chapter_scene_selected(chapter_uuid: String, scene_uuid: String) -> void:
	_chapter_scene_menu.hide_menu()
	get_tree().paused = false
	var chapter = _current_story.find_chapter(chapter_uuid) if _current_story else null
	var scene = chapter.find_scene(scene_uuid) if chapter else null
	if chapter == null or scene == null:
		return
	await _preload_chapter_with_ui(chapter_uuid)
	_play_ctrl.stop_current()
	_story_play_ctrl.start_play_scene(_current_story, chapter, scene)


func _on_chapter_scene_close() -> void:
	_chapter_scene_menu.hide_menu()
	if _chapter_scene_context == "main":
		_show_main_menu(_current_story)
	else:
		_pause_menu.show_menu()


func _hide_play_ui_for_menu() -> void:
	_play_ui_state_before_menu = {
		"play_overlay": _play_overlay.visible,
		"choice_overlay": _choice_overlay.visible,
		"play_buttons_bar": _play_buttons_bar.visible if _play_buttons_bar else false,
		"menu_button": _menu_button.visible,
		"toolbar_toggle": _toolbar_toggle_button.visible if _toolbar_toggle_button else false,
	}
	_play_overlay.visible = false
	_choice_overlay.visible = false
	if _play_buttons_bar:
		_play_buttons_bar.visible = false
	if _toolbar_toggle_button:
		_toolbar_toggle_button.visible = false
	_menu_button.visible = false


func _restore_play_ui_after_menu() -> void:
	_play_overlay.visible = _play_ui_state_before_menu.get("play_overlay", false)
	_choice_overlay.visible = _play_ui_state_before_menu.get("choice_overlay", false)
	if _play_buttons_bar:
		_play_buttons_bar.visible = _play_ui_state_before_menu.get("play_buttons_bar", false) and _settings.toolbar_visible
	_menu_button.visible = _play_ui_state_before_menu.get("menu_button", false)
	if _toolbar_toggle_button:
		_toolbar_toggle_button.visible = _play_ui_state_before_menu.get("toolbar_toggle", false)
	_play_ui_state_before_menu = {}


## Appelé à chaque entrée dans une nouvelle scène pour réévaluer le Skip.
func _on_scene_entered_update_skip(_scene_name: String, _scene_uuid: String) -> void:
	_update_skip_availability()


## Met à jour l'état du bouton Skip selon la scène courante (utilise le cache).
func _update_skip_availability() -> void:
	if _current_story == null:
		return
	_play_ctrl.set_skip_progression(_cached_max_progression["chapter"], _cached_max_progression["scene"])
	var chapter = _story_play_ctrl.get_current_chapter()
	var scene = _story_play_ctrl.get_current_scene()
	var ch_idx := _find_chapter_index(_current_story, chapter.uuid if chapter else "")
	var sc_idx := _find_scene_index(_current_story, ch_idx, scene.uuid if scene else "")
	_play_ctrl.update_skip_availability(ch_idx, sc_idx)


## Charge la progression maximale depuis toutes les sauvegardes et met en cache.
## Appelé une seule fois au chargement de la story.
func _load_max_progression() -> void:
	var max_ch := -1
	var max_sc := -1
	var all_saves: Array = []
	for entry in GameSaveManager.list_saves():
		if entry.get("has_data", false):
			all_saves.append(entry.get("data", {}))
	for entry in GameSaveManager.list_autosaves():
		all_saves.append(entry.get("data", {}))
	if GameSaveManager.quicksave_exists():
		all_saves.append(GameSaveManager.quickload())
	for save_data in all_saves:
		var ch_uuid: String = save_data.get("chapter_uuid", "")
		var sc_uuid: String = save_data.get("scene_uuid", "")
		var ch_idx := _find_chapter_index(_current_story, ch_uuid)
		var sc_idx := _find_scene_index(_current_story, ch_idx, sc_uuid)
		if ch_idx > max_ch or (ch_idx == max_ch and sc_idx > max_sc):
			max_ch = ch_idx
			max_sc = sc_idx
	_cached_max_progression = {"chapter": max_ch, "scene": max_sc}


## Met à jour le cache de progression à partir d'un état de sauvegarde.
func _update_cached_progression(save_data: Dictionary) -> void:
	if _current_story == null:
		return
	var ch_uuid: String = save_data.get("chapter_uuid", "")
	var sc_uuid: String = save_data.get("scene_uuid", "")
	var ch_idx := _find_chapter_index(_current_story, ch_uuid)
	var sc_idx := _find_scene_index(_current_story, ch_idx, sc_uuid)
	var max_ch: int = _cached_max_progression["chapter"]
	var max_sc: int = _cached_max_progression["scene"]
	if ch_idx > max_ch or (ch_idx == max_ch and sc_idx > max_sc):
		_cached_max_progression = {"chapter": ch_idx, "scene": sc_idx}


## Retourne l'index de chapitre par UUID, ou 0 si non trouvé.
func _find_chapter_index(story, chapter_uuid: String) -> int:
	if story == null or chapter_uuid == "":
		return 0
	for i in range(story.chapters.size()):
		if story.chapters[i].uuid == chapter_uuid:
			return i
	return 0


## Retourne l'index de scène dans le chapitre (par UUID), ou 0 si non trouvé.
func _find_scene_index(story, chapter_idx: int, scene_uuid: String) -> int:
	if story == null or scene_uuid == "" or chapter_idx < 0 or chapter_idx >= story.chapters.size():
		return 0
	var chapter = story.chapters[chapter_idx]
	for j in range(chapter.scenes.size()):
		if chapter.scenes[j].uuid == scene_uuid:
			return j
	return 0


## Collecte l'état courant du jeu pour une sauvegarde.
func _collect_game_state() -> Dictionary:
	var chapter = _story_play_ctrl.get_current_chapter()
	var scene = _story_play_ctrl.get_current_scene()
	var seq = _story_play_ctrl.get_current_sequence()
	var vars: Dictionary = {}
	if _story_play_ctrl.get("_variables") != null:
		vars = _story_play_ctrl._variables.duplicate()
	var timestamp := Time.get_datetime_string_from_system(false, true).replace("T", " ")
	return {
		"timestamp": timestamp,
		"story_path": _current_story_path,
		"chapter_uuid": chapter.uuid if chapter else "",
		"chapter_name": chapter.chapter_name if chapter else "",
		"scene_uuid": scene.uuid if scene else "",
		"scene_name": scene.scene_name if scene else "",
		"sequence_uuid": seq.uuid if seq else "",
		"sequence_name": seq.seq_name if seq else "",
		"dialogue_index": _sequence_editor_ctrl.get_play_dialogue_index(),
		"variables": vars,
	}


func _on_save_slot(slot_index: int) -> void:
	var state := _collect_game_state()
	GameSaveManager.save_game_state(slot_index, state, _pending_screenshot)
	_update_cached_progression(state)
	if _game_plugin_manager:
		var ctx = _build_game_plugin_context()
		_game_plugin_manager.dispatch_on_story_saved(
			ctx,
			_current_story.title if _current_story else "",
			slot_index,
			state.get("chapter_name", ""),
			state.get("scene_name", ""),
			state.get("sequence_name", ""),
		)
	_save_load_menu.hide_menu()
	get_tree().paused = false


func _on_autosave_triggered() -> void:
	if _current_story == null:
		return
	# Capture miniature basse résolution (< 1ms via SubViewport 320×180)
	var screenshot: Image = _screenshot_service.capture()
	var state := _collect_game_state()
	_update_cached_progression(state)
	# Écriture JSON + encodage PNG en tâche de fond pour ne pas bloquer le gameplay
	WorkerThreadPool.add_task(_autosave_background.bind(state, screenshot))


## Exécute l'écriture de la sauvegarde automatique en arrière-plan (thread worker).
## Toutes les données sont passées par valeur — aucun accès au scene tree.
static func _autosave_background(state: Dictionary, screenshot: Image) -> void:
	GameSaveManager.autosave(state, screenshot)


func _on_load_slot(slot_index: int) -> void:
	var save_data: Dictionary
	if slot_index == -1:
		save_data = GameSaveManager.quickload()
	elif slot_index < -1:
		var auto_slot := -(slot_index + 2)
		save_data = GameSaveManager.load_autosave(auto_slot)
	else:
		save_data = GameSaveManager.load_game(slot_index)
	if save_data.is_empty():
		return
	_save_load_menu.hide_menu()
	get_tree().paused = false
	# Charger la story si nécessaire
	var target_path: String = save_data.get("story_path", "")
	if target_path != _current_story_path and target_path != "":
		TextureLoader.base_dir = target_path
		var story = StorySaver.load_story(target_path)
		if story == null:
			_show_error(StoryI18nService.get_ui_string("Impossible de charger la story sauvegardée.", _i18n_dict))
			return
		_current_story = story
		_current_story_path = target_path
		_setup_loading_overlay_image(_current_story)
		_reload_i18n()
	# Précharger le PCK du chapitre sauvegardé si nécessaire
	var saved_chapter_uuid: String = save_data.get("chapter_uuid", "")
	if saved_chapter_uuid != "":
		await _preload_chapter_with_ui(saved_chapter_uuid)
	# Reprendre depuis la sauvegarde
	if _game_plugin_manager:
		var ctx = _build_game_plugin_context()
		_game_plugin_manager.dispatch_on_story_loaded(ctx, _current_story.title if _current_story else "", slot_index)
	_play_ctrl.start_from_save(_current_story, save_data, _current_story_path)


func _on_delete_slot(slot_index: int) -> void:
	GameSaveManager.delete_save(slot_index)
	_save_load_menu.refresh()


func _on_save_load_close() -> void:
	_save_load_menu.hide_menu()
	if _save_load_context == "pause":
		_pause_menu.show_menu()
	else:
		if _current_story:
			_show_main_menu(_current_story)
		else:
			_show_story_selector()


func _on_pause_new_game() -> void:
	_pause_menu.hide_menu()
	get_tree().paused = false
	# Précharger le PCK du 1er chapitre si nécessaire
	if _current_story:
		var chapter = _story_play_ctrl._find_entry(_current_story.chapters, _current_story.entry_point_uuid)
		if chapter:
			await _preload_chapter_with_ui(chapter.uuid)
	if _game_plugin_manager:
		var ctx = _build_game_plugin_context()
		_game_plugin_manager.dispatch_on_story_started(
			ctx,
			_current_story.title if _current_story else "",
			_current_story.version if _current_story else "",
		)
	_play_ctrl.stop_and_restart(_current_story, _current_story_path)


func _on_pause_quit() -> void:
	var chapter = _story_play_ctrl.get_current_chapter()
	var scene = _story_play_ctrl.get_current_scene()
	var seq = _story_play_ctrl.get_current_sequence()
	if _game_plugin_manager:
		var ctx = _build_game_plugin_context()
		_game_plugin_manager.dispatch_on_game_quit(
			ctx,
			chapter.chapter_name if chapter else "",
			scene.scene_name if scene else "",
			seq.seq_name if seq else "",
		)
	_pause_menu.hide_menu()
	get_tree().paused = false
	_play_ctrl.stop_current()
	if _current_story:
		_show_main_menu(_current_story)
	else:
		_show_story_selector()


# --- Story selector ---

func _show_story_selector() -> void:
	_visual_editor.load_sequence(null)
	_main_menu.hide_menu()
	_story_selector.visible = true
	_menu_button.visible = false
	_refresh_story_list()


func _refresh_story_list() -> void:
	for child in _story_list.get_children():
		child.queue_free()

	var stories_path = "user://stories"
	if not DirAccess.dir_exists_absolute(stories_path):
		DirAccess.make_dir_recursive_absolute(stories_path)
		_add_no_stories_label()
		return

	var dir = DirAccess.open(stories_path)
	if dir == null:
		_add_no_stories_label()
		return

	var found := false
	dir.list_dir_begin()
	var folder = dir.get_next()
	while folder != "":
		if dir.current_is_dir() and folder != "." and folder != "..":
			var story_yaml = stories_path + "/" + folder + "/story.yaml"
			if FileAccess.file_exists(story_yaml):
				found = true
				_add_story_button(folder, stories_path + "/" + folder)
		folder = dir.get_next()
	dir.list_dir_end()

	if not found:
		_add_no_stories_label()


func _add_story_button(story_name: String, story_path_arg: String) -> void:
	var btn = Button.new()
	btn.text = story_name
	btn.pressed.connect(_on_story_selected.bind(story_path_arg))
	_story_list.add_child(btn)


func _add_no_stories_label() -> void:
	var label = Label.new()
	label.text = StoryI18nService.get_ui_string("Aucune histoire trouvée", _i18n_dict)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate.a = 0.5
	_story_list.add_child(label)


func _on_story_selected(path: String) -> void:
	_load_story_and_show_menu(path)


func _show_error(msg: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()


func _show_info(msg: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = msg
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dialog)
	dialog.popup_centered()


# --- Variables display ---

func _on_variables_display_changed(variables: Dictionary) -> void:
	_variable_sidebar.update_display(variables, _current_story)
	_variable_sidebar_scroll.visible = _variable_sidebar.visible
	_variable_details_overlay.set_i18n(_i18n_dict)


func _on_variable_details_requested() -> void:
	var vars: Dictionary = {}
	if _story_play_ctrl.get("_variables") != null:
		vars = _story_play_ctrl._variables
	_variable_details_overlay.show_details(_current_story, vars)


func _on_variable_details_close() -> void:
	_variable_details_overlay.hide_details()


# --- Game Plugin System ---

func _build_game_plugin_context() -> RefCounted:
	var ctx := GamePluginContextScript.new()
	ctx.story = _current_story
	ctx.story_base_path = _current_story_path
	ctx.game_node = self
	ctx.settings = _settings
	if _story_play_ctrl:
		ctx.current_chapter = _story_play_ctrl.get_current_chapter()
		ctx.current_scene = _story_play_ctrl.get_current_scene()
		ctx.current_sequence = _story_play_ctrl.get_current_sequence()
		if _story_play_ctrl.get("_variables") != null:
			ctx.variables = _story_play_ctrl._variables
	return ctx


func _setup_game_plugins() -> void:
	if _game_plugin_manager == null or _current_story == null:
		return
	var ctx = _build_game_plugin_context()
	_play_ctrl._plugin_ctx = ctx
	_game_plugin_manager.inject_toolbar_buttons(_plugin_toolbar, ctx)
	_game_plugin_manager.inject_overlay_panels(
		_plugin_overlay_left, _plugin_overlay_right, _plugin_overlay_top, ctx)
	await _game_plugin_manager.dispatch_on_game_ready(ctx)


func _on_plugin_chapter_entered(_chapter_name: String, _chapter_uuid: String) -> void:
	if _game_plugin_manager == null:
		return
	var ctx = _build_game_plugin_context()
	_play_ctrl._plugin_ctx = ctx
	_game_plugin_manager.dispatch_on_before_chapter(ctx)


func _on_plugin_scene_entered(_scene_name: String, _scene_uuid: String) -> void:
	if _game_plugin_manager == null:
		return
	var ctx = _build_game_plugin_context()
	_play_ctrl._plugin_ctx = ctx
	_game_plugin_manager.dispatch_on_before_scene(ctx)


func _on_plugin_sequence_entered(_seq_name: String, _seq_uuid: String) -> void:
	if _game_plugin_manager == null:
		return
	var ctx = _build_game_plugin_context()
	_play_ctrl._plugin_ctx = ctx
	_game_plugin_manager.dispatch_on_before_sequence(ctx)


func _on_plugin_choice_made(_seq_uuid: String, choice_index: int, choice_text: String) -> void:
	if _game_plugin_manager == null:
		return
	var ctx = _build_game_plugin_context()
	_game_plugin_manager.dispatch_on_after_choice(ctx, choice_index, choice_text)


func _on_chapter_loading_started(chapter_name: String) -> void:
	_loading_overlay.move_to_front()
	_loading_overlay.visible = true
	_loading_overlay_label.text = StoryI18nService.get_ui_string("Téléchargement...", _i18n_dict)
	if _pck_loader:
		var download_cb = func(_n: String, progress: float):
			_loading_overlay_label.text = StoryI18nService.get_ui_string("Téléchargement...", _i18n_dict) + " %d%%" % int(progress * 100)
		var mounting_cb = func(_n: String):
			_loading_overlay_label.text = StoryI18nService.get_ui_string("Chargement...", _i18n_dict)
		_pck_loader.chapter_download_progress.connect(download_cb)
		_pck_loader.chapter_mounting_started.connect(mounting_cb)
		set_meta("_loading_download_cb", download_cb)
		set_meta("_loading_mounting_cb", mounting_cb)


func _on_chapter_loading_finished() -> void:
	_loading_overlay.visible = false
	if _pck_loader:
		if has_meta("_loading_download_cb"):
			var cb = get_meta("_loading_download_cb")
			if _pck_loader.chapter_download_progress.is_connected(cb):
				_pck_loader.chapter_download_progress.disconnect(cb)
			remove_meta("_loading_download_cb")
		if has_meta("_loading_mounting_cb"):
			var cb = get_meta("_loading_mounting_cb")
			if _pck_loader.chapter_mounting_started.is_connected(cb):
				_pck_loader.chapter_mounting_started.disconnect(cb)
			remove_meta("_loading_mounting_cb")


func _setup_loading_overlay_image(story) -> void:
	if _loading_overlay_bg == null:
		return
	if story == null or story.menu_background.is_empty():
		_loading_overlay_bg.texture = null
		return
	_loading_overlay_bg.texture = TextureLoader.load_texture(story.menu_background)


func _on_analytics_story_finished(reason: String) -> void:
	if _game_plugin_manager:
		var ctx = _build_game_plugin_context()
		_game_plugin_manager.dispatch_on_story_finished(ctx, reason)


# --- Quicksave / Quickload ---

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			_on_quicksave()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F9:
			_on_quickload()
			get_viewport().set_input_as_handled()


func _can_quicksave() -> bool:
	return _sequence_editor_ctrl.is_playing() and not get_tree().paused


func _on_quicksave() -> void:
	if not _can_quicksave():
		return
	var screenshot: Image = _screenshot_service.capture()
	var state := _collect_game_state()
	var ok := GameSaveManager.quicksave(state, screenshot)
	if ok:
		_update_cached_progression(state)
		_show_toast(StoryI18nService.get_ui_string("Sauvegarde rapide effectuée", _i18n_dict))
		if _game_plugin_manager:
			var ctx = _build_game_plugin_context()
			_game_plugin_manager.dispatch_on_quicksave(ctx, _current_story.title if _current_story else "", state.get("chapter_name", ""))


func _on_quickload() -> void:
	if not _can_quicksave():
		return
	if not GameSaveManager.quicksave_exists():
		_show_toast(StoryI18nService.get_ui_string("Aucune sauvegarde rapide", _i18n_dict))
		return
	_show_quickload_confirm()


func _show_quickload_confirm() -> void:
	get_tree().paused = true
	_quickload_confirm_overlay.visible = true


func _do_quickload() -> void:
	_quickload_confirm_overlay.visible = false
	var save_data := GameSaveManager.quickload()
	if save_data.is_empty():
		get_tree().paused = false
		return
	get_tree().paused = false
	var target_path: String = save_data.get("story_path", "")
	if target_path != _current_story_path and target_path != "":
		TextureLoader.base_dir = target_path
		var story = StorySaver.load_story(target_path)
		if story == null:
			_show_error(StoryI18nService.get_ui_string("Impossible de charger la story sauvegardée.", _i18n_dict))
			return
		_current_story = story
		_current_story_path = target_path
		_setup_loading_overlay_image(_current_story)
		_reload_i18n()
	if _game_plugin_manager:
		var ctx = _build_game_plugin_context()
		_game_plugin_manager.dispatch_on_quickload(ctx, _current_story.title if _current_story else "")
	_play_ctrl.start_from_save(_current_story, save_data, _current_story_path)


func _cancel_quickload() -> void:
	_quickload_confirm_overlay.visible = false
	get_tree().paused = false


# --- Toast ---

func _show_toast(message: String) -> void:
	_toast_label.text = message
	_toast_overlay.visible = true
	_toast_generation += 1
	var gen := _toast_generation
	get_tree().create_timer(3.0).timeout.connect(func():
		if _toast_generation == gen:
			_toast_overlay.visible = false
	)


# --- PWA Install Prompt ---

func _on_pwa_prompt_closed(dont_show_again: bool) -> void:
	if dont_show_again:
		_settings.pwa_prompt_dismissed = true
		_settings.save_settings()


# --- UI Theme ---

func _apply_game_ui_theme(story: RefCounted) -> void:
	if story == null or story.get("ui_theme_mode") != "custom":
		return
	var ui_path = "res://story/assets/ui"
	self.theme = GameTheme.create_theme(ui_path)
	if _main_menu and _main_menu.has_method("update_banner"):
		_main_menu.update_banner(ui_path)
	if _pause_menu and _pause_menu.has_method("apply_custom_theme"):
		_pause_menu.apply_custom_theme(ui_path)
	if _save_load_menu and _save_load_menu.has_method("apply_custom_theme"):
		_save_load_menu.apply_custom_theme(ui_path)
	if _chapter_scene_menu and _chapter_scene_menu.has_method("apply_custom_theme"):
		_chapter_scene_menu.apply_custom_theme(ui_path)
		_settings.save_settings()