extends RefCounted

## Service gérant l'exécution de l'exportation des histoires vers des jeux standalone.
## Encapsule l'appel au script shell et l'analyse des logs d'erreur.

class_name ExportService

## Résultat d'une tentative d'exportation.
class ExportResult:
	var success: bool = false
	var output_path: String = ""
	var log_path: String = ""
	var error_message: String = ""

	func _init(p_success: bool, p_output_path: String, p_log_path: String, p_error: String = "") -> void:
		success = p_success
		output_path = p_output_path
		log_path = p_log_path
		error_message = p_error


## Exécute l'exportation pour une story donnée.
func export_story(story: RefCounted, platform: String, output_path: String, story_path: String) -> ExportResult:
	if story == null:
		return ExportResult.new(false, output_path, "", "Aucune histoire chargée.")

	var godot_bin = _find_godot()
	if godot_bin == "":
		return ExportResult.new(false, output_path, "", "Binaire Godot introuvable. Veuillez définir GODOT_PATH dans .env.")

	var game_name = story.menu_title if story.menu_title != "" else story.title
	if story_path == "":
		return ExportResult.new(false, output_path, "", "Veuillez sauvegarder l'histoire avant de l'exporter.")

	# Préparer le dossier de sortie
	var abs_output_path = ProjectSettings.globalize_path(output_path)
	if not DirAccess.dir_exists_absolute(abs_output_path):
		DirAccess.make_dir_recursive_absolute(abs_output_path)
	
	var log_path = abs_output_path + "/export.log"
	var log_file = FileAccess.open(log_path, FileAccess.WRITE)
	if log_file:
		log_file.store_line("=========================================")
		log_file.store_line("  Export story — " + Time.get_datetime_string_from_system())
		log_file.store_line("=========================================")
		log_file.store_line("→ Godot : " + godot_bin)
		log_file.store_line("→ Plateforme : " + platform)
		log_file.store_line("→ Story : " + story_path)
		log_file.close()

	# 1. Créer le dossier temporaire
	var temp_base = "user://temp_export_" + str(Time.get_ticks_msec())
	var abs_temp_base = ProjectSettings.globalize_path(temp_base)
	var abs_temp_project = abs_temp_base + "/project"
	
	DirAccess.make_dir_recursive_absolute(abs_temp_project)
	
	# 2. Copier le projet (sans .godot, .git, build, .claude, specs)
	var project_root = ProjectSettings.globalize_path("res://")
	var excludes = [".godot", ".git", "build", ".claude", "specs", "addons/gut", "stories"]
	_copy_dir_recursive(project_root, abs_temp_project, excludes)
	
	# 3. Copier la story dans res://story/
	var abs_story_dir = ProjectSettings.globalize_path(story_path)
	var abs_temp_story = abs_temp_project + "/story"
	DirAccess.make_dir_recursive_absolute(abs_temp_story)
	_copy_dir_recursive(abs_story_dir, abs_temp_story)
	
	# 4. Réécrire les chemins images (via le script existant, mais appelé localement si possible)
	# Comme on est dans Godot, on peut utiliser StoryPathRewriter directement
	# mais il faut le faire sur les fichiers copiés dans le dossier temporaire.
	# Le StoryPathRewriter attend des chemins res://, mais il travaille sur le système de fichiers.
	# En fait, il est plus simple de le lancer en headless sur le projet temporaire pour éviter les conflits res://.
	var rewrite_args = ["--path", abs_temp_project, "--headless", "--script", "res://src/export/rewrite_runner.gd", "--", "--story-folder", "res://story", "--new-base", "res://story"]
	OS.execute(godot_bin, rewrite_args)

	# 5. Configurer project.godot
	var project_godot_path = abs_temp_project + "/project.godot"
	var project_content = FileAccess.get_file_as_string(project_godot_path)
	project_content = project_content.replace('run/main_scene="res://src/main.tscn"', 'run/main_scene="res://src/game.tscn"')
	project_content = project_content.replace('config/name="' + _get_config_project_name() + '"', 'config/name="' + game_name + '"')
	
	# Désactiver les plugins
	if project_content.find("[editor_plugins]") != -1:
		var lines = project_content.split("\n")
		var new_lines = []
		var in_plugins = false
		for line in lines:
			if line.begins_with("[editor_plugins]"):
				in_plugins = true
				continue
			if in_plugins and line.strip_edges() == "":
				in_plugins = false
				continue
			if not in_plugins:
				new_lines.append(line)
		project_content = "\n".join(new_lines)
	
	# Rendering settings according to platform
	if project_content.find("[rendering]") == -1:
		project_content += "\n[rendering]\n"
	
	if platform == "macos" or platform == "android":
		if project_content.find("textures/vram_compression/import_etc2_astc") != -1:
			# Regex-like replace would be better, but simple replace might work if format is exact
			project_content = project_content.replace("textures/vram_compression/import_etc2_astc=false", "textures/vram_compression/import_etc2_astc=true")
		else:
			project_content = project_content.replace("[rendering]", "[rendering]\ntextures/vram_compression/import_etc2_astc=true")
	elif platform == "linux" or platform == "windows":
		if project_content.find("textures/vram_compression/import_s3tc_bptc") != -1:
			project_content = project_content.replace("textures/vram_compression/import_s3tc_bptc=false", "textures/vram_compression/import_s3tc_bptc=true")
		else:
			project_content = project_content.replace("[rendering]", "[rendering]\ntextures/vram_compression/import_s3tc_bptc=true")
			
	var f_pg = FileAccess.open(project_godot_path, FileAccess.WRITE)
	if f_pg:
		f_pg.store_string(project_content)
		f_pg.close()

	# 6. Configurer game.tscn pour story_path
	var game_tscn_path = abs_temp_project + "/src/game.tscn"
	if FileAccess.file_exists(game_tscn_path):
		var game_content = FileAccess.get_file_as_string(game_tscn_path)
		if game_content.find('story_path = ""') != -1:
			game_content = game_content.replace('story_path = ""', 'story_path = "res://story"')
		else:
			# Si la variable n'existe pas (cas où elle n'est pas dans le .tscn car par défaut), 
			# on l'ajoute dans la section du noeud racine "Game"
			var game_node_pos = game_content.find('[node name="Game"')
			if game_node_pos != -1:
				var end_header = game_content.find("]", game_node_pos)
				if end_header != -1:
					game_content = game_content.insert(end_header + 1, '\nstory_path = "res://story"')
		
		var f_gt = FileAccess.open(game_tscn_path, FileAccess.WRITE)
		if f_gt:
			f_gt.store_string(game_content)
			f_gt.close()

	# 7. Copier le preset et forcer l'inclusion des fichiers .yaml
	var preset_name = _get_preset_name(platform)
	var preset_src = ProjectSettings.globalize_path("res://scripts/export_presets/" + platform + ".cfg")
	var preset_dst = abs_temp_project + "/export_presets.cfg"
	if FileAccess.file_exists(preset_src):
		var preset_content = FileAccess.get_file_as_string(preset_src)
		# On cherche la ligne include_filter pour ajouter *.yaml
		if preset_content.find("include_filter=\"") != -1:
			# Si include_filter existe déjà, on ajoute *.yaml (en évitant les doublons)
			if preset_content.find("*.yaml") == -1:
				preset_content = preset_content.replace("include_filter=\"", "include_filter=\"*.yaml,")
		else:
			# Sinon on l'ajoute dans la section du preset (on suppose qu'elle commence par [preset.0])
			preset_content = preset_content.replace("[preset.0]", "[preset.0]\ninclude_filter=\"*.yaml\"")

		var f_preset = FileAccess.open(preset_dst, FileAccess.WRITE)
		if f_preset:
			f_preset.store_string(preset_content)
			f_preset.close()


	# 8. Préparer le fichier de sortie
	var export_ext = _get_export_extension(platform)
	var safe_name = game_name.validate_filename().replace(" ", "_")
	var export_file = ""
	
	if platform == "web":
		var web_dir = abs_output_path + "/" + safe_name + "_web"
		if not DirAccess.dir_exists_absolute(web_dir):
			DirAccess.make_dir_recursive_absolute(web_dir)
		export_file = web_dir + "/index.html"
	else:
		export_file = abs_output_path + "/" + safe_name + "." + export_ext

	# 9. Import & Export
	var output = []
	# Import d'abord (nécessaire pour générer .godot/)
	OS.execute(godot_bin, ["--path", abs_temp_project, "--headless", "--import"], output, true)
	
	# Export release
	var export_args = ["--path", abs_temp_project, "--headless", "--export-release", preset_name, export_file]
	var exit_code = OS.execute(godot_bin, export_args, output, true)
	
	# Écrire l'output de Godot dans le log
	var f_log = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f_log:
		f_log.seek_end()
		for line in output:
			f_log.store_string(line)
		f_log.close()

	# 10. Nettoyage
	_remove_dir_recursive(abs_temp_base)
	
	if exit_code == 0 and FileAccess.file_exists(export_file):
		return ExportResult.new(true, abs_output_path, log_path)
	else:
		var error_reason = extract_export_error(log_path)
		return ExportResult.new(false, abs_output_path, log_path, error_reason)


