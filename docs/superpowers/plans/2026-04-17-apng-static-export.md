# APNG Static Export — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a checkbox in the export dialog to flatten APNG files into static PNG (first frame), reducing export size.

**Architecture:** A new checkbox in `ExportDialog` feeds a `"static_apng"` option into `ExportService`, which flattens `.apng` files to `.png` before the existing resize/WebP pipeline processes them.

**Tech Stack:** GDScript (Godot 4.6.1), GUT test framework, `Image` API for PNG extraction, `ApngBuilder` for test fixtures.

---

### Task 1: ExportDialog — Add static APNG checkbox

**Files:**
- Modify: `src/ui/dialogs/export_dialog.gd:27-29` (add variable declaration)
- Modify: `src/ui/dialogs/export_dialog.gd:128-133` (add checkbox after WebP checkbox)
- Modify: `src/ui/dialogs/export_dialog.gd:270-275` (include in `get_export_options()`)
- Test: `specs/ui/dialogs/test_export_dialog.gd`

- [ ] **Step 1: Write failing tests**

Add at the end of `specs/ui/dialogs/test_export_dialog.gd`:

```gdscript
# --- APNG statique ---

func test_dialog_has_static_apng_checkbox():
	assert_not_null(_dialog._static_apng_check)
	assert_true(_dialog._static_apng_check is CheckBox)


func test_static_apng_checkbox_unchecked_by_default():
	assert_false(_dialog._static_apng_check.button_pressed)


func test_export_options_include_static_apng_false_by_default():
	var opts = _dialog.get_export_options()
	assert_true(opts.has("static_apng"))
	assert_false(opts["static_apng"])


func test_export_options_include_static_apng_true_when_checked():
	_dialog._static_apng_check.button_pressed = true
	var opts = _dialog.get_export_options()
	assert_true(opts["static_apng"])
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/dialogs/test_export_dialog.gd
```

Expected: FAIL — `_static_apng_check` does not exist.

- [ ] **Step 3: Implement the checkbox**

In `src/ui/dialogs/export_dialog.gd`:

1. Add variable declaration (after line 28, alongside `_webp_check`):

```gdscript
var _static_apng_check: CheckBox
```

2. Add checkbox creation in `_init()` (after the `_webp_check` block, after line 133 `vbox.add_child(_webp_check)`):

```gdscript
# APNG → image fixe
_static_apng_check = CheckBox.new()
_static_apng_check.name = "StaticApngCheck"
_static_apng_check.text = tr("Désactiver les animations (APNG → image fixe)")
_static_apng_check.button_pressed = false
vbox.add_child(_static_apng_check)
```

3. Include in `get_export_options()` (after line 272 `result["webp_conversion"] = ...`):

```gdscript
result["static_apng"] = _static_apng_check.button_pressed
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/dialogs/test_export_dialog.gd
```

Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add src/ui/dialogs/export_dialog.gd specs/ui/dialogs/test_export_dialog.gd
git commit -m "feat(export): add static APNG checkbox in export dialog"
```

---

### Task 2: ExportService — Add `_flatten_apng_files` and `_find_apng_files_recursive`

**Files:**
- Modify: `src/services/export_service.gd` (add two new methods at end of file)
- Test: `specs/services/test_export_service.gd`

- [ ] **Step 1: Write failing tests**

Add at the end of `specs/services/test_export_service.gd`:

```gdscript
# --- Tests _flatten_apng_files ---

func _create_test_apng(path: String, color1: Color = Color.RED, color2: Color = Color.BLUE) -> void:
	var frame1 = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	frame1.fill(color1)
	var frame2 = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	frame2.fill(color2)
	var apng_data = ApngBuilder.build([frame1, frame2], 12.0)
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(apng_data)
	f.close()


