# Onglet "Décliner - Zimage" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer l'onglet "Assembler" dans le plugin AI Studio par un onglet "Décliner - Zimage" utilisant le modèle Zimage Turbo bf16 en mode img2img avec suppression de fond BiRefNet.

**Architecture:** Nouveau `WorkflowType.ZIMAGE_DECLINER = 11` dans `comfyui_client.gd` avec `_build_zimage_decliner_workflow()` basé sur `UPSCALE_ENHANCE_WORKFLOW_TEMPLATE` (Zimage Turbo déjà présent) sans les nœuds upscale, + BiRefNet en sortie. Nouveau fichier tab `ai_studio_zimage_decliner_tab.gd` basé sur Décliner (sans LORAs, sans 2ème image, avec slider Denoise). `ai_studio_dialog.gd` remplace toutes les refs Assembler.

**Tech Stack:** GDScript 4.6, ComfyUI workflow (JSON), GUT 9.3.0 pour les tests.

---

## Fichiers touchés

| Fichier | Action |
|---|---|
| `src/services/comfyui_client.gd` | Modifier : + enum ZIMAGE_DECLINER, + branch build_workflow, + _build_zimage_decliner_workflow() |
| `specs/services/test_comfyui_client.gd` | Modifier : + tests ZIMAGE_DECLINER |
| `plugins/ai_studio/ai_studio_zimage_decliner_tab.gd` | Créer |
| `plugins/ai_studio/ai_studio_dialog.gd` | Modifier : remplace Assembler → ZimageDecliner |
| `plugins/ai_studio/ai_studio_assembler_tab.gd` | Supprimer |
| `plugins/ai_studio/ai_studio_assembler_tab.gd.uid` | Supprimer |

---

### Task 1 : TDD – WorkflowType.ZIMAGE_DECLINER dans comfyui_client.gd

**Files:**
- Modify: `specs/services/test_comfyui_client.gd` (ajouter tests après la section Assembler)
- Modify: `src/services/comfyui_client.gd:19` (enum), `~:907` (build_workflow), `~:1037` (nouvelle fonction)

- [ ] **Step 1 : Écrire les tests qui échoueront**

Ajouter à la fin de `specs/services/test_comfyui_client.gd` (après le dernier test Assembler, vers la ligne 601) :

