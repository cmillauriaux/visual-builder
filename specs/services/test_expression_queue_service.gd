extends GutTest

var ExpressionQueueServiceScript

func before_each():
	ExpressionQueueServiceScript = load("res://src/services/expression_queue_service.gd")

func test_build_queue():
	var svc = ExpressionQueueServiceScript.new()
	svc.build_queue(["Happy", "Sad"], "Hero")
	assert_eq(svc.get_total(), 2)
	assert_eq(svc.get_items()[0]["expression"], "Happy")
	assert_eq(svc.get_items()[0]["filename"], "Hero_Happy")

func test_get_next_pending_index():
	var svc = ExpressionQueueServiceScript.new()
	svc.build_queue(["A", "B"], "P")
	assert_eq(svc.get_next_pending_index(), 0)
	svc.mark_generating(0)
	assert_eq(svc.get_next_pending_index(), 1)
	svc.mark_completed(1, Image.new())
	assert_eq(svc.get_next_pending_index(), -1)

func test_counts():
	var svc = ExpressionQueueServiceScript.new()
	svc.build_queue(["A", "B", "C"], "P")
	svc.mark_completed(0, Image.new())
	svc.mark_failed(1, "Error")
	assert_eq(svc.get_completed_count(), 1)
	assert_eq(svc.get_done_count(), 2)

func test_build_filename():
	var svc = ExpressionQueueServiceScript
	assert_eq(svc._build_filename("Prefix", "My Expression"), "Prefix_My_Expression")
	assert_eq(svc._build_filename("", "Only"), "Only")

func test_remove_item():
	var svc = ExpressionQueueServiceScript.new()
	svc.build_queue(["A", "B"], "P")
	svc.remove_item(0)
	assert_eq(svc.get_total(), 1)
	assert_eq(svc.get_items()[0]["expression"], "B")

func test_build_prompt():
	var svc = ExpressionQueueServiceScript
	assert_eq(
		svc._build_prompt("smile"),
		"keep the same person, only change facial expression to smile, adjust face muscles only, keep all colors and details of the original image, keep exactly the same eye color as the original image, do not recolor irises, light color correction only"
	)

func test_build_prompt_with_empty_hint():
	var svc = ExpressionQueueServiceScript
	assert_eq(
		svc._build_prompt("smile", ""),
		"keep the same person, only change facial expression to smile, adjust face muscles only, keep all colors and details of the original image, keep exactly the same eye color as the original image, do not recolor irises, light color correction only"
	)

func test_build_prompt_with_hint():
	var svc = ExpressionQueueServiceScript
	assert_eq(
		svc._build_prompt("smile", "cute girl"),
		"keep the same person (cute girl), only change facial expression to smile, adjust face muscles only, keep all colors and details of the original image, keep exactly the same eye color as the original image, do not recolor irises, light color correction only"
	)

func test_build_queue_with_hint():
	var svc = ExpressionQueueServiceScript.new()
	svc.build_queue(["smile", "sad"], "hero", "cute girl")
	assert_eq(svc.get_total(), 2)
	assert_string_contains(svc.get_items()[0]["prompt"], "keep the same person (cute girl)")
	assert_string_contains(svc.get_items()[1]["prompt"], "keep the same person (cute girl)")

func test_build_queue_without_hint():
	var svc = ExpressionQueueServiceScript.new()
	svc.build_queue(["smile"], "hero")
	assert_eq(svc.get_total(), 1)
	assert_string_contains(svc.get_items()[0]["prompt"], "keep the same person,")
	assert_false(svc.get_items()[0]["prompt"].contains("("))
