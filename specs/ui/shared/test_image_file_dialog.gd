extends "res://addons/gut/test.gd"

const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")

func test_initial_values():
	var dialog = ImageFileDialog.new()
	assert_eq(dialog.access, FileDialog.ACCESS_FILESYSTEM)
	assert_eq(dialog.file_mode, FileDialog.FILE_MODE_OPEN_FILE)
	assert_true(dialog.filters.has("*.png ; PNG"))
	dialog.free()

func test_preview_container_setup():
	var dialog = ImageFileDialog.new()
	add_child(dialog)
	
	# Check if preview container was added
	var found = false
	var stack = [dialog]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node is MarginContainer and node.custom_minimum_size.x >= 200:
			found = true
			break
		for child in node.get_children(true):
			stack.push_back(child)
	
	assert_true(found, "Preview container should be found in the dialog hierarchy")
	dialog.queue_free()

func test_update_preview_null_on_empty_path():
	var dialog = ImageFileDialog.new()
	dialog._update_preview("")
	assert_null(dialog._preview_rect.texture)
	dialog.free()

func test_update_preview_null_on_directory():
	var dialog = ImageFileDialog.new()
	dialog._update_preview("res://src")
	assert_null(dialog._preview_rect.texture)
	dialog.free()
