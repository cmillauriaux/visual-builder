extends SceneTree

## Script headless pour découper les assets d'une story en PCK par chapitre.
## Usage : godot --headless --path <project> --script res://src/export/pck_chapter_builder.gd -- --output <dir>
##
## Crée :
## - chapter_{uuid}_part{N}.pck pour chaque chapitre (max 19 Mo par PCK)
## - pck_manifest.json (liste des PCK et chapitres)
## - Supprime les assets chapitres du dossier story/ (reste dans les PCK)

const StorySaver = preload("res://src/persistence/story_saver.gd")

## Taille max par PCK en octets (19 Mo pour rester sous la limite Cloudflare de 20 Mo)
const MAX_PCK_SIZE := 19 * 1024 * 1024


func _init():
	var story_folder := "res://story"
	var output_dir := ""

	var args = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--story-folder" and i + 1 < args.size():
			story_folder = args[i + 1]
		elif args[i] == "--output" and i + 1 < args.size():
			output_dir = args[i + 1]

	if output_dir == "":
		output_dir = ProjectSettings.globalize_path(story_folder)

	print("PckChapterBuilder: splitting '%s' → '%s' (max %d Mo/PCK)" % [story_folder, output_dir, MAX_PCK_SIZE / 1024 / 1024])

	var story = StorySaver.load_story(story_folder)
	if story == null:
		printerr("PckChapterBuilder: failed to load story")
		quit(1)
		return

	# 1. Collecter les assets par chapitre
	var chapter_assets := {}  # uuid -> Array[String] (relative paths)
	var menu_assets := _collect_menu_assets(story)

	for chapter in story.chapters:
		var assets := []
		for scene in chapter.scenes:
			for sequence in scene.sequences:
				_collect_sequence_assets(sequence, assets)
		# Dédupliquer et exclure les assets menu
		var unique := {}
		for path in assets:
			if path != "" and path not in menu_assets:
				unique[path] = true
		chapter_assets[chapter.uuid] = unique.keys()

	# 2. Résoudre tous les fichiers associés (raw + .import + .ctex/.mp3str importés)
	var abs_story := ProjectSettings.globalize_path(story_folder)
	var abs_project := ProjectSettings.globalize_path("res://")
	var chapter_file_groups := {}  # uuid -> Array of { files: [[res_path, abs_path]], total_size: int }

	for uuid in chapter_assets:
		var groups := []
		for asset_path in chapter_assets[uuid]:
			var file_entries := _resolve_asset_files(asset_path, abs_story, abs_project)
			var total := 0
			for entry in file_entries:
				var fa = FileAccess.open(entry[1], FileAccess.READ)
				if fa:
					total += fa.get_length()
					fa.close()
			groups.append({"files": file_entries, "total_size": total, "asset_path": asset_path})
		chapter_file_groups[uuid] = groups

	# 3. Créer les PCK par chapitre (découpés en parts de max MAX_PCK_SIZE)
	var manifest := {"chapters": {}}
	var total_pck_count := 0

	for chapter in story.chapters:
		var uuid = chapter.uuid
		var groups: Array = chapter_file_groups.get(uuid, [])
		if groups.is_empty():
			print("  Chapter '%s' has no assets, skipping PCK" % chapter.chapter_name)
			continue

		var chunks := _split_groups_into_chunks(groups)
		var pck_filenames := []

		var total_files := 0
		for g in groups:
			total_files += g["files"].size()
		print("  Chapter '%s': %d assets (%d files with imports) → %d PCK(s)" % [chapter.chapter_name, groups.size(), total_files, chunks.size()])

		for chunk_idx in range(chunks.size()):
			var chunk: Array = chunks[chunk_idx]
			var pck_filename = "chapter_%s_part%d.pck" % [uuid, chunk_idx + 1]
			var pck_path = output_dir + "/" + pck_filename

			var packer = PCKPacker.new()
			var err = packer.pck_start(pck_path)
			if err != OK:
				printerr("  Failed to create PCK: %s" % pck_path)
				continue

			var chunk_size := 0
			var file_count := 0
			for group in chunk:
				for entry in group["files"]:
					var res_path: String = entry[0]
					var abs_path: String = entry[1]
					if FileAccess.file_exists(abs_path):
						packer.add_file(res_path, abs_path)
						var fa = FileAccess.open(abs_path, FileAccess.READ)
						if fa:
							chunk_size += fa.get_length()
							fa.close()
						file_count += 1

			packer.flush()
			pck_filenames.append(pck_filename)
			total_pck_count += 1
			print("    %s (%d files, %.1f Mo)" % [pck_filename, file_count, chunk_size / 1048576.0])

		manifest["chapters"][uuid] = {
			"pcks": pck_filenames,
			"name": chapter.chapter_name
		}

	# 4. Écrire le manifest
	var manifest_path = abs_story + "/pck_manifest.json"
	var f = FileAccess.open(manifest_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(manifest, "\t"))
		f.close()
		print("  Manifest written: %s" % manifest_path)

	# 5. Supprimer les assets chapitres du projet temp (raw + .import + fichiers importés)
	var removed_count := 0
	for uuid in chapter_file_groups:
		for group in chapter_file_groups[uuid]:
			# Supprimer les fichiers inclus dans les PCK (.import + .ctex/.mp3str)
			for entry in group["files"]:
				var abs_path: String = entry[1]
				if FileAccess.file_exists(abs_path):
					DirAccess.remove_absolute(abs_path)
					removed_count += 1
			# Supprimer aussi le fichier raw source (non inclus dans le PCK mais à retirer du core)
			var raw_path = abs_story + "/" + group["asset_path"]
			if FileAccess.file_exists(raw_path):
				DirAccess.remove_absolute(raw_path)
				removed_count += 1

	print("PckChapterBuilder: done — %d PCKs created, %d files moved" % [total_pck_count, removed_count])
	quit(0)


