extends RefCounted

## Service de détection et nettoyage des images non utilisées dans la galerie.


static func collect_used_images(story) -> Array:
	var result := []
	if story == null:
		return result

	if story.menu_background != "":
		result.append(story.menu_background)

	for chapter in story.chapters:
		for scene in chapter.scenes:
			for seq in scene.sequences:
				if seq.background != "":
					result.append(seq.background)
				for fg in seq.foregrounds:
					if fg.image != "":
						result.append(fg.image)
				for dlg in seq.dialogues:
					for fg in dlg.foregrounds:
						if fg.image != "":
							result.append(fg.image)
	return result


static func find_unused_images(story_base_path: String, used_images: Array) -> Dictionary:
	var result := {"backgrounds": [], "foregrounds": []}

	var bg_dir = story_base_path + "/assets/backgrounds"
	var fg_dir = story_base_path + "/assets/foregrounds"

	result["backgrounds"] = _find_unused_in_dir(bg_dir, used_images)
	result["foregrounds"] = _find_unused_in_dir(fg_dir, used_images)

	return result


static func _find_unused_in_dir(dir_path: String, used_images: Array) -> Array:
	var unused := []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return unused

	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var ext = fname.get_extension().to_lower()
			if ext in ["png", "jpg", "jpeg", "webp"]:
				var full_path = dir_path + "/" + fname
				if full_path not in used_images:
					unused.append(full_path)
		fname = dir.get_next()
	dir.list_dir_end()
	return unused


static func calculate_total_size(file_paths: Array) -> int:
	var total := 0
	for path in file_paths:
		var file = FileAccess.open(path, FileAccess.READ)
		if file != null:
			total += file.get_length()
			file.close()
	return total


static func delete_files(file_paths: Array) -> int:
	var count := 0
	for path in file_paths:
		if FileAccess.file_exists(path):
			var err = DirAccess.remove_absolute(path)
			if err == OK:
				count += 1
	return count
