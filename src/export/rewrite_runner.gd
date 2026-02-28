extends SceneTree

## Script exécutable en mode headless pour réécrire les chemins d'images d'une story.
## Usage : godot --headless --path <project> --script res://src/export/rewrite_runner.gd

const StoryPathRewriter = preload("res://src/export/story_path_rewriter.gd")


func _init():
	var story_folder := "res://story"
	var new_base := "res://story"

	var args = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--story-folder" and i + 1 < args.size():
			story_folder = args[i + 1]
		elif args[i] == "--new-base" and i + 1 < args.size():
			new_base = args[i + 1]

	print("StoryPathRewriter: rewriting paths in '%s' with base '%s'" % [story_folder, new_base])
	var success = StoryPathRewriter.rewrite_story_paths(story_folder, new_base)

	if success:
		print("StoryPathRewriter: paths rewritten successfully")
		quit(0)
	else:
		printerr("StoryPathRewriter: failed to rewrite paths")
		quit(1)
