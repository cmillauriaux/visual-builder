# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends SceneTree

## Test script pour vérifier que load_resource_pack fonctionne avec les chapter PCK.
## Usage: godot --headless --path <project> --script res://src/export/test_pck_loading.gd -- --pck <path_to_chapter.pck>

func _init():
	var pck_path := ""

	var args = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--pck" and i + 1 < args.size():
			pck_path = args[i + 1]

	if pck_path == "":
		printerr("Usage: --pck <path_to_chapter.pck>")
		quit(1)
		return

	print("=== Test PCK Loading ===")
	print("PCK path: %s" % pck_path)
	print("File exists: %s" % str(FileAccess.file_exists(pck_path)))

	# 1. Charger le resource pack
	var success = ProjectSettings.load_resource_pack(pck_path)
	print("load_resource_pack result: %s" % str(success))

	if not success:
		printerr("FAILED: load_resource_pack returned false")
		quit(1)
		return

	# 2. Vérifier que les fichiers sont maintenant accessibles
	# Essayer de lister les fichiers qu'on sait être dans le PCK
	var test_paths := [
		"res://story/assets/backgrounds/ai_1772389778_78445.png",
		"res://story/assets/backgrounds/ai_1772389778_78445.png.import",
		"res://.godot/imported/ai_1772389778_78445.png-9f10e5e9f70acb22c74cfca9fcc26d63.ctex",
	]

	for path in test_paths:
		var exists = FileAccess.file_exists(path)
		print("  %s : %s" % [path, "EXISTS" if exists else "MISSING"])

	# 3. Essayer de charger la texture via ResourceLoader
	var tex_path = "res://story/assets/backgrounds/ai_1772389778_78445.png"
	print("\nTrying to load texture: %s" % tex_path)
	var tex = ResourceLoader.load(tex_path)
	if tex:
		print("  SUCCESS: Loaded texture %s (%dx%d)" % [tex.resource_path, tex.get_width(), tex.get_height()])
	else:
		print("  FAILED: ResourceLoader.load returned null")

	# 4. Essayer avec le chemin .ctex directement
	var ctex_path = "res://.godot/imported/ai_1772389778_78445.png-9f10e5e9f70acb22c74cfca9fcc26d63.ctex"
	print("\nTrying to load .ctex directly: %s" % ctex_path)
	var ctex = ResourceLoader.load(ctex_path)
	if ctex:
		print("  SUCCESS: Loaded .ctex %s" % ctex.resource_path)
	else:
		print("  FAILED: ResourceLoader.load returned null for .ctex")

	print("\n=== Test Complete ===")
	quit(0)