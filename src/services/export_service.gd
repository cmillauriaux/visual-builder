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
func export_story(story: RefCounted, platform: String, output_path: String, story_path: String, quality: String = "hd") -> ExportResult:
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
	var story_exclude = ["artbook"]
	if story.get("ui_theme_mode") != "custom":
		story_exclude.append("ui")
	_copy_dir_recursive(abs_story_dir, abs_temp_story, story_exclude)
	
	# 3b. Redimensionner les images si qualité SD ou Ultra SD
	if quality == "sd":
		_resize_story_images(abs_temp_story, 2, log_path)
	elif quality == "ultrasd":
		_resize_story_images(abs_temp_story, 4, log_path)

	# 3c. Optimiser les fichiers audio pour le web (si ffmpeg est disponible)
	if platform == "web":
		_optimize_audio_files(abs_temp_story, log_path)

	# 3d. Copier le menu_background comme boot splash si défini
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

	# 3e. Générer les icônes d'application à partir de app_icon
	if story.get("app_icon") != null and story.app_icon != "":
		var icon_src = story.app_icon
		if not FileAccess.file_exists(icon_src):
			icon_src = abs_story_dir + "/" + story.app_icon
		if FileAccess.file_exists(icon_src):
			_generate_app_icons(icon_src, abs_temp_project, log_path)
		else:
			_append_log(log_path, "⚠ Icône introuvable : " + story.app_icon)

	# 4. Réécrire les chemins assets (absolu → res://story/assets/...)
	# Le script headless a besoin que le projet soit importé pour résoudre les preload().
	_append_log(log_path, "→ Import minimal du projet temporaire...")
	OS.execute(godot_bin, ["--path", abs_temp_project, "--headless", "--import"], [], true)

	_append_log(log_path, "→ Réécriture des chemins assets...")
	var rewrite_args = ["--path", abs_temp_project, "--headless", "--script", "res://src/export/rewrite_runner.gd", "--", "--story-folder", "res://story", "--new-base", "res://story"]
	var rewrite_output = []
	var rewrite_exit = OS.execute(godot_bin, rewrite_args, rewrite_output, true)
	for line in rewrite_output:
		_append_log(log_path, "  " + line.strip_edges())

	if rewrite_exit != 0:
		_append_log(log_path, "⚠ Script de réécriture échoué (exit=%d), fallback direct..." % rewrite_exit)
		_rewrite_paths_direct(abs_temp_story, "res://story", log_path)

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
	var edition_label = {"hd": "HD", "sd": "SD", "ultrasd": "Ultra SD"}.get(quality, "HD")
	var release_date = Time.get_date_string_from_system()
	var f_ov = FileAccess.open(override_path, FileAccess.WRITE)
	if f_ov:
		f_ov.store_line("[application]")
		f_ov.store_line("config/story_path=\"res://story\"")
		f_ov.store_line("config/edition=\"" + edition_label + "\"")
		f_ov.store_line("config/version=\"" + story.version + "\"")
		f_ov.store_line("config/release_date=\"" + release_date + "\"")
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
			if preset_content.find("*.json") == -1:
				preset_content = preset_content.replace("include_filter=\"", "include_filter=\"*.json,")
		else:
			preset_content = preset_content.replace("[preset.0]", "[preset.0]\ninclude_filter=\"*.yaml, *.json\"")
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

	# 9c. Cache-bust : hasher et renommer les fichiers engine (web uniquement)
	if platform == "web" and exit_code == 0 and FileAccess.file_exists(export_file):
		_cache_bust_web_export(export_file.get_base_dir(), log_path)

	# 9d. Créer le fichier _headers pour Cloudflare Pages
	if platform == "web" and exit_code == 0:
		var headers_path = export_file.get_base_dir() + "/_headers"
		var f_headers = FileAccess.open(headers_path, FileAccess.WRITE)
		if f_headers:
			f_headers.store_line("/*")
			f_headers.store_line("  Cross-Origin-Opener-Policy: same-origin")
			f_headers.store_line("  Cross-Origin-Embedder-Policy: require-corp")
			f_headers.store_line("/index.html")
			f_headers.store_line("  Cache-Control: no-cache")
			f_headers.store_line("/*.js")
			f_headers.store_line("  Cache-Control: public, max-age=31536000, immutable")
			f_headers.store_line("/*.wasm")
			f_headers.store_line("  Cache-Control: public, max-age=31536000, immutable")
			f_headers.store_line("/*.pck")
			f_headers.store_line("  Cache-Control: public, max-age=31536000, immutable")
			f_headers.store_line("/*.png")
			f_headers.store_line("  Cache-Control: public, max-age=86400")
			f_headers.close()
			_append_log(log_path, "→ Fichier _headers créé (COOP/COEP + cache)")

	# 10. Nettoyage
	_remove_dir_recursive(abs_temp_base)

	if exit_code == 0 and FileAccess.file_exists(export_file):
		return ExportResult.new(true, abs_output_path, log_path)
	else:
		var error_reason = extract_export_error(log_path)
		return ExportResult.new(false, abs_output_path, log_path, error_reason)


