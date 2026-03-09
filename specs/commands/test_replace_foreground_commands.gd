extends "res://addons/gut/test.gd"

const ForegroundScript = preload("res://src/models/foreground.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")
const ReplaceForegroundImageCommand = preload("res://src/commands/replace_foreground_image_command.gd")
const ReplaceWithNewForegroundCommand = preload("res://src/commands/replace_with_new_foreground_command.gd")

func test_replace_foreground_image_command():
	var fg = ForegroundScript.new()
	fg.image = "old_path.png"
	
	var cmd = ReplaceForegroundImageCommand.new(fg, "new_path.png")
	
	cmd.execute()
	assert_eq(fg.image, "new_path.png")
	
	cmd.undo()
	assert_eq(fg.image, "old_path.png")

func test_replace_with_new_foreground_command_no_prior_foregrounds():
	var dlg = DialogueScript.new()
	var template_fg = ForegroundScript.new()
	template_fg.fg_name = "Hero"
	template_fg.image = "hero_idle.png"
	template_fg.scale = 1.2
	
	var inherited_fgs = [template_fg]
	
	var cmd = ReplaceWithNewForegroundCommand.new(dlg, template_fg, "hero_happy.png", inherited_fgs)
	
	# Initial state: dialogue has no own foregrounds
	assert_eq(dlg.foregrounds.size(), 0)
	
	cmd.execute()
	
	# After execute:
	# 1. Inheritance broken -> copies inherited (1)
	# 2. Adds the new one (1)
	# Total = 2
	assert_eq(dlg.foregrounds.size(), 2)
	assert_eq(dlg.foregrounds[0].image, "hero_idle.png")
	assert_eq(dlg.foregrounds[1].image, "hero_happy.png")
	assert_eq(dlg.foregrounds[1].fg_name, "Hero")
	assert_eq(dlg.foregrounds[1].scale, 1.2)
	assert_ne(dlg.foregrounds[1].uuid, template_fg.uuid) # New UUID for the new foreground
	
	cmd.undo()
	assert_eq(dlg.foregrounds.size(), 0)

func test_replace_with_new_foreground_command_with_prior_foregrounds():
	var dlg = DialogueScript.new()
	var existing_fg = ForegroundScript.new()
	existing_fg.image = "other.png"
	dlg.foregrounds.append(existing_fg)
	
	var template_fg = ForegroundScript.new()
	template_fg.fg_name = "Hero"
	template_fg.image = "hero_idle.png"
	
	var inherited_fgs = [] # Not used if dialogue already has foregrounds
	
	var cmd = ReplaceWithNewForegroundCommand.new(dlg, template_fg, "hero_happy.png", inherited_fgs)
	
	assert_eq(dlg.foregrounds.size(), 1)
	
	cmd.execute()
	assert_eq(dlg.foregrounds.size(), 2)
	assert_eq(dlg.foregrounds[0].image, "other.png")
	assert_eq(dlg.foregrounds[1].image, "hero_happy.png")
	
	cmd.undo()
	assert_eq(dlg.foregrounds.size(), 1)
	assert_eq(dlg.foregrounds[0].image, "other.png")
