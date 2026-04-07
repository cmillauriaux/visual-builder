# Masque Inpainting — Onglet Décliner — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre à l'utilisateur de dessiner un rectangle sur l'image source dans l'onglet Décliner et de l'utiliser comme masque d'inpainting dans le workflow ComfyUI.

**Architecture:** L'utilisateur dessine un rectangle sur le `TextureRect` de l'image source (via drag souris). Ce rectangle est converti en PNG masque noir/blanc (dimensions = image source), uploadé dans ComfyUI comme une seconde image, et un nouveau `WorkflowType.INPAINT` est construit à partir du template `EXPRESSION_WORKFLOW_TEMPLATE` — en remplaçant la détection de visage par un `LoadImage` du masque, en ajoutant `SetLatentNoiseMask` + `SplitSigmas` pour l'inpainting pixel-perfect, et `ImageCompositeMasked` pour recoller le résultat.

**Tech Stack:** GDScript 4.6.1, ComfyUI API, GUT 9.3.0

---

## Fichiers modifiés

| Fichier | Rôle |
|---------|------|
| `src/services/comfyui_client.gd` | `WorkflowType.INPAINT`, `build_mask_bytes()`, `_build_inpaint_workflow()`, extension de `generate()`, upload chain masque |
| `plugins/ai_studio/ai_studio_decliner_tab.gd` | Section UI masque, dessin rectangle, conversion coords, appel generate() avec masque |
| `specs/services/test_comfyui_client.gd` | Tests pour `build_mask_bytes` et `_build_inpaint_workflow` |

---

## Task 1 : Tests pour build_mask_bytes et _build_inpaint_workflow

**Files:**
- Modify: `specs/services/test_comfyui_client.gd`

- [ ] **Step 1 : Écrire les tests**

Ajouter à la fin de `specs/services/test_comfyui_client.gd` :

```gdscript
func test_build_mask_bytes_returns_png_with_correct_dimensions():
	var client = ComfyUIClientScript.new()
	var bytes = client.build_mask_bytes(Rect2i(10, 10, 20, 20), 50, 40)
	assert_true(bytes.size() > 0)
	var img = Image.new()
	assert_eq(img.load_png_from_buffer(bytes), OK)
	assert_eq(img.get_width(), 50)
	assert_eq(img.get_height(), 40)

func test_build_mask_bytes_white_inside_rect():
	var client = ComfyUIClientScript.new()
	var bytes = client.build_mask_bytes(Rect2i(10, 10, 20, 20), 50, 50)
	var img = Image.new()
	img.load_png_from_buffer(bytes)
	# Centre du rectangle : (20, 20) → blanc
	var center = img.get_pixel(20, 20)
	assert_almost_eq(center.r, 1.0, 0.01)

func test_build_mask_bytes_black_outside_rect():
	var client = ComfyUIClientScript.new()
	var bytes = client.build_mask_bytes(Rect2i(10, 10, 20, 20), 50, 50)
	var img = Image.new()
	img.load_png_from_buffer(bytes)
	# Coin haut-gauche (0,0) → noir
	var corner = img.get_pixel(0, 0)
	assert_almost_eq(corner.r, 0.0, 0.01)

func test_build_mask_bytes_empty_rect_returns_all_black():
	var client = ComfyUIClientScript.new()
	var bytes = client.build_mask_bytes(Rect2i(0, 0, 0, 0), 10, 10)
	var img = Image.new()
	img.load_png_from_buffer(bytes)
	var px = img.get_pixel(5, 5)
	assert_almost_eq(px.r, 0.0, 0.01)

func test_build_inpaint_workflow_has_mask_loader():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask_test.png"
	client._mask_feather = 15
	var wf = client.build_workflow("src.png", "test", 42, true, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_true(wf.has("ip:mask"), "ip:mask node absent")
	assert_eq(wf["ip:mask"]["inputs"]["image"], "mask_test.png")

func test_build_inpaint_workflow_has_set_noise_mask():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	var wf = client.build_workflow("src.png", "test", 42, true, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_true(wf.has("set_noise_mask"), "set_noise_mask absent")
	assert_eq(wf["set_noise_mask"]["inputs"]["samples"][0], "75:79:78")

func test_build_inpaint_workflow_has_split_sigmas():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 10
	var wf = client.build_workflow("src.png", "test", 42, true, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_true(wf.has("split_sigmas"), "split_sigmas absent")

func test_build_inpaint_workflow_no_face_detection():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 10
	var wf = client.build_workflow("src.png", "test", 42, true, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_false(wf.has("99"), "Nœud 99 (face detector) présent mais ne devrait pas l'être")
	assert_false(wf.has("100"), "Nœud 100 (bbox detector) présent mais ne devrait pas l'être")

func test_build_inpaint_workflow_no_feather_removes_blur():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 0
	var wf = client.build_workflow("src.png", "test", 42, true, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_false(wf.has("102"), "Nœud 102 (blur) présent alors que feather=0")
	assert_eq(wf["103"]["inputs"]["mask"][0], "101")

func test_build_inpaint_workflow_with_feather_has_blur():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 20
	var wf = client.build_workflow("src.png", "test", 42, true, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_true(wf.has("102"), "Nœud 102 (blur) absent alors que feather=20")
	assert_eq(wf["103"]["inputs"]["mask"][0], "102")

func test_build_inpaint_workflow_no_bg_removal():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 10
	var wf = client.build_workflow("src.png", "test", 42, false, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_false(wf.has("106"), "106 (BiRefNet) présent mais remove_background=false")
	assert_eq(wf["9"]["inputs"]["images"][0], "103")
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_comfyui_client.gd 2>&1 | tail -30
```

