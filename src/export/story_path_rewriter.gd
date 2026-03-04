extends RefCounted

## Réécrit les chemins d'images d'une story pour l'export.
## Transforme les chemins absolus user:// en chemins res:// relatifs au dossier story embarqué.

const StorySaver = preload("res://src/persistence/story_saver.gd")


static func rewrite_story_paths(story_folder: String, new_base: String) -> bool:
	var story = StorySaver.load_story(story_folder)
	if story == null:
		return false

	# Réécrire le background du menu
	story.menu_background = _rewrite_path(story.menu_background, new_base, "backgrounds")

	for chapter in story.chapters:
		for scene in chapter.scenes:
			for sequence in scene.sequences:
				_rewrite_sequence_paths(sequence, new_base)

	StorySaver.save_story(story, story_folder)
	return true


static func _rewrite_sequence_paths(sequence, new_base: String) -> void:
	sequence.background = _rewrite_path(sequence.background, new_base, "backgrounds")

	for fg in sequence.foregrounds:
		fg.image = _rewrite_path(fg.image, new_base, "foregrounds")

	for dialogue in sequence.dialogues:
		for fg in dialogue.foregrounds:
			fg.image = _rewrite_path(fg.image, new_base, "foregrounds")


static func _rewrite_path(path: String, new_base: String, subfolder: String) -> String:
	if path == "":
		return ""
	if not path.begins_with("user://"):
		return path
	var filename = path.get_file()
	return new_base + "/assets/" + subfolder + "/" + filename
