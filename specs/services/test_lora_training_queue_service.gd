# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends GutTest

var LoraTrainingQueueServiceScript

const BASES_FULL = {
	"closeup":       {"image": null, "path": "img_closeup.png"},
	"portrait":      {"image": null, "path": "img_portrait.png"},
	"three_quarter": {"image": null, "path": "img_3q.png"},
	"profile":       {"image": null, "path": "img_profile.png"},
	"buste":         {"image": null, "path": "img_buste.png"},
	"full_body":     {"image": null, "path": "img_fullbody.png"},
}

func before_each():
	LoraTrainingQueueServiceScript = load("res://src/services/lora_training_queue_service.gd")


func test_detect_base_closeup():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("close-up, front view, looking at viewer"), "closeup")


func test_detect_base_full_body():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("full body, front view, standing"), "full_body")


func test_detect_base_buste_upper_body():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("upper body, front view, standing"), "buste")


func test_detect_base_buste_waist_up():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("waist up, three-quarter view, sitting"), "buste")


func test_detect_base_three_quarter():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("portrait, three-quarter left view, looking at viewer"), "three_quarter")


func test_detect_base_profile_over_shoulder():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("portrait, looking over shoulder, neutral expression"), "profile")


func test_detect_base_portrait_default():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("portrait, front view, looking at viewer, smiling"), "portrait")


func test_detect_base_priority_closeup_over_upper_body():
	# "close-up" must win over "upper body" even if both appear
	assert_eq(LoraTrainingQueueServiceScript.detect_base("close-up, upper body, front view"), "closeup")


func test_detect_base_priority_full_body_over_buste():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("full body, upper body, standing"), "full_body")


func test_build_queue_creates_one_item_per_variation():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view", "full body, standing", "close-up, face"])
	assert_eq(svc.get_total(), 3, "One item per variation, no source reference items")


func test_build_queue_all_items_pending():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view", "full body, standing"])
	for item in svc.get_all_items():
		assert_eq(item["status"], LoraTrainingQueueServiceScript.ItemStatus.PENDING)


func test_build_queue_source_path_from_detected_base():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["full body, front view, standing"])
	var item = svc.get_all_items()[0]
	assert_eq(item["source_image_path"], "img_fullbody.png", "full body variation uses full_body base path")


func test_build_queue_source_path_closeup():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["close-up, front view, neutral expression"])
	var item = svc.get_all_items()[0]
	assert_eq(item["source_image_path"], "img_closeup.png")


func test_build_queue_source_path_portrait_default():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view, smiling"])
	var item = svc.get_all_items()[0]
	assert_eq(item["source_image_path"], "img_portrait.png")


func test_build_queue_caption_format():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view, smiling"])
	var item = svc.get_all_items()[0]
	assert_eq(item["caption"], "hero, portrait, front view, smiling")


func test_build_queue_empty_variations():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", [])
	assert_eq(svc.get_total(), 0)


func test_get_next_pending_returns_first_pending():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view", "full body, standing"])
	var idx = svc.get_next_pending_index()
	assert_eq(idx, 0)
	assert_eq(svc.get_all_items()[idx]["status"], LoraTrainingQueueServiceScript.ItemStatus.PENDING)


func test_get_next_pending_skips_completed():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view", "full body, standing"])
	svc.mark_completed(0, Image.new())
	var idx = svc.get_next_pending_index()
	assert_eq(idx, 1)


func test_get_next_pending_returns_minus_one_when_no_pending():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view"])
	svc.mark_completed(0, Image.new())
	assert_eq(svc.get_next_pending_index(), -1)


func test_mark_generating_sets_status():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view"])
	svc.mark_generating(0)
	assert_eq(svc.get_all_items()[0]["status"], LoraTrainingQueueServiceScript.ItemStatus.GENERATING)


func test_mark_completed_sets_status_and_image():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view"])
	var img = Image.new()
	svc.mark_completed(0, img)
	var item = svc.get_all_items()[0]
	assert_eq(item["status"], LoraTrainingQueueServiceScript.ItemStatus.COMPLETED)
	assert_eq(item["image"], img)


func test_mark_failed_sets_status():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view"])
	svc.mark_failed(0)
	assert_eq(svc.get_all_items()[0]["status"], LoraTrainingQueueServiceScript.ItemStatus.FAILED)


func test_get_completed_count():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view", "full body, standing"])
	assert_eq(svc.get_completed_count(), 0)
	svc.mark_completed(0, Image.new())
	assert_eq(svc.get_completed_count(), 1)


func test_cancel_sets_pending_to_failed():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view", "full body, standing"])
	svc.cancel()
	for item in svc.get_all_items():
		assert_eq(item["status"], LoraTrainingQueueServiceScript.ItemStatus.FAILED)


func test_is_cancelled():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view"])
	assert_false(svc.is_cancelled())
	svc.cancel()
	assert_true(svc.is_cancelled())


func test_clear_resets_queue():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view"])
	svc.cancel()
	svc.clear()
	assert_eq(svc.get_total(), 0)
	assert_false(svc.is_cancelled())


func test_remove_item():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view", "full body, standing"])
	svc.remove_item(0)
	assert_eq(svc.get_total(), 1)


func test_reset_item():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view"])
	var img = Image.new()
	svc.mark_completed(0, img)
	svc.reset_item(0)
	var item = svc.get_all_items()[0]
	assert_eq(item["status"], LoraTrainingQueueServiceScript.ItemStatus.PENDING)
	assert_null(item["image"])
