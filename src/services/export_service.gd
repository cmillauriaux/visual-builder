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
	
	# 3. Copier la story dans res://story/ (sans artbook pour éviter les doublons)
	var abs_story_dir = ProjectSettings.globalize_path(story_path)
	var abs_temp_story = abs_temp_project + "/story"
	DirAccess.make_dir_recursive_absolute(abs_temp_story)
	_copy_dir_recursive(abs_story_dir, abs_temp_story, ["artbook"])
	
	# 3b. Optimiser les fichiers audio pour le web (si ffmpeg est disponible)
	if platform == "web":
		_optimize_audio_files(abs_temp_story, log_path)

	# 3c. Copier le menu_background comme boot splash si défini
	var boot_splash_res_path := ""
	if story.menu_background != "":
		var bg_abs_src = abs_story_dir + "/" + story.menu_background
		if FileAccess.file_exists(bg_abs_src):
			var bg_ext = story.menu_background.get_extension().to_lower()
			if bg_ext != "png":
				_remove_dir_recursive(abs_temp_base)
				return ExportResult.new(false, abs_output_path, log_path,
					"Le boot splash nécessite une image PNG.\nL'image de fond du menu (%s) est au format .%s.\nConvertissez-la en PNG avant d'exporter." % [story.menu_background, bg_ext])
			var bg_abs_dst = abs_temp_project + "/boot_splash.png"
			DirAccess.copy_absolute(bg_abs_src, bg_abs_dst)
			boot_splash_res_path = "res://boot_splash.png"

	# 3d. Générer les icônes d'application à partir de app_icon
	if story.get("app_icon") != null and story.app_icon != "":
		var icon_src = story.app_icon
		if not FileAccess.file_exists(icon_src):
			icon_src = abs_story_dir + "/" + story.app_icon
		if FileAccess.file_exists(icon_src):
			_generate_app_icons(icon_src, abs_temp_project, log_path)
		else:
			_append_log(log_path, "⚠ Icône introuvable : " + story.app_icon)

	# 4. Réécrire les chemins images (via le script existant, mais appelé localement si possible)
	# Comme on est dans Godot, on peut utiliser StoryPathRewriter directement
	# mais il faut le faire sur les fichiers copiés dans le dossier temporaire.
	# Le StoryPathRewriter attend des chemins res://, mais il travaille sur le système de fichiers.
	# En fait, il est plus simple de le lancer en headless sur le projet temporaire pour éviter les conflits res://.
	var rewrite_args = ["--path", abs_temp_project, "--headless", "--script", "res://src/export/rewrite_runner.gd", "--", "--story-folder", "res://story", "--new-base", "res://story"]
	OS.execute(godot_bin, rewrite_args)

	# 5. Configurer project.godot et override.cfg
	var project_godot_path = abs_temp_project + "/project.godot"
	var project_content = FileAccess.get_file_as_string(project_godot_path)
	project_content = project_content.replace('run/main_scene="res://src/main.tscn"', 'run/main_scene="res://src/game.tscn"')
	project_content = project_content.replace('config/name="' + _get_config_project_name() + '"', 'config/name="' + game_name + '"')

	# Ajouter une propriété personnalisée pour le chemin de la story
	if project_content.find("[application]") == -1:
		project_content += "\n[application]\n"
	project_content = project_content.replace("[application]", "[application]\nconfig/story_path=\"res://story\"")

	# Boot splash : utiliser le menu_background de la story
	if boot_splash_res_path != "":
		project_content = project_content.replace("[application]", "[application]\nboot_splash/image=\"" + boot_splash_res_path + "\"\nboot_splash/bg_color=Color(0, 0, 0, 1)\nboot_splash/fullsize=true\nboot_splash/show_image=true")

	# Icône du projet : utiliser l'app_icon générée si disponible
	if FileAccess.file_exists(abs_temp_project + "/app_icon.png"):
		var icon_lines = project_content.split("\n")
		var icon_new_lines = []
		for line in icon_lines:
			if line.strip_edges().begins_with("config/icon="):
				icon_new_lines.append('config/icon="res://app_icon.png"')
			else:
				icon_new_lines.append(line)
		project_content = "\n".join(icon_new_lines)
		if project_content.find("config/icon=") == -1:
			project_content = project_content.replace("[application]", '[application]\nconfig/icon="res://app_icon.png"')

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

	# Créer override.cfg pour forcer les paramètres à l'exécution
	var override_path = abs_temp_project + "/override.cfg"
	var f_ov = FileAccess.open(override_path, FileAccess.WRITE)
	if f_ov:
		f_ov.store_line("[application]")
		f_ov.store_line("config/story_path=\"res://story\"")
		f_ov.close()

	# 6. (Anciennement modification de game.tscn, maintenant inutile avec override.cfg)

	# 7. Copier le preset et forcer l'inclusion des fichiers .yaml
	var preset_name = _get_preset_name(platform)
	var preset_src = ProjectSettings.globalize_path("res://scripts/export_presets/" + platform + ".cfg")
	var preset_dst = abs_temp_project + "/export_presets.cfg"
	if FileAccess.file_exists(preset_src):
		var preset_content = FileAccess.get_file_as_string(preset_src)

		# Forcer l'export de toutes les ressources ET des fichiers .yaml
		preset_content = preset_content.replace("export_filter=\"selected_scenes\"", "export_filter=\"all_resources\"")

		if preset_content.find("include_filter=\"") != -1:
			if preset_content.find("*.yaml") == -1:
				preset_content = preset_content.replace("include_filter=\"", "include_filter=\"*.yaml,")
		else:
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

	# 9b. Découper en PCK par chapitre (web uniquement)
	if platform == "web" and exit_code == 0 and FileAccess.file_exists(export_file):
		_split_pck_by_chapter(abs_temp_project, export_file.get_base_dir(), godot_bin, log_path)

	# 9c. Créer le fichier _headers pour Cloudflare Pages (COOP/COEP requis par SharedArrayBuffer)
	if platform == "web" and exit_code == 0:
		var headers_path = export_file.get_base_dir() + "/_headers"
		var f_headers = FileAccess.open(headers_path, FileAccess.WRITE)
		if f_headers:
			f_headers.store_line("/*")
			f_headers.store_line("  Cross-Origin-Opener-Policy: same-origin")
			f_headers.store_line("  Cross-Origin-Embedder-Policy: require-corp")
			f_headers.close()
			_append_log(log_path, "→ Fichier _headers créé pour Cloudflare Pages (COOP/COEP)")

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


