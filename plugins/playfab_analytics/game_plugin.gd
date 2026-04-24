extends "res://src/plugins/game_plugin.gd"

## Plugin d'analytics PlayFab : encapsule le service PlayFab dans un plugin in-game.
## Lit la configuration depuis story.plugin_settings["playfab_analytics"]
## et envoie les événements de télémétrie aux hooks du jeu.

const PlayFabAnalyticsServiceScript = preload("res://plugins/playfab_analytics/playfab_analytics_service.gd")
const GameContributions = preload("res://src/plugins/game_contributions.gd")

var _service: Node = null
var _story_title: String = ""
var _story_version: String = ""
var _game_ctx: RefCounted = null


func get_plugin_name() -> String:
	return "playfab_analytics"


func get_plugin_description() -> String:
	return "Envoie les événements de jeu à PlayFab Analytics"


## Ce plugin n'est pas configurable par l'utilisateur — il est actif si la story le configure.
func is_configurable() -> bool:
	return false


func on_game_ready(ctx: RefCounted) -> void:
	if ctx == null or ctx.story == null or ctx.game_node == null:
		return
	_game_ctx = ctx
	var story = ctx.story
	_story_title = story.title if story.get("title") != null else ""
	_story_version = story.version if story.get("version") != null else ""

	if ctx.settings != null and ctx.settings.analytics_enabled:
		_setup_service()


func _setup_service() -> void:
	if _service != null or _game_ctx == null:
		return
	
	var ps: Dictionary = _get_plugin_config(_game_ctx.story)
	var title_id: String = ps.get("title_id", "")
	var enabled: bool = ps.get("enabled", false)

	if title_id == "" or not enabled:
		return

	_service = Node.new()
	_service.set_script(PlayFabAnalyticsServiceScript)
	_service.name = "PlayFabAnalytics"
	_game_ctx.game_node.add_child(_service)
	_service.configure(title_id, enabled)
	if _service.is_configured():
		_service.login_anonymous()


func on_game_cleanup(ctx: RefCounted) -> void:
	if _service != null and is_instance_valid(_service):
		_service.flush()
		_service.queue_free()
		_service = null


func on_settings_applied(ctx: RefCounted) -> void:
	_game_ctx = ctx
	if ctx.settings == null:
		return
		
	if ctx.settings.analytics_enabled:
		if _service == null:
			_setup_service()
	else:
		if _service != null:
			_service.flush()
			_service.queue_free()
			_service = null


func on_before_chapter(ctx: RefCounted) -> void:
	if _service == null or not _service.is_active():
		return
	var chapter = ctx.current_chapter if ctx != null else null
	_service.track_event("chapter_entered", {
		"chapter_name": chapter.chapter_name if chapter else "",
		"chapter_uuid": chapter.uuid if chapter else "",
	})


func on_before_scene(ctx: RefCounted) -> void:
	if _service == null or not _service.is_active():
		return
	var scene = ctx.current_scene if ctx != null else null
	_service.track_event("scene_entered", {
		"scene_name": scene.scene_name if scene else "",
		"scene_uuid": scene.uuid if scene else "",
	})


func on_before_sequence(ctx: RefCounted) -> void:
	if _service == null or not _service.is_active():
		return
	var seq = ctx.current_sequence if ctx != null else null
	_service.track_event("sequence_entered", {
		"sequence_name": seq.seq_name if seq else "",
		"sequence_uuid": seq.uuid if seq else "",
	})


func on_after_choice(ctx: RefCounted, choice_index: int, choice_text: String) -> void:
	if _service == null or not _service.is_active():
		return
	var seq = ctx.current_sequence if ctx != null else null
	_service.track_event("choice_made", {
		"sequence_uuid": seq.uuid if seq else "",
		"choice_index": choice_index,
		"choice_text": choice_text,
	})


func on_story_started(_ctx: RefCounted, story_title: String, story_version: String) -> void:
	if _service == null or not _service.is_active():
		return
	_service.track_event("story_started", {
		"story_title": story_title,
		"story_version": story_version,
	})


func on_story_finished(_ctx: RefCounted, reason: String) -> void:
	if _service == null or not _service.is_active():
		return
	_service.track_event("story_finished", {"reason": reason})
	_service.flush()


func on_story_saved(_ctx: RefCounted, story_title: String, slot_index: int, chapter: String, scene: String, sequence: String) -> void:
	if _service == null or not _service.is_active():
		return
	_service.track_event("story_saved", {
		"story_title": story_title,
		"slot_index": slot_index,
		"chapter": chapter,
		"scene": scene,
		"sequence": sequence,
	})


