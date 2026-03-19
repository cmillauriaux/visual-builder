extends GutTest

const ScreenshotServiceScript = preload("res://src/services/screenshot_service.gd")
var _service: Node


func before_each():
	_service = Node.new()
	_service.set_script(ScreenshotServiceScript)
	add_child_autofree(_service)


func test_capture_returns_null_without_setup():
	var img = _service.capture()
	assert_null(img, "capture() sans setup doit retourner null")


func test_setup_creates_sub_viewport():
	_service.setup(get_viewport())
	var sub_vp = _service._sub_viewport
	assert_not_null(sub_vp, "Le SubViewport doit être créé après setup()")
	assert_eq(sub_vp.size, Vector2i(320, 180), "SubViewport doit être 320×180")


func test_sub_viewport_mirrors_main_world_2d():
	_service.setup(get_viewport())
	assert_eq(
		_service._sub_viewport.world_2d,
		get_viewport().world_2d,
		"Le SubViewport doit partager le world_2d du viewport principal"
	)


func test_sub_viewport_input_disabled():
	_service.setup(get_viewport())
	var sub_vp = _service._sub_viewport
	assert_false(sub_vp.handle_input_locally, "Le SubViewport ne doit pas gérer l'input")
	assert_true(sub_vp.gui_disable_input, "Le SubViewport doit désactiver l'input GUI")


func test_capture_returns_image_after_setup():
	if DisplayServer.get_name() == "headless":
		pass_test("Skipped en headless — pas de rendu GPU")
		return
	_service.setup(get_viewport())
	# Attendre un frame pour que le SubViewport ait rendu
	await get_tree().process_frame
	await get_tree().process_frame
	var img = _service.capture()
	assert_not_null(img, "capture() doit retourner une Image après setup")
	assert_eq(img.get_width(), 320, "L'image doit faire 320px de large")
	assert_eq(img.get_height(), 180, "L'image doit faire 180px de haut")


func test_constants():
	assert_eq(ScreenshotServiceScript.THUMBNAIL_WIDTH, 320)
	assert_eq(ScreenshotServiceScript.THUMBNAIL_HEIGHT, 180)