func _find_godot() -> String:
	# 1. Vérifier .env (lecture manuelle simple)
	var env_path = ProjectSettings.globalize_path("res://.env")
	if FileAccess.file_exists(env_path):
		var f = FileAccess.open(env_path, FileAccess.READ)
		while not f.eof_reached():
			var line = f.get_line().strip_edges()
			if line.begins_with("GODOT_PATH="):
				var path = line.split("=")[1].strip_edges()
				if FileAccess.file_exists(path):
					return path
		f.close()
	
	# 2. Variable d'environnement
	var env_godot = OS.get_environment("GODOT_PATH")
	if env_godot != "" and FileAccess.file_exists(env_godot):
		return env_godot
		
	# 3. PATH (essai direct)
	var test_output = []
	var test_exit = OS.execute("godot", ["--version"], test_output)
	if test_exit == 0:
		return "godot"
		
	# 4. Chemins par défaut
	var defaults = []
	if OS.get_name() == "macOS":
		defaults.append("/Applications/Godot.app/Contents/MacOS/Godot")
	elif OS.get_name() == "Windows":
		# On pourrait en ajouter d'autres ici
		pass
		
	for d in defaults:
		if FileAccess.file_exists(d):
			return d
			
	return ""


func _copy_dir_recursive(from: String, to: String, exclude: Array = []) -> void:
	var dir = DirAccess.open(from)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name == "." or file_name == "..":
				file_name = dir.get_next()
				continue
				
			var skip = false
			for ex in exclude:
				if file_name == ex:
					skip = true
					break
			if skip:
				file_name = dir.get_next()
				continue
				
			var from_path = from + "/" + file_name
			var to_path = to + "/" + file_name
			
			if dir.current_is_dir():
				if not DirAccess.dir_exists_absolute(to_path):
					DirAccess.make_dir_recursive_absolute(to_path)
				_copy_dir_recursive(from_path, to_path, [])
			else:
				DirAccess.copy_absolute(from_path, to_path)
			file_name = dir.get_next()


