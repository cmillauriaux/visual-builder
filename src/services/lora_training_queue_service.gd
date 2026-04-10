# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Gère la file d'attente de génération de datasets LoRA (variations d'images).
##
## Chaque item représente une variation à générer (PENDING, variation_prompt=la variation demandée).
## Le source_image_path est déterminé automatiquement par detect_base() sur la variation.
##
## Les bases (images de référence) sont gérées séparément par l'orchestrateur.

class_name LoraTrainingQueueService

## Détecte le slot de base à utiliser pour une variation donnée.
## Priorité (premier match) :
##   1. "close-up"                         → "closeup"
##   2. "full body"                         → "full_body"
##   3. "upper body" ou "waist up"          → "buste"
##   4. "three-quarter"                     → "three_quarter"
##   5. "looking over shoulder" ou "profile"→ "profile"
##   6. (défaut)                            → "portrait"
static func detect_base(caption: String) -> String:
	if "close-up" in caption:
		return "closeup"
	if "full body" in caption:
		return "full_body"
	if "upper body" in caption or "waist up" in caption:
		return "buste"
	if "three-quarter" in caption:
		return "three_quarter"
	if "looking over shoulder" in caption or "profile" in caption:
		return "profile"
	return "portrait"

enum ItemStatus { PENDING, GENERATING, COMPLETED, FAILED }

var _items: Array = []
var _cancelled: bool = false


## Construit la file depuis un dict de bases, un keyword LoRA et un tableau de variations.
## Pour chaque variation, le source_image_path est la base correspondante (via detect_base()).
## Aucun item "reference image" — les bases sont gérées séparément dans l'orchestrateur.
func build_queue(bases: Dictionary, keyword: String, variations: Array) -> void:
	_items.clear()
	_cancelled = false
	for variation in variations:
		var base_key = detect_base(variation)
		var source_path = bases[base_key]["path"] if bases.has(base_key) else ""
		_items.append({
			"source_image_path": source_path,
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
