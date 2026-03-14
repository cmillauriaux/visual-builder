extends "res://addons/gut/test.gd"

const ForegroundScript = preload("res://src/models/foreground.gd")
const ReplaceForegroundImageCommand = preload("res://src/commands/replace_foreground_image_command.gd")


func test_execute_sets_new_image():
	var fg = ForegroundScript.new()
	fg.image = "old_path.png"

	var cmd = ReplaceForegroundImageCommand.new(fg, "new_path.png")
	cmd.execute()

	assert_eq(fg.image, "new_path.png")


func test_undo_restores_old_image():
	var fg = ForegroundScript.new()
	fg.image = "old_path.png"

	var cmd = ReplaceForegroundImageCommand.new(fg, "new_path.png")
	cmd.execute()
	cmd.undo()

	assert_eq(fg.image, "old_path.png")


func test_get_label():
	var fg = ForegroundScript.new()
	var cmd = ReplaceForegroundImageCommand.new(fg, "img.png")

	assert_eq(cmd.get_label(), "Remplacer l'image du foreground")