```gdscript
# --- Zimage Decliner workflow ---

func test_build_zimage_decliner_workflow_uses_zimage_model():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "portrait", 1, true, 1.0, 5,
		ComfyUIClientScript.WorkflowType.ZIMAGE_DECLINER, 0.2)
	assert_eq(wf["87:66"]["inputs"]["unet_name"], "z_image_turbo_bf16.safetensors")

func test_build_zimage_decliner_workflow_no_upscale_nodes():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "portrait", 1, true, 1.0, 5,
		ComfyUIClientScript.WorkflowType.ZIMAGE_DECLINER, 0.2)
	assert_false(wf.has("87:76"), "UpscaleModelLoader doit être absent")
	assert_false(wf.has("87:79"), "ImageUpscaleWithModel doit être absent")
	assert_false(wf.has("87:81"), "ImageScaleBy doit être absent")

func test_build_zimage_decliner_workflow_is_img2img():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "portrait", 1, true, 1.0, 5,
		ComfyUIClientScript.WorkflowType.ZIMAGE_DECLINER, 0.2)
	assert_eq(wf["87:80"]["inputs"]["pixels"], ["87:78", 0])
	assert_eq(wf["87:78"]["inputs"]["image"], ["77", 0])

func test_build_zimage_decliner_workflow_denoise_injected():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "portrait", 1, true, 1.0, 5,
		ComfyUIClientScript.WorkflowType.ZIMAGE_DECLINER, 0.35)
	assert_eq(wf["87:69"]["inputs"]["denoise"], 0.35)

func test_build_zimage_decliner_workflow_megapixels_injected():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "portrait", 1, true, 1.0, 5,
		ComfyUIClientScript.WorkflowType.ZIMAGE_DECLINER, 0.2, "", 80, 2.0)
	assert_eq(wf["87:78"]["inputs"]["megapixels"], 2.0)

func test_build_zimage_decliner_workflow_has_birefnet():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "portrait", 1, true, 1.0, 5,
		ComfyUIClientScript.WorkflowType.ZIMAGE_DECLINER, 0.2)
	assert_true(wf.has("zd:birefnet"), "Nœud BiRefNet doit être présent")
	assert_eq(wf["zd:birefnet"]["class_type"], "BiRefNetRMBG")
	assert_eq(wf["zd:birefnet"]["inputs"]["image"], ["87:65", 0])
	assert_eq(wf["9"]["inputs"]["images"], ["zd:birefnet", 0])

func test_build_zimage_decliner_workflow_sets_image_and_prompt():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("hero.png", "close up face", 42, true, 1.0, 5,
		ComfyUIClientScript.WorkflowType.ZIMAGE_DECLINER, 0.2)
	assert_eq(wf["77"]["inputs"]["image"], "hero.png")
	assert_eq(wf["87:67"]["inputs"]["text"], "close up face")
	assert_eq(wf["87:69"]["inputs"]["seed"], 42)

func test_build_zimage_decliner_workflow_sets_cfg_and_steps():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("t.png", "p", 1, true, 2.5, 8,
		ComfyUIClientScript.WorkflowType.ZIMAGE_DECLINER, 0.2)
	assert_eq(wf["87:69"]["inputs"]["cfg"], 2.5)
	assert_eq(wf["87:69"]["inputs"]["steps"], 8)

func test_build_zimage_decliner_workflow_negative_prompt():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("t.png", "p", 1, true, 1.0, 5,
		ComfyUIClientScript.WorkflowType.ZIMAGE_DECLINER, 0.2, "bad quality")
	assert_eq(wf["87:71"]["inputs"]["text"], "bad quality")
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_comfyui_client.gd 2>&1 | tail -30
```

Attendu : erreurs sur `ZIMAGE_DECLINER` (identifier not declared).

- [ ] **Step 3 : Ajouter ZIMAGE_DECLINER à l'enum**

Dans `src/services/comfyui_client.gd`, ligne 19, remplacer :
```gdscript
enum WorkflowType { CREATION = 0, EXPRESSION = 1, OUTPAINT = 2, UPSCALE = 3, ENHANCE = 4, UPSCALE_ENHANCE = 5, BLINK = 6, INPAINT = 7, LORA_CREATE_FLUX = 8, ILLUSTRIOUS = 9, ASSEMBLER = 10 }
```
par :
```gdscript
enum WorkflowType { CREATION = 0, EXPRESSION = 1, OUTPAINT = 2, UPSCALE = 3, ENHANCE = 4, UPSCALE_ENHANCE = 5, BLINK = 6, INPAINT = 7, LORA_CREATE_FLUX = 8, ILLUSTRIOUS = 9, ASSEMBLER = 10, ZIMAGE_DECLINER = 11 }
```

- [ ] **Step 4 : Ajouter la branche dans build_workflow**

Dans `src/services/comfyui_client.gd`, après la ligne `if workflow_type == WorkflowType.ASSEMBLER:` (qui retourne `_build_assembler_workflow(...)`), et avant `var wf = WORKFLOW_TEMPLATE.duplicate(true)`, ajouter :

```gdscript
	if workflow_type == WorkflowType.ZIMAGE_DECLINER:
		return _build_zimage_decliner_workflow(filename, prompt_text, seed, cfg, steps, denoise, negative_prompt, megapixels)
```

- [ ] **Step 5 : Implémenter _build_zimage_decliner_workflow**

Ajouter cette fonction dans `src/services/comfyui_client.gd` après la fonction `_build_assembler_workflow` (après la ligne `return wf` qui la termine, autour de la ligne 1037) :