Résultat attendu : tous les nouveaux tests échouent (`FAILED`) car `build_mask_bytes` et `WorkflowType.INPAINT` n'existent pas encore.

---

## Task 2 : Implémenter build_mask_bytes, WorkflowType.INPAINT et _build_inpaint_workflow

**Files:**
- Modify: `src/services/comfyui_client.gd`

- [ ] **Step 1 : Ajouter INPAINT à l'enum et les nouvelles variables d'instance**

Dans `src/services/comfyui_client.gd`, ligne 19 :

```gdscript
# AVANT :
enum WorkflowType { CREATION = 0, EXPRESSION = 1, OUTPAINT = 2, UPSCALE = 3, ENHANCE = 4, UPSCALE_ENHANCE = 5, BLINK = 6 }

# APRÈS :
enum WorkflowType { CREATION = 0, EXPRESSION = 1, OUTPAINT = 2, UPSCALE = 3, ENHANCE = 4, UPSCALE_ENHANCE = 5, BLINK = 6, INPAINT = 7 }
```

Ajouter après la ligne `var _detection_threshold: float = 0.3` (vers ligne 52) :

```gdscript
var _mask_filename: String = ""
var _mask_feather: int = 15
```

- [ ] **Step 2 : Ajouter la méthode build_mask_bytes**

Ajouter après la méthode `is_generating()` (après ligne 663), avant `_inject_loras` :

```gdscript
static func build_mask_bytes(rect: Rect2i, img_width: int, img_height: int) -> PackedByteArray:
	var img = Image.create(img_width, img_height, false, Image.FORMAT_L8)
	img.fill(Color(0.0, 0.0, 0.0))
	if rect.size.x > 0 and rect.size.y > 0:
		var clamped = Rect2i(
			clampi(rect.position.x, 0, img_width - 1),
			clampi(rect.position.y, 0, img_height - 1),
			0, 0
		)
		clamped.size.x = clampi(rect.size.x, 1, img_width - clamped.position.x)
		clamped.size.y = clampi(rect.size.y, 1, img_height - clamped.position.y)
		img.fill_rect(clamped, Color(1.0, 1.0, 1.0))
	return img.save_png_to_buffer()
```

