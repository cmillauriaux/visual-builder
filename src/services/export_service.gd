# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Service gérant l'exécution de l'exportation des histoires vers des jeux standalone.
## Encapsule l'appel au script shell et l'analyse des logs d'erreur.

class_name ExportService

const WEBP_QUALITY := 0.85

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
func export_story(story: RefCounted, platform: String, output_path: String, story_path: String, quality: String = "hd", export_options: Dictionary = {}, language: String = "", partial_export: Dictionary = {}) -> ExportResult:
	if story == null:
		return ExportResult.new(false, output_path, "", "Aucune histoire chargée.")

	var godot_bin = _find_godot()
	if godot_bin == "":
		return ExportResult.new(false, output_path, "", "Binaire Godot introuvable. Veuillez définir GODOT_PATH dans .env.")

	var plat_cfg: Dictionary = story.platform_settings.get(platform, {}) if story.get("platform_settings") != null else {}
	
	# Préparer le dossier de sortie et le log tôt pour permettre le logging de la configuration
	var abs_output_path = ProjectSettings.globalize_path(output_path)
	if not DirAccess.dir_exists_absolute(abs_output_path):
		DirAccess.make_dir_recursive_absolute(abs_output_path)
	
	var log_path = abs_output_path + "/export.log"
	
	# Configuration spécifique à Android
	if platform == "android":
		_ensure_android_config(plat_cfg, log_path)
		if plat_cfg.get("sdk_path", "") != "":
			var sdk_path = plat_cfg["sdk_path"]
			OS.set_environment("ANDROID_HOME", sdk_path)
			OS.set_environment("ANDROID_SDK_ROOT", sdk_path)
			var sep = ":" if OS.get_name() != "Windows" else ";"
			OS.set_environment("PATH", sdk_path + "/platform-tools" + sep + OS.get_environment("PATH"))

	var game_name = story.menu_title if story.menu_title != "" else story.title
	# iOS/Xcode ne supporte pas certains caractères dans le nom de projet
	if platform == "ios":
		game_name = game_name.replace("&", "and")
	if story_path == "":
		return ExportResult.new(false, output_path, "", "Veuillez sauvegarder l'histoire avant de l'exporter.")

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

	# Supprimer les dossiers de plugins désactivés à l'export
	var excluded_plugins := _get_excluded_plugin_folders(export_options)
	for folder in excluded_plugins:
		var excluded_path: String = abs_temp_project + "/plugins/" + str(folder)
		if DirAccess.dir_exists_absolute(excluded_path):
			_remove_dir_recursive(excluded_path)
			_append_log(log_path, "→ Plugin exclu de l'export : " + str(folder))

	# Générer le registre des plugins restants (nécessaire car DirAccess
	# ne peut pas lister les répertoires dans un PCK exporté)
	_generate_plugin_registry(abs_temp_project, log_path)

	# 3. Copier la story dans res://story/ (sans artbook pour éviter les doublons)
	var abs_story_dir = ProjectSettings.globalize_path(story_path)
	var abs_temp_story = abs_temp_project + "/story"
	DirAccess.make_dir_recursive_absolute(abs_temp_story)
	var story_exclude = ["artbook"]
	if story.get("ui_theme_mode") != "custom":
		story_exclude.append("ui")
	_copy_dir_recursive(abs_story_dir, abs_temp_story, story_exclude)

	# 3b-extra. Filtrer les langues si une langue spécifique est demandée
	if language != "":
		_filter_i18n_language(abs_temp_story, language, log_path)

	# 3b-extra. Filtrer les chapitres si export partiel
	if not partial_export.is_empty():
		_filter_partial_chapters(story, abs_temp_story, partial_export, log_path)

	# 3b-extra. Supprimer les assets non référencés (évite d'embarquer des fichiers inutilisés)
	if platform != "web":
		_remove_unused_assets(abs_temp_story, log_path)

	# 3b-extra. Aplatir les APNG en PNG statiques (première frame)
	var static_apng: bool = export_options.get("static_apng", false)
	if static_apng:
		_flatten_apng_files(abs_temp_story, log_path)

	# 3b. Redimensionner les images si qualité SD ou Ultra SD
	if quality == "sd":
		_resize_story_images(abs_temp_story, 2, log_path)
	elif quality == "ultrasd":
		_resize_story_images(abs_temp_story, 4, log_path)

	# 3b-bis. Convertir PNG/JPG → WebP (réduction ~70-80%)
	var webp_enabled: bool = export_options.get("webp_conversion", true)
	if webp_enabled:
		_convert_images_to_webp(abs_temp_story, log_path)

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

	# 4b. Remplacer les .import/.ctex des images par importer="keep" pour inclure
	# les fichiers bruts dans le PCK (les .ctex sont 4-7x plus lourds).
	if webp_enabled:
		_strip_image_imports(abs_temp_story, abs_temp_project, log_path)

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
	var image_quality_divisor = {"hd": 1, "sd": 2, "ultrasd": 4}.get(quality, 1)
	var project_godot_path = abs_temp_project + "/project.godot"
	var project_content = FileAccess.get_file_as_string(project_godot_path)
	project_content = project_content.replace('run/main_scene="res://src/main.tscn"', 'run/main_scene="res://src/game.tscn"')
	project_content = project_content.replace('config/name="' + _get_config_project_name() + '"', 'config/name="' + game_name + '"')

	# Ajouter une propriété personnalisée pour le chemin de la story
	if project_content.find("[application]") == -1:
		project_content += "\n[application]\n"
	project_content = project_content.replace("[application]", "[application]\nconfig/story_path=\"res://story\"\nconfig/image_quality_divisor=" + str(image_quality_divisor))

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

	if platform == "macos" or platform == "android" or platform == "ios":
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
		f_ov.store_line("config/image_quality_divisor=" + str(image_quality_divisor))
		f_ov.store_line("config/censure_enabled=" + str(export_options.get("censure_enabled", false)).to_lower())
		if not partial_export.is_empty():
			var si: int = int(partial_export.get("start_idx", 0)) + 1
			var ei: int = int(partial_export.get("end_idx", 0)) + 1
			f_ov.store_line("config/partial_range=\"ch%d_to_ch%d\"" % [si, ei])
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
			for ext in ["*.yaml", "*.json", "*.webp", "*.png", "*.jpg"]:
				if preset_content.find(ext) == -1:
					preset_content = preset_content.replace("include_filter=\"", "include_filter=\"" + ext + ",")
		else:
			preset_content = preset_content.replace("[preset.0]", "[preset.0]\ninclude_filter=\"*.yaml,*.json,*.webp,*.png,*.jpg\"")
		# Injecter les platform_settings de la story dans le preset
		if platform == "ios":
			if plat_cfg.get("team_id", "") != "":
				preset_content = preset_content.replace("application/app_store_team_id=\"\"", "application/app_store_team_id=\"" + plat_cfg["team_id"] + "\"")
			if plat_cfg.get("bundle_identifier", "") != "":
				preset_content = preset_content.replace("application/bundle_identifier=\"com.visualnovel.game\"", "application/bundle_identifier=\"" + plat_cfg["bundle_identifier"] + "\"")
		elif platform == "android":
			if plat_cfg.get("package_name", "") != "":
				preset_content = preset_content.replace("package/unique_name=\"com.visualnovel.game\"", "package/unique_name=\"" + plat_cfg["package_name"] + "\"")
			
			# Injecter les paramètres de keystore si fournis
			if plat_cfg.get("keystore_path", "") != "":
				var ks_path = plat_cfg["keystore_path"]
				var ks_alias = plat_cfg.get("keystore_alias", "")
				var ks_pwd = plat_cfg.get("keystore_password", "")
				
				# Remplacer ou ajouter les paramètres de keystore release
				if preset_content.find("keystore/release=\"") != -1:
					preset_content = preset_content.replace("keystore/release=\"\"", "keystore/release=\"" + ks_path + "\"")
					preset_content = preset_content.replace("keystore/release_user=\"\"", "keystore/release_user=\"" + ks_alias + "\"")
					preset_content = preset_content.replace("keystore/release_password=\"\"", "keystore/release_password=\"" + ks_pwd + "\"")
				else:
					preset_content = preset_content.replace("package/signed=true", "package/signed=true\nkeystore/release=\"" + ks_path + "\"\nkeystore/release_user=\"" + ks_alias + "\"\nkeystore/release_password=\"" + ks_pwd + "\"")
			else:
				# Utiliser la clé de debug pour signer l'APK release par défaut si aucune clé release n'est fournie
				var home = OS.get_environment("HOME") if OS.get_name() != "Windows" else OS.get_environment("USERPROFILE")
				var debug_keystore = home + "/.android/debug.keystore"
				if FileAccess.file_exists(debug_keystore):
					preset_content = preset_content.replace("package/signed=true", "package/signed=true\nkeystore/release=\"" + debug_keystore + "\"\nkeystore/release_user=\"androiddebugkey\"\nkeystore/release_password=\"android\"")

		var f_preset = FileAccess.open(preset_dst, FileAccess.WRITE)
		if f_preset:
			f_preset.store_string(preset_content)
			f_preset.close()

	# 8. Préparer le fichier de sortie
	var export_ext = _get_export_extension(platform)
	var safe_name = _build_export_name(game_name, story.version, language, partial_export, export_options, story)
	var export_file = ""

	if platform == "web":
		var web_dir = abs_output_path + "/" + safe_name + "_web"
		if not DirAccess.dir_exists_absolute(web_dir):
			DirAccess.make_dir_recursive_absolute(web_dir)
		export_file = web_dir + "/index.html"
	elif platform == "ios":
		# iOS : exporter le projet Xcode seulement, puis patcher et builder
		export_file = abs_output_path + "/" + safe_name
	else:
		export_file = abs_output_path + "/" + safe_name + "." + export_ext

	# 9. Import & Export
	var output = []

	# Import d'abord (nécessaire pour générer .godot/)
	_append_log(log_path, "→ Importation des ressources...")
	OS.execute(godot_bin, ["--path", abs_temp_project, "--headless", "--import"], output, true)

	# Export release
	var export_args = ["--path", abs_temp_project, "--headless", "--export-release", preset_name, export_file]
	
	# Injection dynamique du SDK Android via argument CLI si présent
	if platform == "android":
		if plat_cfg.get("sdk_path", "") != "":
			export_args.append("--set-setting")
			export_args.append("export/android/android_sdk_path=" + plat_cfg["sdk_path"])
			_append_log(log_path, "→ Utilisation du SDK Android : " + plat_cfg["sdk_path"])
		if plat_cfg.get("jdk_path", "") != "":
			export_args.append("--set-setting")
			export_args.append("export/android/jdk_path=" + plat_cfg["jdk_path"])
			_append_log(log_path, "→ Utilisation du JDK Java : " + plat_cfg["jdk_path"])

	_append_log(log_path, "→ Lancement de l'exportation (%s) vers %s..." % [preset_name, export_file])
	_append_log(log_path, "  Commande : %s %s" % [godot_bin, " ".join(export_args)])
	var exit_code = OS.execute(godot_bin, export_args, output, true)
	_append_log(log_path, "→ Exportation terminée avec le code : %d" % exit_code)

	# 9a. iOS : patcher le projet Xcode (SwiftUICore) et builder le .ipa
	# Godot génère le .xcodeproj à plat dans abs_output_path avec son propre nom
	if platform == "ios" and exit_code == 0:
		_patch_ios_xcode_project(abs_output_path, log_path)
	
	# Écrire l'output de Godot dans le log
	var f_log = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f_log:
		f_log.seek_end()
		for line in output:
			f_log.store_string(line)
		f_log.close()

	# 9b. Découper en PCK par chapitre (web uniquement — inutile sur desktop)
	if platform == "web" and exit_code == 0 and FileAccess.file_exists(export_file):
		_split_pck_by_chapter(abs_temp_project, export_file.get_base_dir(), godot_bin, log_path, preset_name, export_file, true)

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
			f_headers.store_line("/*.webp")
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