func on_story_loaded(_ctx: RefCounted, story_title: String, slot_index: int) -> void:
	if _service == null or not _service.is_active():
		return
	_service.track_event("story_loaded", {
		"story_title": story_title,
		"slot_index": slot_index,
	})


func on_game_quit(_ctx: RefCounted, chapter: String, scene: String, sequence: String) -> void:
	if _service == null or not _service.is_active():
		return
	_service.track_event("game_quit", {
		"chapter": chapter,
		"scene": scene,
		"sequence": sequence,
	})
	_service.flush()


func on_quicksave(_ctx: RefCounted, story_title: String, chapter: String) -> void:
	if _service == null or not _service.is_active():
		return
	_service.track_event("quicksave", {
		"story_title": story_title,
		"chapter": chapter,
	})


func on_quickload(_ctx: RefCounted, story_title: String) -> void:
	if _service == null or not _service.is_active():
		return
	_service.track_event("quickload", {
		"story_title": story_title,
	})


func on_main_menu_displayed(_ctx: RefCounted, platform: String, app_version: String, story_version: String) -> void:
	if _service == null or not _service.is_active():
		return
	_service.track_event("main_menu_displayed", {
		"platform": platform,
		"app_version": app_version,
		"story_version": story_version,
		"story_title": _story_title,
	})


func on_game_event(_ctx: RefCounted, event_name: String, data: Dictionary) -> void:
	if _service == null or not _service.is_active():
		return
	# Si l'événement est un changement d'options, on vérifie si l'utilisateur a désactivé les stats
	if event_name == "options_changed":
		var ctx_settings = _ctx.get("settings") if _ctx != null else null
		if ctx_settings != null and not ctx_settings.get("analytics_enabled", true):
			_service.flush()
			_service.queue_free()
			_service = null
			return
	_service.track_event(event_name, data)


func get_options_controls() -> Array:
	var def := GameContributions.GameOptionsControlDef.new()
	def.create_control = _create_options_control
	return [def]


func _create_options_control(settings: RefCounted) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title_label := Label.new()
	title_label.text = "PlayFab Analytics"
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)

	var check := CheckButton.new()
	check.text = "Envoyer des statistiques anonymes"
	check.button_pressed = settings.analytics_enabled if settings != null else true
	vbox.add_child(check)

	check.toggled.connect(func(pressed: bool):
		if settings != null:
			settings.analytics_enabled = pressed
			settings.save_settings()
		
		if pressed:
			_setup_service()
		else:
			if _service != null:
				_service.flush()
				_service.queue_free()
				_service = null
	)

	return vbox


## Configuration éditeur : champs Title ID et Enabled pour PlayFab.
func get_editor_config_controls() -> Array:
	var def := GameContributions.GameOptionsControlDef.new()
	def.create_control = _create_editor_config
	return [def]


func _create_editor_config(current_settings) -> Control:
	var ps: Dictionary = {}
	if current_settings is Dictionary:
		ps = current_settings

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var title_lbl := Label.new()
	title_lbl.text = "Title ID"
	vbox.add_child(title_lbl)

	var title_edit := LineEdit.new()
	title_edit.name = "PlayFabTitleIdEdit"
	title_edit.placeholder_text = "Laisser vide pour désactiver"
	title_edit.text = ps.get("title_id", "")
	vbox.add_child(title_edit)

	var enabled_check := CheckButton.new()
	enabled_check.name = "PlayFabEnabledCheck"
	enabled_check.text = "Activer le tracking PlayFab"
	enabled_check.button_pressed = ps.get("enabled", false)
	vbox.add_child(enabled_check)

	# Stocker les références pour la lecture via get_editor_config_values()
	vbox.set_meta("_title_edit", title_edit)
	vbox.set_meta("_enabled_check", enabled_check)

	return vbox


## Lit les valeurs actuelles des contrôles éditeur et retourne un Dictionary.
func read_editor_config(control: Control) -> Dictionary:
	if control == null:
		return {}
	var title_edit = control.get_meta("_title_edit", null)
	var enabled_check = control.get_meta("_enabled_check", null)
	return {
		"title_id": title_edit.text if title_edit else "",
		"enabled": enabled_check.button_pressed if enabled_check else false,
	}


func get_service() -> Node:
	return _service


## Extrait la config du plugin depuis la story.
static func _get_plugin_config(story: RefCounted) -> Dictionary:
	if story == null:
		return {}
	if story.get("plugin_settings") != null and story.plugin_settings.has("playfab_analytics"):
		return story.plugin_settings["playfab_analytics"]
	return {}
