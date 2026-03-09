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
