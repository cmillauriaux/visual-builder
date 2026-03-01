extends RefCounted

## Service de renommage d'images dans la galerie.
## Gère : validation du format, renommage sur disque, mise à jour des références
## dans le modèle Story, et transfert des assignations de catégories.

const VALID_NAME_REGEX := "^[a-zA-Z0-9_\\-\\.]+$"


static func validate_name_format(name: String) -> String:
	## Valide uniquement le format du nom (non vide, caractères autorisés).
	## Retourne "" si valide, sinon un message d'erreur localisé.
	var trimmed := name.strip_edges()
	if trimmed == "":
		return "Le nom ne peut pas être vide."
	var regex := RegEx.new()
	regex.compile(VALID_NAME_REGEX)
	if regex.search(trimmed) == null:
		return "Caractères invalides. Utilisez uniquement lettres, chiffres, tirets, underscores ou points."
	return ""


static func rename(old_path: String, new_name: String, category_service = null) -> Dictionary:
	## Renomme un fichier image sur le disque et transfère les catégories.
	## Retourne {"ok": bool, "error": String, "new_path": String, "same_name": bool}
	var trimmed := new_name.strip_edges()

	var format_error := validate_name_format(trimmed)
	if format_error != "":
		return {"ok": false, "error": format_error, "new_path": "", "same_name": false}

	var old_name_no_ext := old_path.get_file().get_basename()
	if trimmed == old_name_no_ext:
		return {"ok": true, "error": "", "new_path": old_path, "same_name": true}

	var ext := "." + old_path.get_extension()
	var dir_path := old_path.get_base_dir()
	var new_path := dir_path.path_join(trimmed + ext)

	if FileAccess.file_exists(new_path):
		return {"ok": false, "error": "Ce nom est déjà utilisé.", "new_path": "", "same_name": false}

	var err := DirAccess.rename_absolute(old_path, new_path)
	if err != OK:
		return {"ok": false, "error": "Le renommage a échoué.", "new_path": "", "same_name": false}

	if category_service != null:
		_transfer_categories(category_service, old_path, new_path)

	return {"ok": true, "error": "", "new_path": new_path, "same_name": false}


static func update_story_references(story, old_path: String, new_path: String) -> int:
	## Met à jour toutes les propriétés du modèle Story référençant old_path.
	## Retourne le nombre de références modifiées.
	var count := 0
	if story == null:
		return count

	if story.menu_background == old_path:
		story.menu_background = new_path
		count += 1

	for chapter in story.chapters:
		for scene in chapter.scenes:
			for seq in scene.sequences:
				if seq.background == old_path:
					seq.background = new_path
					count += 1
				for fg in seq.foregrounds:
					if fg.image == old_path:
						fg.image = new_path
						count += 1
				for dlg in seq.dialogues:
					for fg in dlg.foregrounds:
						if fg.image == old_path:
							fg.image = new_path
							count += 1
	return count


static func _transfer_categories(category_service, old_path: String, new_path: String) -> void:
	var img_cat_svc := load("res://src/services/image_category_service.gd")
	var old_key: String = img_cat_svc.path_to_key(old_path)
	var new_key: String = img_cat_svc.path_to_key(new_path)
	var cats: Array = category_service.get_image_categories(old_key)
	for cat in cats:
		category_service.assign_image_to_category(new_key, cat)
	for cat in cats:
		category_service.unassign_image_from_category(old_key, cat)
