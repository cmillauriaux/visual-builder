# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Charge les PCK chapitres à la demande.
## Sur desktop : charge directement depuis le filesystem.
## Sur web : télécharge via HTTPRequest puis charge.

class_name PckChapterLoader

signal chapter_load_started(chapter_name: String)
signal chapter_download_progress(chapter_name: String, progress: float)
signal chapter_mounting_started(chapter_name: String)
signal chapter_loaded(chapter_uuid: String)

var _manifest: Dictionary = {}
var _loaded_chapters: Dictionary = {}  # uuid -> bool
var _story_base_path: String = ""
var _export_base_url: String = ""  # URL de base pour le web (dossier contenant index.html)
var _scene_tree: SceneTree


func setup(story_base_path: String, scene_tree: SceneTree) -> void:
	_story_base_path = story_base_path
	_scene_tree = scene_tree
	_load_manifest()


func _load_manifest() -> void:
	var manifest_path = _story_base_path + "/pck_manifest.json"
	# Essayer d'abord comme chemin res://
	if not manifest_path.begins_with("res://") and not manifest_path.begins_with("user://"):
		manifest_path = "res://story/pck_manifest.json"

	if not FileAccess.file_exists(manifest_path):
		# Pas de manifest = pas de split PCK, tout est dans le PCK principal
		return

	var f = FileAccess.open(manifest_path, FileAccess.READ)
	if f == null:
		return
	var json_text = f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(json_text)
	if parsed is Dictionary:
		_manifest = parsed


func has_manifest() -> bool:
	return not _manifest.is_empty()


func is_chapter_loaded(uuid: String) -> bool:
	return _loaded_chapters.get(uuid, false)


## Parse une entrée PCK du manifest (rétrocompatible).
## Accepte String (ancien format) ou Dictionary {"file": ..., "size": ...} (nouveau).
## Retourne {"file": String, "size": int} (size = 0 si inconnu).
static func _parse_pck_entry(entry) -> Dictionary:
	if entry is String:
		return {"file": entry, "size": 0}
	elif entry is Dictionary:
		return {"file": entry.get("file", ""), "size": entry.get("size", 0)}
	return {"file": "", "size": 0}


## Assure que le PCK du chapitre est chargé. Retourne true si OK.
## Sur le web, cette méthode est asynchrone (await).
func ensure_chapter_loaded(chapter_uuid: String) -> bool:
	if not has_manifest():
		# Pas de split PCK — tout est déjà dans le PCK principal
		return true

	if is_chapter_loaded(chapter_uuid):
		return true

	var chapter_info = _manifest.get("chapters", {}).get(chapter_uuid, {})
	if chapter_info.is_empty():
		# Chapitre inconnu du manifest — les assets sont peut-être dans le core
		return true

	var chapter_name: String = chapter_info.get("name", "")

	# Support multi-part : "pcks" (array) ou ancien format "pck" (string)
	var pck_entries: Array = []  # Array of {"file": String, "size": int}
	if chapter_info.has("pcks"):
		for entry in chapter_info.get("pcks", []):
			var parsed = _parse_pck_entry(entry)
			if parsed["file"] != "":
				pck_entries.append(parsed)
	elif chapter_info.has("pck"):
		var single: String = chapter_info.get("pck", "")
		if single != "":
			pck_entries = [{"file": single, "size": 0}]

	if pck_entries.is_empty():
		return true

	chapter_load_started.emit(chapter_name)

	var all_success := true

	if OS.get_name() == "Web" and pck_entries.size() > 1:
		all_success = await _load_pcks_web_parallel(pck_entries, chapter_name)
	else:
		# Taille totale connue pour le calcul de progression
		var total_known_size := 0
		for entry in pck_entries:
			total_known_size += entry["size"]
		var cumulated_size := 0

		for i in range(pck_entries.size()):
			var entry: Dictionary = pck_entries[i]
			var pck_filename: String = entry["file"]
			var pck_size: int = entry["size"]
			var progress_base: float
			var progress_scale: float
			if total_known_size > 0:
				progress_base = float(cumulated_size) / float(total_known_size)
				progress_scale = float(pck_size) / float(total_known_size)
			else:
				progress_base = float(i) / float(pck_entries.size())
				progress_scale = 1.0 / float(pck_entries.size())

			var success := false
			if OS.get_name() == "Web":
				success = await _load_pck_web(pck_filename, chapter_name, pck_size, progress_base, progress_scale)
			else:
				success = _load_pck_desktop(pck_filename)

			if not success:
				push_error("PckChapterLoader: failed to load %s" % pck_filename)
				all_success = false
				break
			cumulated_size += pck_size

	if all_success:
		_loaded_chapters[chapter_uuid] = true
		chapter_loaded.emit(chapter_uuid)

	return all_success