func _split_pck_by_chapter(temp_project: String, export_dir: String, godot_bin: String, log_path: String) -> void:
	_append_log(log_path, "→ Découpage PCK par chapitre...")

	# Lancer le script headless pour créer les PCK chapitres
	var split_output = []
	var split_args = [
		"--path", temp_project, "--headless",
		"--script", "res://src/export/pck_chapter_builder.gd",
		"--", "--output", export_dir
	]
	var split_exit = OS.execute(godot_bin, split_args, split_output, true)

	for line in split_output:
		_append_log(log_path, "  " + line.strip_edges())

	if split_exit != 0:
		_append_log(log_path, "  ⚠ Échec du découpage PCK (non bloquant)")
		return

	# Re-exporter le core PCK sans les assets chapitres (qui ont été supprimés par le builder)
	_append_log(log_path, "→ Ré-export du core PCK allégé...")
	var pck_path = export_dir + "/index.pck"
	var reexport_output = []
	var preset_name = "Web"
	var export_file = export_dir + "/index.html"
	var reexport_args = ["--path", temp_project, "--headless", "--export-release", preset_name, export_file]
	OS.execute(godot_bin, reexport_args, reexport_output, true)

	for line in reexport_output:
		_append_log(log_path, "  " + line.strip_edges())

	# Compter les PCK chapitres créés
	var dir = DirAccess.open(export_dir)
	if dir:
		var count = 0
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.begins_with("chapter_") and fname.ends_with(".pck"):
				count += 1
			fname = dir.get_next()
		_append_log(log_path, "→ %d PCK chapitres créés" % count)


func _optimize_audio_files(story_dir: String, log_path: String) -> void:
	# Vérifier que ffmpeg est disponible
	var test_output = []
	var test_exit = OS.execute("ffmpeg", ["-version"], test_output)
	if test_exit != 0:
		_append_log(log_path, "→ ffmpeg non trouvé — optimisation audio ignorée")
		return

	# Trouver les fichiers audio
	var audio_files = _find_audio_files(story_dir)
	if audio_files.is_empty():
		_append_log(log_path, "→ Aucun fichier audio trouvé")
		return

	_append_log(log_path, "→ Optimisation de %d fichiers audio (128kbps)..." % audio_files.size())

	for audio_file in audio_files:
		var tmp_file = audio_file + ".tmp.mp3"
		var output = []
		var exit_code = OS.execute("ffmpeg", ["-y", "-i", audio_file, "-b:a", "128k", "-ac", "2", tmp_file, "-loglevel", "error"], output, true)
		if exit_code == 0 and FileAccess.file_exists(tmp_file):
			DirAccess.remove_absolute(audio_file)
			DirAccess.rename_absolute(tmp_file, audio_file)
			_append_log(log_path, "  → " + audio_file.get_file())
		else:
			if FileAccess.file_exists(tmp_file):
				DirAccess.remove_absolute(tmp_file)
			_append_log(log_path, "  ⚠ Échec pour " + audio_file.get_file())


func _find_audio_files(dir_path: String) -> Array:
	var result = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		var full_path = dir_path + "/" + file_name
		if dir.current_is_dir():
			result.append_array(_find_audio_files(full_path))
		else:
			var ext = file_name.get_extension().to_lower()
			if ext == "mp3" or ext == "ogg" or ext == "wav":
				result.append(full_path)
		file_name = dir.get_next()
	return result


func _append_log(log_path: String, message: String) -> void:
	var f = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_line(message)
		f.close()
	print(message)


func _generate_app_icons(icon_src: String, temp_project: String, log_path: String) -> void:
	var img = Image.new()
	if img.load(icon_src) != OK:
		_append_log(log_path, "⚠ Impossible de charger l'icône : " + icon_src)
		return

	_append_log(log_path, "→ Génération des icônes depuis " + icon_src.get_file() + " (%dx%d)" % [img.get_width(), img.get_height()])

	# Générer les icônes PWA
	var icons_dir = temp_project + "/assets/icons"
	if not DirAccess.dir_exists_absolute(icons_dir):
		DirAccess.make_dir_recursive_absolute(icons_dir)

	var sizes = [144, 180, 512]
	for s in sizes:
		var resized = img.duplicate()
		resized.resize(s, s, Image.INTERPOLATE_LANCZOS)
		var out_path = icons_dir + "/icon_%dx%d.png" % [s, s]
		resized.save_png(out_path)
		_append_log(log_path, "  → icon_%dx%d.png" % [s, s])

	# Générer l'icône projet pour le favicon (config/icon)
	var project_icon = img.duplicate()
	project_icon.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	var project_icon_path = temp_project + "/app_icon.png"
	project_icon.save_png(project_icon_path)
	_append_log(log_path, "  → app_icon.png (favicon projet)")


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
