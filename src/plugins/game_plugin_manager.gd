# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Node

## Gestionnaire des plugins in-game.
## Scanne, charge, et dispatche les événements aux plugins actifs.

const GamePluginContextScript = preload("res://src/plugins/game_plugin_context.gd")
const GameContributions = preload("res://src/plugins/game_contributions.gd")

## Liste des instances VBGamePlugin chargées
var _plugins: Array = []

## État activé/désactivé par nom de plugin
var _enabled_states: Dictionary = {}


## Enregistre un plugin déjà instancié.
func register_plugin(plugin: RefCounted) -> void:
	_plugins.append(plugin)
	var pname: String = plugin.get_plugin_name()
	# Par défaut, un plugin est activé
	if not _enabled_states.has(pname):
		_enabled_states[pname] = true


## Retourne le nombre de plugins enregistrés.
func get_plugin_count() -> int:
	return _plugins.size()


## Retourne true si le plugin est activé.
func is_plugin_enabled(plugin_name: String) -> bool:
	return _enabled_states.get(plugin_name, true)


## Active ou désactive un plugin.
func set_plugin_enabled(plugin_name: String, enabled: bool) -> void:
	_enabled_states[plugin_name] = enabled


## Retourne les plugins configurables (avec is_configurable() == true).
func get_configurable_plugins() -> Array:
	var result: Array = []
	for plugin in _plugins:
		if plugin.is_configurable():
			result.append(plugin)
	return result


## Retourne tous les plugins enregistrés.
func get_plugins() -> Array:
	return _plugins


## Charge les états activés depuis les settings.
func load_enabled_states(settings: RefCounted) -> void:
	if settings == null:
		return
	if settings.get("game_plugins_enabled") != null:
		_enabled_states = settings.game_plugins_enabled.duplicate()


## Sauvegarde les états activés dans les settings.
func save_enabled_states(settings: RefCounted) -> void:
	if settings == null:
		return
	settings.game_plugins_enabled = _enabled_states.duplicate()


## Chemin du registre de plugins (généré par l'export service).
const PLUGIN_REGISTRY_PATH = "res://plugins/_registry.json"


## Scanne les répertoires pour trouver et charger les plugins in-game.
## Si le scan DirAccess échoue (exports PCK), charge depuis le registre.
func scan_and_load_plugins(dirs: Array = ["res://plugins/", "res://game_plugins/"]) -> void:
	var found_paths: Array = []
	for dir_path in dirs:
		found_paths.append_array(_scan_directory(dir_path))

	print("[GamePluginManager] scan found: ", found_paths.size(), " paths via DirAccess")
	if found_paths.is_empty():
		# Fallback : charger depuis le registre (exports PCK)
		found_paths = _load_registry()
		print("[GamePluginManager] registry fallback: ", found_paths.size(), " paths: ", found_paths)

	for path in found_paths:
		_try_load_plugin(path)
	print("[GamePluginManager] total plugins loaded: ", _plugins.size())


## Scanne un répertoire et retourne les chemins des plugins trouvés.
func _scan_directory(plugins_dir: String) -> Array:
	var paths: Array = []
	var dir := DirAccess.open(plugins_dir)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var path := "%s%s/game_plugin.gd" % [plugins_dir, entry]
			if ResourceLoader.exists(path):
				paths.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return paths


