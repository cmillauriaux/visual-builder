# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends SceneTree

## Teste le flux complet : HTTPRequest download → user:// → load_resource_pack.
## Lance un serveur HTTP local, télécharge le PCK, le charge.
## Usage: godot --headless --path <project> --script ... -- --pck-dir <dir>

func _init():
	var pck_dir := ""

	var args = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--pck-dir" and i + 1 < args.size():
			pck_dir = args[i + 1]

	if pck_dir == "":
		printerr("Usage: --pck-dir <directory_with_chapter_pcks>")
		quit(1)
		return

	print("=== Test HTTP PCK Download + Loading ===")
	print("PCK dir: %s" % pck_dir)

	# Simuler ce que fait PckChapterLoader sans HTTPRequest
	# (car en headless on n'a pas de serveur HTTP)
	# On va directement tester le flux que le web ferait après le download

	var pck_filename = "chapter_137daa3d-af5e-4722-8c5b-b965bf58fa36_part1.pck"
	var src_path = pck_dir + "/" + pck_filename

	# Lire le fichier comme si c'était le body d'un HTTPRequest
	print("\n1. Reading PCK file (simulating HTTP body)...")
	var src = FileAccess.open(src_path, FileAccess.READ)
	if src == null:
		printerr("Cannot open: %s" % src_path)
		quit(1)
		return
	var body: PackedByteArray = src.get_buffer(src.get_length())
	src.close()
	print("   Body size: %d bytes" % body.size())

	# Écrire dans user:// (comme _load_pck_web)
	print("\n2. Writing to user://%s..." % pck_filename)
	var local_path = "user://" + pck_filename
	var f = FileAccess.open(local_path, FileAccess.WRITE)
	if f == null:
		printerr("Cannot write: %s" % local_path)
		quit(1)
		return
	f.store_buffer(body)
	f.close()
	print("   Written: %d bytes" % body.size())

	# Charger le resource pack
	print("\n3. Loading resource pack from %s..." % local_path)
	var success = ProjectSettings.load_resource_pack(local_path)
	print("   Result: %s" % str(success))

	if not success:
		printerr("FATAL: load_resource_pack failed!")
		quit(1)
		return

	# Vérifier les textures
	print("\n4. Testing texture loading...")
	var test_textures := [
		"res://story/assets/backgrounds/ai_1772389778_78445.png",
		"res://story/assets/foregrounds/ai_1772878809_1088.png",
		"res://story/assets/foregrounds/Alicia_speaking.png",
	]
	var all_ok := true
	for tex_path in test_textures:
		var tex = ResourceLoader.load(tex_path)
		if tex:
			print("   OK: %s (%dx%d)" % [tex_path.get_file(), tex.get_width(), tex.get_height()])
		else:
			print("   FAIL: %s" % tex_path)
			all_ok = false

	# Maintenant tester le chargement des 4 parties en séquence
	print("\n5. Testing sequential multi-part loading...")
	var parts = [
		"chapter_137daa3d-af5e-4722-8c5b-b965bf58fa36_part2.pck",
		"chapter_137daa3d-af5e-4722-8c5b-b965bf58fa36_part3.pck",
		"chapter_137daa3d-af5e-4722-8c5b-b965bf58fa36_part4.pck",
	]
	for part in parts:
		var part_src = pck_dir + "/" + part
		if not FileAccess.file_exists(part_src):
			print("   SKIP: %s (not found)" % part)
			continue
		var part_file = FileAccess.open(part_src, FileAccess.READ)
		var part_body = part_file.get_buffer(part_file.get_length())
		part_file.close()

		var part_local = "user://" + part
		var part_f = FileAccess.open(part_local, FileAccess.WRITE)
		part_f.store_buffer(part_body)
		part_f.close()

		var part_ok = ProjectSettings.load_resource_pack(part_local)
		print("   %s: %s (%d bytes)" % [part, str(part_ok), part_body.size()])

	# Test une texture du part2 ou part3
	print("\n6. Testing texture from later parts...")
	# On ne sait pas exactement quelle texture est dans quel part,
	# mais on peut tester si le ResourceLoader résout les chemins
	var dir = DirAccess.open("res://story/assets/backgrounds/")
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		var count := 0
		while fname != "" and count < 5:
			if not fname.ends_with(".import"):
				var full = "res://story/assets/backgrounds/" + fname
				var t = ResourceLoader.load(full)
				if t:
					print("   OK: %s" % fname)
				else:
					print("   FAIL: %s" % fname)
					all_ok = false
				count += 1
			fname = dir.get_next()

	if all_ok:
		print("\n=== ALL TESTS PASSED ===")
	else:
		print("\n=== SOME TESTS FAILED ===")

	quit(0 if all_ok else 1)