func _create_flatten_test_dir() -> String:
	var temp_dir = ProjectSettings.globalize_path("user://test_flatten_apng_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_dir + "/assets/foregrounds")
	DirAccess.make_dir_recursive_absolute(temp_dir + "/chapters/ch1/scenes")
	return temp_dir


func test_find_apng_files_recursive():
	var service = ExportServiceScript.new()
	var temp_dir = _create_flatten_test_dir()

	_create_test_apng(temp_dir + "/assets/foregrounds/hero.apng")
	_create_test_apng(temp_dir + "/assets/foregrounds/villain.apng")
	# Non-APNG file (should be ignored)
	_create_test_image(temp_dir + "/assets/foregrounds/static.png", 32, 32)

	var files = service._find_apng_files_recursive(temp_dir)
	var names: Array = []
	for p in files:
		names.append(p.get_file())

	assert_eq(files.size(), 2, "Should find exactly 2 APNG files")
	assert_true("hero.apng" in names, "Should find hero.apng")
	assert_true("villain.apng" in names, "Should find villain.apng")
	assert_false("static.png" in names, "Should not include PNG files")

	service._remove_dir_recursive(temp_dir)


func test_flatten_apng_replaces_with_png():
	var service = ExportServiceScript.new()
	var temp_dir = _create_flatten_test_dir()
	var log_path = temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	_create_test_apng(temp_dir + "/assets/foregrounds/hero.apng", Color.RED, Color.BLUE)

	# YAML referencing the APNG
	f = FileAccess.open(temp_dir + "/chapters/ch1/scenes/s1.yaml", FileAccess.WRITE)
	f.store_string('sequences:\n  - foregrounds:\n      - image: "assets/foregrounds/hero.apng"\n')
	f.close()

	service._flatten_apng_files(temp_dir, log_path)

	# APNG should be deleted
	assert_false(FileAccess.file_exists(temp_dir + "/assets/foregrounds/hero.apng"), "APNG should be deleted")
	# PNG should exist
	assert_true(FileAccess.file_exists(temp_dir + "/assets/foregrounds/hero.png"), "PNG should be created")

	service._remove_dir_recursive(temp_dir)


func test_flatten_apng_creates_valid_first_frame_png():
	var service = ExportServiceScript.new()
	var temp_dir = _create_flatten_test_dir()
	var log_path = temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	_create_test_apng(temp_dir + "/assets/foregrounds/hero.apng", Color.RED, Color.BLUE)

	service._flatten_apng_files(temp_dir, log_path)

	# The resulting PNG should be loadable and match the first frame (RED)
	var img = Image.new()
	assert_eq(img.load(temp_dir + "/assets/foregrounds/hero.png"), OK, "PNG should be loadable")
	assert_eq(img.get_width(), 32, "Width should match")
	assert_eq(img.get_height(), 32, "Height should match")
	var pixel = img.get_pixel(16, 16)
	assert_almost_eq(pixel.r, 1.0, 0.01, "First frame should be red (R)")
	assert_almost_eq(pixel.g, 0.0, 0.01, "First frame should be red (G)")
	assert_almost_eq(pixel.b, 0.0, 0.01, "First frame should be red (B)")

	service._remove_dir_recursive(temp_dir)


func test_flatten_apng_updates_yaml_refs():
	var service = ExportServiceScript.new()
	var temp_dir = _create_flatten_test_dir()
	var log_path = temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	_create_test_apng(temp_dir + "/assets/foregrounds/hero.apng")

	f = FileAccess.open(temp_dir + "/chapters/ch1/scenes/s1.yaml", FileAccess.WRITE)
	f.store_string('sequences:\n  - foregrounds:\n      - image: "assets/foregrounds/hero.apng"\n        anim_speed: 1.5\n        anim_loop: true\n')
	f.close()

	service._flatten_apng_files(temp_dir, log_path)

	var content = FileAccess.get_file_as_string(temp_dir + "/chapters/ch1/scenes/s1.yaml")
	assert_true(content.find("hero.png") >= 0, "YAML should reference hero.png")
	assert_true(content.find("hero.apng") < 0, "YAML should no longer reference hero.apng")

	service._remove_dir_recursive(temp_dir)


func test_flatten_apng_smaller_than_original():
	var service = ExportServiceScript.new()
	var temp_dir = _create_flatten_test_dir()
	var log_path = temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	_create_test_apng(temp_dir + "/assets/foregrounds/hero.apng")

	var fa = FileAccess.open(temp_dir + "/assets/foregrounds/hero.apng", FileAccess.READ)
	var apng_size = fa.get_length()
	fa.close()

	service._flatten_apng_files(temp_dir, log_path)

	fa = FileAccess.open(temp_dir + "/assets/foregrounds/hero.png", FileAccess.READ)
	var png_size = fa.get_length()
	fa.close()

	assert_true(png_size < apng_size, "Static PNG (%d) should be smaller than APNG (%d)" % [png_size, apng_size])

	service._remove_dir_recursive(temp_dir)


func test_flatten_apng_no_apng_files_does_nothing():
	var service = ExportServiceScript.new()
	var temp_dir = _create_flatten_test_dir()
	var log_path = temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	# Only static images, no APNG
	_create_test_image(temp_dir + "/assets/foregrounds/hero.png", 32, 32)

	service._flatten_apng_files(temp_dir, log_path)

	# PNG should be untouched
	assert_true(FileAccess.file_exists(temp_dir + "/assets/foregrounds/hero.png"), "PNG should still exist")

	service._remove_dir_recursive(temp_dir)
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_export_service.gd -ginclude_subdirs
```

Expected: FAIL — `_flatten_apng_files` and `_find_apng_files_recursive` do not exist.

- [ ] **Step 3: Implement the two methods**

Add at the end of `src/services/export_service.gd` (before the closing of the file):

```gdscript
## Aplatit les fichiers APNG en PNG statiques (première frame).
## Supprime les .apng et met à jour les références YAML.
func _flatten_apng_files(story_dir: String, log_path: String) -> void:
	var apng_files = _find_apng_files_recursive(story_dir)
	if apng_files.is_empty():
		return

	_append_log(log_path, "→ Aplatissement APNG → PNG (%d fichiers)..." % apng_files.size())

	var total_original_size := 0
	var total_png_size := 0
	var converted_count := 0
	var conversions: Dictionary = {}  # old_filename -> new_filename

	for apng_path in apng_files:
		var fa = FileAccess.open(apng_path, FileAccess.READ)
		if fa == null:
			_append_log(log_path, "  ⚠ Impossible d'ouvrir : " + apng_path.get_file())
			continue
		var original_size = fa.get_length()
		var data = fa.get_buffer(original_size)
		fa.close()

		var img = Image.new()
		if img.load_png_from_buffer(data) != OK:
			_append_log(log_path, "  ⚠ Impossible de charger : " + apng_path.get_file())
			continue

		var png_path = apng_path.get_basename() + ".png"
		if img.save_png(png_path) != OK:
			_append_log(log_path, "  ⚠ Échec sauvegarde : " + png_path.get_file())
			continue

		DirAccess.remove_absolute(apng_path)
		conversions[apng_path.get_file()] = png_path.get_file()

		var new_size := 0
		var fa2 = FileAccess.open(png_path, FileAccess.READ)
		if fa2:
			new_size = fa2.get_length()
			fa2.close()

		total_original_size += original_size
		total_png_size += new_size
		converted_count += 1

	if converted_count > 0:
		_replace_filenames_in_yaml(story_dir, conversions, log_path)

	if total_original_size > 0:
		var savings = 100.0 * (1.0 - float(total_png_size) / float(total_original_size))
		_append_log(log_path, "  → %d APNG aplatis : %.1f Mo → %.1f Mo (−%.0f%%)" % [
			converted_count,
			total_original_size / 1048576.0,
			total_png_size / 1048576.0,
			savings
		])


## Parcourt récursivement un dossier et retourne les chemins de tous les fichiers .apng.
func _find_apng_files_recursive(dir_path: String) -> Array:
	var result = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = dir_path + "/" + file_name
			if dir.current_is_dir():
				result.append_array(_find_apng_files_recursive(full_path))
			elif file_name.get_extension().to_lower() == "apng":
				result.append(full_path)
		file_name = dir.get_next()
	return result
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_export_service.gd -ginclude_subdirs
```

Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add src/services/export_service.gd specs/services/test_export_service.gd
git commit -m "feat(export): add _flatten_apng_files to convert APNG to static PNG"
```

---

### Task 3: ExportService — Wire `_flatten_apng_files` into the export pipeline

**Files:**
- Modify: `src/services/export_service.gd:99-114` (add call between unused assets removal and resize)

- [ ] **Step 1: Add the call in `export_story()`**

In `src/services/export_service.gd`, insert after line 103 (`_remove_unused_assets(abs_temp_story, log_path)`) and before line 105 (`# 3b. Redimensionner les images`):

```gdscript
	# 3b-extra. Aplatir les APNG en PNG statiques (première frame)
	var static_apng: bool = export_options.get("static_apng", false)
	if static_apng:
		_flatten_apng_files(abs_temp_story, log_path)
```

- [ ] **Step 2: Run the full export service tests**

Run:
```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_export_service.gd -ginclude_subdirs
```

Expected: ALL PASS (no regression).

- [ ] **Step 3: Run the export dialog tests**

Run:
```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/dialogs/test_export_dialog.gd
```

Expected: ALL PASS (no regression).

- [ ] **Step 4: Commit**

```bash
git add src/services/export_service.gd
git commit -m "feat(export): wire static APNG option into export pipeline"
```

---

### Task 4: Final validation

- [ ] **Step 1: Run all export-related tests**

Run:
```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/dialogs/test_export_dialog.gd
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_export_service.gd
```

Expected: ALL PASS.

- [ ] **Step 2: Run `/check-global-acceptance`**

This is the final task — run the full validation suite.