func _find_godot() -> String:
	# 0. En contexte éditeur, utiliser le binaire Godot qui tourne déjà.
	# Garantit la même version pour l'export → bytecode GDScript compatible.
	if OS.has_feature("editor"):
		var exe = OS.get_executable_path()
		if exe != "" and FileAccess.file_exists(exe):
			return exe

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
		defaults.append("/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")
		defaults.append("/Applications/Godot.app/Contents/MacOS/Godot")
	elif OS.get_name() == "Windows":
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
				_copy_dir_recursive(from_path, to_path, exclude)
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

	# Cache-bust : hasher et renommer les PCK chapitres AVANT le re-export
	_append_log(log_path, "→ Cache-bust : hashage des PCK chapitres...")
	var manifest_path_temp = temp_project + "/story/pck_manifest.json"
	var manifest_text = ""
	if FileAccess.file_exists(manifest_path_temp):
		manifest_text = FileAccess.get_file_as_string(manifest_path_temp)

	var dir = DirAccess.open(export_dir)
	if dir and manifest_text != "":
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.begins_with("chapter_") and fname.ends_with(".pck"):
				var full_path = export_dir + "/" + fname
				var hash = _compute_file_hash(full_path)
				var base = fname.get_basename()
				var new_name = base + "." + hash + ".pck"
				dir.rename(fname, new_name)
				manifest_text = manifest_text.replace(fname, new_name)
				_append_log(log_path, "  %s → %s" % [fname, new_name])
			fname = dir.get_next()

		var f_manifest = FileAccess.open(manifest_path_temp, FileAccess.WRITE)
		if f_manifest:
			f_manifest.store_string(manifest_text)
			f_manifest.close()

	# Re-exporter le core PCK (bake le manifest avec les noms hashés)
	_append_log(log_path, "→ Ré-export du core PCK allégé...")
	var reexport_output = []
	var preset_name = "Web"
	var export_file = export_dir + "/index.html"
	var reexport_args = ["--path", temp_project, "--headless", "--export-release", preset_name, export_file]
	OS.execute(godot_bin, reexport_args, reexport_output, true)

	for line in reexport_output:
		_append_log(log_path, "  " + line.strip_edges())

	# Compter les PCK chapitres créés
	var dir2 = DirAccess.open(export_dir)
	if dir2:
		var count = 0
		dir2.list_dir_begin()
		var fname2 = dir2.get_next()
		while fname2 != "":
			if fname2.begins_with("chapter_") and fname2.ends_with(".pck"):
				count += 1
			fname2 = dir2.get_next()
		_append_log(log_path, "→ %d PCK chapitres créés" % count)


