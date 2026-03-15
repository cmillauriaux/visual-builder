extends "res://src/plugins/editor_plugin.gd"

const AIStudioDialog = preload("res://plugins/ai_studio/ai_studio_dialog.gd")
const Contributions = preload("res://src/plugins/contributions.gd")


func get_plugin_name() -> String:
	return "ai_studio"


func get_menu_entries() -> Array:
	var entry := Contributions.MenuEntry.new()
	entry.menu_id = "parametres"
	entry.label = "Studio IA"
	entry.callback = func(ctx): _open_dialog(ctx)
	return [entry]


func _open_dialog(ctx) -> void:
	if ctx.story == null:
		return
	var dlg := Window.new()
	dlg.set_script(AIStudioDialog)
	dlg.close_requested.connect(dlg.queue_free)
	ctx.main_node.add_child(dlg)
	dlg.setup(ctx.story, ctx.story_base_path)
	dlg.popup_centered()
