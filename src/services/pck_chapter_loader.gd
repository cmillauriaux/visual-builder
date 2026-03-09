extends RefCounted

## Charge les PCK chapitres à la demande.
## Sur desktop : charge directement depuis le filesystem.
## Sur web : télécharge via HTTPRequest puis charge.

class_name PckChapterLoader

signal chapter_load_started(chapter_name: String)
signal chapter_load_progress(chapter_name: String, progress: float)
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
	var pck_filenames: Array = []
	if chapter_info.has("pcks"):
		pck_filenames = chapter_info.get("pcks", [])
	elif chapter_info.has("pck"):
		var single: String = chapter_info.get("pck", "")
		if single != "":
			pck_filenames = [single]

	if pck_filenames.is_empty():
		return true

	chapter_load_started.emit(chapter_name)

	var all_success := true

	if OS.get_name() == "Web" and pck_filenames.size() > 1:
		all_success = await _load_pcks_web_parallel(pck_filenames, chapter_name)
	else:
		for i in range(pck_filenames.size()):
			var pck_filename: String = pck_filenames[i]
			var part_progress_base := float(i) / float(pck_filenames.size())
			var part_progress_scale := 1.0 / float(pck_filenames.size())

			var success := false
			if OS.get_name() == "Web":
				success = await _load_pck_web(pck_filename, chapter_name, part_progress_base, part_progress_scale)
			else:
				success = _load_pck_desktop(pck_filename)

			if not success:
				push_error("PckChapterLoader: failed to load %s" % pck_filename)
				all_success = false
				break

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
func _load_pcks_web_parallel(pck_filenames: Array, chapter_name: String) -> bool:
	var t_start := Time.get_ticks_msec()
	print("PCK PARALLEL: starting %d downloads at %d ms" % [pck_filenames.size(), t_start])

	var base_url = JavaScriptBridge.eval("window.location.href.substring(0, window.location.href.lastIndexOf('/') + 1)")
	var count := pck_filenames.size()

	# Lancer toutes les requêtes HTTP simultanément
	var http_nodes: Array[HTTPRequest] = []
	var results: Array = []  # Array de Variant (null = pas encore fini)
	results.resize(count)

	for i in range(count):
		var pck_filename: String = pck_filenames[i]
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

	# Timer de progression agrégée
	var progress_timer := Timer.new()
	progress_timer.wait_time = 0.1
	progress_timer.autostart = true
	_scene_tree.root.add_child(progress_timer)
	progress_timer.timeout.connect(func():
		var total_downloaded := 0
		var total_size := 0
		for h in http_nodes:
			if is_instance_valid(h):
				var bs = h.get_body_size()
				if bs > 0:
					total_size += bs
					total_downloaded += h.get_downloaded_bytes()
		if total_size > 0:
			chapter_load_progress.emit(chapter_name, float(total_downloaded) / float(total_size))
	)

	# Attendre que tous les téléchargements soient terminés
	# On poll via un Timer court au lieu d'await sur chaque signal individuel
	# pour éviter les race conditions (signal déjà émis avant l'await)
	while true:
		var all_done := true
		for i in range(count):
			if results[i] == null:
				all_done = false
				break
		if all_done:
			break
		# Attendre la prochaine frame
		await _scene_tree.process_frame

	progress_timer.stop()
	progress_timer.queue_free()

	# Nettoyer les HTTPRequest nodes
	for h in http_nodes:
		if is_instance_valid(h):
			h.queue_free()

	print("PCK PARALLEL: all downloads done at %d ms (total download: %d ms)" % [Time.get_ticks_msec(), Time.get_ticks_msec() - t_start])

	# Monter les PCK séquentiellement (l'ordre peut compter pour les overrides)
	for i in range(count):
		var pck_filename: String = pck_filenames[i]
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

	chapter_load_progress.emit(chapter_name, 1.0)
	print("PCK PARALLEL: total time: %d ms" % [Time.get_ticks_msec() - t_start])
	return true


func _load_pck_web(pck_filename: String, chapter_name: String, progress_base: float = 0.0, progress_scale: float = 1.0) -> bool:
	# Sur le web, télécharger le PCK via HTTPRequest puis le charger
	print("PCK TIMING [%s] _load_pck_web START at %d ms" % [pck_filename, Time.get_ticks_msec()])
	var http = HTTPRequest.new()
	_scene_tree.root.add_child(http)

	# Construire l'URL absolue à partir de l'URL de la page courante
	var base_url = JavaScriptBridge.eval("window.location.href.substring(0, window.location.href.lastIndexOf('/') + 1)")
	var url = str(base_url) + pck_filename

	var err = http.request(url)
	print("PCK TIMING [%s] http.request() called at %d ms" % [pck_filename, Time.get_ticks_msec()])
	if err != OK:
		push_error("PckChapterLoader: HTTP request error %d for %s" % [err, url])
		http.queue_free()
		return false

	# Suivre la progression via un Timer (pas de boucle while pour éviter
	# une race condition avec le signal request_completed)
	var progress_timer := Timer.new()
	progress_timer.wait_time = 0.1
	progress_timer.autostart = true
	_scene_tree.root.add_child(progress_timer)
	progress_timer.timeout.connect(func():
		if not is_instance_valid(http):
			return
		var body_size = http.get_body_size()
		var downloaded = http.get_downloaded_bytes()
		if body_size > 0:
			var p = float(downloaded) / float(body_size)
			chapter_load_progress.emit(chapter_name, progress_base + p * progress_scale)
	)

	# Attendre la fin du téléchargement (await direct, pas de polling)
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

	# Écrire dans user:// pour que load_resource_pack puisse y accéder
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
	chapter_load_progress.emit(chapter_name, progress_base + progress_scale)

	var success := ProjectSettings.load_resource_pack(local_path)
	print("PCK TIMING [%s] load_resource_pack: %d ms (abs: %d ms)" % [pck_filename, Time.get_ticks_msec() - t1, Time.get_ticks_msec()])
	print("PCK TIMING [%s] _load_pck_web END at %d ms" % [pck_filename, Time.get_ticks_msec()])
	return success