func _optimize_audio_files(story_dir: String, log_path: String) -> void:
	# Trouver ffmpeg (Godot ne voit pas toujours le PATH complet)
	var ffmpeg_bin = _find_ffmpeg()
	if ffmpeg_bin == "":
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
		var exit_code = OS.execute(ffmpeg_bin, ["-y", "-i", audio_file, "-b:a", "128k", "-ac", "2", tmp_file, "-loglevel", "error"], output, true)
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


func _resize_story_images(story_dir: String, divisor: int, log_path: String) -> void:
	var files = _find_image_files_recursive(story_dir)
	_append_log(log_path, "→ Redimensionnement images (÷%d) : %d fichiers..." % [divisor, files.size()])
	for path in files:
		var img = Image.new()
		if img.load(path) != OK:
			_append_log(log_path, "  ⚠ Impossible de charger : " + path.get_file())
			continue
		var new_w = max(1, img.get_width() / divisor)
		var new_h = max(1, img.get_height() / divisor)
		img.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
		var ext = path.get_extension().to_lower()
		if ext == "png":
			img.save_png(path)
		else:
			img.save_jpg(path)
		_append_log(log_path, "  → %s (%dx%d)" % [path.get_file(), new_w, new_h])


func _find_image_files_recursive(dir_path: String) -> Array:
	var result = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = dir_path + "/" + file_name
			if dir.current_is_dir():
				result.append_array(_find_image_files_recursive(full_path))
			else:
				var ext = file_name.get_extension().to_lower()
				if ext == "png" or ext == "jpg" or ext == "jpeg":
					result.append(full_path)
		file_name = dir.get_next()
	return result