func _load_pck_desktop(pck_filename: String) -> bool:
	# Sur desktop, les PCK sont à côté de l'exécutable ou dans res://
	var pck_path = "res://" + pck_filename
	# Essayer aussi le chemin absolu à côté du PCK principal
	if not FileAccess.file_exists(pck_path):
		var exe_dir = OS.get_executable_path().get_base_dir()
		pck_path = exe_dir + "/" + pck_filename

	return ProjectSettings.load_resource_pack(pck_path)


## Télécharge tous les PCK en parallèle, puis les monte séquentiellement.
## Le téléchargement est le goulot d'étranglement (~30s par fichier via HTTPRequest),
## donc on lance toutes les requêtes simultanément pour que le temps total ≈ max(durées)
## au lieu de sum(durées).
func _load_pcks_web_parallel(pck_entries: Array, chapter_name: String) -> bool:
	var t_start := Time.get_ticks_msec()
	print("PCK PARALLEL: starting %d downloads at %d ms" % [pck_entries.size(), t_start])

	var base_url = JavaScriptBridge.eval("window.location.href.substring(0, window.location.href.lastIndexOf('/') + 1)")  # noqa: eval
	var count := pck_entries.size()

	# Calculer la taille totale connue (depuis le manifest)
	var total_known_size := 0
	for entry in pck_entries:
		total_known_size += entry["size"]

	# Lancer toutes les requêtes HTTP simultanément
	var http_nodes: Array[HTTPRequest] = []
	var results: Array = []  # Array de Variant (null = pas encore fini)
	results.resize(count)

	for i in range(count):
		var pck_filename: String = pck_entries[i]["file"]
		var http := HTTPRequest.new()
		_scene_tree.root.add_child(http)
		http_nodes.append(http)
		results[i] = null

		var url = str(base_url) + pck_filename
		var idx := i  # Capture pour la closure
		http.request_completed.connect(func(p_result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
			print("PCK PARALLEL: [%s] download complete at %d ms (HTTP %d, %d bytes)" % [pck_filename, Time.get_ticks_msec(), response_code, body.size()])
			results[idx] = [p_result, response_code, headers, body]
		)

		var err = http.request(url)
		if err != OK:
			push_error("PckChapterLoader: HTTP request error %d for %s" % [err, url])
			# Nettoyer tout
			for h in http_nodes:
				if is_instance_valid(h):
					h.queue_free()
			return false
		print("PCK PARALLEL: [%s] request fired at %d ms" % [pck_filename, Time.get_ticks_msec()])

	# Timer de progression agrégée basée sur les tailles du manifest
	var progress_timer := Timer.new()
	progress_timer.wait_time = 0.1
	progress_timer.autostart = true
	_scene_tree.root.add_child(progress_timer)
	progress_timer.timeout.connect(func():
		var total_downloaded := 0
		for h in http_nodes:
			if is_instance_valid(h):
				total_downloaded += h.get_downloaded_bytes()
		if total_known_size > 0:
			chapter_download_progress.emit(chapter_name, clampf(float(total_downloaded) / float(total_known_size), 0.0, 1.0))
		else:
			# Fallback : utiliser get_body_size() du serveur (ancien comportement)
			var fallback_size := 0
			for h in http_nodes:
				if is_instance_valid(h):
					var bs = h.get_body_size()
					if bs > 0:
						fallback_size += bs
			if fallback_size > 0:
				chapter_download_progress.emit(chapter_name, float(total_downloaded) / float(fallback_size))
	)

	# Attendre que tous les téléchargements soient terminés
	while true:
		var all_done := true
		for i in range(count):
			if results[i] == null:
				all_done = false
				break
		if all_done:
			break
		await _scene_tree.process_frame

	progress_timer.stop()
	progress_timer.queue_free()

	# Nettoyer les HTTPRequest nodes
	for h in http_nodes:
		if is_instance_valid(h):
			h.queue_free()

	print("PCK PARALLEL: all downloads done at %d ms (total download: %d ms)" % [Time.get_ticks_msec(), Time.get_ticks_msec() - t_start])

	# Phase montage
	chapter_mounting_started.emit(chapter_name)

	for i in range(count):
		var pck_filename: String = pck_entries[i]["file"]
		var result: Array = results[i]
		var response_code: int = result[1]
		var body: PackedByteArray = result[3]

		if response_code != 200:
			push_error("PckChapterLoader: failed to download %s (HTTP %d)" % [pck_filename, response_code])
			return false

		var local_path = "user://" + pck_filename
		var t0 := Time.get_ticks_msec()
		var f = FileAccess.open(local_path, FileAccess.WRITE)
		if f == null:
			push_error("PckChapterLoader: failed to write %s" % local_path)
			return false
		f.store_buffer(body)
		f.close()
		print("PCK PARALLEL: [%s] store_buffer+close: %d ms" % [pck_filename, Time.get_ticks_msec() - t0])

		var t1 := Time.get_ticks_msec()
		var success := ProjectSettings.load_resource_pack(local_path)
		print("PCK PARALLEL: [%s] load_resource_pack: %d ms" % [pck_filename, Time.get_ticks_msec() - t1])

		if not success:
			push_error("PckChapterLoader: failed to load resource pack %s" % local_path)
			return false

	print("PCK PARALLEL: total time: %d ms" % [Time.get_ticks_msec() - t_start])
	return true


func _load_pck_web(pck_filename: String, chapter_name: String, known_size: int, progress_base: float = 0.0, progress_scale: float = 1.0) -> bool:
	# Sur le web, télécharger le PCK via HTTPRequest puis le charger
	print("PCK TIMING [%s] _load_pck_web START at %d ms" % [pck_filename, Time.get_ticks_msec()])
	var http = HTTPRequest.new()
	_scene_tree.root.add_child(http)

	# Construire l'URL absolue à partir de l'URL de la page courante
	var base_url = JavaScriptBridge.eval("window.location.href.substring(0, window.location.href.lastIndexOf('/') + 1)")  # noqa: eval
	var url = str(base_url) + pck_filename

	var err = http.request(url)
	print("PCK TIMING [%s] http.request() called at %d ms" % [pck_filename, Time.get_ticks_msec()])
	if err != OK:
		push_error("PckChapterLoader: HTTP request error %d for %s" % [err, url])
		http.queue_free()
		return false

	# Suivre la progression via un Timer
	var progress_timer := Timer.new()
	progress_timer.wait_time = 0.1
	progress_timer.autostart = true
	_scene_tree.root.add_child(progress_timer)
	progress_timer.timeout.connect(func():
		if not is_instance_valid(http):
			return
		var downloaded = http.get_downloaded_bytes()
		var ref_size = known_size if known_size > 0 else http.get_body_size()
		if ref_size > 0:
			var p = clampf(float(downloaded) / float(ref_size), 0.0, 1.0)
			chapter_download_progress.emit(chapter_name, progress_base + p * progress_scale)
	)

	# Attendre la fin du téléchargement
	var t_wait_start := Time.get_ticks_msec()
	var result = await http.request_completed
	print("PCK TIMING [%s] await request_completed at %d ms (waited %d ms)" % [pck_filename, Time.get_ticks_msec(), Time.get_ticks_msec() - t_wait_start])

	progress_timer.stop()
	progress_timer.queue_free()
	http.queue_free()

	var response_code: int = result[1]
	var body: PackedByteArray = result[3]

	if response_code != 200:
		push_error("PckChapterLoader: failed to download %s (HTTP %d)" % [pck_filename, response_code])
		return false

	# Phase montage
	chapter_mounting_started.emit(chapter_name)

	var local_path = "user://" + pck_filename
	var t0 := Time.get_ticks_msec()
	var f = FileAccess.open(local_path, FileAccess.WRITE)
	if f == null:
		push_error("PckChapterLoader: failed to write %s" % local_path)
		return false
	f.store_buffer(body)
	f.close()
	print("PCK TIMING [%s] store_buffer+close: %d ms (abs: %d ms)" % [pck_filename, Time.get_ticks_msec() - t0, Time.get_ticks_msec()])

	var t1 := Time.get_ticks_msec()
	var success := ProjectSettings.load_resource_pack(local_path)
	print("PCK TIMING [%s] load_resource_pack: %d ms (abs: %d ms)" % [pck_filename, Time.get_ticks_msec() - t1, Time.get_ticks_msec()])
	print("PCK TIMING [%s] _load_pck_web END at %d ms" % [pck_filename, Time.get_ticks_msec()])
	return success