```gdscript
func _build_zimage_decliner_workflow(filename: String, prompt_text: String, seed: int, cfg: float, steps: int, denoise: float, negative_prompt: String, megapixels: float) -> Dictionary:
	var wf = UPSCALE_ENHANCE_WORKFLOW_TEMPLATE.duplicate(true)
	# Supprimer les nœuds upscale (non nécessaires pour img2img pur)
	for key in ["87:76", "87:79", "87:81"]:
		wf.erase(key)
	# Rewire VAEEncode : entrée depuis ImageScaleToTotalPixels (mégapixels) directement
	wf["87:80"]["inputs"]["pixels"] = ["87:78", 0]
	# Paramètres dynamiques
	wf["77"]["inputs"]["image"] = filename
	wf["87:67"]["inputs"]["text"] = prompt_text
	wf["87:71"]["inputs"]["text"] = negative_prompt
	wf["87:69"]["inputs"]["seed"] = seed
	wf["87:69"]["inputs"]["steps"] = steps
	wf["87:69"]["inputs"]["cfg"] = cfg
	wf["87:69"]["inputs"]["denoise"] = denoise
	wf["87:78"]["inputs"]["megapixels"] = megapixels
	# BiRefNet pour suppression de fond systématique
	wf["zd:birefnet"] = {
		"class_type": "BiRefNetRMBG",
		"inputs": {
			"model": "BiRefNet-general",
			"mask_blur": 0,
			"mask_offset": 0,
			"invert_output": false,
			"refine_foreground": true,
			"background": "Alpha",
			"background_color": "#222222",
			"image": ["87:65", 0]
		}
	}
	wf["9"]["inputs"]["images"] = ["zd:birefnet", 0]
	return wf
```

- [ ] **Step 6 : Lancer les tests et vérifier qu'ils passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_comfyui_client.gd 2>&1 | tail -30
```

Attendu : tous les tests `test_build_zimage_decliner_*` passent (PASS).

- [ ] **Step 7 : Commit**

```bash
cd src && git add services/comfyui_client.gd && cd ..
cd specs && git add services/test_comfyui_client.gd && cd ..
git add src/services/comfyui_client.gd specs/services/test_comfyui_client.gd
git commit -m "feat: add WorkflowType.ZIMAGE_DECLINER (Zimage Turbo img2img + BiRefNet)"
```

---

### Task 2 : Créer ai_studio_zimage_decliner_tab.gd

**Files:**
- Create: `plugins/ai_studio/ai_studio_zimage_decliner_tab.gd`

- [ ] **Step 1 : Créer le fichier**

Créer `plugins/ai_studio/ai_studio_zimage_decliner_tab.gd` avec ce contenu :

```gdscript
extends RefCounted

const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")
const ImageRenameService = preload("res://src/services/image_rename_service.gd")

# Shared refs (set via initialize)
var _parent_window: Window
var _get_config_fn: Callable
var _neg_input: TextEdit
var _show_preview_fn: Callable
var _open_gallery_fn: Callable
var _save_config_fn: Callable
var _resolve_path_fn: Callable
var _story_base_path: String = ""

# UI widgets
var _source_preview: TextureRect
var _source_path_label: Label
var _choose_source_btn: Button
var _choose_gallery_btn: Button
var _prompt_input: TextEdit
var _cfg_slider: HSlider
var _cfg_value_label: Label
var _cfg_hint: Label
var _steps_slider: HSlider
var _steps_value_label: Label
var _denoise_slider: HSlider
var _denoise_value_label: Label
var _megapixels_slider: HSlider
var _megapixels_value_label: Label
var _generate_btn: Button
var _result_preview: TextureRect
var _status_label: Label
var _progress_bar: ProgressBar
var _name_input: LineEdit
var _save_btn: Button
var _regenerate_btn: Button

# State
var _client: Node = null
var _source_image_path: String = ""
var _generated_image: Image = null


func initialize(
	parent_window: Window,
	get_config_fn: Callable,
	neg_input: TextEdit,
	show_preview_fn: Callable,
	open_gallery_fn: Callable,
	save_config_fn: Callable,
	resolve_path_fn: Callable
) -> void:
	_parent_window = parent_window
	_get_config_fn = get_config_fn
	_neg_input = neg_input
	_show_preview_fn = show_preview_fn
	_open_gallery_fn = open_gallery_fn
	_save_config_fn = save_config_fn
	_resolve_path_fn = resolve_path_fn