## Construit le nom de fichier d'export avec langue, plage de chapitres, censure et version.
func _build_export_name(game_name: String, version: String, language: String, partial_export: Dictionary, export_options: Dictionary, story) -> String:
	var safe = game_name.validate_filename().replace(" ", "_")
	if language != "":
		safe += "_" + language.validate_filename()
	if not partial_export.is_empty():
		var si: int = int(partial_export.get("start_idx", 0)) + 1
		var ei: int = int(partial_export.get("end_idx", 0)) + 1
		safe += "_ch%d_to_ch%d" % [si, ei]
	if export_options.get("censure_enabled", false):
		safe += "_CENSORED"
	safe += "_v" + version.validate_filename().replace(" ", "_")
	return safe


## Supprime les fichiers i18n qui ne correspondent pas à la langue sélectionnée.
func _filter_i18n_language(story_dir: String, language: String, log_path: String) -> void:
	var i18n_dir = story_dir + "/i18n"
	if not DirAccess.dir_exists_absolute(i18n_dir):
		return

	var YamlParser = load("res://src/persistence/yaml_parser.gd")
	var yaml_path = i18n_dir + "/languages.yaml"

	# Lire la langue source depuis le languages.yaml AVANT suppression.
	# CRITIQUE : "default" = langue dans laquelle le story est rédigé (souvent "fr").
	# _reload_i18n n'applique les traductions que si _settings.language ≠ source_lang.
	# Si on exporte en "en" et que source_lang devient "en" aussi, 0 traduction appliquée.
	var source_lang: String = "fr"  # fallback sûr
	if YamlParser != null and FileAccess.file_exists(yaml_path):
		var existing = YamlParser.yaml_to_dict(FileAccess.get_file_as_string(yaml_path))
		if existing != null and existing.has("default"):
			source_lang = str(existing["default"])

	# Supprimer les fichiers i18n des autres langues
	var dir = DirAccess.open(i18n_dir)
	if dir != null:
		dir.list_dir_begin()
		var entry = dir.get_next()
		while entry != "":
			if not dir.current_is_dir() and entry.ends_with(".yaml") and entry != "languages.yaml":
				if entry.get_basename() != language:
					DirAccess.remove_absolute(i18n_dir + "/" + entry)
					_append_log(log_path, "→ i18n supprimé (langue non sélectionnée) : " + entry)
			entry = dir.get_next()
		dir.list_dir_end()

	# Toujours écrire languages.yaml avec source_lang intact et languages = [language].
	# Sans ce fichier explicite le jeu bootstrappe depuis les .yaml restants et peut
	# déduire default=language → source_lang==_settings.language → 0 traduction.
	if YamlParser != null:
		var new_config = {"default": source_lang, "languages": [language]}
		var f = FileAccess.open(yaml_path, FileAccess.WRITE)
		if f:
			f.store_string(YamlParser.dict_to_yaml(new_config))
			f.close()
		_append_log(log_path, "→ languages.yaml : source=%s, export=%s" % [source_lang, language])

	# Filtrer les fichiers voice : ne garder que ceux de la langue sélectionnée.
	# Parcourir les YAML de scènes pour collecter les voice_files à garder,
	# puis supprimer les fichiers MP3 non référencés dans assets/voices/.
	_filter_voice_files(story_dir, language, source_lang, log_path)


