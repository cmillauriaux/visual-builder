# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends GutTest

var LoraTrainingQueueServiceScript

func before_each():
	LoraTrainingQueueServiceScript = load("res://src/services/lora_training_queue_service.gd")


func test_build_queue_creates_variation_items():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png", "img2.png"], "hero", ["front view", "side view", "back view"])
	var items = svc.get_all_items()
	var pending_count = 0
	for item in items:
		if item["status"] == LoraTrainingQueueServiceScript.ItemStatus.PENDING:
			pending_count += 1
	assert_eq(pending_count, 6, "2 sources × 3 variations = 6 PENDING variation items")


func test_build_queue_adds_source_items_as_completed():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png", "img2.png"], "hero", ["front view", "side view"])
	var items = svc.get_all_items()
	var completed_sources: Array = []
	for item in items:
		if item["status"] == LoraTrainingQueueServiceScript.ItemStatus.COMPLETED and item["variation_prompt"] == "reference image":
			completed_sources.append(item)
	assert_eq(completed_sources.size(), 2, "2 sources → 2 COMPLETED items with variation_prompt 'reference image'")
	assert_eq(completed_sources[0]["source_image_path"], "img1.png")
	assert_eq(completed_sources[1]["source_image_path"], "img2.png")


func test_build_queue_total():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png", "img2.png"], "hero", ["front view", "side view", "back view"])
	assert_eq(svc.get_total(), 8, "2 sources + (2 × 3 variations) = 8 total items")


func test_caption_format():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png"], "hero", ["front view, standing, white background"])
	var items = svc.get_all_items()
	var variation_item = null
	for item in items:
		if item["variation_prompt"] != "reference image":
			variation_item = item
			break
	assert_not_null(variation_item)
	assert_eq(variation_item["caption"], "hero, front view, standing, white background")


func test_source_item_caption():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png"], "hero", ["front view"])
	var items = svc.get_all_items()
	var source_item = null
	for item in items:
		if item["variation_prompt"] == "reference image":
			source_item = item
			break
	assert_not_null(source_item)
	assert_eq(source_item["caption"], "hero, reference image")


func test_get_next_pending_returns_first_pending():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png"], "hero", ["front view", "side view"])
	# source items are COMPLETED, variation items are PENDING
	var idx = svc.get_next_pending_index()
	assert_true(idx >= 0, "Should return a valid index for the first PENDING item")
	var items = svc.get_all_items()
	assert_eq(items[idx]["status"], LoraTrainingQueueServiceScript.ItemStatus.PENDING)


func test_get_next_pending_skips_completed():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png"], "hero", ["front view", "side view"])
	var first = svc.get_next_pending_index()
	svc.mark_completed(first, Image.new())
	var second = svc.get_next_pending_index()
	assert_true(second != first, "Should skip the completed item")
	assert_true(second >= 0)


func test_get_next_pending_returns_minus_one_when_no_pending():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png"], "hero", ["front view"])
	var idx = svc.get_next_pending_index()
	while idx >= 0:
		svc.mark_completed(idx, Image.new())
		idx = svc.get_next_pending_index()
	assert_eq(svc.get_next_pending_index(), -1)


func test_mark_generating_sets_status():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png"], "hero", ["front view"])
	var idx = svc.get_next_pending_index()
	svc.mark_generating(idx)
	assert_eq(svc.get_all_items()[idx]["status"], LoraTrainingQueueServiceScript.ItemStatus.GENERATING)


func test_mark_completed_sets_status_and_image():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png"], "hero", ["front view"])
	var idx = svc.get_next_pending_index()
	var img = Image.new()
	svc.mark_completed(idx, img)
	var item = svc.get_all_items()[idx]
	assert_eq(item["status"], LoraTrainingQueueServiceScript.ItemStatus.COMPLETED)
	assert_eq(item["image"], img)


func test_mark_failed_sets_status():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png"], "hero", ["front view"])
	var idx = svc.get_next_pending_index()
	svc.mark_failed(idx)
	assert_eq(svc.get_all_items()[idx]["status"], LoraTrainingQueueServiceScript.ItemStatus.FAILED)


func test_get_completed_count():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png"], "hero", ["front view", "side view"])
	# source items already COMPLETED = 1
	var initial = svc.get_completed_count()
	var idx = svc.get_next_pending_index()
	svc.mark_completed(idx, Image.new())
	assert_eq(svc.get_completed_count(), initial + 1)


func test_cancel_sets_pending_to_failed():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png"], "hero", ["front view", "side view"])
	svc.cancel()
	var items = svc.get_all_items()
	for item in items:
		if item["variation_prompt"] != "reference image":
			assert_eq(item["status"], LoraTrainingQueueServiceScript.ItemStatus.FAILED,
				"PENDING items should become FAILED after cancel")


func test_is_cancelled():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png"], "hero", ["front view"])
	assert_false(svc.is_cancelled())
	svc.cancel()
	assert_true(svc.is_cancelled())


func test_clear_resets_queue():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png"], "hero", ["front view"])
	svc.cancel()
	svc.clear()
	assert_eq(svc.get_total(), 0)
	assert_false(svc.is_cancelled())


func test_remove_item():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png"], "hero", ["front view", "side view"])
	var total_before = svc.get_total()
	svc.remove_item(0)
	assert_eq(svc.get_total(), total_before - 1)


func test_reset_item():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(["img1.png"], "hero", ["front view"])
	var idx = svc.get_next_pending_index()
	var img = Image.new()
	svc.mark_completed(idx, img)
	svc.reset_item(idx)
	var item = svc.get_all_items()[idx]
	assert_eq(item["status"], LoraTrainingQueueServiceScript.ItemStatus.PENDING)
	assert_null(item["image"])