- [ ] **Step 3 : Ajouter _build_inpaint_workflow**

Ajouter après `_build_expression_workflow` (après la ligne 869), avant `_build_blink_workflow` :

```gdscript
func _build_inpaint_workflow(filename: String, mask_filename: String, prompt_text: String, seed: int, remove_background: bool, cfg: float, steps: int, denoise: float, negative_prompt: String, mask_feather: int, megapixels: float, loras: Array) -> Dictionary:
	var wf = EXPRESSION_WORKFLOW_TEMPLATE.duplicate(true)

	# Supprimer la détection de visage
	wf.erase("99")
	wf.erase("100")

	# Charger le masque directement depuis un fichier PNG
	wf["ip:mask"] = {
		"class_type": "LoadImage",
		"inputs": { "image": mask_filename }
	}

	# GrowMask depuis le masque utilisateur
	wf["101"]["inputs"]["mask"] = ["ip:mask", 0]
	wf["101"]["inputs"]["expand"] = mask_feather

	# Fondu des bords du masque
	var final_mask_node: String
	if mask_feather <= 0:
		wf.erase("102")
		final_mask_node = "101"
	else:
		var blur_kernel: int = min(99, max(3, mask_feather)) | 1  # toujours impair
		var blur_sigma: float = minf(50.0, maxf(1.0, mask_feather * 0.5))
		wf["102"]["inputs"]["kernel_size"] = blur_kernel
		wf["102"]["inputs"]["sigma"] = blur_sigma
		final_mask_node = "102"

	# Composite : recoller le résultat sur l'original avec le masque
	wf["103"]["inputs"]["mask"] = [final_mask_node, 0]

	# SetLatentNoiseMask : le KSampler ne dénoise QUE dans la zone masquée
	wf["set_noise_mask"] = {
		"class_type": "SetLatentNoiseMask",
		"inputs": {
			"samples": ["75:79:78", 0],
			"mask": [final_mask_node, 0]
		}
	}
	wf["75:64"]["inputs"]["latent_image"] = ["set_noise_mask", 0]

	# SplitSigmas : contrôle du niveau de débruitage
	var split_step = max(1, roundi(steps * (1.0 - denoise)))
	wf["split_sigmas"] = {
		"class_type": "SplitSigmas",
		"inputs": {
			"sigmas": ["75:62", 0],
			"step": split_step
		}
	}
	wf["75:64"]["inputs"]["sigmas"] = ["split_sigmas", 1]

	# EmptyFlux2LatentImage non utilisé (img2img)
	wf.erase("75:66")

	# Paramètres dynamiques
	wf["76"]["inputs"]["image"] = filename
	wf["75:74"]["inputs"]["text"] = prompt_text
	wf["75:73"]["inputs"]["noise_seed"] = seed
	wf["75:63"]["inputs"]["cfg"] = cfg
	wf["75:62"]["inputs"]["steps"] = steps
	wf["75:80"]["inputs"]["megapixels"] = megapixels

	_apply_negative_prompt(wf, negative_prompt)
	_inject_loras(wf, loras)

	if not remove_background:
		wf["9"]["inputs"]["images"] = ["103", 0]
		wf.erase("106")

	return wf
```

- [ ] **Step 4 : Ajouter le cas INPAINT dans build_workflow**

Dans `build_workflow()` (vers ligne 767), ajouter avant le `var wf = WORKFLOW_TEMPLATE...` final :

```gdscript
	if workflow_type == WorkflowType.INPAINT:
		return _build_inpaint_workflow(filename, _mask_filename, prompt_text, seed, remove_background, cfg, steps, denoise, negative_prompt, _mask_feather, megapixels, loras)
```