## Résout les fichiers importés d'un asset : .import metadata + .ctex/.mp3str importé.
## Les fichiers bruts (.png, .mp3) ne sont PAS inclus car Godot utilise uniquement
## les versions importées au runtime.
## Retourne un Array de [res_path, abs_path].
func _resolve_asset_files(asset_path: String, abs_story: String, abs_project: String) -> Array:
	var files := []  # Array of [res_path, abs_path]

	var abs_raw = abs_story + "/" + asset_path
	var res_raw = "res://story/" + asset_path

	# 1. Fichier .import (ex: assets/backgrounds/image.png.import)
	var abs_import = abs_raw + ".import"
	var res_import = res_raw + ".import"
	if FileAccess.file_exists(abs_import):
		files.append([res_import, abs_import])

		# 3. Parser le .import pour trouver le fichier importé (.ctex, .mp3str, etc.)
		var import_file = FileAccess.open(abs_import, FileAccess.READ)
		if import_file:
			var import_text = import_file.get_as_text()
			import_file.close()
			for line in import_text.split("\n"):
				var stripped = line.strip_edges()
				if stripped.begins_with("path="):
					var value = stripped.substr(5).strip_edges()
					# Enlever les guillemets
					if value.begins_with("\"") and value.ends_with("\""):
						value = value.substr(1, value.length() - 2)
					if value.begins_with("res://"):
						var rel_from_project = value.substr(6)  # Enlever "res://"
						var abs_imported = abs_project + rel_from_project
						if FileAccess.file_exists(abs_imported):
							files.append([value, abs_imported])
						else:
							print("    Warning: imported file not found: %s" % abs_imported)
					break  # Un seul path= suffit

	return files


## Répartit les groupes d'assets en chunks ne dépassant pas MAX_PCK_SIZE chacun.
## Chaque groupe contient tous les fichiers d'un asset (raw + .import + .ctex).
func _split_groups_into_chunks(groups: Array) -> Array:
	# Trier par taille décroissante (bin packing greedy)
	var sorted_groups = groups.duplicate()
	sorted_groups.sort_custom(func(a, b): return a["total_size"] > b["total_size"])

	var chunks := []  # Array of Array[group]
	var chunk_sizes := []  # Taille courante de chaque chunk

	for group in sorted_groups:
		var size: int = group["total_size"]

		# Trouver un chunk qui peut accueillir ce groupe
		var placed := false
		for i in range(chunks.size()):
			if chunk_sizes[i] + size <= MAX_PCK_SIZE:
				chunks[i].append(group)
				chunk_sizes[i] += size
				placed = true
				break

		if not placed:
			chunks.append([group])
			chunk_sizes.append(size)

	if chunks.is_empty():
		chunks.append([])

	return chunks


func _collect_menu_assets(story) -> Dictionary:
	var assets := {}
	if story.menu_background != "":
		assets[story.menu_background] = true
	if story.menu_music != "":
		assets[story.menu_music] = true
	if story.get("game_over_background") and story.game_over_background != "":
		assets[story.game_over_background] = true
	if story.get("to_be_continued_background") and story.to_be_continued_background != "":
		assets[story.to_be_continued_background] = true
	if story.get("app_icon") and story.app_icon != "":
		assets[story.app_icon] = true
	return assets


func _collect_sequence_assets(sequence, assets: Array) -> void:
	if sequence.background != "":
		assets.append(sequence.background)
	if sequence.music != "":
		assets.append(sequence.music)
	if sequence.audio_fx != "":
		assets.append(sequence.audio_fx)

	for fg in sequence.foregrounds:
		if fg.image != "":
			assets.append(fg.image)

	for dialogue in sequence.dialogues:
		for fg in dialogue.foregrounds:
			if fg.image != "":
				assets.append(fg.image)