func _remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name == "." or file_name == "..":
				file_name = dir.get_next()
				continue
			
			var full_path = path + "/" + file_name
			if dir.current_is_dir():
				_remove_dir_recursive(full_path)
			else:
				DirAccess.remove_absolute(full_path)
			file_name = dir.get_next()
		DirAccess.remove_absolute(path)


func _get_config_project_name() -> String:
	return ProjectSettings.get_setting("application/config/name")


func _get_export_extension(platform: String) -> String:
	match platform:
		"web": return "html"
		"macos": return "zip"
		"linux": return "x86_64"
		"windows": return "exe"
		"android": return "apk"
	return "bin"


func _get_preset_name(platform: String) -> String:
	match platform:
		"web": return "Web"
		"macos": return "macOS"
		"linux": return "Linux"
		"windows": return "Windows"
		"android": return "Android"
	return ""


## Analyse le fichier de log pour en extraire la raison précise de l'échec.
func extract_export_error(log_path: String) -> String:
	var file = FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		return "L'export a échoué (log introuvable)."
	
	var content = file.get_as_text()
	file.close()
	
	var lines = content.split("
")
	var reasons := []
	var capture_next := false
	
	for line in lines:
		var stripped = line.strip_edges()
		# Nettoyage des codes ANSI (couleurs terminal)
		var clean = _strip_ansi_codes(stripped)
		
		if clean.find("due to configuration errors:") >= 0:
			capture_next = true
			continue
			
		if capture_next:
			if clean == "" or clean.begins_with("at:"):
				capture_next = false
			else:
				reasons.append(clean)
			continue
			
		if clean.find("ERREUR:") >= 0 and clean.find("due to configuration") < 0 and clean.find("Project export") < 0:
			var msg = clean.replace("ERROR:", "").replace("ERREUR:", "").strip_edges()
			if msg != "" and not msg.begins_with("at:"):
				reasons.append(msg)
				
	if reasons.is_empty():
		return "L'export a échoué."
		
	return "
".join(reasons)


func _strip_ansi_codes(text: String) -> String:
	var clean = text
	while clean.find("\u001b[") >= 0:
		var start = clean.find("\u001b[")
		var end = clean.find("m", start)
		if end >= 0:
			clean = clean.substr(0, start) + clean.substr(end + 1)
		else:
			break
	return clean