- [ ] **Step 5 : Lancer les tests pour vérifier qu'ils passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_comfyui_client.gd 2>&1 | tail -30
```

Résultat attendu : tous les tests passent (`PASSED`).

- [ ] **Step 6 : Commit**

```bash
git add src/services/comfyui_client.gd specs/services/test_comfyui_client.gd
git commit -m "feat(comfyui): add WorkflowType.INPAINT with SetLatentNoiseMask inpainting"
```

---

## Task 3 : Étendre generate() pour le support du masque

**Files:**
- Modify: `src/services/comfyui_client.gd`

- [ ] **Step 1 : Étendre la signature de generate() et initialiser les vars**

Modifier la signature de `generate()` (ligne 1214) pour ajouter deux paramètres à la fin :

```gdscript
# AVANT :
func generate(config: RefCounted, source_image_path: String, prompt_text: String, remove_background: bool = true, cfg: float = 1.0, steps: int = 4, workflow_type: int = WorkflowType.CREATION, denoise: float = 0.5, negative_prompt: String = "", face_box_size: int = 80, megapixels: float = 1.0, loras: Array = [], second_image_path: String = "") -> void:

# APRÈS :
func generate(config: RefCounted, source_image_path: String, prompt_text: String, remove_background: bool = true, cfg: float = 1.0, steps: int = 4, workflow_type: int = WorkflowType.CREATION, denoise: float = 0.5, negative_prompt: String = "", face_box_size: int = 80, megapixels: float = 1.0, loras: Array = [], second_image_path: String = "", mask_bytes: PackedByteArray = PackedByteArray(), mask_feather: int = 15) -> void:
```

Dans le corps de `generate()`, après `_second_image_bytes = PackedByteArray()` (ligne 1232), ajouter :

```gdscript
	_mask_filename = ""
	if not mask_bytes.is_empty():
		_mask_filename = "inpaint_mask_%d.png" % randi()
	_mask_bytes_data = mask_bytes
	_mask_feather = mask_feather
```

Ajouter la variable d'instance `_mask_bytes_data: PackedByteArray = PackedByteArray()` dans la section des vars d'instance (après `_mask_feather`).

- [ ] **Step 2 : Ajouter _do_upload_mask**

Ajouter après `_do_upload_second` (après ligne 1443) :

```gdscript
func _do_upload_mask(prompt_text: String) -> void:
	var multipart = build_multipart_body(_mask_filename, _mask_bytes_data)
	var body_bytes: PackedByteArray = multipart[0]
	var boundary: String = multipart[1]

	var http = HTTPRequest.new()
	add_child(http)

	var url = _config.get_full_url("/upload/image")
	var headers: Array = ["Content-Type: multipart/form-data; boundary=" + boundary]
	for h in _config.get_auth_headers():
		headers.append(h)

	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray):
		http.queue_free()
		if _cancelled:
			_generating = false
			return
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_generating = false
			_fail("Erreur upload masque (code %d, result %d)" % [code, result])
			return
		generation_progress.emit("Masque uploadé. Lancement du workflow...")
		_do_prompt(_source_filename, prompt_text)
	)

	http.request_raw(url, PackedStringArray(headers), HTTPClient.METHOD_POST, body_bytes)
```

- [ ] **Step 3 : Modifier _do_upload pour appeler _do_upload_mask si nécessaire**

Dans le callback de `_do_upload` (vers ligne 1398), modifier la section `request_completed` :

```gdscript
# AVANT :
		if _second_image_filename != "" and not _second_image_bytes.is_empty():
			generation_progress.emit("Upload de l'image 2 vers ComfyUI...")
			_do_upload_second(prompt_text)
		else:
			generation_progress.emit("Image uploadée. Lancement du workflow...")
			_do_prompt(filename, prompt_text)