## Filtre les fichiers audio voice pour ne garder que ceux de la langue sélectionnée.
## Parcourt les scènes YAML, collecte les chemins voice à garder, supprime le reste.
func _filter_voice_files(story_dir: String, language: String, source_lang: String, log_path: String) -> void:
	var voices_dir = story_dir + "/assets/voices"
	if not DirAccess.dir_exists_absolute(voices_dir):
		return

	# Collecter tous les fichiers voice existants
	var all_voice_files: Dictionary = {}  # filename -> true
	var dir = DirAccess.open(voices_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and (entry.ends_with(".mp3") or entry.ends_with(".ogg") or entry.ends_with(".wav")):
			all_voice_files[entry] = true
		entry = dir.get_next()
	dir.list_dir_end()

	if all_voice_files.is_empty():
		return

	# Parcourir les scènes YAML pour collecter les voice_files à garder
	var keep_files: Dictionary = {}  # filename -> true
	var chapters_dir = story_dir + "/chapters"
	if DirAccess.dir_exists_absolute(chapters_dir):
		var ch_dir = DirAccess.open(chapters_dir)
		if ch_dir != null:
			ch_dir.list_dir_begin()
			var ch_entry = ch_dir.get_next()
			while ch_entry != "":
				if ch_dir.current_is_dir() and not ch_entry.begins_with("."):
					var scenes_dir = chapters_dir + "/" + ch_entry + "/scenes"
					_collect_voice_files_to_keep(scenes_dir, language, source_lang, keep_files)
				ch_entry = ch_dir.get_next()
			ch_dir.list_dir_end()

	# Supprimer les fichiers voice non référencés
	var removed_count: int = 0
	for filename in all_voice_files:
		if not keep_files.has(filename):
			DirAccess.remove_absolute(voices_dir + "/" + filename)
			removed_count += 1
	if removed_count > 0:
		_append_log(log_path, "→ %d fichier(s) voice supprimé(s) (langue non sélectionnée)" % removed_count)
	_append_log(log_path, "→ %d fichier(s) voice conservé(s)" % keep_files.size())


## Parcourt les fichiers YAML d'un dossier de scènes et collecte les voice_files à garder.
func _collect_voice_files_to_keep(scenes_dir: String, language: String, source_lang: String, keep_files: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(scenes_dir):
		return
	var dir = DirAccess.open(scenes_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".yaml"):
			var content = FileAccess.get_file_as_string(scenes_dir + "/" + entry)
			_extract_voice_keeps_from_content(content, language, source_lang, keep_files)
		entry = dir.get_next()
	dir.list_dir_end()


## Extrait les noms de fichiers voice à garder depuis le contenu YAML d'une scène.
## Gère deux formats YAML :
##   Inline : voice_files: { default: "path", en: "path" }
##   Block  : voice_files:\n          default: "path"\n          en: "path"
func _extract_voice_keeps_from_content(content: String, language: String, source_lang: String, keep_files: Dictionary) -> void:
	var lines = content.split("\n")
	var i: int = 0
	while i < lines.size():
		var line = lines[i]
		var stripped = line.strip_edges()
		var vf_pos = stripped.find("voice_files:")
		if vf_pos == -1:
			i += 1
			continue

		var after_colon = stripped.substr(vf_pos + "voice_files:".length()).strip_edges()
		if after_colon.begins_with("{"):
			# Format inline : voice_files: { default: "path", en: "path" }
			var brace_end = after_colon.find("}")
			if brace_end == -1:
				i += 1
				continue
			var block = after_colon.substr(1, brace_end - 1)
			_keep_voice_from_pairs(block.split(","), language, source_lang, keep_files, block)
			i += 1
		elif after_colon == "" or after_colon == "{}":
			if after_colon == "{}":
				i += 1
				continue
			# Format block : lignes indentées qui suivent
			var base_indent = _get_indent(line)
			var pairs: Array = []
			var has_language_key: bool = false
			i += 1
			while i < lines.size():
				var next_line = lines[i]
				if next_line.strip_edges() == "":
					i += 1
					continue
				var next_indent = _get_indent(next_line)
				if next_indent <= base_indent:
					break
				var pair = next_line.strip_edges()
				pairs.append(pair)
				# Vérifier si la langue demandée est présente
				if pair.begins_with(language + ":"):
					has_language_key = true
				i += 1
			# Traiter les paires collectées
			for pair in pairs:
				var colon = pair.find(":")
				if colon == -1:
					continue
				var key = pair.substr(0, colon).strip_edges()
				var val = pair.substr(colon + 1).strip_edges()
				val = val.trim_prefix("\"").trim_suffix("\"")
				if val == "":
					continue
				var filename = val.get_file()
				if key == language:
					keep_files[filename] = true
				elif key == "default" and language == source_lang:
					keep_files[filename] = true
				elif key == "default" and not has_language_key:
					keep_files[filename] = true
		else:
			i += 1


## Retourne le niveau d'indentation (nombre d'espaces en début de ligne).
func _get_indent(line: String) -> int:
	var count: int = 0
	for ch_idx in line.length():
		if line[ch_idx] == " ":
			count += 1
		elif line[ch_idx] == "\t":
			count += 4
		else:
			break
	return count


## Traite les paires clé: "valeur" d'un bloc inline voice_files.
func _keep_voice_from_pairs(parts: Array, language: String, source_lang: String, keep_files: Dictionary, block: String) -> void:
	for part in parts:
		var p: String = part.strip_edges()
		if p == "":
			continue
		var colon = p.find(":")
		if colon == -1:
			continue
		var key = p.substr(0, colon).strip_edges()
		var val = p.substr(colon + 1).strip_edges()
		val = val.trim_prefix("\"").trim_suffix("\"")
		if val == "":
			continue
		var filename = val.get_file()
		if key == language:
			keep_files[filename] = true
		elif key == "default" and language == source_lang:
			keep_files[filename] = true
		elif key == "default" and not block.contains(language + ":"):
			keep_files[filename] = true


## Filtre les chapitres selon l'intervalle partial_export {start_idx, end_idx}.
## Supprime les dossiers de chapitres hors plage et met à jour story.yaml.
func _filter_partial_chapters(story, story_dir: String, partial_export: Dictionary, log_path: String) -> void:
	var start_idx: int = int(partial_export.get("start_idx", 0))
	var end_idx: int = int(partial_export.get("end_idx", story.chapters.size() - 1))
	if end_idx < start_idx:
		end_idx = start_idx

	# Collecter les UUIDs sélectionnés
	var selected_uuids: Array = []
	for i in story.chapters.size():
		if i >= start_idx and i <= end_idx:
			selected_uuids.append(story.chapters[i].uuid)

	# Supprimer les dossiers de chapitres non sélectionnés
	var chapters_dir = story_dir + "/chapters"
	if DirAccess.dir_exists_absolute(chapters_dir):
		var dir = DirAccess.open(chapters_dir)
		if dir != null:
			dir.list_dir_begin()
			var entry = dir.get_next()
			while entry != "":
				if dir.current_is_dir() and not entry.begins_with("."):
					if not selected_uuids.has(entry):
						_remove_dir_recursive(chapters_dir + "/" + entry)
						_append_log(log_path, "→ Chapitre exclu (export partiel) : " + entry)
				entry = dir.get_next()
			dir.list_dir_end()

	# Patcher les conséquences redirect_chapter orphelines → to_be_continued
	_patch_orphan_redirects(chapters_dir, selected_uuids, log_path)

	# Mettre à jour story.yaml pour ne lister que les chapitres sélectionnés
	var story_yaml_path = story_dir + "/story.yaml"
	if not FileAccess.file_exists(story_yaml_path):
		return
	var YamlParser = load("res://src/persistence/yaml_parser.gd")
	if YamlParser == null:
		return
	var content = FileAccess.get_file_as_string(story_yaml_path)
	var story_dict = YamlParser.yaml_to_dict(content)
	if story_dict == null or not story_dict.has("chapters"):
		return
	var filtered_chapters: Array = []
	for ch in story_dict["chapters"]:
		if ch is Dictionary and selected_uuids.has(ch.get("uuid", "")):
			filtered_chapters.append(ch)
	story_dict["chapters"] = filtered_chapters
	var updated_yaml = YamlParser.dict_to_yaml(story_dict)
	var f = FileAccess.open(story_yaml_path, FileAccess.WRITE)
	if f:
		f.store_string(updated_yaml)
		f.close()
	_append_log(log_path, "→ story.yaml mis à jour : %d chapitres conservés" % filtered_chapters.size())


## Convertit les conséquences redirect_chapter orphelines en to_be_continued.
## Une conséquence est orpheline si son target ne fait pas partie des selected_uuids.
func _patch_orphan_redirects(chapters_dir: String, selected_uuids: Array, log_path: String) -> void:
	if not DirAccess.dir_exists_absolute(chapters_dir):
		return
	var YamlParser = load("res://src/persistence/yaml_parser.gd")
	if YamlParser == null:
		return
	for chapter_uuid in selected_uuids:
		var scenes_dir = chapters_dir + "/" + chapter_uuid + "/scenes"
		if not DirAccess.dir_exists_absolute(scenes_dir):
			continue
		var dir = DirAccess.open(scenes_dir)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry = dir.get_next()
		while entry != "":
			if not dir.current_is_dir() and entry.ends_with(".yaml"):
				var scene_path = scenes_dir + "/" + entry
				var modified = _patch_scene_redirects(scene_path, selected_uuids, YamlParser, log_path)
				if modified:
					_append_log(log_path, "→ Scène patchée (redirect→to_be_continued) : " + chapter_uuid + "/scenes/" + entry)
			entry = dir.get_next()
		dir.list_dir_end()


## Parcourt un fichier scene YAML et convertit les redirect_chapter orphelins en to_be_continued.
## Retourne true si le fichier a été modifié.
func _patch_scene_redirects(scene_path: String, selected_uuids: Array, YamlParser, log_path: String) -> bool:
	var content = FileAccess.get_file_as_string(scene_path)
	if content == "":
		return false
	var scene_dict = YamlParser.yaml_to_dict(content)
	if scene_dict == null or not scene_dict.has("sequences"):
		return false
	var modified = false
	for seq in scene_dict["sequences"]:
		if not seq is Dictionary or not seq.has("ending"):
			continue
		var ending = seq["ending"]
		if not ending is Dictionary:
			continue
		if ending.get("type") == "auto_redirect" and ending.has("consequence"):
			if _patch_consequence(ending["consequence"], selected_uuids):
				modified = true
		elif ending.get("type") == "choices" and ending.has("choices"):
			for choice in ending["choices"]:
				if choice is Dictionary and choice.has("consequence"):
					if _patch_consequence(choice["consequence"], selected_uuids):
						modified = true
	if modified:
		var updated_yaml = YamlParser.dict_to_yaml(scene_dict)
		var f = FileAccess.open(scene_path, FileAccess.WRITE)
		if f:
			f.store_string(updated_yaml)
			f.close()
	return modified


## Convertit une conséquence redirect_chapter orpheline en to_be_continued.
## Retourne true si la conséquence a été modifiée.
func _patch_consequence(consequence: Dictionary, selected_uuids: Array) -> bool:
	if consequence.get("type") != "redirect_chapter":
		return false
	var target = consequence.get("target", "")
	if target == "" or selected_uuids.has(target):
		return false
	consequence["type"] = "to_be_continued"
	consequence.erase("target")
	return true


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
		"ios": return "ipa"
	return "bin"


func _get_preset_name(platform: String) -> String:
	match platform:
		"web": return "Web"
		"macos": return "macOS"
		"linux": return "Linux"
		"windows": return "Windows"
		"android": return "Android"
		"ios": return "iOS"
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


func _split_pck_by_chapter(temp_project: String, export_dir: String, godot_bin: String, log_path: String, reexport_preset: String, reexport_file: String, cache_bust_names: bool = false) -> void:
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

	# Cache-bust : hasher et renommer les PCK chapitres (web uniquement — HTTP cache)
	var manifest_path_temp = temp_project + "/story/pck_manifest.json"
	var manifest_text = ""
	if FileAccess.file_exists(manifest_path_temp):
		manifest_text = FileAccess.get_file_as_string(manifest_path_temp)

	if cache_bust_names:
		_append_log(log_path, "→ Cache-bust : hashage des PCK chapitres...")
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

	# Re-exporter le core PCK allégé (sans les assets chapitres retirés par pck_chapter_builder)
	_append_log(log_path, "→ Ré-export du core PCK allégé...")
	var reexport_output = []
	var reexport_args = ["--path", temp_project, "--headless", "--export-release", reexport_preset, reexport_file]
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
		if ext == "webp":
			img.save_webp(path, true, WEBP_QUALITY)
		elif ext == "png":
			img.save_png(path)
		else:
			img.save_jpg(path)
		_append_log(log_path, "  → %s (%dx%d)" % [path.get_file(), new_w, new_h])


func _convert_images_to_webp(story_dir: String, log_path: String) -> void:
	var files = _find_image_files_recursive(story_dir)
	if files.is_empty():
		return

	_append_log(log_path, "→ Conversion WebP (%d images, qualité %.0f%%)..." % [files.size(), WEBP_QUALITY * 100])

	var total_original_size := 0
	var total_webp_size := 0
	var converted_count := 0
	var conversions: Dictionary = {}  # old_filename -> new_filename

	for path in files:
		var ext = path.get_extension().to_lower()
		if ext == "webp":
			continue

		var original_size := 0
		var fa = FileAccess.open(path, FileAccess.READ)
		if fa:
			original_size = fa.get_length()
			fa.close()

		var img = Image.new()
		if img.load(path) != OK:
			_append_log(log_path, "  ⚠ Impossible de charger : " + path.get_file())
			continue

		var webp_path = path.get_basename() + ".webp"
		var err = img.save_webp(webp_path, true, WEBP_QUALITY)
		if err != OK:
			_append_log(log_path, "  ⚠ Échec conversion : " + path.get_file())
			continue

		DirAccess.remove_absolute(path)
		conversions[path.get_file()] = webp_path.get_file()

		var new_size := 0
		var fa2 = FileAccess.open(webp_path, FileAccess.READ)
		if fa2:
			new_size = fa2.get_length()
			fa2.close()

		total_original_size += original_size
		total_webp_size += new_size
		converted_count += 1

	if converted_count > 0:
		_replace_filenames_in_yaml(story_dir, conversions, log_path)

	if total_original_size > 0:
		var savings = 100.0 * (1.0 - float(total_webp_size) / float(total_original_size))
		_append_log(log_path, "  → %d images converties : %.1f Mo → %.1f Mo (−%.0f%%)" % [
			converted_count,
			total_original_size / 1048576.0,
			total_webp_size / 1048576.0,
			savings
		])


func _replace_filenames_in_yaml(story_dir: String, conversions: Dictionary, log_path: String) -> void:
	var yaml_files = _find_yaml_files_recursive(story_dir)
	var modified_count := 0

	for yaml_path in yaml_files:
		var content = FileAccess.get_file_as_string(yaml_path)
		var original = content

		for old_name in conversions:
			content = content.replace(old_name, conversions[old_name])

		if content != original:
			var f = FileAccess.open(yaml_path, FileAccess.WRITE)
			if f:
				f.store_string(content)
				f.close()
				modified_count += 1

	if modified_count > 0:
		_append_log(log_path, "  → %d fichier(s) YAML mis à jour (.png/.jpg → .webp)" % modified_count)


## Remplace les .import des images story par des stubs "keep" et supprime les .ctex.
## Godot avec importer="keep" inclut le fichier source tel quel dans le PCK,
## ce qui est 4-7x plus léger que les .ctex générés par l'import standard.
func _strip_image_imports(story_dir: String, project_dir: String, log_path: String) -> void:
	var image_files := _find_image_files_recursive(story_dir)
	var stripped := 0

	for img_path in image_files:
		var import_path = img_path + ".import"
		if FileAccess.file_exists(import_path):
			# Supprimer le .ctex référencé dans le .import
			var fa = FileAccess.open(import_path, FileAccess.READ)
			if fa:
				var text = fa.get_as_text()
				fa.close()
				for line in text.split("\n"):
					var s = line.strip_edges()
					if s.begins_with("path="):
						var val = s.substr(5).strip_edges()
						if val.begins_with("\"") and val.ends_with("\""):
							val = val.substr(1, val.length() - 2)
						if val.begins_with("res://"):
							var abs_ctex = project_dir + "/" + val.substr("res://".length())
							if FileAccess.file_exists(abs_ctex):
								DirAccess.remove_absolute(abs_ctex)
						break

			# Réécrire le .import avec importer="keep" pour empêcher la ré-import
			var f = FileAccess.open(import_path, FileAccess.WRITE)
			if f:
				f.store_string("[remap]\n\nimporter=\"keep\"\ntype=\"\"\npath=\"\"\n")
				f.close()
			stripped += 1

	if stripped > 0:
		_append_log(log_path, "→ %d images converties en import 'keep' (inclusion brute, .ctex supprimés)" % stripped)


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
				if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp":
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


## Supprime les fichiers assets de story/assets/ qui ne sont référencés dans aucun fichier YAML.
## Utilisé pour les exports desktop afin de ne pas embarquer d'assets inutilisés dans le PCK.
func _remove_unused_assets(story_dir: String, log_path: String) -> void:
	var yaml_files := _find_yaml_files_recursive(story_dir)
	var all_yaml_content: Array = []
	for yaml_path in yaml_files:
		all_yaml_content.append(FileAccess.get_file_as_string(yaml_path))
	var combined_yaml := "\n".join(PackedStringArray(all_yaml_content))

	var asset_extensions := ["png", "jpg", "jpeg", "mp3", "ogg", "wav", "webp"]
	var removed := 0

	var assets_dir := story_dir + "/assets"
	if not DirAccess.dir_exists_absolute(assets_dir):
		return

	removed = _remove_unreferenced_in_dir(assets_dir, combined_yaml, asset_extensions)

	if removed > 0:
		_append_log(log_path, "-> %d fichier(s) asset non reference(s) supprime(s)" % removed)


## Parcourt récursivement un dossier et supprime les fichiers media non référencés dans le YAML.
func _remove_unreferenced_in_dir(dir_path: String, yaml_content: String, extensions: Array) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var removed := 0
	var entries: Array = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			entries.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	for e in entries:
		var name: String = str(e)
		var full_path: String = dir_path + "/" + name
		if DirAccess.dir_exists_absolute(full_path):
			removed += _remove_unreferenced_in_dir(full_path, yaml_content, extensions)
		else:
			var ext: String = name.get_extension().to_lower()
			if ext in extensions and not yaml_content.contains(name):
				DirAccess.remove_absolute(full_path)
				removed += 1
	return removed


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


## Génère un registre JSON listant les plugins présents dans le projet temporaire.
## Ce registre est lu par GamePluginManager au runtime quand DirAccess ne fonctionne pas (exports PCK).
func _generate_plugin_registry(abs_temp_project: String, log_path: String) -> void:
	var plugin_paths: Array = []
	var plugins_dir := abs_temp_project + "/plugins"
	if DirAccess.dir_exists_absolute(plugins_dir):
		var dir := DirAccess.open(plugins_dir)
		if dir:
			dir.list_dir_begin()
			var entry := dir.get_next()
			while entry != "":
				if dir.current_is_dir() and not entry.begins_with("."):
					var gd_path := plugins_dir + "/" + entry + "/game_plugin.gd"
					if FileAccess.file_exists(gd_path):
						plugin_paths.append("res://plugins/" + entry + "/game_plugin.gd")
				entry = dir.get_next()
			dir.list_dir_end()
	
	var game_plugins_dir := abs_temp_project + "/game_plugins"
	if DirAccess.dir_exists_absolute(game_plugins_dir):
		var dir2 := DirAccess.open(game_plugins_dir)
		if dir2:
			dir2.list_dir_begin()
			var entry2 := dir2.get_next()
			while entry2 != "":
				if dir2.current_is_dir() and not entry2.begins_with("."):
					var gd_path2 := game_plugins_dir + "/" + entry2 + "/game_plugin.gd"
					if FileAccess.file_exists(gd_path2):
						plugin_paths.append("res://game_plugins/" + entry2 + "/game_plugin.gd")
				entry2 = dir2.get_next()
			dir2.list_dir_end()

	# Même s'il n'y a pas de plugins, on crée un fichier vide ou vide-ish
	# Mais dans notre cas, il y a forcément des plugins
	if not plugin_paths.is_empty():
		# On s'assure que le dossier plugins existe
		if not DirAccess.dir_exists_absolute(plugins_dir):
			DirAccess.make_dir_recursive_absolute(plugins_dir)
			
		var registry_path := plugins_dir + "/_registry.json"
		var file := FileAccess.open(registry_path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(plugin_paths))
			file.close()
			_append_log(log_path, "→ Registre plugins généré : %d plugin(s) [%s]" % [plugin_paths.size(), ", ".join(plugin_paths)])
		else:
			_append_log(log_path, "ERREUR: Impossible d'écrire le registre dans " + registry_path)


## Scanne les plugins et retourne les dossiers à exclure en fonction des export_options.
func _get_excluded_plugin_folders(export_options: Dictionary) -> Array:
	var excluded: Array = []
	for dir_path in ["res://plugins/", "res://game_plugins/"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if dir.current_is_dir() and not entry.begins_with("."):
				var path := "%s%s/game_plugin.gd" % [dir_path, entry]
				if FileAccess.file_exists(path):
					var script = load(path)
					if script:
						var instance = script.new()
						if instance.has_method("get_export_options") and instance.has_method("get_plugin_folder"):
							var folder: String = instance.get_plugin_folder()
							if folder == "":
								folder = entry
							for opt in instance.get_export_options():
								var key: String = opt.key
								# Si l'option est explicitement décochée → exclure
								if export_options.has(key) and not export_options[key]:
									excluded.append(folder)
									break
			entry = dir.get_next()
		dir.list_dir_end()
	return excluded


## Patch le projet Xcode généré par Godot pour Xcode 16+/26 (SwiftUICore).
## xcode_path peut être :
##   - un dossier contenant un .xcodeproj (ex: /tmp/export/)
##   - un chemin de base dont le .xcodeproj est un frère (ex: /tmp/MyGame → /tmp/MyGame.xcodeproj)
func _patch_ios_xcode_project(xcode_path: String, log_path: String) -> void:
	var xcodeproj := ""

	# Cas 1 : le chemin + ".xcodeproj" existe directement (Godot export_project_only)
	if DirAccess.dir_exists_absolute(xcode_path + ".xcodeproj"):
		xcodeproj = xcode_path + ".xcodeproj"
	else:
		# Cas 2 : chercher un .xcodeproj dans le dossier donné
		var dir = DirAccess.open(xcode_path)
		if dir == null:
			_append_log(log_path, "ERREUR: impossible d'ouvrir " + xcode_path)
			return
		dir.list_dir_begin()
		var entry = dir.get_next()
		while entry != "":
			if entry.ends_with(".xcodeproj"):
				xcodeproj = xcode_path + "/" + entry
				break
			entry = dir.get_next()
		dir.list_dir_end()

	if xcodeproj == "":
		_append_log(log_path, "ERREUR: aucun .xcodeproj trouvé dans " + xcode_path)
		return

	var pbxproj_path = xcodeproj + "/project.pbxproj"
	var f = FileAccess.open(pbxproj_path, FileAccess.READ)
	if f == null:
		_append_log(log_path, "ERREUR: impossible de lire " + pbxproj_path)
		return
	var content = f.get_as_text()
	f.close()

	if content.find("LD_CLASSIC_2620") >= 0:
		_append_log(log_path, "→ Xcode project déjà patché (ld_classic Xcode 26)")
		return

	# Godot 4.6 utilise SwiftUI dans libgodot.a. Xcode 26+ interdit le linkage
	# direct de SwiftUICore (framework privé). L'ancien linker (-ld_classic) contourne
	# ce check. Godot a déjà LD_CLASSIC_15xx pour Xcode 15, on ajoute Xcode 26.
	var ld_classic_entries := '"LD_CLASSIC_2600" = "-ld_classic";\n'
	ld_classic_entries += '\t\t\t\t"LD_CLASSIC_2610" = "-ld_classic";\n'
	ld_classic_entries += '\t\t\t\t"LD_CLASSIC_2620" = "-ld_classic";'
	content = content.replace('"LD_CLASSIC_1510" = "-ld_classic";', '"LD_CLASSIC_1510" = "-ld_classic";\n\t\t\t\t' + ld_classic_entries)

	if content.find("LD_CLASSIC_2620") < 0:
		_append_log(log_path, "→ Xcode project: LD_CLASSIC_1510 non trouvé, patch ignoré")
		return

	var fw = FileAccess.open(pbxproj_path, FileAccess.WRITE)
	if fw:
		fw.store_string(content)
		fw.close()
		_append_log(log_path, "→ Xcode project patché: ajout LD_CLASSIC pour Xcode 26")


## Aplatit les fichiers APNG en PNG statiques (première frame).
## Supprime les .apng et met à jour les références YAML.
func _flatten_apng_files(story_dir: String, log_path: String) -> void:
	var apng_files = _find_apng_files_recursive(story_dir)
	if apng_files.is_empty():
		return

	_append_log(log_path, "→ Aplatissement APNG → PNG (%d fichiers)..." % apng_files.size())

	var total_original_size := 0
	var total_png_size := 0
	var converted_count := 0
	var conversions: Dictionary = {}  # old_filename -> new_filename

	for apng_path in apng_files:
		var fa = FileAccess.open(apng_path, FileAccess.READ)
		if fa == null:
			_append_log(log_path, "  ⚠ Impossible d'ouvrir : " + apng_path.get_file())
			continue
		var original_size = fa.get_length()
		var data = fa.get_buffer(original_size)
		fa.close()

		var img = Image.new()
		if img.load_png_from_buffer(data) != OK:
			_append_log(log_path, "  ⚠ Impossible de charger : " + apng_path.get_file())
			continue

		var png_path = apng_path.get_basename() + ".png"
		if img.save_png(png_path) != OK:
			_append_log(log_path, "  ⚠ Échec sauvegarde : " + png_path.get_file())
			continue

		DirAccess.remove_absolute(apng_path)
		conversions[apng_path.get_file()] = png_path.get_file()

		var new_size := 0
		var fa2 = FileAccess.open(png_path, FileAccess.READ)
		if fa2:
			new_size = fa2.get_length()
			fa2.close()

		total_original_size += original_size
		total_png_size += new_size
		converted_count += 1

	if converted_count > 0:
		_replace_filenames_in_yaml(story_dir, conversions, log_path)

	if total_original_size > 0:
		var savings = 100.0 * (1.0 - float(total_png_size) / float(total_original_size))
		_append_log(log_path, "  → %d APNG aplatis : %.1f Mo → %.1f Mo (−%.0f%%)" % [
			converted_count,
			total_original_size / 1048576.0,
			total_png_size / 1048576.0,
			savings
		])


## Parcourt récursivement un dossier et retourne les chemins de tous les fichiers .apng.
func _find_apng_files_recursive(dir_path: String) -> Array:
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
				result.append_array(_find_apng_files_recursive(full_path))
			elif file_name.get_extension().to_lower() == "apng":
				result.append(full_path)
		file_name = dir.get_next()
	return result


## Build le .ipa depuis le projet Xcode exporté.
func _build_ios_ipa(xcode_dir: String, ipa_path: String, log_path: String) -> int:
	var script_path = ProjectSettings.globalize_path("res://scripts/build_ios_xcode.sh")
	var output = []
	var exit_code = OS.execute("bash", [script_path, xcode_dir, ipa_path], output, true)
	for line in output:
		_append_log(log_path, line)
	if exit_code != 0:
		_append_log(log_path, "ERREUR: build iOS échoué (code " + str(exit_code) + ")")
	return exit_code


## S'assure que les chemins SDK/JDK sont présents dans les EditorSettings globaux.
## Godot 4 valide ces chemins AVANT l'exportation et refuse de continuer s'ils manquent.
func _ensure_android_config(plat_cfg: Dictionary, log_path: String) -> void:
	var sdk_path = plat_cfg.get("sdk_path", "")
	var jdk_path = plat_cfg.get("jdk_path", "")
	if sdk_path == "" and jdk_path == "":
		return

	var settings_path = ""
	if OS.get_name() == "macOS":
		settings_path = "~/Library/Application Support/Godot/editor_settings-4.6.tres"
	elif OS.get_name() == "Windows":
		settings_path = "~/AppData/Roaming/Godot/editor_settings-4.6.tres"
	else:
		settings_path = "~/.config/godot/editor_settings-4.6.tres"
	
	settings_path = settings_path.replace("~", OS.get_environment("HOME") if OS.get_name() != "Windows" else OS.get_environment("USERPROFILE"))
	var home = OS.get_environment("HOME") if OS.get_name() != "Windows" else OS.get_environment("USERPROFILE")
	
	if not FileAccess.file_exists(settings_path):
		_append_log(log_path, "⚠ EditorSettings non trouvé à: " + settings_path)
		return

	var content = FileAccess.get_file_as_string(settings_path)
	var original = content
	
	# Fixer le chemin de la clé de debug
	var debug_keystore = home + "/.android/debug.keystore"
	if FileAccess.file_exists(debug_keystore):
		if content.find("export/android/debug_keystore") != -1:
			var regex = RegEx.new()
			regex.compile("export/android/debug_keystore\\s*=\\s*\".*\"")
			content = regex.sub(content, "export/android/debug_keystore = \"" + debug_keystore + "\"", true)
		else:
			content = content.replace("[resource]", "[resource]\nexport/android/debug_keystore = \"" + debug_keystore + "\"")
	
	if sdk_path != "":
		if content.find("export/android/android_sdk_path") != -1:
			var regex = RegEx.new()
			regex.compile("export/android/android_sdk_path\\s*=\\s*\".*\"")
			content = regex.sub(content, "export/android/android_sdk_path = \"" + sdk_path + "\"", true)
		else:
			content = content.replace("[resource]", "[resource]\nexport/android/android_sdk_path = \"" + sdk_path + "\"")
	
	if jdk_path != "":
		# Godot 4 utilise java_sdk_path
		if content.find("export/android/java_sdk_path") != -1:
			var regex = RegEx.new()
			regex.compile("export/android/java_sdk_path\\s*=\\s*\".*\"")
			content = regex.sub(content, "export/android/java_sdk_path = \"" + jdk_path + "\"", true)
		else:
			content = content.replace("[resource]", "[resource]\nexport/android/java_sdk_path = \"" + jdk_path + "\"")

	if content != original:
		var f = FileAccess.open(settings_path, FileAccess.WRITE)
		if f:
			f.store_string(content)
			f.close()
			_append_log(log_path, "→ EditorSettings mis à jour avec les chemins SDK/JDK")
		else:
			_append_log(log_path, "⚠ Impossible d'écrire dans EditorSettings")