func build_tab(tab_container: TabContainer) -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "Décliner - Zimage"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Image source
	var source_label = Label.new()
	source_label.text = "Image source :"
	vbox.add_child(source_label)

	var source_hbox = HBoxContainer.new()
	vbox.add_child(source_hbox)

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

	_source_path_label = Label.new()
	_source_path_label.text = "Aucune image sélectionnée"
	_source_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_hbox.add_child(_source_path_label)

	_choose_source_btn = Button.new()
	_choose_source_btn.text = "Parcourir..."
	_choose_source_btn.pressed.connect(_on_choose_source)
	source_hbox.add_child(_choose_source_btn)

	_choose_gallery_btn = Button.new()
	_choose_gallery_btn.text = "Galerie..."
	_choose_gallery_btn.pressed.connect(_on_choose_from_gallery)
	source_hbox.add_child(_choose_gallery_btn)

	vbox.add_child(HSeparator.new())

	# Prompt
	var prompt_label = Label.new()
	prompt_label.text = "Prompt :"
	vbox.add_child(prompt_label)

	_prompt_input = TextEdit.new()
	_prompt_input.custom_minimum_size.y = 60
	_prompt_input.placeholder_text = "Décrivez l'image à générer..."
	_prompt_input.text_changed.connect(func(): _update_generate_button())
	vbox.add_child(_prompt_input)

	# CFG slider
	var cfg_hbox = HBoxContainer.new()
	cfg_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(cfg_hbox)

	var cfg_label = Label.new()
	cfg_label.text = "CFG :"
	cfg_hbox.add_child(cfg_label)

	_cfg_slider = HSlider.new()
	_cfg_slider.min_value = 1.0
	_cfg_slider.max_value = 30.0
	_cfg_slider.step = 0.5
	_cfg_slider.value = 1.0
	_cfg_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cfg_slider.value_changed.connect(func(val: float):
		_cfg_value_label.text = str(val)
		var has_negative = _neg_input.text.strip_edges() != ""
		update_cfg_hint(has_negative)
	)
	cfg_hbox.add_child(_cfg_slider)

	_cfg_value_label = Label.new()
	_cfg_value_label.text = "1.0"
	_cfg_value_label.custom_minimum_size.x = 32
	cfg_hbox.add_child(_cfg_value_label)

	_cfg_hint = Label.new()
	_cfg_hint.text = "CFG >= 3 requis pour le negative prompt"
	_cfg_hint.add_theme_font_size_override("font_size", 11)
	_cfg_hint.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	_cfg_hint.visible = false
	vbox.add_child(_cfg_hint)

	# Steps slider
	var steps_hbox = HBoxContainer.new()
	steps_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(steps_hbox)

	var steps_label = Label.new()
	steps_label.text = "Steps :"
	steps_hbox.add_child(steps_label)

	_steps_slider = HSlider.new()
	_steps_slider.min_value = 1
	_steps_slider.max_value = 50
	_steps_slider.step = 1
	_steps_slider.value = 5
	_steps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps_slider.value_changed.connect(func(val: float): _steps_value_label.text = str(int(val)))
	steps_hbox.add_child(_steps_slider)

	_steps_value_label = Label.new()
	_steps_value_label.text = "5"
	_steps_value_label.custom_minimum_size.x = 32
	steps_hbox.add_child(_steps_value_label)

	# Denoise slider
	var denoise_hbox = HBoxContainer.new()
	denoise_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(denoise_hbox)

	var denoise_label = Label.new()
	denoise_label.text = "Denoise :"
	denoise_hbox.add_child(denoise_label)

	_denoise_slider = HSlider.new()
	_denoise_slider.min_value = 0.05
	_denoise_slider.max_value = 1.0
	_denoise_slider.step = 0.05
	_denoise_slider.value = 0.2
	_denoise_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_denoise_slider.value_changed.connect(func(val: float): _denoise_value_label.text = str(snapped(val, 0.05)))
	denoise_hbox.add_child(_denoise_slider)

	_denoise_value_label = Label.new()
	_denoise_value_label.text = "0.2"
	_denoise_value_label.custom_minimum_size.x = 32
	denoise_hbox.add_child(_denoise_value_label)

	# Megapixels slider
	var mp_hbox = HBoxContainer.new()
	mp_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(mp_hbox)

	var mp_label = Label.new()
	mp_label.text = "Mégapixels :"
	mp_hbox.add_child(mp_label)

	_megapixels_slider = HSlider.new()
	_megapixels_slider.min_value = 0.5
	_megapixels_slider.max_value = 4.0
	_megapixels_slider.step = 0.5
	_megapixels_slider.value = 1.0
	_megapixels_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_megapixels_slider.value_changed.connect(func(val: float): _megapixels_value_label.text = str(snapped(val, 0.5)))
	mp_hbox.add_child(_megapixels_slider)

	_megapixels_value_label = Label.new()
	_megapixels_value_label.text = "1.0"
	_megapixels_value_label.custom_minimum_size.x = 32
	mp_hbox.add_child(_megapixels_value_label)

	# Generate button
	_generate_btn = Button.new()
	_generate_btn.text = "Générer"
	_generate_btn.disabled = true
	_generate_btn.pressed.connect(_on_generate_pressed)
	vbox.add_child(_generate_btn)

	vbox.add_child(HSeparator.new())

	# Result preview
	_result_preview = TextureRect.new()
	_result_preview.custom_minimum_size = Vector2(200, 200)
	_result_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_result_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_result_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_preview.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _result_preview.texture:
				_show_preview_fn.call(_result_preview.texture, "Résultat IA")
	)
	vbox.add_child(_result_preview)

	# Status
	_status_label = Label.new()
	_status_label.text = ""
	vbox.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.visible = false
	_progress_bar.custom_minimum_size.y = 8
	_progress_bar.indeterminate = true
	vbox.add_child(_progress_bar)

	# Image name
	var name_label = Label.new()
	name_label.text = "Nom de l'image :"
	vbox.add_child(name_label)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Nom du fichier (sans extension)"
	_name_input.editable = false
	vbox.add_child(_name_input)

	# Action buttons
	var action_hbox = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(action_hbox)

	_save_btn = Button.new()
	_save_btn.text = "Sauvegarder"
	_save_btn.disabled = true
	_save_btn.pressed.connect(_on_save_pressed)
	action_hbox.add_child(_save_btn)

	_regenerate_btn = Button.new()
	_regenerate_btn.text = "Regénérer"
	_regenerate_btn.disabled = true
	_regenerate_btn.pressed.connect(_on_generate_pressed)
	action_hbox.add_child(_regenerate_btn)