# APRÈS :
		if _second_image_filename != "" and not _second_image_bytes.is_empty():
			generation_progress.emit("Upload de l'image 2 vers ComfyUI...")
			_do_upload_second(prompt_text)
		elif _mask_filename != "" and not _mask_bytes_data.is_empty():
			generation_progress.emit("Upload du masque vers ComfyUI...")
			_do_upload_mask(prompt_text)
		else:
			generation_progress.emit("Image uploadée. Lancement du workflow...")
			_do_prompt(filename, prompt_text)
```

- [ ] **Step 4 : Modifier _do_upload_second pour appeler _do_upload_mask si nécessaire**

Dans le callback de `_do_upload_second` (vers ligne 1430) :

```gdscript
# AVANT :
		generation_progress.emit("Images uploadées. Lancement du workflow...")
		_do_prompt(_source_filename, prompt_text)

# APRÈS :
		if _mask_filename != "" and not _mask_bytes_data.is_empty():
			generation_progress.emit("Upload du masque vers ComfyUI...")
			_do_upload_mask(prompt_text)
		else:
			generation_progress.emit("Images uploadées. Lancement du workflow...")
			_do_prompt(_source_filename, prompt_text)
```

- [ ] **Step 5 : Ajouter le masque au payload RunPod**

Dans `_do_runpod_run` (vers ligne 1287), après le bloc second image :

```gdscript
# Après :
	if _second_image_filename != "" and not _second_image_bytes.is_empty():
		images_payload.append({"name": _second_image_filename, "image": Marshalls.raw_to_base64(_second_image_bytes)})

# Ajouter :
	if _mask_filename != "" and not _mask_bytes_data.is_empty():
		images_payload.append({"name": _mask_filename, "image": Marshalls.raw_to_base64(_mask_bytes_data)})
```

- [ ] **Step 6 : Lancer les tests pour vérifier qu'aucune régression n'est introduite**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_comfyui_client.gd 2>&1 | tail -20
```

Résultat attendu : tous les tests passent.

- [ ] **Step 7 : Commit**

```bash
git add src/services/comfyui_client.gd
git commit -m "feat(comfyui): extend generate() with optional mask_bytes for inpainting"
```

---

## Task 4 : Ajouter la section Masque dans ai_studio_decliner_tab.gd

**Files:**
- Modify: `plugins/ai_studio/ai_studio_decliner_tab.gd`

- [ ] **Step 1 : Ajouter les variables d'état et de widgets**

Dans la section `# UI widgets` (après `_regenerate_btn`), ajouter :

```gdscript
var _mask_checkbox: CheckBox
var _mask_content: VBoxContainer
var _mask_coords_label: Label
var _mask_feather_slider: HSlider
var _mask_feather_value_label: Label
var _mask_clear_btn: Button
var _mask_overlay: Panel
var _preview_wrapper: Control
```

Dans la section `# State` (après `_lora_widgets`), ajouter :

```gdscript
var _mask_rect: Rect2i = Rect2i()
var _mask_drawing: bool = false
var _mask_draw_start: Vector2 = Vector2.ZERO
var _source_image_size: Vector2i = Vector2i.ZERO
```

- [ ] **Step 2 : Envelopper _source_preview dans un wrapper Control**

Dans `build_tab()`, remplacer la création directe de `_source_preview` dans `source_hbox`. Actuellement (ligne 94) :

```gdscript
	_source_preview = TextureRect.new()
	_source_preview.custom_minimum_size = Vector2(64, 64)
	_source_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_source_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_source_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_source_preview.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _source_preview.texture:
				_show_preview_fn.call(_source_preview.texture, _source_image_path.get_file())
	)
	source_hbox.add_child(_source_preview)
```

Remplacer par :

