extends SceneTree

## Simule exactement le flux web : lit un PCK, l'écrit dans user://, puis load_resource_pack.
## Usage: godot --headless --path <project> --script res://src/export/test_pck_user_path.gd -- --pck <path>

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

	print("=== Test PCK Loading via user:// (simulating web flow) ===")

	# 1. Lire le PCK comme si c'était un body HTTPRequest
	var src = FileAccess.open(pck_path, FileAccess.READ)
	if src == null:
		printerr("Cannot open: %s" % pck_path)
		quit(1)
		return
	var body = src.get_buffer(src.get_length())
	src.close()
	print("Read PCK body: %d bytes" % body.size())

	# 2. Écrire dans user:// (exactement comme _load_pck_web)
	var local_path = "user://test_chapter.pck"
	var f = FileAccess.open(local_path, FileAccess.WRITE)
	if f == null:
		printerr("Cannot write to %s" % local_path)
		quit(1)
		return
	f.store_buffer(body)
	f.close()
	print("Written to: %s" % local_path)
	print("File exists after write: %s" % str(FileAccess.file_exists(local_path)))

	# Vérifier la taille
	var check = FileAccess.open(local_path, FileAccess.READ)
	if check:
		print("File size in user://: %d bytes" % check.get_length())
		check.close()

	# 3. Charger via load_resource_pack (exactement comme _load_pck_web)
	var success = ProjectSettings.load_resource_pack(local_path)
	print("load_resource_pack('%s') = %s" % [local_path, str(success)])

	if success:
		# 4. Vérifier qu'une texture est accessible
		var tex_path = "res://story/assets/backgrounds/ai_1772389778_78445.png"
		var exists = FileAccess.file_exists(tex_path)
		print("Texture file exists: %s" % str(exists))
		var tex = ResourceLoader.load(tex_path)
		if tex:
			print("SUCCESS: Loaded %s (%dx%d)" % [tex_path, tex.get_width(), tex.get_height()])
		else:
			print("FAILED: ResourceLoader.load returned null")
	else:
		print("FAILED: load_resource_pack returned false!")
		# Tester avec le chemin globalisé
		var global = ProjectSettings.globalize_path(local_path)
		print("Trying globalized path: %s" % global)
		var success2 = ProjectSettings.load_resource_pack(global)
		print("load_resource_pack('%s') = %s" % [global, str(success2)])

	print("=== Test Complete ===")
	quit(0)