func _try_load_plugin(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var loaded = load(path)
	if loaded == null:
		push_warning("GamePluginManager: failed to load %s" % path)
		return
	var instance = loaded.new()
	var pname: String = ""
	if instance.has_method("get_plugin_name"):
		pname = instance.get_plugin_name()
	if pname == "":
		push_warning("GamePluginManager: plugin at %s returned empty name, skipping" % path)
		return
	# Éviter les doublons
	for existing in _plugins:
		if existing.get_plugin_name() == pname:
			return
	register_plugin(instance)


## Charge la liste des chemins de plugins depuis le registre JSON.
func _load_registry() -> Array:
	if not FileAccess.file_exists(PLUGIN_REGISTRY_PATH):
		return []
	var file := FileAccess.open(PLUGIN_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return []
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed is Array:
		return parsed
	return []


## Retourne les plugins actifs (actifs = enregistrés + activés).
func _get_active_plugins() -> Array:
	var result: Array = []
	for plugin in _plugins:
		var pname: String = plugin.get_plugin_name()
		if is_plugin_enabled(pname):
			result.append(plugin)
	return result


# --- Dispatch hooks événementiels ---

func dispatch_on_game_ready(ctx: RefCounted) -> void:
	for plugin in _get_active_plugins():
		await plugin.on_game_ready(ctx)


func dispatch_on_game_cleanup(ctx: RefCounted) -> void:
	for plugin in _get_active_plugins():
		plugin.on_game_cleanup(ctx)


func dispatch_on_before_chapter(ctx: RefCounted) -> void:
	for plugin in _get_active_plugins():
		plugin.on_before_chapter(ctx)


func dispatch_on_after_chapter(ctx: RefCounted) -> void:
	for plugin in _get_active_plugins():
		plugin.on_after_chapter(ctx)


func dispatch_on_before_scene(ctx: RefCounted) -> void:
	for plugin in _get_active_plugins():
		plugin.on_before_scene(ctx)


func dispatch_on_after_scene(ctx: RefCounted) -> void:
	for plugin in _get_active_plugins():
		plugin.on_after_scene(ctx)


func dispatch_on_before_sequence(ctx: RefCounted) -> void:
	for plugin in _get_active_plugins():
		plugin.on_before_sequence(ctx)


func dispatch_on_after_sequence(ctx: RefCounted) -> void:
	for plugin in _get_active_plugins():
		plugin.on_after_sequence(ctx)


# --- Pipeline de transformation ---

## Pipeline dialogue : chaîne les on_before_dialogue de chaque plugin actif.
func pipeline_before_dialogue(ctx: RefCounted, character: String, text: String) -> Dictionary:
	var result := {"character": character, "text": text}
	for plugin in _get_active_plugins():
		result = plugin.on_before_dialogue(ctx, result["character"], result["text"])
	return result


## Dispatch on_after_dialogue à tous les plugins actifs.
func dispatch_on_after_dialogue(ctx: RefCounted, character: String, text: String) -> void:
	for plugin in _get_active_plugins():
		plugin.on_after_dialogue(ctx, character, text)


## Pipeline choix : chaîne les on_before_choice de chaque plugin actif.
func pipeline_before_choice(ctx: RefCounted, choices: Array) -> Array:
	var result := choices
	for plugin in _get_active_plugins():
		result = plugin.on_before_choice(ctx, result)
	return result


## Dispatch on_after_choice à tous les plugins actifs.
func dispatch_on_after_choice(ctx: RefCounted, choice_index: int, choice_text: String) -> void:
	for plugin in _get_active_plugins():
		plugin.on_after_choice(ctx, choice_index, choice_text)


## Pipeline style : appelle on_style_choice_button sur chaque plugin actif pour un bouton donné.
func pipeline_style_choice_button(ctx: RefCounted, btn: Button, choice: RefCounted, index: int) -> void:
	for plugin in _get_active_plugins():
		plugin.on_style_choice_button(ctx, btn, choice, index)


# --- Dispatch hooks cycle de vie de la story ---

func dispatch_on_story_started(ctx: RefCounted, story_title: String, story_version: String) -> void:
	for plugin in _get_active_plugins():
		plugin.on_story_started(ctx, story_title, story_version)


func dispatch_on_story_finished(ctx: RefCounted, reason: String) -> void:
	for plugin in _get_active_plugins():
		plugin.on_story_finished(ctx, reason)


func dispatch_on_story_saved(ctx: RefCounted, story_title: String, slot_index: int, chapter: String, scene: String, sequence: String) -> void:
	for plugin in _get_active_plugins():
		plugin.on_story_saved(ctx, story_title, slot_index, chapter, scene, sequence)


func dispatch_on_story_loaded(ctx: RefCounted, story_title: String, slot_index: int) -> void:
	for plugin in _get_active_plugins():
		plugin.on_story_loaded(ctx, story_title, slot_index)


func dispatch_on_game_quit(ctx: RefCounted, chapter: String, scene: String, sequence: String) -> void:
	for plugin in _get_active_plugins():
		plugin.on_game_quit(ctx, chapter, scene, sequence)


func dispatch_on_quicksave(ctx: RefCounted, story_title: String, chapter: String) -> void:
	for plugin in _get_active_plugins():
		plugin.on_quicksave(ctx, story_title, chapter)


func dispatch_on_quickload(ctx: RefCounted, story_title: String) -> void:
	for plugin in _get_active_plugins():
		plugin.on_quickload(ctx, story_title)


# --- UI injection ---

## Injecte les boutons toolbar des plugins actifs dans le container.
func inject_toolbar_buttons(container: HBoxContainer, ctx: RefCounted) -> void:
	if container == null:
		return
	# Clear existing plugin buttons
	for child in container.get_children():
		child.queue_free()
	for plugin in _get_active_plugins():
		for item in plugin.get_toolbar_buttons():
			var btn := Button.new()
			btn.text = item.label
			if item.icon != null:
				btn.icon = item.icon
			var cb: Callable = item.callback
			btn.pressed.connect(func(): cb.call(ctx))
			container.add_child(btn)
	container.visible = container.get_child_count() > 0


## Injecte les panneaux overlay des plugins actifs.
func inject_overlay_panels(left: Control, right: Control, top: Control, ctx: RefCounted) -> void:
	_clear_container(left)
	_clear_container(right)
	_clear_container(top)
	for plugin in _get_active_plugins():
		for def in plugin.get_overlay_panels():
			var target: Control = null
			match def.position:
				"left":
					target = left
				"right":
					target = right
				"top":
					target = top
			if target == null:
				push_warning("GamePluginManager: unknown overlay position '%s'" % def.position)
				continue
			var panel: Control = def.create_panel.call(ctx)
			if panel != null:
				target.add_child(panel)
				target.visible = true


## Injecte les contrôles des plugins dans la section Options.
func inject_options_controls(container: VBoxContainer, settings: RefCounted) -> void:
	if container == null:
		return
	# Clear existing
	for child in container.get_children():
		child.queue_free()

	for plugin in _plugins:
		var pname: String = plugin.get_plugin_name()

		# Toggle activé/désactivé pour les plugins configurables
		if plugin.is_configurable():
			var hbox := HBoxContainer.new()
			var label := Label.new()
			label.text = plugin.get_plugin_description() if plugin.get_plugin_description() != "" else pname
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(label)
			var check := CheckButton.new()
			check.button_pressed = is_plugin_enabled(pname)
			check.toggled.connect(func(enabled):
				set_plugin_enabled(pname, enabled)
				save_enabled_states(settings)
				if settings and settings.has_method("save_settings"):
					settings.save_settings()
			)
			hbox.add_child(check)
			container.add_child(hbox)

		# Contrôles personnalisés du plugin (si actif)
		if is_plugin_enabled(pname):
			for def in plugin.get_options_controls():
				var ctrl: Control = def.create_control.call(settings)
				if ctrl != null:
					container.add_child(ctrl)

	container.visible = container.get_child_count() > 0


func _clear_container(container: Control) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	container.visible = false