```gdscript
	_preview_wrapper = Control.new()
	_preview_wrapper.custom_minimum_size = Vector2(64, 64)
	_preview_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_wrapper.clip_contents = true
	source_hbox.add_child(_preview_wrapper)

	_source_preview = TextureRect.new()
	_source_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_source_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_source_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_source_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_source_preview.gui_input.connect(func(event: InputEvent):
		if _mask_checkbox != null and _mask_checkbox.button_pressed and _source_preview.texture != null:
			_handle_mask_input(event)
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _source_preview.texture:
				_show_preview_fn.call(_source_preview.texture, _source_image_path.get_file())
	)
	_preview_wrapper.add_child(_source_preview)

	# Overlay rectangle du masque
	_mask_overlay = Panel.new()
	_mask_overlay.visible = false
	_mask_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask_style = StyleBoxFlat.new()
	mask_style.bg_color = Color(0.2, 0.6, 1.0, 0.15)
	mask_style.border_width_left = 2
	mask_style.border_width_right = 2
	mask_style.border_width_top = 2
	mask_style.border_width_bottom = 2
	mask_style.border_color = Color(0.3, 0.7, 1.0, 1.0)
	_mask_overlay.add_theme_stylebox_override("panel", mask_style)
	_preview_wrapper.add_child(_mask_overlay)
```

- [ ] **Step 3 : Ajouter la section Masque dans le vbox**

Dans `build_tab()`, après le bloc source image (`source_hbox`) et avant `# Prompt`, insérer la section masque. Localiser la ligne `# Prompt` (vers ligne 121) et insérer avant :

```gdscript
	# Masque inpainting (optionnel)
	vbox.add_child(HSeparator.new())
	var mask_header = HBoxContainer.new()
	mask_header.add_theme_constant_override("separation", 8)
	vbox.add_child(mask_header)

	_mask_checkbox = CheckBox.new()
	_mask_checkbox.text = "Masque inpainting"
	_mask_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mask_header.add_child(_mask_checkbox)

	_mask_content = VBoxContainer.new()
	_mask_content.visible = false
	_mask_content.add_theme_constant_override("separation", 4)
	vbox.add_child(_mask_content)

	var mask_hint = Label.new()
	mask_hint.text = "Clique-glisse sur l'aperçu pour définir la zone à régénérer."
	mask_hint.add_theme_font_size_override("font_size", 11)
	mask_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	mask_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mask_content.add_child(mask_hint)

	var mask_coords_row = HBoxContainer.new()
	mask_coords_row.add_theme_constant_override("separation", 8)
	_mask_content.add_child(mask_coords_row)

	var coords_lbl = Label.new()
	coords_lbl.text = "Zone :"
	mask_coords_row.add_child(coords_lbl)

	_mask_coords_label = Label.new()
	_mask_coords_label.text = "—"
	_mask_coords_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mask_coords_row.add_child(_mask_coords_label)

	_mask_clear_btn = Button.new()
	_mask_clear_btn.text = "Effacer"
	_mask_clear_btn.pressed.connect(func():
		_mask_rect = Rect2i()
		_update_mask_overlay()
		_update_mask_coords_label()
	)
	mask_coords_row.add_child(_mask_clear_btn)

	var mask_feather_row = HBoxContainer.new()
	mask_feather_row.add_theme_constant_override("separation", 8)
	_mask_content.add_child(mask_feather_row)

	var feather_lbl = Label.new()
	feather_lbl.text = "Fondu :"
	mask_feather_row.add_child(feather_lbl)

	_mask_feather_slider = HSlider.new()
	_mask_feather_slider.min_value = 0
	_mask_feather_slider.max_value = 100
	_mask_feather_slider.step = 1
	_mask_feather_slider.value = 15
	_mask_feather_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mask_feather_slider.value_changed.connect(func(val: float): _mask_feather_value_label.text = str(int(val)))
	mask_feather_row.add_child(_mask_feather_slider)

	_mask_feather_value_label = Label.new()
	_mask_feather_value_label.text = "15"
	_mask_feather_value_label.custom_minimum_size.x = 28
	mask_feather_row.add_child(_mask_feather_value_label)

	_mask_checkbox.toggled.connect(func(on: bool):
		_mask_content.visible = on
		if not on:
			_mask_rect = Rect2i()
			_update_mask_overlay()
			_update_mask_coords_label()
	)

	vbox.add_child(HSeparator.new())
```

