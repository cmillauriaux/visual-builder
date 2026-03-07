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


func _load_pck_web(pck_filename: String, chapter_name: String, progress_base: float = 0.0, progress_scale: float = 1.0) -> bool:
	# Sur le web, télécharger le PCK via HTTPRequest puis le charger
	var http = HTTPRequest.new()
	_scene_tree.root.add_child(http)

	# Construire l'URL absolue à partir de l'URL de la page courante
	var base_url = JavaScriptBridge.eval("window.location.href.substring(0, window.location.href.lastIndexOf('/') + 1)")
	var url = str(base_url) + pck_filename

	var err = http.request(url)
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
	var result = await http.request_completed

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
	var f = FileAccess.open(local_path, FileAccess.WRITE)
	if f == null:
		push_error("PckChapterLoader: failed to write %s" % local_path)
		return false
	f.store_buffer(body)
	f.close()

	chapter_load_progress.emit(chapter_name, progress_base + progress_scale)

	return ProjectSettings.load_resource_pack(local_path)
