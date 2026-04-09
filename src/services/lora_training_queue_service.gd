# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Gère la file d'attente de génération de datasets LoRA (variations d'images).
##
## Chaque item représente soit une image source (COMPLETED, variation_prompt="reference image")
## soit une variation à générer (PENDING, variation_prompt=la variation demandée).
##
## Ordre : pour chaque source, l'item source est inséré en premier, suivi de ses variations.

class_name LoraTrainingQueueService

enum ItemStatus { PENDING, GENERATING, COMPLETED, FAILED }

var _items: Array = []
var _cancelled: bool = false


## Construit la file depuis un tableau de chemins sources, un keyword LoRA et un tableau de variations.
## Pour chaque source : 1 item COMPLETED (reference image) + N items PENDING (1 par variation).
func build_queue(sources: Array, keyword: String, variations: Array) -> void:
	_items.clear()
	_cancelled = false
	for source in sources:
		# Item source (image de référence, déjà disponible)
		_items.append({
			"source_image_path": source,
			"keyword": keyword,
			"variation_prompt": "reference image",
			"status": ItemStatus.COMPLETED,
			"image": null,
			"caption": "%s, reference image" % keyword,
		})
		# Items variation à générer
		for variation in variations:
			_items.append({
				"source_image_path": source,
				"keyword": keyword,
				"variation_prompt": variation,
				"status": ItemStatus.PENDING,
				"image": null,
				"caption": "%s, %s" % [keyword, variation],
			})


func get_all_items() -> Array:
	return _items


func get_total() -> int:
	return _items.size()


func get_completed_count() -> int:
	var count := 0
	for item in _items:
		if item["status"] == ItemStatus.COMPLETED:
			count += 1
	return count


func get_next_pending_index() -> int:
	for i in range(_items.size()):
		if _items[i]["status"] == ItemStatus.PENDING:
			return i
	return -1


func mark_generating(index: int) -> void:
	_items[index]["status"] = ItemStatus.GENERATING


func mark_completed(index: int, image: Image) -> void:
	_items[index]["status"] = ItemStatus.COMPLETED
	_items[index]["image"] = image


func mark_failed(index: int, error: String = "") -> void:
	_items[index]["status"] = ItemStatus.FAILED
	if error != "":
		_items[index]["error"] = error


func cancel() -> void:
	_cancelled = true
	for item in _items:
		if item["status"] == ItemStatus.PENDING:
			item["status"] = ItemStatus.FAILED


func is_cancelled() -> bool:
	return _cancelled


func clear() -> void:
	_items.clear()
	_cancelled = false


func remove_item(index: int) -> void:
	_items.remove_at(index)


func reset_item(index: int) -> void:
	_items[index]["status"] = ItemStatus.PENDING
	_items[index]["image"] = null
