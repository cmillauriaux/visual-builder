extends GutTest

const ExpressionQueueService = preload("res://src/services/expression_queue_service.gd")

var _service: RefCounted


func before_each():
	_service = ExpressionQueueService.new()


# --- build_queue ---

func test_build_queue_creates_correct_count():
	_service.build_queue(["smile", "sad", "shy"], "hero")
	assert_eq(_service.get_total(), 3)


func test_build_queue_single_expression():
	_service.build_queue(["smile"], "char")
	assert_eq(_service.get_total(), 1)


func test_build_queue_clears_previous():
	_service.build_queue(["smile"], "a")
	_service.build_queue(["sad"], "b")
	assert_eq(_service.get_total(), 1)
	assert_eq(_service.get_items()[0]["expression"], "sad")


func test_build_queue_all_items_pending():
	_service.build_queue(["smile", "sad"], "hero")
	for item in _service.get_items():
		assert_eq(item["status"], ExpressionQueueService.ItemStatus.PENDING)


func test_build_queue_items_have_correct_expressions():
	_service.build_queue(["smile", "sad"], "hero")
	assert_eq(_service.get_items()[0]["expression"], "smile")
	assert_eq(_service.get_items()[1]["expression"], "sad")


func test_build_queue_preserves_order():
	_service.build_queue(["smile", "sad", "shy", "angry"], "hero")
	var items = _service.get_items()
	assert_eq(items[0]["expression"], "smile")
	assert_eq(items[1]["expression"], "sad")
	assert_eq(items[2]["expression"], "shy")
	assert_eq(items[3]["expression"], "angry")


func test_build_queue_resets_cancelled():
	_service.cancel()
	_service.build_queue(["smile"], "hero")
	assert_false(_service.is_cancelled())


# --- Prompt building ---

func test_build_prompt_without_eye_color():
	var prompt = ExpressionQueueService._build_prompt("smile")
	assert_eq(prompt, "smile")


func test_build_prompt_with_eye_color():
	var prompt = ExpressionQueueService._build_prompt("smile", "blue")
	assert_eq(prompt, "smile, blue eyes")


func test_build_prompt_with_complex_expression_and_eye_color():
	var prompt = ExpressionQueueService._build_prompt("laughing out loud", "green")
	assert_eq(prompt, "laughing out loud, green eyes")


func test_build_queue_items_have_correct_prompt():
	_service.build_queue(["smile"], "hero")
	assert_eq(_service.get_items()[0]["prompt"], "smile")


func test_build_queue_items_have_correct_prompt_with_eye_color():
	_service.build_queue(["smile"], "hero", "blue")
	assert_eq(_service.get_items()[0]["prompt"], "smile, blue eyes")


# --- Filename building ---

func test_build_filename_format():
	var filename = ExpressionQueueService._build_filename("hero", "smile")
	assert_eq(filename, "hero_smile")


func test_build_filename_replaces_spaces():
	var filename = ExpressionQueueService._build_filename("char", "laughing out loud")
	assert_eq(filename, "char_laughing_out_loud")


func test_build_filename_empty_prefix():
	var filename = ExpressionQueueService._build_filename("", "smile")
	assert_eq(filename, "smile")


func test_build_queue_items_have_correct_filename():
	_service.build_queue(["smile"], "hero")
	assert_eq(_service.get_items()[0]["filename"], "hero_smile")


# --- Queue state management ---

func test_mark_generating_updates_status():
	_service.build_queue(["smile"], "hero")
	_service.mark_generating(0)
	assert_eq(_service.get_items()[0]["status"], ExpressionQueueService.ItemStatus.GENERATING)


func test_mark_generating_updates_current_index():
	_service.build_queue(["smile", "sad"], "hero")
	_service.mark_generating(1)
	assert_eq(_service.get_current_index(), 1)


func test_mark_completed_stores_image():
	_service.build_queue(["smile"], "hero")
	_service.mark_generating(0)
	var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	_service.mark_completed(0, img)
	assert_eq(_service.get_items()[0]["status"], ExpressionQueueService.ItemStatus.COMPLETED)
	assert_eq(_service.get_items()[0]["image"], img)


func test_mark_failed_updates_status():
	_service.build_queue(["smile"], "hero")
	_service.mark_generating(0)
	_service.mark_failed(0, "Connection error")
	assert_eq(_service.get_items()[0]["status"], ExpressionQueueService.ItemStatus.FAILED)
	assert_eq(_service.get_items()[0]["error"], "Connection error")


func test_get_next_pending_returns_first_pending():
	_service.build_queue(["smile", "sad", "shy"], "hero")
	assert_eq(_service.get_next_pending_index(), 0)


func test_get_next_pending_skips_completed():
	_service.build_queue(["smile", "sad", "shy"], "hero")
	_service.mark_generating(0)
	_service.mark_completed(0, Image.create(1, 1, false, Image.FORMAT_RGBA8))
	assert_eq(_service.get_next_pending_index(), 1)


func test_get_next_pending_skips_failed():
	_service.build_queue(["smile", "sad"], "hero")
	_service.mark_generating(0)
	_service.mark_failed(0, "error")
	assert_eq(_service.get_next_pending_index(), 1)


func test_get_next_pending_returns_minus_one_when_all_done():
	_service.build_queue(["smile"], "hero")
	_service.mark_generating(0)
	_service.mark_completed(0, Image.create(1, 1, false, Image.FORMAT_RGBA8))
	assert_eq(_service.get_next_pending_index(), -1)


# --- Cancel ---

func test_cancel_sets_flag():
	_service.build_queue(["smile"], "hero")
	assert_false(_service.is_cancelled())
	_service.cancel()
	assert_true(_service.is_cancelled())


# --- Counting ---

func test_get_completed_count():
	_service.build_queue(["smile", "sad", "shy"], "hero")
	_service.mark_generating(0)
	_service.mark_completed(0, Image.create(1, 1, false, Image.FORMAT_RGBA8))
	_service.mark_generating(1)
	_service.mark_failed(1, "error")
	assert_eq(_service.get_completed_count(), 1)


func test_get_done_count():
	_service.build_queue(["smile", "sad", "shy"], "hero")
	_service.mark_generating(0)
	_service.mark_completed(0, Image.create(1, 1, false, Image.FORMAT_RGBA8))
	_service.mark_generating(1)
	_service.mark_failed(1, "error")
	assert_eq(_service.get_done_count(), 2)


func test_get_completed_items():
	_service.build_queue(["smile", "sad"], "hero")
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	_service.mark_generating(0)
	_service.mark_completed(0, img)
	_service.mark_generating(1)
	_service.mark_failed(1, "error")
	var completed = _service.get_completed_items()
	assert_eq(completed.size(), 1)
	assert_eq(completed[0]["expression"], "smile")


# --- Reset / Remove ---

func test_reset_item():
	_service.build_queue(["smile"], "hero")
	_service.mark_generating(0)
	_service.mark_failed(0, "error")
	_service.reset_item(0)
	assert_eq(_service.get_items()[0]["status"], ExpressionQueueService.ItemStatus.PENDING)
	assert_null(_service.get_items()[0]["image"])
	assert_false(_service.get_items()[0].has("error"))


func test_remove_item():
	_service.build_queue(["smile", "sad"], "hero")
	_service.remove_item(0)
	assert_eq(_service.get_total(), 1)
	assert_eq(_service.get_items()[0]["expression"], "sad")


# --- Initial state ---

func test_initial_empty():
	assert_eq(_service.get_total(), 0)
	assert_eq(_service.get_items(), [])
	assert_eq(_service.get_current_index(), -1)
	assert_false(_service.is_cancelled())
