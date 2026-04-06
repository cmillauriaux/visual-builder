# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Gère la file d'attente de génération par lots pour les expressions faciales.

enum ItemStatus { PENDING, GENERATING, COMPLETED, FAILED }

var _items: Array = []
var _current_index: int = -1
var _cancelled: bool = false


func build_queue(expressions: Array, prefix: String, hint: String = "") -> void:
	_items.clear()
	_current_index = -1
	_cancelled = false
	for expr in expressions:
		_items.append({
			"expression": expr,
			"prompt": _build_prompt(expr, hint),
			"filename": _build_filename(prefix, expr),
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


static func _build_prompt(expression: String, hint: String = "") -> String:
	var person_part: String
	if hint == "":
		person_part = "keep the same person"
	else:
		person_part = "keep the same person (%s)" % hint
	return "%s, only change facial expression to %s, adjust face muscles only, keep all colors and details of the original image, keep exactly the same eye color as the original image, do not recolor irises, light color correction only" % [person_part, expression]


static func _build_filename(prefix: String, expression: String) -> String:
	var expr_slug = expression.replace(" ", "_")
	if prefix == "":
		return expr_slug
	return "%s_%s" % [prefix, expr_slug]