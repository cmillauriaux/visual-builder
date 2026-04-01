extends GutTest

var BlinkQueueServiceScript

func before_each():
	BlinkQueueServiceScript = load("res://src/services/blink_queue_service.gd")


func test_build_queue_populates_items():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/hero_smile.png", "res://img/hero_sad.png"])
	assert_eq(svc.get_total(), 2)


func test_build_queue_sets_source_path():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/hero_smile.png"])
	assert_eq(svc.get_items()[0]["source_path"], "res://img/hero_smile.png")


func test_build_queue_sets_blink_filename():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/hero_smile.png"])
	assert_eq(svc.get_items()[0]["blink_filename"], "hero_smile_blink.png")


func test_build_queue_sets_prompt():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/hero_smile.png"])
	assert_eq(
		svc.get_items()[0]["prompt"],
		"keep the same person, close both eyes gently as in a natural blink, adjust eyelids only, keep all colors and details of the original image, keep exactly the same eye color undertone, light color correction only"
	)


func test_build_queue_sets_status_pending():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/hero_smile.png"])
	assert_eq(svc.get_items()[0]["status"], BlinkQueueServiceScript.ItemStatus.PENDING)


func test_build_queue_clears_previous():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png", "res://img/b.png"])
	svc.build_queue(["res://img/c.png"])
	assert_eq(svc.get_total(), 1)
	assert_eq(svc.get_items()[0]["source_path"], "res://img/c.png")


func test_get_next_pending_index_initial():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png", "res://img/b.png"])
	assert_eq(svc.get_next_pending_index(), 0)


func test_get_next_pending_index_skips_generating():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png", "res://img/b.png"])
	svc.mark_generating(0)
	assert_eq(svc.get_next_pending_index(), 1)


func test_get_next_pending_index_returns_minus_one_when_all_done():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png", "res://img/b.png"])
	svc.mark_completed(0, Image.new())
	svc.mark_completed(1, Image.new())
	assert_eq(svc.get_next_pending_index(), -1)


func test_get_next_pending_index_empty_queue():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue([])
	assert_eq(svc.get_next_pending_index(), -1)


func test_mark_generating_updates_status():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png"])
	svc.mark_generating(0)
	assert_eq(svc.get_items()[0]["status"], BlinkQueueServiceScript.ItemStatus.GENERATING)


func test_mark_generating_updates_current_index():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png", "res://img/b.png"])
	svc.mark_generating(1)
	assert_eq(svc.get_current_index(), 1)


func test_mark_completed_updates_status():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png"])
	svc.mark_completed(0, Image.new())
	assert_eq(svc.get_items()[0]["status"], BlinkQueueServiceScript.ItemStatus.COMPLETED)


func test_mark_completed_stores_image():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png"])
	var img = Image.new()
	svc.mark_completed(0, img)
	assert_eq(svc.get_items()[0]["image"], img)


func test_mark_failed_updates_status():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png"])
	svc.mark_failed(0, "Network error")
	assert_eq(svc.get_items()[0]["status"], BlinkQueueServiceScript.ItemStatus.FAILED)


func test_mark_failed_stores_error():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png"])
	svc.mark_failed(0, "Network error")
	assert_eq(svc.get_items()[0]["error"], "Network error")


func test_cancel_sets_flag():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png"])
	assert_false(svc.is_cancelled())
	svc.cancel()
	assert_true(svc.is_cancelled())


func test_cancel_resets_on_new_queue():
	var svc = BlinkQueueServiceScript.new()
	svc.cancel()
	svc.build_queue(["res://img/a.png"])
	assert_false(svc.is_cancelled())


func test_get_completed_count():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png", "res://img/b.png", "res://img/c.png"])
	svc.mark_completed(0, Image.new())
	svc.mark_failed(1, "Error")
	assert_eq(svc.get_completed_count(), 1)


func test_get_done_count():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png", "res://img/b.png", "res://img/c.png"])
	svc.mark_completed(0, Image.new())
	svc.mark_failed(1, "Error")
	assert_eq(svc.get_done_count(), 2)


func test_get_completed_items():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png", "res://img/b.png"])
	svc.mark_completed(0, Image.new())
	svc.mark_failed(1, "Error")
	var completed = svc.get_completed_items()
	assert_eq(completed.size(), 1)
	assert_eq(completed[0]["source_path"], "res://img/a.png")


func test_reset_item_sets_pending():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png"])
	svc.mark_failed(0, "Error")
	svc.reset_item(0)
	assert_eq(svc.get_items()[0]["status"], BlinkQueueServiceScript.ItemStatus.PENDING)


func test_reset_item_clears_image():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png"])
	svc.mark_completed(0, Image.new())
	svc.reset_item(0)
	assert_null(svc.get_items()[0]["image"])


func test_reset_item_clears_error():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png"])
	svc.mark_failed(0, "Error")
	svc.reset_item(0)
	assert_false(svc.get_items()[0].has("error"))


func test_remove_item_decreases_total():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png", "res://img/b.png"])
	svc.remove_item(0)
	assert_eq(svc.get_total(), 1)


func test_remove_item_removes_correct_item():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png", "res://img/b.png"])
	svc.remove_item(0)
	assert_eq(svc.get_items()[0]["source_path"], "res://img/b.png")


func test_build_blink_filename_with_extension():
	assert_eq(
		BlinkQueueServiceScript._build_blink_filename("hero_smile.png"),
		"hero_smile_blink.png"
	)


func test_build_blink_filename_nested_path():
	assert_eq(
		BlinkQueueServiceScript._build_blink_filename("res://characters/hero_smile.png"),
		"hero_smile_blink.png"
	)


func test_build_blink_filename_jpg():
	assert_eq(
		BlinkQueueServiceScript._build_blink_filename("portrait.jpg"),
		"portrait_blink.jpg"
	)


func test_build_blink_filename_no_extension():
	assert_eq(
		BlinkQueueServiceScript._build_blink_filename("portrait"),
		"portrait_blink"
	)


func test_all_items_share_same_prompt():
	var svc = BlinkQueueServiceScript.new()
	svc.build_queue(["res://img/a.png", "res://img/b.png", "res://img/c.png"])
	var expected_prompt = "keep the same person, close both eyes gently as in a natural blink, adjust eyelids only, keep all colors and details of the original image, keep exactly the same eye color undertone, light color correction only"
	for item in svc.get_items():
		assert_eq(item["prompt"], expected_prompt)
