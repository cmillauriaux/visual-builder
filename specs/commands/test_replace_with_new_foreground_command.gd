extends "res://addons/gut/test.gd"

const ForegroundScript = preload("res://src/models/foreground.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")
const ReplaceWithNewForegroundCommand = preload("res://src/commands/replace_with_new_foreground_command.gd")


func test_execute_no_prior_foregrounds():
	var dlg = DialogueScript.new()
	var template_fg = ForegroundScript.new()
	template_fg.fg_name = "Hero"
	template_fg.image = "hero_idle.png"
	template_fg.scale = 1.2

	var inherited_fgs = [template_fg]

	var cmd = ReplaceWithNewForegroundCommand.new(dlg, template_fg, "hero_happy.png", inherited_fgs)
	assert_eq(dlg.foregrounds.size(), 0)

	cmd.execute()

	# Inherited (1) + new (1) = 2
	assert_eq(dlg.foregrounds.size(), 2)
	assert_eq(dlg.foregrounds[0].image, "hero_idle.png")
	assert_eq(dlg.foregrounds[1].image, "hero_happy.png")
	assert_eq(dlg.foregrounds[1].fg_name, "Hero")
	assert_eq(dlg.foregrounds[1].scale, 1.2)
	assert_ne(dlg.foregrounds[1].uuid, template_fg.uuid)


func test_undo_no_prior_foregrounds():
	var dlg = DialogueScript.new()
	var template_fg = ForegroundScript.new()
	template_fg.fg_name = "Hero"
	template_fg.image = "hero_idle.png"
	var inherited_fgs = [template_fg]

	var cmd = ReplaceWithNewForegroundCommand.new(dlg, template_fg, "hero_happy.png", inherited_fgs)
	cmd.execute()
	cmd.undo()

	assert_eq(dlg.foregrounds.size(), 0)


func test_execute_with_prior_foregrounds():
	var dlg = DialogueScript.new()
	var existing_fg = ForegroundScript.new()
	existing_fg.image = "other.png"
	dlg.foregrounds.append(existing_fg)

	var template_fg = ForegroundScript.new()
	template_fg.fg_name = "Hero"
	template_fg.image = "hero_idle.png"

	var cmd = ReplaceWithNewForegroundCommand.new(dlg, template_fg, "hero_happy.png", [])
	cmd.execute()

	assert_eq(dlg.foregrounds.size(), 2)
	assert_eq(dlg.foregrounds[0].image, "other.png")
	assert_eq(dlg.foregrounds[1].image, "hero_happy.png")


func test_undo_with_prior_foregrounds():
	var dlg = DialogueScript.new()
	var existing_fg = ForegroundScript.new()
	existing_fg.image = "other.png"
	dlg.foregrounds.append(existing_fg)

	var template_fg = ForegroundScript.new()
	template_fg.fg_name = "Hero"
	template_fg.image = "hero_idle.png"

	var cmd = ReplaceWithNewForegroundCommand.new(dlg, template_fg, "hero_happy.png", [])
	cmd.execute()
	cmd.undo()

	assert_eq(dlg.foregrounds.size(), 1)
	assert_eq(dlg.foregrounds[0].image, "other.png")


func test_copies_all_properties():
	var dlg = DialogueScript.new()
	var template_fg = ForegroundScript.new()
	template_fg.fg_name = "Test"
	template_fg.z_order = 5
	template_fg.opacity = 0.8
	template_fg.flip_h = true
	template_fg.flip_v = true
	template_fg.scale = 2.0
	template_fg.anchor_bg = Vector2(0.3, 0.7)
	template_fg.anchor_fg = Vector2(0.5, 1.0)
	template_fg.transition_type = "fade"
	template_fg.transition_duration = 1.5

	var cmd = ReplaceWithNewForegroundCommand.new(dlg, template_fg, "new.png", [])
	cmd.execute()

	var new_fg = dlg.foregrounds[0]
	assert_eq(new_fg.fg_name, "Test")
	assert_eq(new_fg.image, "new.png")
	assert_eq(new_fg.z_order, 5)
	assert_eq(new_fg.flip_h, true)
	assert_eq(new_fg.flip_v, true)
	assert_eq(new_fg.scale, 2.0)
	assert_eq(new_fg.anchor_bg, Vector2(0.3, 0.7))
	assert_eq(new_fg.transition_type, "fade")
	assert_eq(new_fg.transition_duration, 1.5)


func test_get_label():
	var dlg = DialogueScript.new()
	var fg = ForegroundScript.new()
	var cmd = ReplaceWithNewForegroundCommand.new(dlg, fg, "img.png", [])

	assert_eq(cmd.get_label(), "Remplacer par un nouveau foreground")