Supprimer le `vbox.add_child(HSeparator.new())` qui se trouvait déjà avant `# Image source 2` (vers ligne 213) car la section masque ajoutera son propre séparateur. Vérifier le résultat final pour éviter les séparateurs en double.

- [ ] **Step 4 : Ajouter les méthodes de gestion du masque**

Ajouter à la fin du fichier (après `_load_preview`) :

```gdscript
func _handle_mask_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mask_drawing = true
			_mask_draw_start = event.position
			_mask_rect = Rect2i()
			_update_mask_overlay()
			_update_mask_coords_label()
		else:
			_mask_drawing = false
	elif event is InputEventMouseMotion and _mask_drawing:
		var p1 = _mask_draw_start
		var p2 = event.position
		var display_rect = Rect2(
			Vector2(minf(p1.x, p2.x), minf(p1.y, p2.y)),
			Vector2(absf(p2.x - p1.x), absf(p2.y - p1.y))
		)
		_mask_rect = _display_rect_to_image_rect(display_rect)
		_update_mask_overlay()
		_update_mask_coords_label()


func _display_rect_to_image_rect(display_rect: Rect2) -> Rect2i:
	if _source_preview.texture == null:
		return Rect2i()
	var tex_size = Vector2(
		_source_preview.texture.get_width(),
		_source_preview.texture.get_height()
	)
	var rect_size = _source_preview.size
	var scale = minf(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	var displayed_size = tex_size * scale
	var img_offset = (rect_size - displayed_size) * 0.5

	var pos_in_img = (display_rect.position - img_offset) / scale
	var size_in_img = display_rect.size / scale

	var ix = clampi(int(pos_in_img.x), 0, int(tex_size.x))
	var iy = clampi(int(pos_in_img.y), 0, int(tex_size.y))
	var iw = clampi(int(size_in_img.x), 0, int(tex_size.x) - ix)
	var ih = clampi(int(size_in_img.y), 0, int(tex_size.y) - iy)
	return Rect2i(ix, iy, iw, ih)


func _update_mask_overlay() -> void:
	if _mask_overlay == null or _source_preview.texture == null:
		if _mask_overlay != null:
			_mask_overlay.visible = false
		return
	if _mask_rect.size.x == 0 or _mask_rect.size.y == 0:
		_mask_overlay.visible = false
		return
	var tex_size = Vector2(
		_source_preview.texture.get_width(),
		_source_preview.texture.get_height()
	)
	var rect_size = _source_preview.size
	var scale = minf(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	var displayed_size = tex_size * scale
	var img_offset = (rect_size - displayed_size) * 0.5

	_mask_overlay.position = Vector2(_mask_rect.position) * scale + img_offset
	_mask_overlay.size = Vector2(_mask_rect.size) * scale
	_mask_overlay.visible = true


func _update_mask_coords_label() -> void:
	if _mask_coords_label == null:
		return
	if _mask_rect.size.x == 0:
		_mask_coords_label.text = "—"
	else:
		_mask_coords_label.text = "x: %d  y: %d  l: %d  h: %d" % [
			_mask_rect.position.x, _mask_rect.position.y,
			_mask_rect.size.x, _mask_rect.size.y
		]
```

- [ ] **Step 5 : Mettre à jour _load_preview pour capturer les dimensions de l'image source**

Modifier `_load_preview` (fin du fichier) :

```gdscript
func _load_preview(tex_rect: TextureRect, path: String) -> void:
	if path == "":
		tex_rect.texture = null
		return
	var img = Image.new()
	if img.load(path) == OK:
		tex_rect.texture = ImageTexture.create_from_image(img)
		if tex_rect == _source_preview:
			_source_image_size = Vector2i(img.get_width(), img.get_height())
			# Réinitialiser le masque quand on change l'image source
			_mask_rect = Rect2i()
			_update_mask_overlay()
			_update_mask_coords_label()
	else:
		tex_rect.texture = null
```