func setup(story_base_path: String, has_story: bool) -> void:
	_story_base_path = story_base_path
	_choose_gallery_btn.disabled = not has_story


func update_generate_button() -> void:
	_update_generate_button()


func update_cfg_hint(has_negative: bool) -> void:
	if _cfg_hint:
		_cfg_hint.visible = has_negative and _cfg_slider.value < 3.0


func cancel_generation() -> void:
	if _client != null:
		_client.cancel()
		_client.queue_free()
		_client = null


# ========================================================
# Private logic
# ========================================================


func _update_generate_button() -> void:
	if _generate_btn == null:
		return
	var has_url = _get_config_fn.call().get_url() != ""
	var has_prompt = _prompt_input.text.strip_edges() != ""
	var has_source = _source_image_path != ""
	_generate_btn.disabled = not (has_url and has_prompt and has_source)


func _on_choose_source() -> void:
	var dialog = ImageFileDialog.new()
	dialog.file_selected.connect(func(path: String):
		_source_image_path = path
		_source_path_label.text = path.get_file()
		_load_preview(_source_preview, path)
		_update_generate_button()
	)
	_parent_window.add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))


func _on_choose_from_gallery() -> void:
	_open_gallery_fn.call(func(path: String):
		_source_image_path = path
		_source_path_label.text = path.get_file()
		_load_preview(_source_preview, path)
		_update_generate_button()
	)


