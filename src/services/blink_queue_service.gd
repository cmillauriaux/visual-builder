extends RefCounted

## Gère la file d'attente de génération par lots pour les clignements d'yeux.
## Itère sur N images sources avec 1 prompt fixe.

enum ItemStatus { PENDING, GENERATING, COMPLETED, FAILED }

const BLINK_PROMPT := "keep the same person, close both eyes gently as in a natural blink, adjust eyelids only, keep all colors and details of the original image, keep exactly the same eye color undertone, light color correction only"

var _items: Array = []
var _current_index: int = -1
var _cancelled: bool = false


func build_queue(source_paths: Array) -> void:
	_items.clear()
	_current_index = -1
	_cancelled = false
	for path in source_paths:
		_items.append({
			"source_path": path,
			"blink_filename": _build_blink_filename(path),
			"prompt": BLINK_PROMPT,
			"status": ItemStatus.PENDING,
			"image": null,
		})


func get_items() -> Array:
	return _items


func get_total() -> int:
	return _items.size()


func get_current_index() -> int:
	return _current_index


func get_next_pending_index() -> int:
	for i in range(_items.size()):
		if _items[i]["status"] == ItemStatus.PENDING:
			return i
	return -1


func mark_generating(index: int) -> void:
	_items[index]["status"] = ItemStatus.GENERATING
	_current_index = index


func mark_completed(index: int, image: Image) -> void:
	_items[index]["status"] = ItemStatus.COMPLETED
	_items[index]["image"] = image


func mark_failed(index: int, error: String) -> void:
	_items[index]["status"] = ItemStatus.FAILED
	_items[index]["error"] = error


func cancel() -> void:
	_cancelled = true


func is_cancelled() -> bool:
	return _cancelled


func get_completed_count() -> int:
	var count := 0
	for item in _items:
		if item["status"] == ItemStatus.COMPLETED:
			count += 1
	return count


func get_done_count() -> int:
	var count := 0
	for item in _items:
		if item["status"] == ItemStatus.COMPLETED or item["status"] == ItemStatus.FAILED:
			count += 1
	return count


func get_completed_items() -> Array:
	return _items.filter(func(item): return item["status"] == ItemStatus.COMPLETED)


func reset_item(index: int) -> void:
	_items[index]["status"] = ItemStatus.PENDING
	_items[index]["image"] = null
	if _items[index].has("error"):
		_items[index].erase("error")


func remove_item(index: int) -> void:
	_items.remove_at(index)
	if _current_index >= _items.size():
		_current_index = _items.size() - 1


static func _build_blink_filename(source_path: String) -> String:
	var base := source_path.get_basename()
	var ext := source_path.get_extension()
	if ext == "":
		return base + "_blink"
	return base + "_blink." + ext