- [ ] **Step 6 : Commit**

```bash
git add plugins/ai_studio/ai_studio_decliner_tab.gd
git commit -m "feat(decliner): add mask inpainting UI with rectangle draw overlay"
```

---

## Task 5 : Brancher le masque dans _on_generate_pressed()

**Files:**
- Modify: `plugins/ai_studio/ai_studio_decliner_tab.gd`

- [ ] **Step 1 : Modifier _on_generate_pressed pour utiliser le masque**

Dans `_on_generate_pressed()`, remplacer les lignes :

```gdscript
	var cfg_value = _cfg_slider.value
	var steps_value = int(_steps_slider.value)
	var workflow_type: int = ComfyUIClient.WorkflowType.CREATION
	var neg_prompt = _neg_input.text.strip_edges()
	_client.generate(config, _source_image_path, _prompt_input.text, true, cfg_value, steps_value, workflow_type, 0.5, neg_prompt, 80, _megapixels_slider.value, _get_selected_loras(), _source_image2_path)
```

Par :

```gdscript
	var cfg_value = _cfg_slider.value
	var steps_value = int(_steps_slider.value)
	var workflow_type: int = ComfyUIClient.WorkflowType.CREATION
	var neg_prompt = _neg_input.text.strip_edges()
	var mask_bytes = PackedByteArray()
	var mask_feather = 15
	if _mask_checkbox != null and _mask_checkbox.button_pressed and _mask_rect.size.x > 0 and _source_image_size.x > 0:
		mask_bytes = ComfyUIClient.build_mask_bytes(_mask_rect, _source_image_size.x, _source_image_size.y)
		mask_feather = int(_mask_feather_slider.value)
		workflow_type = ComfyUIClient.WorkflowType.INPAINT
	_client.generate(config, _source_image_path, _prompt_input.text, true, cfg_value, steps_value, workflow_type, 0.5, neg_prompt, 80, _megapixels_slider.value, _get_selected_loras(), _source_image2_path, mask_bytes, mask_feather)
```

- [ ] **Step 2 : Désactiver le bouton Effacer pendant la génération**

Dans `_set_inputs_enabled()`, ajouter à la fin :

```gdscript
	if _mask_clear_btn != null:
		_mask_clear_btn.disabled = not enabled
```

- [ ] **Step 3 : Lancer tous les tests unitaires**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd 2>&1 | tail -20
```

Résultat attendu : tous les tests passent sans régression.

- [ ] **Step 4 : Commit**

```bash
git add plugins/ai_studio/ai_studio_decliner_tab.gd
git commit -m "feat(decliner): wire mask inpainting into generate() call"
```

---

## Task 6 : Validation finale

**Files:** aucun (validation uniquement)

- [ ] **Step 1 : Lancer la validation globale**

```bash
# Depuis le terminal Claude Code :
/check-global-acceptance
```

- [ ] **Step 2 : Vérification visuelle (si possible)**

Lancer l'éditeur Godot et ouvrir le plugin AI Studio :
1. Ouvrir l'onglet Décliner
2. Charger une image source → la case "Masque inpainting" doit apparaître
3. Cocher la case → la section masque se déplie
4. Cliquer-glisser sur l'aperçu → un rectangle bleu semi-transparent doit apparaître
5. Les coordonnées doivent s'actualiser en temps réel
6. Cliquer "Effacer" → le rectangle disparaît
7. Décocher → la section se replie et le masque est réinitialisé

- [ ] **Step 3 : Commit final si tout est vert**

```bash
git add -u
git commit -m "chore: finalize inpainting mask feature in Décliner tab"
```
