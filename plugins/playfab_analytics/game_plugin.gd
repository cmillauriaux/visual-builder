extends "res://src/plugins/game_plugin.gd"

## Plugin d'analytics PlayFab : encapsule le service PlayFab dans un plugin in-game.
## Lit la configuration depuis la story (playfab_title_id, playfab_enabled)
## et envoie les événements de télémétrie aux hooks du jeu.

const PlayFabAnalyticsServiceScript = preload("res://src/services/playfab_analytics_service.gd")
const GameContributions = preload("res://src/plugins/game_contributions.gd")

var _service: Node = null
var _story_title: String = ""
var _story_version: String = ""


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
	var story = ctx.story
	_story_title = story.title if story.get("title") != null else ""
	_story_version = story.version if story.get("version") != null else ""

	var title_id: String = story.playfab_title_id if story.get("playfab_title_id") != null else ""
	var enabled: bool = story.playfab_enabled if story.get("playfab_enabled") != null else false

	if title_id == "" or not enabled:
		return

	_service = Node.new()
	_service.set_script(PlayFabAnalyticsServiceScript)
	_service.name = "PlayFabAnalytics"
	ctx.game_node.add_child(_service)
	_service.configure(title_id, enabled)
	if _service.is_configured():
		_service.login_anonymous()


func on_game_cleanup(ctx: RefCounted) -> void:
	if _service != null and is_instance_valid(_service):
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


## Méthodes publiques pour que game.gd puisse encore appeler track_event
## pour les événements spécifiques (story_started, story_saved, etc.)
func track_event(event_name: String, body: Dictionary = {}) -> void:
	if _service != null and _service.is_active():
		_service.track_event(event_name, body)


func flush() -> void:
	if _service != null:
		_service.flush()


func get_options_controls() -> Array:
	var def := GameContributions.GameOptionsControlDef.new()
	def.create_control = _create_options_control
	return [def]


func _create_options_control(_settings: RefCounted) -> Control:
	var hbox := HBoxContainer.new()
	var label := Label.new()
	label.text = "PlayFab Analytics"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	var status := Label.new()
	if _service != null and _service.is_active():
		status.text = "Actif"
		status.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	elif _service != null and _service.is_configured():
		status.text = "Connexion..."
		status.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))
	else:
		status.text = "Inactif"
		status.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hbox.add_child(status)
	return hbox


func get_service() -> Node:
	return _service
