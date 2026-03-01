extends RefCounted

## Service de gestion des catégories d'images.
## Permet d'organiser les images (backgrounds/foregrounds) en catégories,
## avec persistance YAML.

signal categories_changed

const YamlParser = preload("res://src/persistence/yaml_parser.gd")

const DEFAULT_CATEGORIES := ["Base", "NPC", "Character"]
const CATEGORIES_FILE := "assets/categories.yaml"

var _categories: Array = []
var _assignments: Dictionary = {}


func _init() -> void:
	_categories = DEFAULT_CATEGORIES.duplicate()


func get_categories() -> Array:
	return _categories.duplicate()


func add_category(name: String) -> void:
	if name in _categories:
		return
	_categories.append(name)
	categories_changed.emit()


func rename_category(old_name: String, new_name: String) -> void:
	var idx = _categories.find(old_name)
	if idx < 0:
		return
	if new_name in _categories:
		return
	_categories[idx] = new_name
	for image_key in _assignments:
		var cats: Array = _assignments[image_key]
		var cat_idx = cats.find(old_name)
		if cat_idx >= 0:
			cats[cat_idx] = new_name
	categories_changed.emit()


func remove_category(name: String) -> void:
	var idx = _categories.find(name)
	if idx < 0:
		return
	_categories.remove_at(idx)
	for image_key in _assignments:
		var cats: Array = _assignments[image_key]
		cats.erase(name)
	# Nettoyer les assignments vides
	var to_remove := []
	for image_key in _assignments:
		if (_assignments[image_key] as Array).is_empty():
			to_remove.append(image_key)
	for key in to_remove:
		_assignments.erase(key)
	categories_changed.emit()


func assign_image_to_category(image_key: String, category: String) -> void:
	if category not in _categories:
		return
	if image_key not in _assignments:
		_assignments[image_key] = []
	var cats: Array = _assignments[image_key]
	if category not in cats:
		cats.append(category)


func unassign_image_from_category(image_key: String, category: String) -> void:
	if image_key not in _assignments:
		return
	var cats: Array = _assignments[image_key]
	cats.erase(category)
	if cats.is_empty():
		_assignments.erase(image_key)


func is_image_in_category(image_key: String, category: String) -> bool:
	if image_key not in _assignments:
		return false
	return category in (_assignments[image_key] as Array)


func get_image_categories(image_key: String) -> Array:
	if image_key not in _assignments:
		return []
	return (_assignments[image_key] as Array).duplicate()


func get_assigned_image_count(category: String) -> int:
	var count := 0
	for image_key in _assignments:
		if category in (_assignments[image_key] as Array):
			count += 1
	return count


func filter_paths_by_category(paths: Array, category: String) -> Array:
	var result := []
	for path in paths:
		var key = _path_to_key(path)
		if is_image_in_category(key, category):
			result.append(path)
	return result


func save_to(base_path: String) -> void:
	var file_path = base_path + "/" + CATEGORIES_FILE
	var dir_path = file_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	var data := {}
	data["categories"] = _categories.duplicate()

	var assignments_list := []
	for image_key in _assignments:
		var cats: Array = _assignments[image_key]
		if not cats.is_empty():
			assignments_list.append({
				"image": image_key,
				"categories": cats.duplicate()
			})
	data["assignments"] = assignments_list

	var yaml = YamlParser.dict_to_yaml(data)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(yaml)
		file.close()


func load_from(base_path: String) -> void:
	var file_path = base_path + "/" + CATEGORIES_FILE
	if not FileAccess.file_exists(file_path):
		_categories = DEFAULT_CATEGORIES.duplicate()
		_assignments = {}
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_categories = DEFAULT_CATEGORIES.duplicate()
		_assignments = {}
		return

	var content = file.get_as_text()
	file.close()

	var data = YamlParser.yaml_to_dict(content)

	if "categories" in data and data["categories"] is Array:
		_categories = []
		for cat in data["categories"]:
			_categories.append(str(cat))
	else:
		_categories = DEFAULT_CATEGORIES.duplicate()

	_assignments = {}
	if "assignments" in data and data["assignments"] is Array:
		for entry in data["assignments"]:
			if entry is Dictionary and "image" in entry and "categories" in entry:
				var image_key = str(entry["image"])
				var cats := []
				if entry["categories"] is Array:
					for c in entry["categories"]:
						cats.append(str(c))
				_assignments[image_key] = cats


static func _path_to_key(path: String) -> String:
	# Extrait "backgrounds/file.png" ou "foregrounds/file.png" d'un chemin absolu
	var bg_idx = path.find("/backgrounds/")
	if bg_idx >= 0:
		return path.substr(bg_idx + 1)
	var fg_idx = path.find("/foregrounds/")
	if fg_idx >= 0:
		return path.substr(fg_idx + 1)
	return path.get_file()


static func path_to_key(path: String) -> String:
	return _path_to_key(path)