func _on_generate_pressed() -> void:
	_save_config_fn.call()

	if _client != null:
		_client.cancel()
		_client.queue_free()

	_client = Node.new()
	_client.set_script(ComfyUIClient)
	_parent_window.add_child(_client)

	_client.generation_completed.connect(_on_generation_completed)
	_client.generation_failed.connect(_on_generation_failed)
	_client.generation_progress.connect(_on_generation_progress)

	_generate_btn.disabled = true
	_save_btn.disabled = true
	_regenerate_btn.disabled = true
	_generated_image = null
	_result_preview.texture = null
	_name_input.text = ""
	_name_input.editable = false
	_set_inputs_enabled(false)
	_show_status("Lancement...")

	var config = _get_config_fn.call()
	var neg_prompt = _neg_input.text.strip_edges()
	_client.generate(
		config, _source_image_path, _prompt_input.text,
		true,
		_cfg_slider.value, int(_steps_slider.value),
		ComfyUIClient.WorkflowType.ZIMAGE_DECLINER,
		_denoise_slider.value,
		neg_prompt, 80, _megapixels_slider.value,
		[]
	)


func _on_generation_completed(image: Image) -> void:
	_generated_image = image
	var tex = ImageTexture.create_from_image(image)
	_result_preview.texture = tex
	_show_success("Génération terminée !")
	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	_name_input.text = "ai_" + timestamp
	_name_input.editable = true
	_save_btn.disabled = false
	_regenerate_btn.disabled = false
	_set_inputs_enabled(true)
	_update_generate_button()


func _on_generation_failed(error: String) -> void:
	_show_error("Erreur : " + error)
	_regenerate_btn.disabled = false
	_set_inputs_enabled(true)
	_update_generate_button()


func _on_generation_progress(status: String) -> void:
	_show_status(status)


func _on_save_pressed() -> void:
	if _generated_image == null:
		return

	var img_name = _name_input.text.strip_edges()
	if img_name == "":
		var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
		img_name = "ai_" + timestamp

	var format_error = ImageRenameService.validate_name_format(img_name)
	if format_error != "":
		_show_error(format_error)
		return

	var dir_path = _story_base_path + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path = dir_path + "/" + img_name + ".png"

	if FileAccess.file_exists(file_path):
		var dialog = ConfirmationDialog.new()
		dialog.dialog_text = "L'image « %s » existe déjà.\nVoulez-vous l'écraser ?" % file_path.get_file()
		dialog.ok_button_text = "Écraser"
		_parent_window.add_child(dialog)
		dialog.confirmed.connect(func():
			_do_save(file_path, dir_path)
			dialog.queue_free()
		)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered()
		return

	_do_save(file_path, dir_path)


func _do_save(file_path: String, dir_path: String) -> void:
	_generated_image.save_png(file_path)
	GalleryCacheService.clear_dir(dir_path)
	_show_success("Image sauvegardée : " + file_path.get_file())

	_generated_image = null
	_result_preview.texture = null
	_name_input.text = ""
	_name_input.editable = false
	_save_btn.disabled = true


