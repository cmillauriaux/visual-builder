# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Réécrit les chemins d'assets d'une story pour l'export.
## Transforme les chemins absolus (user://, chemins système) en chemins res://
## relatifs au dossier story embarqué.

const StorySaver = preload("res://src/persistence/story_saver.gd")


static func rewrite_story_paths(story_folder: String, new_base: String) -> bool:
	var story = StorySaver.load_story(story_folder)
	if story == null:
		return false

	# Réécrire les assets du menu
	story.menu_background = _rewrite_path(story.menu_background, new_base, "backgrounds")
	story.menu_music = _rewrite_path(story.menu_music, new_base, "music")

	# Réécrire l'icône de l'application
	if story.get("app_icon") and story.app_icon != "":
		story.app_icon = _rewrite_path(story.app_icon, new_base, "icons")

	# Réécrire les assets game_over et to_be_continued
	if story.get("game_over_background") and story.game_over_background != "":
		story.game_over_background = _rewrite_path(story.game_over_background, new_base, "backgrounds")
	if story.get("to_be_continued_background") and story.to_be_continued_background != "":
		story.to_be_continued_background = _rewrite_path(story.to_be_continued_background, new_base, "backgrounds")

	for chapter in story.chapters:
		for scene in chapter.scenes:
			for sequence in scene.sequences:
				_rewrite_sequence_paths(sequence, new_base)

	StorySaver.save_story(story, story_folder)
	return true


static func _rewrite_sequence_paths(sequence, new_base: String) -> void:
	sequence.background = _rewrite_path(sequence.background, new_base, "backgrounds")
	sequence.music = _rewrite_path(sequence.music, new_base, "music")
	sequence.audio_fx = _rewrite_path(sequence.audio_fx, new_base, "fx")

	for fg in sequence.foregrounds:
		fg.image = _rewrite_path(fg.image, new_base, "foregrounds")

	for dialogue in sequence.dialogues:
		for fg in dialogue.foregrounds:
			fg.image = _rewrite_path(fg.image, new_base, "foregrounds")
		for lang in dialogue.voice_files:
			dialogue.voice_files[lang] = _rewrite_path(dialogue.voice_files[lang], new_base, "voices")


static func _rewrite_path(path: String, new_base: String, subfolder: String) -> String:
	if path == "":
		return ""
	# Déjà un chemin res:// valide — ne pas réécrire
	if path.begins_with("res://"):
		return path
	# Chemins user:// → réécrire
	if path.begins_with("user://"):
		var filename = path.get_file()
		return new_base + "/assets/" + subfolder + "/" + filename
	# Chemins absolus système (C:/..., D:\..., /home/...) → réécrire
	if path.begins_with("/") or (path.length() >= 3 and path[1] == ":" and (path[2] == "/" or path[2] == "\\")):
		var filename = path.get_file()
		return new_base + "/assets/" + subfolder + "/" + filename
	# Chemin relatif déjà correct — ne pas modifier
	return path