func _find_ffmpeg() -> String:
	# 1. Essai direct (fonctionne si ffmpeg est dans le PATH de Godot)
	var test_output = []
	if OS.execute("ffmpeg", ["-version"], test_output) == 0:
		return "ffmpeg"
	# 2. Chemins courants par OS
	var candidates = []
	if OS.get_name() == "macOS":
		candidates = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
	elif OS.get_name() == "Linux":
		candidates = ["/usr/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
	elif OS.get_name() == "Windows":
		candidates = ["C:/ffmpeg/bin/ffmpeg.exe"]
	for path in candidates:
		if FileAccess.file_exists(path):
			return path
	return ""


## Réécriture directe des chemins dans les fichiers YAML (fallback si le script headless échoue).
## Scanne tous les .yaml de la story et remplace les chemins absolus par des chemins res://.
func _rewrite_paths_direct(story_dir: String, new_base: String, log_path: String) -> void:
	var yaml_files = _find_yaml_files_recursive(story_dir)
	var total_rewrites = 0

	# Mapping clé YAML → sous-dossier assets
	var key_map = {
		"menu_background": "backgrounds",
		"menu_music": "music",
		"app_icon": "icons",
		"background": "backgrounds",
		"music": "music",
		"audio_fx": "fx",
		"image": "foregrounds",
	}

	for yaml_path in yaml_files:
		var content = FileAccess.get_file_as_string(yaml_path)
		var lines = content.split("\n")
		var new_lines = []
		var modified = false

		for line in lines:
			var rewritten = _rewrite_yaml_path_line(line, key_map, new_base)
			if rewritten != line:
				modified = true
				total_rewrites += 1
			new_lines.append(rewritten)

		if modified:
			var f = FileAccess.open(yaml_path, FileAccess.WRITE)
			if f:
				f.store_string("\n".join(new_lines))
				f.close()

	_append_log(log_path, "  Fallback : %d chemins réécrits dans %d fichiers" % [total_rewrites, yaml_files.size()])


## Réécrit un chemin absolu dans une ligne YAML si la clé correspond à un champ d'asset.
func _rewrite_yaml_path_line(line: String, key_map: Dictionary, new_base: String) -> String:
	var stripped = line.strip_edges()
	for key in key_map:
		# Chercher le pattern: key: "value" ou key: value
		var prefix = key + ": "
		if not stripped.begins_with(prefix) and not stripped.begins_with("  " + prefix):
			# Aussi chercher dans les inline dicts: { ..., key: "value", ... }
			if stripped.find(key + ": \"") == -1:
				continue

		# Extraire la valeur entre guillemets pour ce champ
		var key_pos = stripped.find(key + ": ")
		if key_pos == -1:
			continue
		var value_start = key_pos + key.length() + 2
		var value = ""
		if value_start < stripped.length() and stripped[value_start] == '"':
			var end_quote = stripped.find('"', value_start + 1)
			if end_quote != -1:
				value = stripped.substr(value_start + 1, end_quote - value_start - 1)
		else:
			# Valeur sans guillemets
			value = stripped.substr(value_start).strip_edges()

		if value == "":
			continue

		# Vérifier si c'est un chemin absolu qui doit être réécrit
		var is_absolute = value.begins_with("/") or (value.length() >= 3 and value.unicode_at(1) == 58 and (value[2] == "/" or value[2] == "\\"))
		var is_user = value.begins_with("user://")
		if not is_absolute and not is_user:
			continue

		# Réécrire : extraire le nom de fichier et construire le nouveau chemin
		var filename = value.get_file()
		var subfolder = key_map[key]
		var new_path = new_base + "/assets/" + subfolder + "/" + filename
		line = line.replace(value, new_path)
		break

	return line


func _find_yaml_files_recursive(dir_path: String) -> Array:
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
			result.append_array(_find_yaml_files_recursive(full_path))
		elif file_name.get_extension().to_lower() == "yaml":
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
	if not FileAccess.file_exists(icon_src):
		_append_log(log_path, "⚠ Impossible de charger l'icône : " + icon_src)
		return
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


## Calcule un hash MD5 court (8 caractères hex) du contenu d'un fichier.
func _compute_file_hash(file_path: String) -> String:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	var f = FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return "00000000"
	while not f.eof_reached():
		var chunk = f.get_buffer(65536)
		if chunk.size() > 0:
			ctx.update(chunk)
	f.close()
	var hash_bytes = ctx.finish()
	return hash_bytes.hex_encode().substr(0, 8)


## Cache-bust : hasher et renommer les fichiers engine web, mettre à jour index.html.
func _cache_bust_web_export(export_dir: String, log_path: String) -> void:
	var pck_path = export_dir + "/index.pck"
	if not FileAccess.file_exists(pck_path):
		return

	var deploy_hash = _compute_file_hash(pck_path)
	_append_log(log_path, "→ Cache-bust : hash de déploiement %s" % deploy_hash)

	var d = DirAccess.open(export_dir)
	if d == null:
		return

	# Renommer les fichiers engine principaux
	for ext in ["js", "wasm", "pck"]:
		var old_name = "index." + ext
		var new_name = "index." + deploy_hash + "." + ext
		if FileAccess.file_exists(export_dir + "/" + old_name):
			d.rename(old_name, new_name)
			_append_log(log_path, "  %s → %s" % [old_name, new_name])

	# Renommer les audio worklets
	for worklet in ["audio.worklet.js", "audio.position.worklet.js"]:
		var old_name = "index." + worklet
		var new_name = "index." + deploy_hash + "." + worklet
		if FileAccess.file_exists(export_dir + "/" + old_name):
			d.rename(old_name, new_name)
			_append_log(log_path, "  %s → %s" % [old_name, new_name])

	# Mettre à jour index.html
	var html_path = export_dir + "/index.html"
	var html = FileAccess.get_file_as_string(html_path)
	html = html.replace('src="index.js"', 'src="index.%s.js"' % deploy_hash)
	html = html.replace('"executable":"index"', '"executable":"index.%s"' % deploy_hash)
	html = html.replace('"index.pck":', '"index.%s.pck":' % deploy_hash)
	html = html.replace('"index.wasm":', '"index.%s.wasm":' % deploy_hash)
	var f_html = FileAccess.open(html_path, FileAccess.WRITE)
	if f_html:
		f_html.store_string(html)
		f_html.close()
	_append_log(log_path, "  index.html mis à jour")