func _show_status(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_progress_bar.visible = true


func _show_success(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_progress_bar.visible = false


func _show_error(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_progress_bar.visible = false


func _set_inputs_enabled(enabled: bool) -> void:
	_neg_input.editable = enabled
	_prompt_input.editable = enabled
	_choose_source_btn.disabled = not enabled
	_choose_gallery_btn.disabled = not enabled


func _load_preview(tex_rect: TextureRect, path: String) -> void:
	if path == "":
		tex_rect.texture = null
		return
	var img = Image.new()
	if img.load(path) == OK:
		tex_rect.texture = ImageTexture.create_from_image(img)
	else:
		tex_rect.texture = null
```

- [ ] **Step 2 : Commit**

```bash
git add plugins/ai_studio/ai_studio_zimage_decliner_tab.gd
git commit -m "feat: add ai_studio_zimage_decliner_tab (Décliner UI + Zimage Turbo bf16)"
```

---

### Task 3 : Mettre à jour ai_studio_dialog.gd + supprimer les fichiers Assembler

**Files:**
- Modify: `plugins/ai_studio/ai_studio_dialog.gd`
- Delete: `plugins/ai_studio/ai_studio_assembler_tab.gd`
- Delete: `plugins/ai_studio/ai_studio_assembler_tab.gd.uid`

- [ ] **Step 1 : Mettre à jour les imports et la déclaration de tab dans ai_studio_dialog.gd**

Ligne 4 — mettre à jour le commentaire :
```gdscript
## Studio IA : dialogue avancé de génération d'images par IA.
## Onze onglets : Décliner, Décliner - Zimage, Expressions, Blink, Outpainting, Inpaint, Upscale, Enhance, Upscale + Enhance, LORA Generator, Create.
```

Ligne 15 — remplacer :
```gdscript
const AssemblerTab = preload("res://plugins/ai_studio/ai_studio_assembler_tab.gd")
```
par :
```gdscript
const ZimageDeclinerTab = preload("res://plugins/ai_studio/ai_studio_zimage_decliner_tab.gd")
```

Ligne 58 — remplacer :
```gdscript
var _assembler_tab: RefCounted = null
```
par :
```gdscript
var _zimage_decl_tab: RefCounted = null
```

- [ ] **Step 2 : Mettre à jour setup(), _on_close(), _build_ui()**

Dans `setup()` (ligne 87), remplacer :
```gdscript
	_assembler_tab.setup(story_base_path, has_story)
```
par :
```gdscript
	_zimage_decl_tab.setup(story_base_path, has_story)
```

Dans `_on_close()` (ligne 101), remplacer :
```gdscript
	_assembler_tab.cancel_generation()
```
par :
```gdscript
	_zimage_decl_tab.cancel_generation()
```

Dans `_build_ui()` (ligne 180), remplacer :
```gdscript
	_assembler_tab = AssemblerTab.new()
```
par :
```gdscript
	_zimage_decl_tab = ZimageDeclinerTab.new()
```

Dans `_build_ui()` (ligne 191), remplacer `_assembler_tab` par `_zimage_decl_tab` dans le tableau :
```gdscript
	for tab in [_decl_tab, _zimage_decl_tab, _expr_tab, _blink_tab, _outpaint_tab, _inpaint_tab, _upscale_tab, _enhance_tab, _upscale_enhance_tab, _lora_gen_tab, _create_tab]:
```

- [ ] **Step 3 : Mettre à jour _update_all_generate_buttons() et _update_cfg_hints()**

Dans `_update_all_generate_buttons()` (ligne 280), remplacer :
```gdscript
	_assembler_tab.update_generate_button()
```
par :
```gdscript
	_zimage_decl_tab.update_generate_button()
```

Dans `_update_cfg_hints()` (ligne 294), remplacer `_assembler_tab` par `_zimage_decl_tab` dans le tableau :
```gdscript
	for tab in [_decl_tab, _zimage_decl_tab, _expr_tab, _blink_tab, _outpaint_tab, _inpaint_tab, _upscale_tab, _enhance_tab, _upscale_enhance_tab, _lora_gen_tab, _create_tab]:
```

- [ ] **Step 4 : Supprimer les fichiers Assembler orphelins**

```bash
rm plugins/ai_studio/ai_studio_assembler_tab.gd
rm plugins/ai_studio/ai_studio_assembler_tab.gd.uid
```

- [ ] **Step 5 : Lancer tous les tests pour vérifier qu'il n'y a pas de régression**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd 2>&1 | tail -20
```

Attendu : aucune régression, tous les tests passent.

- [ ] **Step 6 : Commit**

```bash
git add plugins/ai_studio/ai_studio_dialog.gd
git rm plugins/ai_studio/ai_studio_assembler_tab.gd plugins/ai_studio/ai_studio_assembler_tab.gd.uid
git commit -m "refactor: replace Assembler tab with Décliner - Zimage tab in AI Studio dialog"
```
